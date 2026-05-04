import type {Timestamp} from "firebase-admin/firestore";
import type {Category} from "./categories";
import type {Difficulty} from "./difficulty";

/**
 * Canonical AI question shape. No explanation field (PR-8 DEPRECATED).
 */
export interface GeneratedQuestion {
  question: string;
  options: [string, string, string, string];
  correctIndex: 0 | 1 | 2 | 3;
  category: Category;
  difficulty: Difficulty;
}

export interface PersistedQuestion extends GeneratedQuestion {
  id: string;
  createdAt: Timestamp;
  generatorProvider: "gemini" | "openai" | "anthropic";
  verifierProvider: "gemini" | "openai" | "anthropic";
  embedding?: number[];
  useCount: number;
  lastUsedAt?: Timestamp;
}

export function isGeneratedQuestion(x: unknown): x is GeneratedQuestion {
  if (!x || typeof x !== "object") return false;
  const q = x as Record<string, unknown>;
  if (typeof q.question !== "string" || q.question.length === 0) return false;
  if (!Array.isArray(q.options) || q.options.length !== 4) return false;
  if (!q.options.every((o) => typeof o === "string" && o.length > 0)) return false;
  if (![0, 1, 2, 3].includes(q.correctIndex as number)) return false;
  // category/difficulty checks delegated to isCategory / isDifficulty at call site
  return true;
}
