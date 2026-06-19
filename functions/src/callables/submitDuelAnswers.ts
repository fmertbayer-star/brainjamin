import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {checkAchievements} from "./checkAchievements";

const DUEL_QUESTION_COUNT = 10;
const DUEL_QUESTION_TIME_MS = 15 * 1000;
const SUBMITTABLE_STATUSES = new Set([
  "waiting",
  "matched",
  "player1_done",
  "player2_done",
]);

type DuelAnswerInput = {
  questionIndex: number;
  selectedOption: number;
  timeMs: number;
  remainingMs?: number;
};

type SubmitDuelAnswersRequest = {
  duelId?: string;
  answers?: DuelAnswerInput[];
};

type NormalizedAnswer = {
  questionIndex: number;
  selectedOption: number;
  timeMs: number;
};

export const submitDuelAnswers = onCall<SubmitDuelAnswersRequest>(
  {
    cors: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const duelId = request.data?.duelId?.trim();
    if (!duelId) {
      logger.warn("submitDuelAnswers invalid duelId", {uid});
      throw new HttpsError("invalid-argument", "duelId is required.");
    }

    const answers = request.data?.answers;
    if (!Array.isArray(answers) || answers.length !== DUEL_QUESTION_COUNT) {
      logger.warn("submitDuelAnswers invalid answers length", {uid, duelId});
      throw new HttpsError(
        "invalid-argument",
        `answers must be an array of length ${DUEL_QUESTION_COUNT}.`
      );
    }

    const seenIndexes = new Set<number>();
    const normalizedAnswers: NormalizedAnswer[] = [];
    for (let i = 0; i < answers.length; i++) {
      const a = answers[i];
      if (
        !a ||
        !Number.isInteger(a.questionIndex) ||
        !Number.isInteger(a.selectedOption) ||
        !Number.isInteger(a.timeMs)
      ) {
        logger.warn("submitDuelAnswers malformed answer entry", {uid, duelId, index: i});
        throw new HttpsError(
          "invalid-argument",
          `answers[${i}] must have integer questionIndex, selectedOption, timeMs.`
        );
      }
      if (a.questionIndex < 0 || a.questionIndex >= DUEL_QUESTION_COUNT) {
        throw new HttpsError(
          "invalid-argument",
          `answers[${i}].questionIndex must be between 0 and ${DUEL_QUESTION_COUNT - 1}.`
        );
      }
      if (a.selectedOption < -1 || a.selectedOption > 3) {
        throw new HttpsError(
          "invalid-argument",
          `answers[${i}].selectedOption must be between -1 and 3.`
        );
      }
      if (a.timeMs < 0) {
        throw new HttpsError(
          "invalid-argument",
          `answers[${i}].timeMs must be >= 0.`
        );
      }
      if (seenIndexes.has(a.questionIndex)) {
        throw new HttpsError(
          "invalid-argument",
          `answers contains duplicate questionIndex ${a.questionIndex}.`
        );
      }
      seenIndexes.add(a.questionIndex);
      normalizedAnswers.push({
        questionIndex: a.questionIndex,
        selectedOption: a.selectedOption,
        timeMs: Math.min(a.timeMs, DUEL_QUESTION_TIME_MS),
      });
    }
    for (let i = 0; i < DUEL_QUESTION_COUNT; i++) {
      if (!seenIndexes.has(i)) {
        throw new HttpsError(
          "invalid-argument",
          "answers must contain questionIndex values 0 through 9 exactly once."
        );
      }
    }
    normalizedAnswers.sort((a, b) => a.questionIndex - b.questionIndex);

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      logger.warn("submitDuelAnswers banned user blocked", {uid, duelId});
      throw new HttpsError("permission-denied", "Account is banned.");
    }

    const duelRef = db.collection("duels").doc(duelId);
    const duelSnap = await duelRef.get();
    if (!duelSnap.exists) {
      throw new HttpsError("not-found", "Duel not found.");
    }
    const player1Id = duelSnap.get("player1_id");
    const player2Id = duelSnap.get("player2_id");
    if (uid !== player1Id && uid !== player2Id) {
      throw new HttpsError("permission-denied", "You are not a participant in this duel.");
    }

    const isPlayer1 = uid === player1Id;
    const status = duelSnap.get("status");

    if (status === "waiting" && !isPlayer1) {
      throw new HttpsError(
        "failed-precondition",
        "Creator must play before an opponent attaches in this duel state."
      );
    }

    if (!SUBMITTABLE_STATUSES.has(status)) {
      throw new HttpsError(
        "failed-precondition",
        "Answers are not accepted for this duel state."
      );
    }
    if (isPlayer1 && status === "player1_done") {
      logger.info("submitDuelAnswers already submitted", {uid, duelId});
      throw new HttpsError(
        "already-exists",
        "You have already submitted answers for this duel."
      );
    }
    if (!isPlayer1 && status === "player2_done") {
      logger.info("submitDuelAnswers already submitted", {uid, duelId});
      throw new HttpsError(
        "already-exists",
        "You have already submitted answers for this duel."
      );
    }

    const duelQuestionsSnap = await db
      .collection("duel_questions")
      .doc(duelId)
      .collection("q")
      .get();
    const correctIndexByQ = new Map<number, number>();
    for (const doc of duelQuestionsSnap.docs) {
      const idx = Number.parseInt(doc.id, 10);
      const correctIndex = doc.get("correctIndex");
      if (
        Number.isInteger(idx) &&
        Number.isInteger(correctIndex) &&
        correctIndex >= 0 &&
        correctIndex <= 3
      ) {
        correctIndexByQ.set(idx, correctIndex);
      }
    }
    for (let i = 0; i < DUEL_QUESTION_COUNT; i++) {
      if (!correctIndexByQ.has(i)) {
        throw new HttpsError("failed-precondition", "Duel questions are not ready.");
      }
    }

    let correctCount = 0;
    let totalRemainingMs = 0;
    let totalElapsedMs = 0;
    for (const answer of normalizedAnswers) {
      const correctIndex = correctIndexByQ.get(answer.questionIndex) as number;
      const remainingMs = Math.max(0, DUEL_QUESTION_TIME_MS - answer.timeMs);
      totalRemainingMs += remainingMs;
      totalElapsedMs += answer.timeMs;
      if (answer.selectedOption >= 0 && answer.selectedOption === correctIndex) {
        correctCount++;
      }
    }
    const score = correctCount +
      (totalRemainingMs / (DUEL_QUESTION_COUNT * DUEL_QUESTION_TIME_MS));

    const result = await db.runTransaction(async (tx) => {
      const txDuelSnap = await tx.get(duelRef);
      if (!txDuelSnap.exists) {
        throw new HttpsError("not-found", "Duel not found.");
      }
      const txStatus = txDuelSnap.get("status");

      if (txStatus === "waiting" && !isPlayer1) {
        throw new HttpsError(
          "failed-precondition",
          "Creator must play before an opponent attaches in this duel state."
        );
      }

      if (!SUBMITTABLE_STATUSES.has(txStatus)) {
        throw new HttpsError(
          "failed-precondition",
          "Answers are not accepted for this duel state."
        );
      }
      if (isPlayer1 && txStatus === "player1_done") {
        logger.info("submitDuelAnswers already submitted", {uid, duelId});
        throw new HttpsError(
          "already-exists",
          "You have already submitted answers for this duel."
        );
      }
      if (!isPlayer1 && txStatus === "player2_done") {
        logger.info("submitDuelAnswers already submitted", {uid, duelId});
        throw new HttpsError(
          "already-exists",
          "You have already submitted answers for this duel."
        );
      }

      const updates: Record<string, unknown> = {};
      const slotPrefix = isPlayer1 ? "player1" : "player2";
      updates[`${slotPrefix}_correct_count`] = correctCount;
      updates[`${slotPrefix}_time_ms`] = totalElapsedMs;
      updates[`${slotPrefix}_total_remaining_ms`] = totalRemainingMs;
      updates[`${slotPrefix}_score`] = score;
      updates[`${slotPrefix}_done_at`] = FieldValue.serverTimestamp();

      const txWillComplete =
        (isPlayer1 && txStatus === "player2_done") ||
        (!isPlayer1 && txStatus === "player1_done");

      if (!txWillComplete) {
        updates.status = isPlayer1 ? "player1_done" : "player2_done";
        tx.update(duelRef, updates);
        return {
          duelId,
          correctCount,
          totalRemainingMs,
          score,
          status: updates.status as string,
          completed: false,
        };
      }

      const otherCorrectCountRaw = txDuelSnap.get(
        isPlayer1 ? "player2_correct_count" : "player1_correct_count"
      );
      const otherTotalRemainingRaw = txDuelSnap.get(
        isPlayer1 ? "player2_total_remaining_ms" : "player1_total_remaining_ms"
      );
      if (!Number.isInteger(otherCorrectCountRaw) || !Number.isInteger(otherTotalRemainingRaw)) {
        throw new HttpsError("failed-precondition", "Other player results are not ready.");
      }

      const otherCorrectCount = otherCorrectCountRaw as number;
      const otherTotalRemainingMs = otherTotalRemainingRaw as number;
      const txPlayer1Id = txDuelSnap.get("player1_id");
      const txPlayer2Id = txDuelSnap.get("player2_id");

      let winnerId: string | null = null;
      if (isPlayer1) {
        if (correctCount > otherCorrectCount) {
          winnerId = txPlayer1Id;
        } else if (correctCount < otherCorrectCount) {
          winnerId = txPlayer2Id;
        } else if (totalRemainingMs > otherTotalRemainingMs) {
          winnerId = txPlayer1Id;
        } else if (totalRemainingMs < otherTotalRemainingMs) {
          winnerId = txPlayer2Id;
        }
      } else {
        if (correctCount > otherCorrectCount) {
          winnerId = txPlayer2Id;
        } else if (correctCount < otherCorrectCount) {
          winnerId = txPlayer1Id;
        } else if (totalRemainingMs > otherTotalRemainingMs) {
          winnerId = txPlayer2Id;
        } else if (totalRemainingMs < otherTotalRemainingMs) {
          winnerId = txPlayer1Id;
        }
      }

      updates.status = "completed";
      updates.winner_id = winnerId;
      updates.completed_at = FieldValue.serverTimestamp();
      tx.update(duelRef, updates);

      const p1Ref = db.collection("users").doc(String(txPlayer1Id));
      const p2Ref = db.collection("users").doc(String(txPlayer2Id));
      let callerXpAwarded = 25;

      if (winnerId === null) {
        tx.set(p1Ref, {
          xp: FieldValue.increment(25),
          totalAnswered: FieldValue.increment(1),
        }, {merge: true});
        tx.set(p2Ref, {
          xp: FieldValue.increment(25),
          totalAnswered: FieldValue.increment(1),
        }, {merge: true});
        callerXpAwarded = 25;
      } else if (winnerId === txPlayer1Id) {
        tx.set(p1Ref, {
          xp: FieldValue.increment(50),
          totalAnswered: FieldValue.increment(1),
        }, {merge: true});
        tx.set(p2Ref, {
          xp: FieldValue.increment(10),
          totalAnswered: FieldValue.increment(1),
        }, {merge: true});
        callerXpAwarded = isPlayer1 ? 50 : 10;
      } else {
        tx.set(p1Ref, {
          xp: FieldValue.increment(10),
          totalAnswered: FieldValue.increment(1),
        }, {merge: true});
        tx.set(p2Ref, {
          xp: FieldValue.increment(50),
          totalAnswered: FieldValue.increment(1),
        }, {merge: true});
        callerXpAwarded = isPlayer1 ? 10 : 50;
      }

      logger.info("submitDuelAnswers completed", {
        duelId,
        winnerId,
        p1Correct: isPlayer1 ? correctCount : otherCorrectCount,
        p2Correct: isPlayer1 ? otherCorrectCount : correctCount,
      });

      return {
        duelId,
        correctCount,
        totalRemainingMs,
        score,
        status: "completed",
        completed: true,
        winnerId,
        xpAwarded: callerXpAwarded,
      };
    });

    if (result.completed) {
      const duelSnap = await duelRef.get();
      const player1Id = duelSnap.get("player1_id");
      const player2Id = duelSnap.get("player2_id");
      const winnerId = result.winnerId ?? null;
      if (typeof player1Id === "string") {
        void checkAchievements(player1Id, {
          trigger: "duel",
          payload: {won: winnerId === player1Id},
        }).catch((err) => logger.error("checkAchievements", err));
      }
      if (typeof player2Id === "string") {
        void checkAchievements(player2Id, {
          trigger: "duel",
          payload: {won: winnerId === player2Id},
        }).catch((err) => logger.error("checkAchievements", err));
      }
    }
    logger.info("submitDuelAnswers submitted", {uid, duelId, correctCount});
    return result;
  }
);

