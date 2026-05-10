import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  CLASSIC_TOURNAMENT_QUESTION_COUNT,
  computeClassicScore,
} from "../shared/classicScoring";

function validateAnswers(raw: unknown): number[] {
  if (!Array.isArray(raw) || raw.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT) {
    throw new HttpsError(
      "invalid-argument",
      `answers must be an array of length ${CLASSIC_TOURNAMENT_QUESTION_COUNT}.`,
    );
  }
  const out: number[] = [];
  for (let i = 0; i < CLASSIC_TOURNAMENT_QUESTION_COUNT; i++) {
    const v = raw[i];
    if (
      typeof v !== "number" ||
      !Number.isInteger(v) ||
      v < 0 ||
      v > 3
    ) {
      throw new HttpsError(
        "invalid-argument",
        "each answer must be an integer 0-3.",
      );
    }
    out.push(v);
  }
  return out;
}

export const submitClassicTournamentAnswers = onCall<
  {slotId?: string; answers?: unknown},
  Promise<{
    correctCount: number;
    sessionStatus: "submitted";
    submittedAt: Timestamp;
  }>
>(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const slotId = request.data?.slotId?.trim();
    if (!slotId) {
      throw new HttpsError("invalid-argument", "slotId is required.");
    }

    const answers = validateAnswers(request.data?.answers);

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "Account is banned.");
    }

    const sessionId = `${slotId}_${uid}`;
    const sessionRef = db.collection("tournament_sessions").doc(sessionId);
    const tournamentRef = db.collection("tournaments").doc(slotId);

    await db.runTransaction(async (tx) => {
      const sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          "session_missing_fetch_first",
        );
      }
      const sessionData = sessionSnap.data()!;
      if (sessionData.status === "submitted") {
        throw new HttpsError(
          "already-exists",
          "answers_already_submitted",
        );
      }
      if (sessionData.status !== "in_progress") {
        throw new HttpsError(
          "failed-precondition",
          "session_not_in_progress",
        );
      }

      const tournamentSnap = await tx.get(tournamentRef);
      if (!tournamentSnap.exists) {
        throw new HttpsError("not-found", "Tournament not found.");
      }
      const endsAt = tournamentSnap.get("ends_at") as Timestamp | undefined;
      if (!endsAt) {
        throw new HttpsError("failed-precondition", "tournament_ends_at_missing");
      }
      const now = Timestamp.now();
      if (now.toMillis() > endsAt.toMillis()) {
        throw new HttpsError("failed-precondition", "window_closed");
      }

      const correctRaw = sessionData.shuffled_correct_indices as unknown;
      if (
        !Array.isArray(correctRaw) ||
        correctRaw.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT
      ) {
        throw new HttpsError("failed-precondition", "session_missing_correct_indices");
      }
      const correctIndices = correctRaw as number[];
      const {correctCount} = computeClassicScore(answers, correctIndices);

      const qIdsRaw = sessionData.question_ids as unknown;
      let questionIds: string[];
      if (
        Array.isArray(qIdsRaw) &&
        qIdsRaw.length === CLASSIC_TOURNAMENT_QUESTION_COUNT
      ) {
        questionIds = qIdsRaw as string[];
      } else {
        const sq = sessionData.shuffled_questions as unknown;
        if (!Array.isArray(sq) || sq.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT) {
          throw new HttpsError("failed-precondition", "session_missing_question_ids");
        }
        questionIds = (sq as Array<{question_id?: string}>).map((row, i) => {
          const id = row.question_id;
          if (typeof id !== "string") {
            throw new HttpsError("internal", `question_id_missing:${i}`);
          }
          return id;
        });
      }

      tx.update(sessionRef, {
        status: "submitted",
        answers,
        correct_count: correctCount,
        submitted_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      });

      for (const qId of questionIds) {
        const seenRef = db
          .collection("used_questions")
          .doc(uid)
          .collection("seen")
          .doc(qId);
        tx.set(
          seenRef,
          {
            seenAt: FieldValue.serverTimestamp(),
            source: "classic_tournament",
            slot_id: slotId,
          },
          {merge: true},
        );
      }
    });

    const after = await sessionRef.get();
    const submittedAt = after.get("submitted_at") as Timestamp | undefined;
    if (!submittedAt) {
      throw new HttpsError("internal", "submit_timestamp_missing");
    }
    const correctCount = after.get("correct_count") as number;

    return {
      correctCount,
      sessionStatus: "submitted",
      submittedAt,
    };
  },
);
