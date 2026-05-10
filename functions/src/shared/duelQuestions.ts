import {
  FieldPath,
  FieldValue,
  Timestamp,
  type Firestore,
  type WriteBatch,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {HttpsError} from "firebase-functions/v2/https";
import {CATEGORIES, isCategory} from "./categories";
import {mcqShuffle} from "./mcqShuffle";

export const DUEL_QUESTION_COUNT = 10;
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

type ChosenQuestion = {
  questionId: string;
  question: string;
  options: string[];
  correctIndex: number;
  category: string;
  difficulty: number;
};

function toNormalizedErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message.toLowerCase();
  }
  return String(error).toLowerCase();
}

function parsePoolQuestion(
  questionId: string,
  data: Record<string, unknown>,
): ChosenQuestion | null {
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
    questionId,
    question,
    options: options as string[],
    correctIndex,
    category,
    difficulty,
  };
}

function shuffleCategories(): string[] {
  const out = [...CATEGORIES];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

function categoryPickOrder(pref: string | null | undefined): string[] {
  const shuffled = shuffleCategories();
  if (pref && isCategory(pref)) {
    const rest = shuffled.filter((c) => c !== pref);
    return [pref, ...rest];
  }
  return shuffled;
}

async function loadSeenPlayerOnly(
  db: Firestore,
  playerId: string,
  logContext: {operation: string; duelId: string},
): Promise<Set<string>> {
  const cutoff = Timestamp.fromMillis(Date.now() - THIRTY_DAYS_MS);
  const seenRef = db.collection("used_questions").doc(playerId).collection("seen");
  try {
    const filteredSnap = await seenRef.where("seenAt", ">=", cutoff).get();
    return new Set(filteredSnap.docs.map((d) => d.id));
  } catch (error) {
    logger.warn("generateDuelQuestionSet seenAt filtered read failed; using fallback", {
      ...logContext,
      playerId,
      error: toNormalizedErrorMessage(error),
    });
    const fallbackSnap = await seenRef.get();
    return new Set(fallbackSnap.docs.map((d) => d.id));
  }
}

export type GenerateDuelQuestionSetOpts = {
  db: Firestore;
  batch: WriteBatch;
  duelId: string;
  player1Id: string;
  category?: string | null;
  /** For logging correlation only */
  logContext?: {operation: string};
};

/**
 * Stages duel_questions and used_questions (player1 only) writes on `batch`.
 * Caller must commit. Does not mutate the duel document.
 */
export async function generateDuelQuestionSet(
  opts: GenerateDuelQuestionSetOpts,
): Promise<string[]> {
  const {db, batch, duelId, player1Id, category} = opts;
  const logContext = {
    operation: opts.logContext?.operation ?? "generateDuelQuestionSet",
    duelId,
  };

  const dedupSeenIds = await loadSeenPlayerOnly(db, player1Id, logContext);

  const pickedThisDuel = new Set<string>();
  const chosen: ChosenQuestion[] = [];

  const categories = categoryPickOrder(category);

  for (const catName of categories) {
    if (chosen.length >= DUEL_QUESTION_COUNT) {
      break;
    }

    let poolDocs: QueryDocumentSnapshot[] = [];
    try {
      const flaggedSnap = await db
        .collection("questions_public")
        .where("category", "==", catName)
        .where("flagged", "==", false)
        .orderBy("createdAt", "desc")
        .limit(30)
        .get();
      poolDocs = flaggedSnap.docs;
    } catch (error) {
      logger.warn("generateDuelQuestionSet flagged query failed; using fallback", {
        ...logContext,
        category: catName,
        error: toNormalizedErrorMessage(error),
      });
    }

    if (poolDocs.length === 0) {
      const fallbackSnap = await db
        .collection("questions_public")
        .where("category", "==", catName)
        .orderBy("createdAt", "desc")
        .limit(30)
        .get();
      poolDocs = fallbackSnap.docs.filter((doc) => doc.get("flagged") !== true);
    }

    const eligible = poolDocs
      .map((doc) => parsePoolQuestion(doc.id, doc.data() as Record<string, unknown>))
      .filter((q): q is ChosenQuestion => q !== null)
      .filter((q) => !dedupSeenIds.has(q.questionId) && !pickedThisDuel.has(q.questionId));

    if (eligible.length === 0) {
      continue;
    }

    const picked = eligible[Math.floor(Math.random() * eligible.length)];
    chosen.push(picked);
    pickedThisDuel.add(picked.questionId);
  }

  if (chosen.length < DUEL_QUESTION_COUNT) {
    logger.error("generateDuelQuestionSet pool insufficient", {
      ...logContext,
      chosen: chosen.length,
      player1Id,
    });
    throw new HttpsError("failed-precondition", "duel_pool_insufficient");
  }

  const duelQuestionsRef = db.collection("duel_questions").doc(duelId).collection("q");

  const questionIds: string[] = [];
  for (let i = 0; i < DUEL_QUESTION_COUNT; i++) {
    const picked = chosen[i];
    const {shuffledOptions, shuffledCorrectIndex} = mcqShuffle(
      picked.options,
      picked.correctIndex,
    );
    questionIds.push(picked.questionId);
    batch.set(duelQuestionsRef.doc(String(i)), {
      questionId: picked.questionId,
      question: picked.question,
      options: shuffledOptions,
      correctIndex: shuffledCorrectIndex,
      category: picked.category,
      difficulty: picked.difficulty,
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.set(
      db.collection("used_questions")
        .doc(player1Id)
        .collection("seen")
        .doc(picked.questionId),
      {seenAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
  }

  return questionIds;
}

/** Ordered question IDs from duel_questions/{duelId}/q for player2 dedup-at-attach. */
export async function readDuelQuestionIds(
  db: Firestore,
  duelId: string,
): Promise<string[]> {
  const existingSnap = await db
    .collection("duel_questions")
    .doc(duelId)
    .collection("q")
    .orderBy(FieldPath.documentId(), "asc")
    .get();

  const ids = existingSnap.docs.map((doc) => {
    const qid = doc.get("questionId");
    return typeof qid === "string" ? qid : "";
  });

  const valid = ids.filter((id) => id.length > 0);
  if (valid.length !== DUEL_QUESTION_COUNT) {
    logger.warn("readDuelQuestionIds unexpected count", {
      duelId,
      count: valid.length,
    });
  }

  return valid;
}

/** Best-effort used_questions for player2 after match/join — never throws. */
export async function writePlayer2SeenBestEffort(
  db: Firestore,
  player2Id: string,
  questionIds: string[],
  contextLabel: string,
): Promise<void> {
  if (questionIds.length === 0) {
    return;
  }

  try {
    const batch = db.batch();
    for (const qid of questionIds) {
      if (!qid) {
        continue;
      }
      batch.set(
        db.collection("used_questions").doc(player2Id).collection("seen").doc(qid),
        {seenAt: FieldValue.serverTimestamp()},
        {merge: true},
      );
    }
    await batch.commit();
    logger.info("writePlayer2SeenBestEffort ok", {
      contextLabel,
      player2Id,
      count: questionIds.length,
    });
  } catch (error) {
    logger.warn("writePlayer2SeenBestEffort failed", {
      contextLabel,
      player2Id,
      error: toNormalizedErrorMessage(error),
    });
  }
}
