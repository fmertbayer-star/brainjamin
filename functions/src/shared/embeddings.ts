/**
 * Brainjamin V1 dedup: cosine ≥ 0.88 threshold per PR-13. Threshold tuning is a Sprint 2.3 task after pilot batch.
 */

import OpenAI from "openai";
import {getEnv} from "./aiProviders";

export const EMBEDDING_MODEL = "text-embedding-3-small";
export const EMBEDDING_DIMS = 1536;
export const DEDUP_THRESHOLD = 0.88;

export function buildEmbedText(input: {
  question: string;
  options: readonly string[];
  correctIndex: number;
}): string {
  const q = input.question.trim();
  const o = input.options;
  const a = o[input.correctIndex].trim();
  return (
    `Q: ${q}\n` +
    `A: ${a}\n` +
    `Options: ${o[0].trim()} | ${o[1].trim()} | ${o[2].trim()} | ${o[3].trim()}`
  );
}

export async function embedText(text: string): Promise<number[]> {
  const apiKey = getEnv("OPENAI_API_KEY");
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");
  const client = new OpenAI({apiKey});
  const res = await client.embeddings.create({
    model: EMBEDDING_MODEL,
    input: text,
  });
  const emb = res.data[0]?.embedding;
  if (!emb) throw new Error("OpenAI embeddings returned no vector");
  return emb;
}

export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error(`cosineSimilarity: length mismatch (${a.length} vs ${b.length})`);
  }
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  const denom = Math.sqrt(na) * Math.sqrt(nb);
  if (denom === 0) return 0;
  return dot / denom;
}
