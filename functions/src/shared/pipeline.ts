/**
 * Single-question generation pipeline (PR-13). Keep orchestration here;
 * prompts live in prompts.ts.
 */

import {FieldValue, getFirestore} from "firebase-admin/firestore";
import type {Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions/v2";
import {generateWithProviders, type GenProvider} from "./aiProviders";
import type {Category} from "./categories";
import {isCategory} from "./categories";
import {buildEmbedText, cosineSimilarity, DEDUP_THRESHOLD, embedText, EMBEDDING_DIMS} from "./embeddings";
import type {Difficulty} from "./difficulty";
import {isDifficulty} from "./difficulty";
import {moderateText} from "./moderation";
import {
  buildGeneratorPrompt,
  buildVerifierPrompt,
} from "./prompts";
import type {GeneratedQuestion, PersistedQuestion} from "./questionSchema";
import {isGeneratedQuestion} from "./questionSchema";
import {pickVerifierProvider} from "./verifierProvider";

const GEN_ORDER: GenProvider[] = ["gemini", "openai", "anthropic"];

export const MAX_ATTEMPTS_PER_QUESTION = 5;

export type RejectReason =
  | "generator_refused"
  | "generator_invalid_json"
  | "generator_schema_invalid"
  | "moderation_flagged"
  | "verifier_incorrect"
  | "verifier_uncertain"
  | "verifier_invalid_json"
  | "dedup_hit";

export interface AttemptLog {
  attempt: number;
  rejected: boolean;
  reason?: RejectReason;
  detail?: string;
  generatorProvider?: GenProvider;
  verifierProvider?: GenProvider;
}

export interface PipelineResult {
  persisted: PersistedQuestion | null;
  attempts: AttemptLog[];
}

function stripJsonFences(raw: string): string {
  let s = raw.trim();
  if (s.startsWith("```")) {
    const firstNl = s.indexOf("\n");
    if (firstNl !== -1) {
      s = s.slice(firstNl + 1);
    }
    const fenceEnd = s.lastIndexOf("```");
    if (fenceEnd !== -1) {
      s = s.slice(0, fenceEnd);
    }
  }
  return s.trim();
}

function parseVerifierVerdict(
  obj: unknown,
): "correct" | "incorrect" | "uncertain" | null {
  if (!obj || typeof obj !== "object") {
    return null;
  }
  const v = (obj as Record<string, unknown>).verdict;
  if (v === "correct" || v === "incorrect" || v === "uncertain") {
    return v;
  }
  return null;
}

function verifierFailReason(
  v: "incorrect" | "uncertain",
): RejectReason {
  return v === "incorrect" ? "verifier_incorrect" : "verifier_uncertain";
}

export async function generateOneQuestion(
  category: Category,
  difficulty: Difficulty,
  deps?: {now?: () => Date},
): Promise<PipelineResult> {
  void deps;
  const attempts: AttemptLog[] = [];
  const db = getFirestore();

  for (let attempt = 1; attempt <= MAX_ATTEMPTS_PER_QUESTION; attempt++) {
    const {systemPrompt, userPrompt} = buildGeneratorPrompt({
      category,
      difficulty,
    });

    let generatorResult: Awaited<ReturnType<typeof generateWithProviders>>;
    try {
      generatorResult = await generateWithProviders(userPrompt, {
        systemPrompt,
        responseFormat: "json_object",
      });
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      attempts.push({
        attempt,
        rejected: true,
        reason: "generator_invalid_json",
        detail,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "generator_invalid_json",
      });
      continue;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(stripJsonFences(generatorResult.raw));
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      attempts.push({
        attempt,
        rejected: true,
        reason: "generator_invalid_json",
        detail,
        generatorProvider: generatorResult.provider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "generator_invalid_json",
      });
      continue;
    }

    if (
      parsed &&
      typeof parsed === "object" &&
      (parsed as Record<string, unknown>).refused === true
    ) {
      const reason =
        typeof (parsed as Record<string, unknown>).reason === "string" ?
          (parsed as Record<string, unknown>).reason as string :
          "";
      attempts.push({
        attempt,
        rejected: true,
        reason: "generator_refused",
        detail: reason,
        generatorProvider: generatorResult.provider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "generator_refused",
      });
      continue;
    }

    if (!isGeneratedQuestion(parsed)) {
      attempts.push({
        attempt,
        rejected: true,
        reason: "generator_schema_invalid",
        detail: "isGeneratedQuestion failed",
        generatorProvider: generatorResult.provider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "generator_schema_invalid",
      });
      continue;
    }

    const genQ = parsed as GeneratedQuestion;
    if (
      !isCategory(genQ.category) ||
      !isDifficulty(genQ.difficulty) ||
      genQ.category !== category ||
      genQ.difficulty !== difficulty
    ) {
      attempts.push({
        attempt,
        rejected: true,
        reason: "generator_schema_invalid",
        detail: "category/difficulty mismatch",
        generatorProvider: generatorResult.provider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "generator_schema_invalid",
      });
      continue;
    }

    const modText =
      `${genQ.question} ${genQ.options.join(" ")}`;
    try {
      const mod = await moderateText(modText);
      if (mod.flagged) {
        attempts.push({
          attempt,
          rejected: true,
          reason: "moderation_flagged",
          detail: mod.categories.join(","),
          generatorProvider: generatorResult.provider,
        });
        logger.warn("pipeline attempt rejected", {
          category,
          difficulty,
          attempt,
          reason: "moderation_flagged",
        });
        continue;
      }
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      attempts.push({
        attempt,
        rejected: true,
        reason: "moderation_flagged",
        detail,
        generatorProvider: generatorResult.provider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "moderation_flagged",
      });
      continue;
    }

    const verifierProvider =
      pickVerifierProvider(generatorResult.provider);
    const vp = buildVerifierPrompt({
      question: genQ.question,
      options: genQ.options,
      correctIndex: genQ.correctIndex,
    });
    const verifierOrder: GenProvider[] = [
      verifierProvider,
      ...GEN_ORDER.filter(
        (p) =>
          p !== verifierProvider &&
          p !== generatorResult.provider,
      ),
    ];

    let vRaw: Awaited<ReturnType<typeof generateWithProviders>>;
    try {
      vRaw = await generateWithProviders(vp.userPrompt, {
        systemPrompt: vp.systemPrompt,
        order: verifierOrder,
        responseFormat: "json_object",
      });
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      attempts.push({
        attempt,
        rejected: true,
        reason: "verifier_invalid_json",
        detail,
        generatorProvider: generatorResult.provider,
        verifierProvider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "verifier_invalid_json",
      });
      continue;
    }

    let vParsed: unknown;
    try {
      vParsed = JSON.parse(stripJsonFences(vRaw.raw));
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      attempts.push({
        attempt,
        rejected: true,
        reason: "verifier_invalid_json",
        detail,
        generatorProvider: generatorResult.provider,
        verifierProvider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "verifier_invalid_json",
      });
      continue;
    }

    const verdict = parseVerifierVerdict(vParsed);
    if (verdict === null || verdict !== "correct") {
      const r =
        verdict === "incorrect" || verdict === "uncertain" ?
          verifierFailReason(verdict) :
          "verifier_invalid_json";
      attempts.push({
        attempt,
        rejected: true,
        reason: r,
        detail:
          verdict === null ?
            "missing verdict" :
            String((vParsed as Record<string, unknown>).reason ?? ""),
        generatorProvider: generatorResult.provider,
        verifierProvider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: r,
      });
      continue;
    }

    let embedding: number[];
    try {
      embedding = await embedText(buildEmbedText({
        question: genQ.question,
        options: genQ.options,
        correctIndex: genQ.correctIndex,
      }));
    } catch (err) {
      const detail =
        "embedding_failed:" +
        (err instanceof Error ? err.message : String(err));
      attempts.push({
        attempt,
        rejected: true,
        reason: "dedup_hit",
        detail,
        generatorProvider: generatorResult.provider,
        verifierProvider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "dedup_hit",
      });
      continue;
    }

    const snapQ = await db
      .collection("questions_public")
      .where("category", "==", category)
      .limit(500)
      .get();

    let duplicateHit = false;
    for (const doc of snapQ.docs) {
      const ex = doc.data();
      const emb = ex.embedding;
      if (
        Array.isArray(emb) &&
        emb.length === EMBEDDING_DIMS &&
        emb.every((n: unknown) => typeof n === "number")
      ) {
        const sim = cosineSimilarity(embedding, emb as number[]);
        if (sim >= DEDUP_THRESHOLD) {
          attempts.push({
            attempt,
            rejected: true,
            reason: "dedup_hit",
            detail: `existing_id:${doc.id}, sim:${sim.toFixed(3)}`,
            generatorProvider: generatorResult.provider,
            verifierProvider,
          });
          logger.warn("pipeline attempt rejected", {
            category,
            difficulty,
            attempt,
            reason: "dedup_hit",
          });
          duplicateHit = true;
          break;
        }
      }
    }
    if (duplicateHit) {
      continue;
    }

    const docRef = db.collection("questions_public").doc();
    await docRef.set({
      id: docRef.id,
      question: genQ.question,
      options: genQ.options,
      correctIndex: genQ.correctIndex,
      category: genQ.category,
      difficulty: genQ.difficulty,
      createdAt: FieldValue.serverTimestamp(),
      generatorProvider: generatorResult.provider,
      verifierProvider,
      embedding,
      useCount: 0,
    });

    const written = await docRef.get();
    const d = written.data();
    if (!d) {
      attempts.push({
        attempt,
        rejected: true,
        reason: "generator_schema_invalid",
        detail: "persist read failed",
        generatorProvider: generatorResult.provider,
        verifierProvider,
      });
      logger.warn("pipeline attempt rejected", {
        category,
        difficulty,
        attempt,
        reason: "generator_schema_invalid",
      });
      continue;
    }

    const persisted: PersistedQuestion = {
      id: docRef.id,
      question: d.question as string,
      options: d.options as [string, string, string, string],
      correctIndex: d.correctIndex as 0 | 1 | 2 | 3,
      category: d.category as Category,
      difficulty: d.difficulty as Difficulty,
      createdAt: d.createdAt as Timestamp,
      generatorProvider: d.generatorProvider as GenProvider,
      verifierProvider: d.verifierProvider as GenProvider,
      embedding: d.embedding as number[] | undefined,
      useCount: typeof d.useCount === "number" ? d.useCount : 0,
      lastUsedAt: d.lastUsedAt as Timestamp | undefined,
    };

    attempts.push({
      attempt,
      rejected: false,
      generatorProvider: generatorResult.provider,
      verifierProvider,
    });
    logger.info("pipeline attempt persisted", {
      category,
      difficulty,
      attempt,
      id: persisted.id,
    });

    return {persisted, attempts};
  }

  return {persisted: null, attempts};
}
