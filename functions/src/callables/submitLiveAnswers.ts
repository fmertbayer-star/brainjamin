import {
  FieldValue,
  getFirestore,
  Timestamp,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";

type RawAnswer = {
  q_index: number;
  selected_index: number | null;
  submitted_at_ms: number;
};

type SubmitLiveRequest = {
  ltId?: string;
  answers?: unknown;
};

type SubmitLiveResponse = {
  success: true;
  scored: true;
  correct_count: number;
  total_answer_ms: number;
};

const QUESTIONS = 20;
const ANSWER_CAP_MS = 15_000;

function isAnswerEntry(x: unknown): x is RawAnswer {
  if (x === null || typeof x !== "object") {
    return false;
  }
  const o = x as Record<string, unknown>;
  if (
    typeof o.q_index !== "number" ||
    !Number.isInteger(o.q_index) ||
    typeof o.submitted_at_ms !== "number"
  ) {
    return false;
  }
  const si = o.selected_index;
  if (si === null) {
    return true;
  }
  if (typeof si !== "number" || !Number.isInteger(si)) {
    return false;
  }
  return si >= 0 && si <= 3;
}

function validateAnswers(raw: unknown): RawAnswer[] {
  if (!Array.isArray(raw)) {
    throw new HttpsError(
      "invalid-argument",
      "answers must be an array of { q_index, selected_index, submitted_at_ms }.",
    );
  }
  if (raw.length > QUESTIONS) {
    throw new HttpsError(
      "invalid-argument",
      `answers length must be at most ${QUESTIONS}.`,
    );
  }
  if (!raw.every(isAnswerEntry)) {
    throw new HttpsError(
      "invalid-argument",
      "each answer needs integer q_index 0..19, selected_index 0..3 or null, and submitted_at_ms.",
    );
  }
  const seen = new Set<number>();
  for (const a of raw) {
    if (a.q_index < 0 || a.q_index > QUESTIONS - 1) {
      throw new HttpsError(
        "invalid-argument",
        `q_index must be in 0..${QUESTIONS - 1}.`,
      );
    }
    if (seen.has(a.q_index)) {
      throw new HttpsError(
        "invalid-argument",
        "answers: duplicate q_index.",
      );
    }
    seen.add(a.q_index);
  }
  return raw as RawAnswer[];
}

function liveQuestionRef(db: Firestore, ltId: string, q: number) {
  return db.collection("live_questions").doc(ltId).collection("q").doc(String(q));
}

async function computeLiveScore(
  db: Firestore,
  ltId: string,
  answers: RawAnswer[],
): Promise<{correctCount: number; totalAnswerMs: number}> {
  const byQ = new Map<
    number,
    {selected_index: number | null; submitted_at_ms: number}
  >();
  for (const a of answers) {
    byQ.set(a.q_index, {
      selected_index: a.selected_index,
      submitted_at_ms: a.submitted_at_ms,
    });
  }

  let correctCount = 0;
  let totalAnswerMs = 0;

  for (let q = 0; q < QUESTIONS; q++) {
    const qSnap = await liveQuestionRef(db, ltId, q).get();
    if (!qSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        `live_question_missing:${q}`,
      );
    }
    const startedAt = qSnap.get("started_at") as Timestamp | undefined;
    if (!startedAt) {
      throw new HttpsError(
        "failed-precondition",
        `live_question_missing_started_at:${q}`,
      );
    }
    const correctIndexRaw = qSnap.get("correct_index");
    const trustedCorrect =
      typeof correctIndexRaw === "number" &&
      correctIndexRaw >= 0 &&
      correctIndexRaw <= 3 ?
        correctIndexRaw :
        null;

    const entry = byQ.get(q);
    if (!entry || entry.selected_index === null) {
      totalAnswerMs += ANSWER_CAP_MS;
      continue;
    }

    if (
      trustedCorrect !== null &&
      entry.selected_index === trustedCorrect
    ) {
      correctCount++;
    }

    const rawElapsed =
      entry.submitted_at_ms - startedAt.toMillis();
    const elapsedMs = Math.min(
      ANSWER_CAP_MS,
      Math.max(0, rawElapsed),
    );
    totalAnswerMs += elapsedMs;
  }

  return {correctCount, totalAnswerMs};
}

export const submitLiveAnswers = onCall<SubmitLiveRequest, Promise<SubmitLiveResponse>>(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const ltId = request.data?.ltId?.trim();
    if (!ltId) {
      throw new HttpsError("invalid-argument", "ltId is required.");
    }

    const answers = validateAnswers(request.data?.answers);

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "Account is banned.");
    }

    const liveRef = db.collection("live_tournaments").doc(ltId);
    const liveSnap = await liveRef.get();
    if (!liveSnap.exists) {
      throw new HttpsError("not-found", "live_tournament_not_found");
    }
    if (liveSnap.get("status") !== "ended") {
      throw new HttpsError(
        "failed-precondition",
        "live_tournament_not_ended",
      );
    }

    const partRef = db
      .collection("live_participants")
      .doc(ltId)
      .collection("users")
      .doc(uid);
    const partSnap = await partRef.get();
    if (!partSnap.exists) {
      throw new HttpsError("failed-precondition", "not_a_participant");
    }

    const resultRef = db
      .collection("live_results")
      .doc(ltId)
      .collection("users")
      .doc(uid);
    const existingResult = await resultRef.get();
    if (existingResult.exists && existingResult.get("scored") === true) {
      const ccRaw = existingResult.get("correct_count");
      const tamRaw = existingResult.get("total_answer_ms");
      const correctCount =
        typeof ccRaw === "number" && Number.isFinite(ccRaw) ? ccRaw : 0;
      const totalAnswerMs =
        typeof tamRaw === "number" && Number.isFinite(tamRaw) ? tamRaw : 0;
      logger.info(
        `[submitLiveAnswers] ltId=${ltId} uid=${uid} already scored`,
      );
      return {
        success: true,
        scored: true,
        correct_count: correctCount,
        total_answer_ms: totalAnswerMs,
      };
    }

    const {correctCount, totalAnswerMs} = await computeLiveScore(
      db,
      ltId,
      answers,
    );

    await resultRef.set({
      uid,
      correct_count: correctCount,
      total_answer_ms: totalAnswerMs,
      raw_answers: answers,
      submitted_at: FieldValue.serverTimestamp(),
      scored: true,
      rank: null,
      xp_awarded: null,
      xp_granted_at: null,
    });

    return {
      success: true,
      scored: true,
      correct_count: correctCount,
      total_answer_ms: totalAnswerMs,
    };
  },
);
