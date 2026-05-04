/**
 * Shared multi-provider AI text generation helper (Brainjamin PR-13 order).
 *
 * Failover policy:
 *   - Tries providers in `order` (default: gemini → openai → anthropic).
 *   - One attempt per provider, no internal retry, no backoff.
 *   - 60s timeout per provider attempt.
 *   - On any thrown error or timeout, moves to the next provider.
 *   - If all providers fail, throws the last error.
 *
 * Model strings are loaded via getAiModels() from ai_config/models with a
 * 5-minute in-memory cache and fail-soft fallback.
 */

import Anthropic from "@anthropic-ai/sdk";
import {GoogleGenerativeAI} from "@google/generative-ai";
import OpenAI from "openai";
import * as logger from "firebase-functions/logger";
import {getAiModels} from "./aiModelsLoader";

export type GenProvider = "gemini" | "openai" | "anthropic";

export type ResponseFormat = "json_object" | "text";

export interface ProviderOptions {
  /** Optional system prompt. Sent as native system message on OpenAI/Anthropic;
   *  concatenated before the user prompt on Gemini. */
  systemPrompt?: string;
  /** Order of providers to try. Default: ["gemini", "openai", "anthropic"]. */
  order?: GenProvider[];
  /** Per-provider model override. Defaults applied when missing. */
  models?: {
    gemini?: string;
    openai?: string;
    anthropic?: string;
  };
  /** Max output tokens. Default 16384. */
  maxOutputTokens?: number;
  /** Temperature. Default 0.7. */
  temperature?: number;
  /** Timeout per provider attempt in ms. Default 60000. */
  timeoutMs?: number;
  /** Response format hint. Default "json_object". */
  responseFormat?: ResponseFormat;
}

export interface ProviderResult {
  raw: string;
  provider: GenProvider;
}

const DEFAULT_ORDER: GenProvider[] = ["gemini", "openai", "anthropic"];
const DEFAULT_MAX_TOKENS = 16384;
const DEFAULT_TEMPERATURE = 0.7;
const DEFAULT_TIMEOUT_MS = 60_000;
const DEFAULT_RESPONSE_FORMAT: ResponseFormat = "json_object";

/** Reads process.env for LLM + moderation keys when secrets are attached at deploy time. */
export function getEnv(name: string): string | undefined {
  const v = process.env[name]?.trim() || undefined;
  return v;
}

function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`${label} timeout (${ms}ms)`)), ms);
    promise.then(
      (v) => {
        clearTimeout(t);
        resolve(v);
      },
      (e) => {
        clearTimeout(t);
        reject(e);
      },
    );
  });
}

async function callGemini(
  systemPrompt: string | undefined,
  userPrompt: string,
  model: string,
  maxTokens: number,
  temperature: number,
): Promise<string> {
  const apiKey = getEnv("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY not set");
  const gen = new GoogleGenerativeAI(apiKey);
  const m = gen.getGenerativeModel({model});
  const combined = systemPrompt ? `${systemPrompt}\n\n${userPrompt}` : userPrompt;
  const res = await m.generateContent({
    contents: [{role: "user", parts: [{text: combined}]}],
    generationConfig: {
      maxOutputTokens: maxTokens,
      temperature,
    },
  });
  const text = res.response.text();
  if (!text) throw new Error("Gemini returned empty content");
  return text;
}

async function callOpenAI(
  systemPrompt: string | undefined,
  userPrompt: string,
  model: string,
  maxTokens: number,
  temperature: number,
  responseFormat: ResponseFormat,
): Promise<string> {
  const apiKey = getEnv("OPENAI_API_KEY");
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");
  const client = new OpenAI({apiKey});
  const messages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [];
  if (systemPrompt) {
    messages.push({role: "system", content: systemPrompt});
  }
  messages.push({role: "user", content: userPrompt});
  const res = await client.chat.completions.create({
    model,
    temperature,
    max_completion_tokens: maxTokens,
    messages,
    response_format: responseFormat === "json_object" ? {type: "json_object"} : undefined,
  });
  const content = res.choices[0]?.message?.content ?? "";
  if (!content) throw new Error("OpenAI returned empty content");
  return content;
}

async function callAnthropic(
  systemPrompt: string | undefined,
  userPrompt: string,
  model: string,
  maxTokens: number,
): Promise<string> {
  const apiKey = getEnv("ANTHROPIC_API_KEY");
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");
  const client = new Anthropic({apiKey});
  const params: Anthropic.MessageCreateParamsNonStreaming = {
    model,
    max_tokens: maxTokens,
    messages: [{role: "user", content: userPrompt}],
  };
  if (systemPrompt) {
    params.system = systemPrompt;
  }
  const res = await client.messages.create(params);
  const block = res.content.find((b: {type: string}) => b.type === "text");
  const raw = block && block.type === "text" ? block.text : "";
  if (!raw.trim()) throw new Error("Anthropic returned empty content");
  return raw;
}

/**
 * Generate text via the configured provider chain with failover.
 *
 * @throws The last provider error if all providers fail.
 */
export async function generateWithProviders(
  prompt: string,
  options: ProviderOptions = {},
): Promise<ProviderResult> {
  const systemPrompt = options.systemPrompt;
  const order = options.order ?? DEFAULT_ORDER;
  const loaded = await getAiModels();
  const defaults: Record<GenProvider, string> = {
    gemini: loaded.gemini_model,
    openai: loaded.openai_model,
    anthropic: loaded.anthropic_model,
  };
  const overrides = options.models ?? {};
  const models: Record<GenProvider, string> = {
    gemini: overrides.gemini ?? defaults.gemini,
    openai: overrides.openai ?? defaults.openai,
    anthropic: overrides.anthropic ?? defaults.anthropic,
  };
  const maxTokens = options.maxOutputTokens ?? DEFAULT_MAX_TOKENS;
  const temperature = options.temperature ?? DEFAULT_TEMPERATURE;
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const responseFormat = options.responseFormat ?? DEFAULT_RESPONSE_FORMAT;

  let lastErr: unknown = new Error("No providers attempted");

  for (const provider of order) {
    try {
      logger.info({
        message: "[aiProviders] trying",
        provider,
        model: models[provider],
      });
      let raw: string;
      if (provider === "gemini") {
        raw = await withTimeout(
          callGemini(systemPrompt, prompt, models.gemini, maxTokens, temperature),
          timeoutMs,
          "gemini",
        );
      } else if (provider === "openai") {
        raw = await withTimeout(
          callOpenAI(
            systemPrompt,
            prompt,
            models.openai,
            maxTokens,
            temperature,
            responseFormat,
          ),
          timeoutMs,
          "openai",
        );
      } else if (provider === "anthropic") {
        raw = await withTimeout(
          callAnthropic(systemPrompt, prompt, models.anthropic, maxTokens),
          timeoutMs,
          "anthropic",
        );
      } else {
        throw new Error(`Unknown provider: ${provider as string}`);
      }
      logger.info({message: "[aiProviders] success", provider});
      return {raw, provider};
    } catch (e) {
      lastErr = e;
      logger.warn({
        message: "[aiProviders] provider failed",
        provider,
        err: String(e),
      });
    }
  }

  const detail = lastErr instanceof Error ? lastErr.message : String(lastErr);
  throw new Error(`All AI providers failed: ${detail}`);
}
