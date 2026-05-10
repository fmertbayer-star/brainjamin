/**
 * One-shot: initialize category_rotation/state (canonical category order matches
 * functions/src/shared/categories.ts). Idempotent — skips if doc exists.
 *
 *   node functions/scripts/initCategoryRotation.mjs
 *
 * Requires: gcloud auth application-default login (same as other Admin scripts).
 */
import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

// Mirror of CATEGORIES in functions/src/shared/categories.ts (TS not imported).
const CATEGORIES = [
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
];

initializeApp({credential: applicationDefault()});
const db = getFirestore();

async function main() {
  const ref = db.collection("category_rotation").doc("state");
  const snap = await ref.get();
  if (snap.exists) {
    console.log("category_rotation/state already exists; aborting");
    process.exit(0);
  }

  const payload = {
    currentIndex: 0,
    categories: CATEGORIES,
    lastRotatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  await ref.set(payload);
  const written = await ref.get();
  console.log(written.data());
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
