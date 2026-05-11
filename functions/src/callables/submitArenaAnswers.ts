import {
  FieldValue,
  getFirestore,
  Timestamp,
  type Firestore,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";

import {ARENA_ANSWER_WINDOW_MS, QUESTIONS_PER_ARENA} from "../arena/shared";

type RawAnswer = {
  q_index: number;
  selected_index: number | null;
  submitted_at_ms: number;
};

type SubmitArenaRequest = {
  arena_id?: unknown;
  answers?: unknown;
};

type SubmitArenaResponse = {
  success: true;
  scored: true;
  correct_count: number;
  total_answer_ms: number;
};

const ANSWER_CAP_MS = ARENA_ANSWER_WINDOW_MS;

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
  if (si === -1) {
    return true;
  }
  if (typeof si !== "number" || !Number.isInteger(si)) {
    return false;
  }
  return si >= 0 && si <= 3;
}

function normalizeSelectedIndex(
  si: number | null,
): number | null {
  if (si === null) {
    return null;
  }
  if (si === -1) {
    return null;
  }
  return si;
}

function validateAnswers(raw: unknown): RawAnswer[] {
  if (!Array.isArray(raw)) {
    throw new HttpsError(
      "invalid-argument",
      "answers must be an array of { q_index, selected_index, submitted_at_ms }.",
    );
  }
  if (raw.length !== QUESTIONS_PER_ARENA) {
    throw new HttpsError(
      "invalid-argument",
      `answers length must be exactly ${QUESTIONS_PER_ARENA}.`,
    );
  }
  if (!raw.every(isAnswerEntry)) {
    throw new HttpsError(
      "invalid-argument",
      "each answer needs integer q_index 0..9, selected_index 0..3 or null or -1 (skip), and submitted_at_ms.",
    );
  }
  const seen = new Set<number>();
  for (const a of raw) {
    if (a.q_index < 0 || a.q_index > QUESTIONS_PER_ARENA - 1) {
      throw new HttpsError(
        "invalid-argument",
        `q_index must be in 0..${QUESTIONS_PER_ARENA - 1}.`,
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
  for (let q = 0; q < QUESTIONS_PER_ARENA; q++) {
    if (!seen.has(q)) {
      throw new HttpsError(
        "invalid-argument",
        "answers must include every q_index 0..9.",
      );
    }
  }
  return raw as RawAnswer[];
}

function arenaQuestionRef(db: Firestore, arenaId: string, q: number) {
  return db
    .collection("arena_questions")
    .doc(arenaId)
    .collection("q")
    .doc(String(q));
}

async function computeArenaScore(
  db: Firestore,
  arenaId: string,
  answers: RawAnswer[],
): Promise<{correctCount: number; totalAnswerMs: number}> {
  const byQ = new Map<
    number,
    {selected_index: number | null; submitted_at_ms: number}
  >();
  for (const a of answers) {
    byQ.set(a.q_index, {
      selected_index: normalizeSelectedIndex(a.selected_index),
      submitted_at_ms: a.submitted_at_ms,
    });
  }

  let correctCount = 0;
  let totalAnswerMs = 0;

  for (let q = 0; q < QUESTIONS_PER_ARENA; q++) {
    const qSnap = await arenaQuestionRef(db, arenaId, q).get();
    if (!qSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        `arena_question_missing:${q}`,
      );
    }
    const startedAt = qSnap.get("started_at") as Timestamp | undefined;
    if (!startedAt) {
      throw new HttpsError(
        "failed-precondition",
        `arena_question_missing_started_at:${q}`,
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

export const submitArenaAnswers = onCall<
  SubmitArenaRequest,
  Promise<SubmitArenaResponse>
>(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }

    const arenaIdRaw = request.data?.arena_id;
    const arenaId =
      typeof arenaIdRaw === "string" ? arenaIdRaw.trim() : "";
    if (!arenaId) {
      throw new HttpsError("invalid-argument", "invalid_arena_id");
    }

    const answers = validateAnswers(request.data?.answers);

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "banned");
    }

    const arenaRef = db.collection("arenas").doc(arenaId);
    const arenaSnap = await arenaRef.get();
    if (!arenaSnap.exists) {
      throw new HttpsError("not-found", "arena_not_found");
    }
    if (arenaSnap.get("status") !== "ended") {
      throw new HttpsError(
        "failed-precondition",
        "arena_not_ended",
      );
    }

    const partRef = db
      .collection("arena_participants")
      .doc(arenaId)
      .collection("users")
      .doc(uid);
    const partSnap = await partRef.get();
    if (!partSnap.exists) {
      throw new HttpsError("permission-denied", "not_a_participant");
    }

    const resultRef = db
      .collection("arena_results")
      .doc(arenaId)
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
        `[submitArenaAnswers] arenaId=${arenaId} uid=${uid} already scored`,
      );
      return {
        success: true,
        scored: true,
        correct_count: correctCount,
        total_answer_ms: totalAnswerMs,
      };
    }

    const {correctCount, totalAnswerMs} = await computeArenaScore(
      db,
      arenaId,
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
