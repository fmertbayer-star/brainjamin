import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {CLASSIC_TOURNAMENT_QUESTION_COUNT} from "../shared/classicScoring";

type RevealQuestion = {
  questionId: string;
  question: string;
  options: [string, string, string, string];
  category: string;
  difficulty: number;
  userAnswerIndex: number | null;
  correctIndex: number;
  isCorrect: boolean;
};

type RevealResult = {
  questions: RevealQuestion[];
  sessionMeta: {
    correctCount: number;
    rank: number | null;
    xpAwarded: number | null;
    submittedAt: Timestamp;
  };
  leaderboardSnippet: {
    totalParticipants: number;
    top10: Array<{rank: number; displayName: string; correctCount: number}>;
  } | null;
};

export const getClassicTournamentReveal = onCall<
  {slotId?: string},
  Promise<RevealResult>
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
    const tournamentSnap = await tournamentRef.get();
    if (!tournamentSnap.exists) {
      throw new HttpsError("not-found", "Tournament not found.");
    }
    const tournament = tournamentSnap.data();
    if (tournament?.status !== "ended") {
      throw new HttpsError("failed-precondition", "tournament_not_ended");
    }

    const sessionId = `${slotId}_${uid}`;
    const sessionSnap = await db.collection("tournament_sessions").doc(sessionId).get();
    if (!sessionSnap.exists) {
      throw new HttpsError("not-found", "session_not_found");
    }
    const s = sessionSnap.data();
    if (!s || s.status !== "submitted") {
      throw new HttpsError("failed-precondition", "session_not_submitted");
    }

    const shuffledQuestions = s.shuffled_questions as unknown;
    const shuffledCorrect = s.shuffled_correct_indices as unknown;
    const answers = s.answers as unknown;
    const submittedAt = s.submitted_at as Timestamp | undefined;
    const correctCount = s.correct_count;

    if (
      !Array.isArray(shuffledQuestions) ||
      !Array.isArray(shuffledCorrect) ||
      !Array.isArray(answers) ||
      shuffledQuestions.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT ||
      shuffledCorrect.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT ||
      answers.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT ||
      !submittedAt ||
      typeof correctCount !== "number"
    ) {
      throw new HttpsError("internal", "session_shape_invalid");
    }

    const questions: RevealQuestion[] = [];
    for (let i = 0; i < CLASSIC_TOURNAMENT_QUESTION_COUNT; i++) {
      const q = shuffledQuestions[i] as Record<string, unknown>;
      const opts = q?.shuffled_options;
      const corr = shuffledCorrect[i];
      const rawUserAnswer = answers[i];
      if (
        !q ||
        typeof q.question_id !== "string" ||
        typeof q.question !== "string" ||
        !Array.isArray(opts) ||
        opts.length !== 4 ||
        opts.some((o) => typeof o !== "string") ||
        typeof q.category !== "string" ||
        typeof q.difficulty !== "number" ||
        !Number.isInteger(q.difficulty) ||
        typeof corr !== "number" ||
        !Number.isInteger(corr) ||
        corr < 0 ||
        corr > 3
      ) {
        throw new HttpsError("internal", "session_question_shape_invalid");
      }

      let userAnswerIndex: number | null = null;
      if (
        typeof rawUserAnswer === "number" &&
        Number.isInteger(rawUserAnswer) &&
        rawUserAnswer >= 0 &&
        rawUserAnswer <= 3
      ) {
        userAnswerIndex = rawUserAnswer;
      }

      questions.push({
        questionId: q.question_id,
        question: q.question,
        options: opts as [string, string, string, string],
        category: q.category,
        difficulty: q.difficulty,
        userAnswerIndex,
        correctIndex: corr,
        isCorrect: userAnswerIndex === corr,
      });
    }

    const lbSnap = await db.collection("tournament_leaderboards").doc(slotId).get();
    let leaderboardSnippet: RevealResult["leaderboardSnippet"] = null;
    if (lbSnap.exists) {
      const d = lbSnap.data();
      const topRaw = d?.top_100;
      const totalParticipants = d?.total_participants;
      if (Array.isArray(topRaw) && typeof totalParticipants === "number") {
        const top10 = topRaw.slice(0, 10).map((e) => {
          const row = e as Record<string, unknown>;
          return {
            rank: typeof row.rank === "number" ? row.rank : 0,
            displayName: typeof row.display_name === "string" ?
              row.display_name :
              "Anonymous Player",
            correctCount: typeof row.correct_count === "number" ? row.correct_count : 0,
          };
        });
        leaderboardSnippet = {
          totalParticipants,
          top10,
        };
      }
    }

    return {
      questions,
      sessionMeta: {
        correctCount,
        rank: typeof s.rank === "number" ? s.rank : null,
        xpAwarded: typeof s.xp_awarded === "number" ? s.xp_awarded : null,
        submittedAt,
      },
      leaderboardSnippet,
    };
  },
);
