import type {Category} from "./categories";
import type {Difficulty} from "./difficulty";
import {DIFFICULTY_LABELS} from "./difficulty";

export interface GenPromptInput {
  category: Category;
  difficulty: Difficulty;
}

/**
 * Generator: JSON-only output, US English, PR-13 / PR-8 constraints.
 */
export function buildGeneratorPrompt(input: GenPromptInput): {
  systemPrompt: string;
  userPrompt: string;
} {
  const diffLabel = DIFFICULTY_LABELS[input.difficulty];
  const astroExtra =
    input.category === "astrology" ?
      "\n\nFrame as astrological tradition (sun signs, houses, planetary " +
      "associations) — not as scientific claims about personality or future " +
      "events. The verifier will accept questions about traditional " +
      "astrological associations as factually correct within that tradition." :
      "";

  const systemPrompt =
    "You write verifiable multiple-choice trivia for a mobile game. " +
    "Output must be valid JSON only — no markdown, no prose outside JSON.\n\n" +
    "Either return exactly one of:\n" +
    "(1) {\"refused\": true, \"reason\": \"<short>\"}\n" +
    "OR\n" +
    "(2) {\"question\": string, \"options\": [string, string, string, string], " +
    "\"correctIndex\": 0|1|2|3, \"category\": \"<the category passed in>\", " +
    "\"difficulty\": <number>}\n\n" +
    "Rules:\n" +
    "- US English spelling.\n" +
    "- Exactly four options; the marked correct answer must be unambiguously " +
    "true; three distractors plausible but verifiably incorrect.\n" +
    "- If unsure of any date, figure, name, or source, do NOT generate. " +
    "Return {\"refused\": true, \"reason\": \"<short>\"} instead.\n" +
    "- Self-contained — no images, audio, or external context.\n" +
    "- Avoid current-events questions whose answer may have shifted in the " +
    "last 12 months.\n" +
    "- Avoid politically inflammatory framing.\n" +
    `- Difficulty is ${input.difficulty} (${diffLabel}): 1=very_easy … ` +
    "5=very_hard.\n" +
    `- Stay strictly within category "${input.category}".\n` +
    "- Do not include an explanation field (schema has none).\n" +
    astroExtra;

  const userPrompt =
    `Generate one question for category "${input.category}" at difficulty ` +
    `${input.difficulty} (label: ${diffLabel}). ` +
    `Echo "category" as exactly "${input.category}" and "difficulty" as ` +
    `the integer ${input.difficulty}.`;

  return {systemPrompt, userPrompt};
}

export interface VerifierPromptInput {
  question: string;
  options: [string, string, string, string];
  correctIndex: 0 | 1 | 2 | 3;
}

/**
 * Verifier: JSON verdict; only "correct" passes (incorrect + uncertain reject).
 */
export function buildVerifierPrompt(input: VerifierPromptInput): {
  systemPrompt: string;
  userPrompt: string;
} {
  const opts = JSON.stringify(input.options);
  const systemPrompt =
    "You verify multiple-choice trivia. Output valid JSON only, no markdown.\n" +
    "Schema: {\"verdict\": \"correct\"|\"incorrect\"|\"uncertain\", " +
    "\"reason\": \"<one sentence>\"}\n\n" +
    "Decision rules:\n" +
    "- \"correct\": the marked answer is true AND all three other options are " +
    "false.\n" +
    "- \"incorrect\": the marked answer is wrong, OR more than one option is " +
    "correct, OR the marked answer is ambiguous.\n" +
    "- \"uncertain\": you cannot verify with high confidence.\n" +
    "Only verdict \"correct\" passes review. Both \"incorrect\" and " +
    "\"uncertain\" mean rejection.";

  const userPrompt =
    `Question: ${input.question}\n` +
    `Options (index 0–3): ${opts}\n` +
    `Marked correct index: ${input.correctIndex}\n` +
    "Return the JSON verdict.";

  return {systemPrompt, userPrompt};
}
