/**
 * Defaults are intentionally cheap/fast. Override at runtime by writing to
 * Firestore `ai_config/models` document. Cache TTL 5 min — use
 * `invalidateAiModelsCache()` after write if immediate effect is needed.
 *
 * Source path: `ai_config/models` with fields:
 *   - gemini_model
 *   - openai_model
 *   - anthropic_model
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const CACHE_TTL_MS = 5 * 60 * 1000;

export type AiModelsConfig = {
  gemini_model: string;
  openai_model: string;
  anthropic_model: string;
};

const FALLBACK_MODELS: AiModelsConfig = {
  gemini_model: "gemini-2.5-flash",
  openai_model: "gpt-4o-mini",
  anthropic_model: "claude-haiku-4-5-20251001",
};

let cachedModels: AiModelsConfig | null = null;
let cacheTimestamp = 0;

function nonEmptyStringOrFallback(
  data: Record<string, unknown>,
  key: "gemini_model" | "openai_model" | "anthropic_model",
  fallback: string,
): string {
  const v = data[key];
  if (typeof v === "string" && v.trim()) return v;
  return fallback;
}

export async function getAiModels(): Promise<AiModelsConfig> {
  const now = Date.now();
  if (cachedModels && now - cacheTimestamp < CACHE_TTL_MS) {
    return cachedModels;
  }

  try {
    const doc = await admin.firestore().collection("ai_config").doc("models").get();
    if (doc.exists) {
      const data = (doc.data() ?? {}) as Record<string, unknown>;
      const config: AiModelsConfig = {
        gemini_model: nonEmptyStringOrFallback(
          data,
          "gemini_model",
          FALLBACK_MODELS.gemini_model,
        ),
        openai_model: nonEmptyStringOrFallback(
          data,
          "openai_model",
          FALLBACK_MODELS.openai_model,
        ),
        anthropic_model: nonEmptyStringOrFallback(
          data,
          "anthropic_model",
          FALLBACK_MODELS.anthropic_model,
        ),
      };
      cachedModels = config;
      cacheTimestamp = now;
      return config;
    }
    logger.info("ai_config/models document missing, using fallback models");
  } catch (err) {
    logger.warn("Failed to load ai models from Firestore, using fallback", {
      err: String(err),
    });
  }

  cachedModels = {...FALLBACK_MODELS};
  cacheTimestamp = now;
  return cachedModels;
}

export function invalidateAiModelsCache(): void {
  cachedModels = null;
  cacheTimestamp = 0;
}
