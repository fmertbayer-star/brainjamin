/**
 * PR-13 asymmetry — verifier MUST differ from generator. Deterministic
 * rotation rather than random pick: easier to reason about in tests;
 * uniform load across providers when generator load is uniform.
 */

import type {GenProvider} from "./aiProviders";

export function pickVerifierProvider(generator: GenProvider): GenProvider {
  switch (generator) {
  case "gemini":
    return "openai";
  case "openai":
    return "anthropic";
  case "anthropic":
    return "gemini";
  default: {
    const _exhaustive: never = generator;
    return _exhaustive;
  }
  }
}
