/**
 * Arena (Sprint 3.5a) — constants and validation helpers.
 */

import type {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {isCategory} from "../shared/categories";

export const ARENA_MAX_PER_DAY = 3;
export const ARENA_MIN_LEAD_MINUTES = 10;
export const ARENA_MAX_LEAD_HOURS = 24;
export const ARENA_QUESTION_COUNT = 10;

/** Sync tick (Sprint 3.5d-1) — mirrors Live tournament pacing. */
export const ARENA_ANSWER_WINDOW_MS = 15_000;
export const ARENA_REVEAL_DISPLAY_MS = 3000;
export const QUESTIONS_PER_ARENA = 10;
/** Late join closes when advancing past this 0-based question index (after Q3 reveal). */
export const ARENA_LATE_JOIN_CLOSE_AT_Q_INDEX = 3;

/** Two questions per difficulty 1–5 (10 total). Used by generateArenaQuestions. */
export const ARENA_DIFFICULTY_DISTRIBUTION: ReadonlyArray<{
  difficulty: 1 | 2 | 3 | 4 | 5;
  count: number;
}> = [
  {difficulty: 1, count: 2},
  {difficulty: 2, count: 2},
  {difficulty: 3, count: 2},
  {difficulty: 4, count: 2},
  {difficulty: 5, count: 2},
];

export const ARENA_CUSTOM_TOPIC_MAX_LEN = 80;
export const ARENA_CUSTOM_TOPIC_MIN_LEN = 3;
export const ARENA_GEN_MAX_ATTEMPTS_PER_QUESTION = 5;
export const ARENA_GEN_INTRA_DEDUP_THRESHOLD = 0.88;

/** XP grant tiers when an arena finalizes (Sprint 3.5c). */
export const ARENA_XP_BY_RANK = {
  rank1: 100,
  rank2to3: 50,
  rankRest: 25,
} as const;

export interface ArenaQuestionDoc {
  arena_id: string;
  q_index: number;
  question: string;
  options: [string, string, string, string];
  /** Client-visible correct choice; null until tick reveal (see runArenaTournament Option C). */
  correct_index: number | null;
  /** Server copy of correct_index for reveal/scoring; written when scheduled→running. */
  correct_index_server?: number;
  started_at?: Timestamp | null;
  difficulty: number;
  source_type: "preset" | "custom_topic";
  source_question_id?: string;
  generator_provider?: string;
  verifier_provider?: string;
  created_at: Timestamp;
}

export interface ArenaViabilityResult {
  viable: boolean;
  reason?: string;
  suggestion?: string;
}

export type ArenaMode = "list" | "battle";
export type ArenaSourceType = "preset" | "custom_topic";
export type ArenaStatus =
  | "preparing"
  | "scheduled"
  | "running"
  | "ended"
  | "no_participants"
  | "generation_failed"
  | "expired";

const MS_PER_MINUTE = 60 * 1000;
const MS_PER_HOUR = 60 * MS_PER_MINUTE;

export function utcDateKeyYyyyMmDd(nowMs: number): string {
  return new Date(nowMs).toISOString().slice(0, 10);
}

export function assertWindow(scheduledStartMs: number, nowMs: number): void {
  const minStart = nowMs + ARENA_MIN_LEAD_MINUTES * MS_PER_MINUTE;
  const maxStart = nowMs + ARENA_MAX_LEAD_HOURS * MS_PER_HOUR;
  if (scheduledStartMs < minStart || scheduledStartMs > maxStart) {
    throw new HttpsError(
      "invalid-argument",
      "scheduled_start_outside_window",
    );
  }
}

export function assertCategoryOrTopic(
  sourceType: ArenaSourceType,
  categoryId: unknown,
  customTopic: unknown,
): {categoryId: string | null; customTopic: string | null} {
  if (sourceType === "preset") {
    if (typeof categoryId !== "string" || !isCategory(categoryId)) {
      throw new HttpsError("invalid-argument", "invalid_category_id");
    }
    if (customTopic !== undefined && customTopic !== null && customTopic !== "") {
      throw new HttpsError("invalid-argument", "custom_topic_must_be_empty");
    }
    return {categoryId, customTopic: null};
  }
  if (sourceType === "custom_topic") {
    if (categoryId !== undefined && categoryId !== null && categoryId !== "") {
      throw new HttpsError("invalid-argument", "category_id_must_be_empty");
    }
    if (typeof customTopic !== "string") {
      throw new HttpsError("invalid-argument", "invalid_custom_topic");
    }
    const trimmed = customTopic.trim();
    if (trimmed.length < 1 || trimmed.length > 80) {
      throw new HttpsError("invalid-argument", "invalid_custom_topic_length");
    }
    return {categoryId: null, customTopic: trimmed};
  }
  throw new HttpsError("invalid-argument", "invalid_source_type");
}

export function isArenaMode(x: unknown): x is ArenaMode {
  return x === "list" || x === "battle";
}

export function isArenaSourceType(x: unknown): x is ArenaSourceType {
  return x === "preset" || x === "custom_topic";
}
