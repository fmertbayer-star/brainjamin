/**
 * OpenAI Moderation API is free — no rate-limit concern at our scale (4000 questions seed +
 * ~1200/month). Pipeline policy (PR-13): any flag → reject + regenerate.
 */

import OpenAI from "openai";
import {getEnv} from "./aiProviders";

export interface ModerationResult {
  flagged: boolean;
  categories: string[];
}

/**
 * Runs OpenAI moderation on text. Throws on API/network errors.
 */
export async function moderateText(text: string): Promise<ModerationResult> {
  const apiKey = getEnv("OPENAI_API_KEY");
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");
  const client = new OpenAI({apiKey});
  const res = await client.moderations.create({
    model: "omni-moderation-latest",
    input: text,
  });
  const result = res.results[0];
  if (!result) {
    throw new Error("OpenAI moderation returned no results");
  }
  const flagged = result.flagged;
  const categories: string[] = [];
  const cats = result.categories;
  if (cats && typeof cats === "object") {
    for (const [name, v] of Object.entries(cats)) {
      if (v === true) categories.push(name);
    }
  }
  return {flagged, categories};
}
