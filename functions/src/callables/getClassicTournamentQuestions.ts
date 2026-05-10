import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {CLASSIC_TOURNAMENT_QUESTION_COUNT} from "../shared/classicScoring";
import {mcqShuffle} from "../shared/mcqShuffle";

type ClassicQuestionPayload = {
  questionId: string;
  question: string;
  options: [string, string, string, string];
  category: string;
  difficulty: number;
};

type ClientQuestionSnapshotRow = {
  question_id: string;
  question: string;
  options: [string, string, string, string];
  category: string;
  difficulty: number;
};

type ShuffledQuestionRow = {
  question_id: string;
  question: string;
  shuffled_options: [string, string, string, string];
  shuffled_correct_index: number;
  category: string;
  difficulty: number;
};

function assertTournamentWindowAndShape(
  data: FirebaseFirestore.DocumentData | undefined,
  slotId: string,
): void {
  if (!data) {
    throw new HttpsError("internal", `tournament_data_missing:${slotId}`);
  }
  const status = data.status;
  if (status !== "visible") {
    throw new HttpsError(
      "failed-precondition",
      "tournament_not_available",
    );
  }
  const gc = data.generated_count;
  const gcn = typeof gc === "number" ? gc : 0;
  if (gcn < CLASSIC_TOURNAMENT_QUESTION_COUNT) {
    throw new HttpsError(
      "failed-precondition",
      "tournament_not_ready",
    );
  }
  const qIds = data.q_ids as unknown;
  if (
    !Array.isArray(qIds) ||
    qIds.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT
  ) {
    throw new HttpsError("internal", `tournament_q_ids_invalid:${slotId}`);
  }
  const startsAt = data.starts_at as Timestamp | undefined;
  const endsAt = data.ends_at as Timestamp | undefined;
  if (!startsAt || !endsAt) {
    throw new HttpsError("failed-precondition", "tournament_times_missing");
  }
  const now = Timestamp.now();
  const nowMs = now.toMillis();
  if (
    nowMs < startsAt.toMillis() ||
    nowMs > endsAt.toMillis()
  ) {
    throw new HttpsError(
      "failed-precondition",
      "tournament_outside_window",
    );
  }
}

function toClientPayload(
  rows: ClientQuestionSnapshotRow[],
): ClassicQuestionPayload[] {
  return rows.map((r) => ({
    questionId: r.question_id,
    question: r.question,
    options: r.options,
    category: r.category,
    difficulty: r.difficulty,
  }));
}

export const getClassicTournamentQuestions = onCall<
  {slotId?: string},
  Promise<{questions: ClassicQuestionPayload[]; sessionStatus: "in_progress" | "submitted"}>
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

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "Account is banned.");
    }

    const tournamentRef = db.collection("tournaments").doc(slotId);
    const preSnap = await tournamentRef.get();
    if (!preSnap.exists) {
      throw new HttpsError("not-found", "Tournament not found.");
    }
    assertTournamentWindowAndShape(preSnap.data(), slotId);

    const sessionId = `${slotId}_${uid}`;
    const sessionRef = db.collection("tournament_sessions").doc(sessionId);

    const result = await db.runTransaction(async (tx) => {
      const tSnap = await tx.get(tournamentRef);
      if (!tSnap.exists) {
        throw new HttpsError("not-found", "Tournament not found.");
      }
      assertTournamentWindowAndShape(tSnap.data(), slotId);

      const sSnap = await tx.get(sessionRef);
      if (sSnap.exists) {
        const d = sSnap.data();
        const st = d?.status;
        const snap = d?.client_questions_snapshot as unknown;
        if (!Array.isArray(snap)) {
          throw new HttpsError("internal", "session_snapshot_corrupt");
        }
        const rows = snap as ClientQuestionSnapshotRow[];
        if (st === "submitted") {
          return {
            questions: toClientPayload(rows),
            sessionStatus: "submitted" as const,
          };
        }
        if (st === "in_progress") {
          return {
            questions: toClientPayload(rows),
            sessionStatus: "in_progress" as const,
          };
        }
        throw new HttpsError("failed-precondition", "session_invalid_state");
      }

      const qIds = (tSnap.get("q_ids") as unknown) as string[];
      if (
        !Array.isArray(qIds) ||
        qIds.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT
      ) {
        throw new HttpsError("internal", "tournament_q_ids_invalid");
      }

      const shuffledQuestions: ShuffledQuestionRow[] = [];
      const clientSnapshot: ClientQuestionSnapshotRow[] = [];
      const shuffledCorrectIndices: number[] = [];

      for (const qId of qIds) {
        if (typeof qId !== "string" || !qId.length) {
          throw new HttpsError("internal", "invalid_q_id");
        }
        const qRef = db.collection("questions_public").doc(qId);
        const qSnap = await tx.get(qRef);
        if (!qSnap.exists) {
          throw new HttpsError(
            "internal",
            `question_not_found:${qId}`,
          );
        }
        const q = qSnap.data()!;
        const questionText = q.question;
        const options = q.options;
        const correctIndex = q.correctIndex;
        const category = q.category;
        const difficulty = q.difficulty;

        if (
          typeof questionText !== "string" ||
          !Array.isArray(options) ||
          options.length !== 4 ||
          options.some((o: unknown) => typeof o !== "string") ||
          typeof correctIndex !== "number" ||
          !Number.isInteger(correctIndex) ||
          correctIndex < 0 ||
          correctIndex > 3 ||
          typeof category !== "string" ||
          typeof difficulty !== "number" ||
          !Number.isInteger(difficulty)
        ) {
          throw new HttpsError(
            "internal",
            `invalid_question_shape:${qId}`,
          );
        }

        const {shuffledOptions, shuffledCorrectIndex} = mcqShuffle(
          options as string[],
          correctIndex,
        );

        const opts = shuffledOptions as [string, string, string, string];
        shuffledQuestions.push({
          question_id: qId,
          question: questionText,
          shuffled_options: opts,
          shuffled_correct_index: shuffledCorrectIndex,
          category,
          difficulty,
        });
        shuffledCorrectIndices.push(shuffledCorrectIndex);
        clientSnapshot.push({
          question_id: qId,
          question: questionText,
          options: opts,
          category,
          difficulty,
        });
      }

      tx.set(sessionRef, {
        uid,
        slot_id: slotId,
        session_id: sessionId,
        status: "in_progress",
        shuffled_questions: shuffledQuestions,
        shuffled_correct_indices: shuffledCorrectIndices,
        client_questions_snapshot: clientSnapshot,
        question_ids: qIds,
        created_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      });

      return {
        questions: toClientPayload(clientSnapshot),
        sessionStatus: "in_progress" as const,
      };
    });

    return result;
  },
);
