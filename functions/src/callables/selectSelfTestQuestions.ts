import {
  type DocumentData,
  FieldValue,
  getFirestore,
  type QueryDocumentSnapshot,
  Timestamp,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {randomUUID} from "crypto";
import {mcqShuffle} from "../shared/mcqShuffle";

const THIRTY_DAYS_MS = 30 * 24 * 3600 * 1000;

function parseQuestionDoc(
  data: DocumentData,
): {
  questionText: string;
  options: string[];
  correctIndex: number;
  category: string;
  difficulty: number;
} | null {
  const question = data.question;
  const options = data.options;
  const correctIndex = data.correctIndex;
  const category = data.category;
  const difficulty = data.difficulty;
  if (typeof question !== "string" || question.length === 0) {
    return null;
  }
  if (
    !Array.isArray(options) ||
    options.length !== 4 ||
    options.some((o) => typeof o !== "string")
  ) {
    return null;
  }
  if (
    typeof correctIndex !== "number" ||
    !Number.isInteger(correctIndex) ||
    correctIndex < 0 ||
    correctIndex > 3
  ) {
    return null;
  }
  if (typeof category !== "string" || category.length === 0) {
    return null;
  }
  if (
    typeof difficulty !== "number" ||
    !Number.isInteger(difficulty) ||
    difficulty < 1 ||
    difficulty > 5
  ) {
    return null;
  }
  return {
    questionText: question,
    options,
    correctIndex,
    category,
    difficulty,
  };
}

function pickFiveRandomDistinct<T>(items: T[]): T[] {
  if (items.length < 5) {
    return items;
  }
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, 5);
}

export const selectSelfTestQuestions = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }
    const uid = request.auth.uid;
    const db = getFirestore();

    const thirtyDaysAgo = Timestamp.fromMillis(Date.now() - THIRTY_DAYS_MS);
    const seenSnap = await db
      .collection("used_questions")
      .doc(uid)
      .collection("seen")
      .where("seenAt", ">", thirtyDaysAgo)
      .get();

    const seenIds = new Set<string>();
    for (const d of seenSnap.docs) {
      seenIds.add(d.id);
    }

    const pickedByDifficulty: QueryDocumentSnapshot[] = [];

    for (let d = 1; d <= 5; d++) {
      const primary = db
        .collection("questions_public")
        .where("difficulty", "==", d)
        .where("flagged", "==", false)
        .limit(75);

      let poolDocs = (await primary.get()).docs;

      if (poolDocs.length === 0) {
        const fallback = await db
          .collection("questions_public")
          .where("difficulty", "==", d)
          .limit(75)
          .get();
        poolDocs = fallback.docs.filter((doc) => doc.get("flagged") !== true);
      }

      const filtered = poolDocs.filter((doc) => !seenIds.has(doc.id));
      const available = filtered.length;

      if (available < 5) {
        throw new HttpsError(
          "failed-precondition",
          "self_test_insufficient_pool",
          {difficulty: d, available},
        );
      }

      const chosen = pickFiveRandomDistinct(filtered);
      pickedByDifficulty.push(...chosen);
    }

    type OutQ = {
      qId: string;
      questionText: string;
      options: string[];
      correctIndex: number;
      category: string;
      difficulty: number;
    };

    const questions: OutQ[] = [];
    const questionIds: string[] = [];
    const shuffledCorrectIndices: number[] = [];

    for (const doc of pickedByDifficulty) {
      const parsed = parseQuestionDoc(doc.data());
      if (!parsed) {
        throw new HttpsError(
          "failed-precondition",
          "self_test_invalid_pool_doc",
          {qId: doc.id},
        );
      }
      const {shuffledOptions, shuffledCorrectIndex} = mcqShuffle(
        parsed.options,
        parsed.correctIndex,
      );
      questions.push({
        qId: doc.id,
        questionText: parsed.questionText,
        options: shuffledOptions,
        correctIndex: shuffledCorrectIndex,
        category: parsed.category,
        difficulty: parsed.difficulty,
      });
      questionIds.push(doc.id);
      shuffledCorrectIndices.push(shuffledCorrectIndex);
    }

    const sessionId = `${uid}_${randomUUID()}`;
    await db.collection("self_test_sessions").doc(sessionId).set({
      uid,
      startedAt: FieldValue.serverTimestamp(),
      questionIds,
      shuffledCorrectIndices,
      status: "in_progress",
    });

    return {
      sessionId,
      questions,
    };
  },
);
