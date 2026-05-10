/**
 * Arena custom-topic generation — reuses LLM/moderation/verifier/embedding helpers
 * without writing to questions_public (Sprint 3.5b).
 */

import {logger} from "firebase-functions/v2";
import {generateWithProviders, type GenProvider} from "../shared/aiProviders";
import {
  buildCustomTopicGeneratorPrompt,
  buildVerifierPrompt,
} from "../shared/prompts";
import type {GeneratedQuestion} from "../shared/questionSchema";
import {isGeneratedQuestion} from "../shared/questionSchema";
import type {Difficulty} from "../shared/difficulty";
import {isDifficulty} from "../shared/difficulty";
import {moderateText} from "../shared/moderation";
import {pickVerifierProvider} from "../shared/verifierProvider";
import {buildEmbedText, embedText} from "../shared/embeddings";
import {
  ARENA_GEN_MAX_ATTEMPTS_PER_QUESTION,
} from "./shared";

const GEN_ORDER: GenProvider[] = ["gemini", "openai", "anthropic"];

export interface ArenaCandidate {
  question: string;
  options: [string, string, string, string];
  correctIndex: 0 | 1 | 2 | 3;
  difficulty: Difficulty;
  generatorProvider: GenProvider;
  verifierProvider: GenProvider;
  embedding: number[];
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

export async function generateOneArenaQuestion(input: {
  topic: string;
  difficulty: Difficulty;
  recentStems: string[];
}): Promise<ArenaCandidate | null> {
  const {topic, difficulty, recentStems} = input;

  for (let attempt = 1; attempt <= ARENA_GEN_MAX_ATTEMPTS_PER_QUESTION; attempt++) {
    const {systemPrompt, userPrompt} = buildCustomTopicGeneratorPrompt({
      topic,
      difficulty,
      recentStems,
    });

    let generatorResult: Awaited<ReturnType<typeof generateWithProviders>>;
    try {
      generatorResult = await generateWithProviders(userPrompt, {
        systemPrompt,
        responseFormat: "json_object",
      });
    } catch {
      continue;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(stripJsonFences(generatorResult.raw));
    } catch {
      continue;
    }

    if (
      parsed &&
      typeof parsed === "object" &&
      (parsed as Record<string, unknown>).refused === true
    ) {
      continue;
    }

    if (!isGeneratedQuestion(parsed)) {
      continue;
    }

    const genQ = parsed as GeneratedQuestion;
    if (!isDifficulty(genQ.difficulty) || genQ.difficulty !== difficulty) {
      continue;
    }

    const modText = `${genQ.question} ${genQ.options.join(" ")}`;
    try {
      const mod = await moderateText(modText);
      if (mod.flagged) {
        continue;
      }
    } catch {
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
    } catch {
      continue;
    }

    let vParsed: unknown;
    try {
      vParsed = JSON.parse(stripJsonFences(vRaw.raw));
    } catch {
      continue;
    }

    const verdict = parseVerifierVerdict(vParsed);
    if (verdict !== "correct") {
      continue;
    }

    let embedding: number[];
    try {
      embedding = await embedText(
        buildEmbedText({
          question: genQ.question,
          options: genQ.options,
          correctIndex: genQ.correctIndex,
        }),
      );
    } catch {
      continue;
    }

    return {
      question: genQ.question,
      options: genQ.options,
      correctIndex: genQ.correctIndex,
      difficulty: genQ.difficulty,
      generatorProvider: generatorResult.provider,
      verifierProvider,
      embedding,
    };
  }

  logger.warn("generateOneArenaQuestion exhausted attempts", {topic});
  return null;
}
