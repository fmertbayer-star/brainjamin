/**
 * Brainjamin AI provider secrets. Attach via `secrets: [...AI_SECRETS]` on
 * every callable that calls `generateWithProviders` or any verifier.
 */

import {defineSecret} from "firebase-functions/params";

export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
export const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
export const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

export const AI_SECRETS = [
  GEMINI_API_KEY,
  OPENAI_API_KEY,
  ANTHROPIC_API_KEY,
];
