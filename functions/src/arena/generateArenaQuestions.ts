/**
 * generateArenaQuestions — populates arena_questions + schedules arena (Sprint 3.5b).
 */

import {
  FieldValue,
  getFirestore,
  type Firestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";

import {cosineSimilarity} from "../shared/embeddings";
import type {Difficulty} from "../shared/difficulty";
import {AI_SECRETS} from "../shared/secrets";
import type {ArenaSourceType} from "./shared";
import {
  ARENA_GEN_INTRA_DEDUP_THRESHOLD,
  ARENA_QUESTION_COUNT,
} from "./shared";
import {generateOneArenaQuestion, type ArenaCandidate} from "./arenaPipeline";

type GenerateArenaRequest = {
  arena_id?: unknown;
};

const CUSTOM_TOPIC_DIFFICULTY = 3 as Difficulty;
const MAX_CUSTOM_GENERATION_ROUNDS = 30;

function shuffleDocs<T>(docs: T[]): T[] {
  const copy = [...docs];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function parsePresetPoolDoc(
  doc: QueryDocumentSnapshot,
): {
  question: string;
  options: [string, string, string, string];
  correctIndex: number;
  difficulty: number;
} | null {
  const data = doc.data() as Record<string, unknown>;
  const question = data.question;
  const options = data.options;
  const correctIndex = data.correctIndex;
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
  if (
    typeof difficulty !== "number" ||
    !Number.isInteger(difficulty) ||
    difficulty < 1 ||
    difficulty > 5
  ) {
    return null;
  }
  return {
    question,
    options: options as [string, string, string, string],
    correctIndex,
    difficulty,
  };
}

async function fetchPresetPoolDocs(
  db: Firestore,
  catName: string,
): Promise<QueryDocumentSnapshot[]> {
  let poolDocs: QueryDocumentSnapshot[] = [];
  try {
    const flaggedSnap = await db
      .collection("questions_public")
      .where("category", "==", catName)
      .where("flagged", "==", false)
      .orderBy("createdAt", "desc")
      .limit(60)
      .get();
    poolDocs = flaggedSnap.docs;
  } catch (error) {
    logger.warn(
      "generateArenaQuestions preset flagged query failed; using fallback",
      {category: catName, error: String(error)},
    );
  }

  if (poolDocs.length === 0) {
    const fallbackSnap = await db
      .collection("questions_public")
      .where("category", "==", catName)
      .orderBy("createdAt", "desc")
      .limit(60)
      .get();
    poolDocs = fallbackSnap.docs.filter((doc) => doc.get("flagged") !== true);
  }

  return poolDocs;
}

export const generateArenaQuestions = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: AI_SECRETS,
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }

    const data = request.data as GenerateArenaRequest | undefined;
    const arenaIdRaw = data?.arena_id;
    if (typeof arenaIdRaw !== "string" || arenaIdRaw.trim().length === 0) {
      throw new HttpsError("invalid-argument", "invalid_arena_id");
    }
    const arenaId = arenaIdRaw.trim();

    const db = getFirestore();
    const usersRef = db.collection("users").doc(uid);
    const userSnap = await usersRef.get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "banned");
    }

    const arenaRef = db.collection("arenas").doc(arenaId);
    const arenaSnap = await arenaRef.get();
    if (!arenaSnap.exists) {
      throw new HttpsError("not-found", "arena_not_found");
    }

    const arenaData = arenaSnap.data()!;
    const creatorId = arenaData.creator_id;
    if (typeof creatorId !== "string" || creatorId !== uid) {
      throw new HttpsError("permission-denied", "arena_not_creator");
    }

    const status = arenaData.status;
    if (status !== "preparing") {
      throw new HttpsError("failed-precondition", "arena_already_generated");
    }

    const sourceType = arenaData.source_type as ArenaSourceType | undefined;
    if (sourceType !== "preset" && sourceType !== "custom_topic") {
      throw new HttpsError("failed-precondition", "arena_invalid_source");
    }

    const questionsCol = db
      .collection("arena_questions")
      .doc(arenaId)
      .collection("q");

    if (sourceType === "preset") {
      const categoryId = arenaData.category_id;
      if (typeof categoryId !== "string" || categoryId.length === 0) {
        throw new HttpsError("failed-precondition", "arena_missing_category");
      }

      const poolDocs = await fetchPresetPoolDocs(db, categoryId);
      const eligible = poolDocs.filter((d) => parsePresetPoolDoc(d) !== null);

      if (eligible.length < ARENA_QUESTION_COUNT) {
        throw new HttpsError("failed-precondition", "arena_pool_insufficient");
      }

      const chosen = shuffleDocs(eligible).slice(0, ARENA_QUESTION_COUNT);

      const batch = db.batch();
      for (let i = 0; i < ARENA_QUESTION_COUNT; i++) {
        const doc = chosen[i]!;
        const parsed = parsePresetPoolDoc(doc)!;
        batch.set(questionsCol.doc(String(i)), {
          arena_id: arenaId,
          q_index: i,
          question: parsed.question,
          options: parsed.options,
          correct_index: parsed.correctIndex,
          difficulty: parsed.difficulty,
          source_type: "preset",
          source_question_id: doc.id,
          created_at: FieldValue.serverTimestamp(),
        });
      }

      batch.update(arenaRef, {
        status: "scheduled",
        updated_at: FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return {
        arena_id: arenaId,
        status: "scheduled" as const,
        question_count: ARENA_QUESTION_COUNT,
      };
    }

    const customTopic = arenaData.custom_topic;
    if (typeof customTopic !== "string" || customTopic.trim().length === 0) {
      throw new HttpsError("failed-precondition", "arena_missing_custom_topic");
    }
    const topic = customTopic.trim();

    const accepted: ArenaCandidate[] = [];
    const recentStems: string[] = [];
    let rounds = 0;

    while (accepted.length < ARENA_QUESTION_COUNT && rounds < MAX_CUSTOM_GENERATION_ROUNDS) {
      rounds++;
      const cand = await generateOneArenaQuestion({
        topic,
        difficulty: CUSTOM_TOPIC_DIFFICULTY,
        recentStems,
      });

      if (!cand) {
        continue;
      }

      let dup = false;
      for (const prev of accepted) {
        if (
          cosineSimilarity(cand.embedding, prev.embedding) >=
            ARENA_GEN_INTRA_DEDUP_THRESHOLD
        ) {
          dup = true;
          break;
        }
      }
      if (dup) {
        continue;
      }

      accepted.push(cand);
      recentStems.push(cand.question);
    }

    if (accepted.length < ARENA_QUESTION_COUNT) {
      throw new HttpsError("internal", "arena_generation_failed");
    }

    const batch = db.batch();
    for (let i = 0; i < ARENA_QUESTION_COUNT; i++) {
      const cand = accepted[i]!;
      batch.set(questionsCol.doc(String(i)), {
        arena_id: arenaId,
        q_index: i,
        question: cand.question,
        options: cand.options,
        correct_index: cand.correctIndex,
        difficulty: cand.difficulty,
        source_type: "custom_topic",
        generator_provider: cand.generatorProvider,
        verifier_provider: cand.verifierProvider,
        created_at: FieldValue.serverTimestamp(),
      });
    }

    batch.update(arenaRef, {
      status: "scheduled",
      updated_at: FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return {
      arena_id: arenaId,
      status: "scheduled" as const,
      question_count: ARENA_QUESTION_COUNT,
    };
  },
);
