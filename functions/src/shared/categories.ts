/**
 * V1 canonical list — 20 categories driving the 10-day tournament rotation per BRAINJAMIN.md § TOURNAMENT ENGINE.
 * Adding a category requires also updating the Flutter-side mirror
 * (Sprint 2.2.b will note its location). Removing a category leaves orphaned questions in the
 * pool — handle migration explicitly.
 */

export const CATEGORIES = [
  "history",
  "geography",
  "movies_tv",
  "music",
  "sports",
  "science",
  "technology",
  "literature",
  "art",
  "food_drink",
  "animals",
  "nature",
  "pop_culture",
  "mythology",
  "video_games",
  "fashion",
  "astrology",
  "health",
  "space",
  "world_capitals",
] as const;

export type Category = typeof CATEGORIES[number];

export function isCategory(x: unknown): x is Category {
  return typeof x === "string" && (CATEGORIES as readonly string[]).includes(x);
}
