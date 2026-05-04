/**
 * V1 category whitelist. Adding a category requires also updating the Flutter-side mirror
 * (Sprint 2.2.b will note its location). Removing a category leaves orphaned questions in the
 * pool — handle migration explicitly.
 */

export const CATEGORIES = [
  "history",
  "geography",
  "science",
  "nature",
  "technology",
  "sports",
  "music",
  "movies",
  "tv",
  "literature",
  "art",
  "food",
  "language",
  "mythology",
  "astrology",
  "politics",
  "business",
  "mathematics",
  "general_knowledge",
  "pop_culture",
] as const;

export type Category = typeof CATEGORIES[number];

export function isCategory(x: unknown): x is Category {
  return typeof x === "string" && (CATEGORIES as readonly string[]).includes(x);
}
