import {FieldPath, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
type GetDuelQuestionsRequest = {
  duelId?: string;
};
const ALLOWED_STATUSES = new Set([
  "waiting",
  "matched",
  "player1_done",
  "player2_done",
  "completed",
]);
export const getDuelQuestions = onCall<GetDuelQuestionsRequest>(
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
      throw new HttpsError("invalid-argument", "duelId is required.");
    }
    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      logger.warn("getDuelQuestions banned user blocked", {uid, duelId});
      throw new HttpsError("permission-denied", "Account is banned.");
    }
    const duelRef = db.collection("duels").doc(duelId);
    const duelSnap = await duelRef.get();
    if (!duelSnap.exists) {
      logger.warn("getDuelQuestions duel not found", {uid, duelId});
      throw new HttpsError("not-found", "Duel not found.");
    }
    const player1Id = duelSnap.get("player1_id");
    const player2Id = duelSnap.get("player2_id");
    if (uid !== player1Id && uid !== player2Id) {
      logger.warn("getDuelQuestions non-participant blocked", {uid, duelId});
      throw new HttpsError(
        "permission-denied",
        "You are not a participant in this duel."
      );
    }
    const status = duelSnap.get("status");
    if (!ALLOWED_STATUSES.has(status)) {
      logger.warn("getDuelQuestions invalid duel state", {uid, duelId, status});
      throw new HttpsError(
        "failed-precondition",
        "Questions are not available for this duel state."
      );
    }
    if (duelSnap.get("questions_generated") !== true) {
      logger.error("getDuelQuestions questions_generated false", {
        uid,
        duelId,
      });
      throw new HttpsError(
        "internal",
        `Duel questions not generated — this should not happen under Model A. duelId=${duelId}`
      );
    }
    const duelQuestionsRef = db.collection("duel_questions").doc(duelId).collection("q");
    const existingSnap = await duelQuestionsRef
      .orderBy(FieldPath.documentId(), "asc")
      .get();
    const questions = existingSnap.docs.map((doc) => {
      const data = doc.data();
      return {
        questionId: data.questionId,
        question: data.question,
        options: data.options,
        category: data.category,
        difficulty: data.difficulty,
      };
    });
    logger.info("getDuelQuestions read", {uid, duelId, count: questions.length});
    return {duelId, questions};
  }
);

