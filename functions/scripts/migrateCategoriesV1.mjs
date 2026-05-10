/**
 * DESTRUCTIVE — run only after reviewing output.
 *
 * Migrates questions_public to the V1 canonical 20-category list: deletes every
 * question whose category is not in the canonical set (or is missing), deletes
 * matching embeddings/{qId}, and removes category_rotation/state so you can
 * re-run initCategoryRotation.mjs.
 *
 *   node functions/scripts/migrateCategoriesV1.mjs
 *
 * Requires: gcloud auth application-default login
 */

import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getFirestore, FieldPath} from "firebase-admin/firestore";

const BATCH_SIZE = 400;
const PAGE_SIZE = 500;

const CANONICAL = [
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

const canonicalSet = new Set(CANONICAL);

initializeApp({credential: applicationDefault()});
const db = getFirestore();

async function scanQuestionsPublic() {
  const deadRefs = [];
  let alive = 0;
  /** @type {Record<string, number>} */
  const deadBreakdown = {};

  let lastDoc = null;
  let scanned = 0;

  while (true) {
    let q = db
      .collection("questions_public")
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDoc) {
      q = q.startAfter(lastDoc);
    }
    const snap = await q.get();
    if (snap.empty) {
      break;
    }

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data();
      const cat = data.category;
      if (typeof cat === "string" && canonicalSet.has(cat)) {
        alive++;
      } else {
        deadRefs.push(doc.ref);
        const key =
          cat === undefined || cat === null ? "<missing>" : String(cat);
        deadBreakdown[key] = (deadBreakdown[key] || 0) + 1;
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < PAGE_SIZE) {
      break;
    }
  }

  return {deadRefs, alive, scanned, deadBreakdown};
}

async function deleteInBatches(refs) {
  let batchNum = 0;
  let total = 0;
  for (let i = 0; i < refs.length; i += BATCH_SIZE) {
    const chunk = refs.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const ref of chunk) {
      batch.delete(ref);
    }
    await batch.commit();
    batchNum++;
    total += chunk.length;
    console.log(`Batch ${batchNum} committed: ${chunk.length} docs deleted`);
  }
  return total;
}

async function main() {
  console.log("Scanning questions_public...");
  const {deadRefs, alive, scanned, deadBreakdown} = await scanQuestionsPublic();
  const dead = deadRefs.length;

  console.log("\n--- Pre-delete summary ---");
  console.log(`Total docs scanned: ${scanned}`);
  console.log(`Alive count: ${alive}`);
  console.log(`Dead count: ${dead}`);
  console.log("Dead category breakdown:", JSON.stringify(deadBreakdown, null, 2));

  const deadIds = deadRefs.map((r) => r.id);

  let questionsDeleted = 0;
  if (deadRefs.length > 0) {
    console.log("\nDeleting dead question docs...");
    questionsDeleted = await deleteInBatches(deadRefs);
  } else {
    console.log("\nNo dead question docs to delete.");
  }

  let embeddingsDeleted = 0;
  if (deadIds.length > 0) {
    const embeddingRefs = deadIds.map((id) =>
      db.collection("embeddings").doc(id),
    );
    console.log("\nDeleting embeddings...");
    embeddingsDeleted = await deleteInBatches(embeddingRefs);
    console.log(`Embeddings cleanup: ${embeddingsDeleted} docs deleted`);
  } else {
    console.log("\nEmbeddings cleanup: 0 docs deleted");
  }

  const rotRef = db.collection("category_rotation").doc("state");
  const rotSnap = await rotRef.get();
  if (rotSnap.exists) {
    await rotRef.delete();
    console.log(
      "\nOld rotation state deleted; run initCategoryRotation.mjs next.",
    );
  }

  console.log("\n--- Final summary ---");
  console.log(`Questions deleted: ${questionsDeleted}`);
  console.log(`Embeddings deleted: ${embeddingsDeleted}`);
  console.log(`Questions remaining (alive): ${alive}`);

  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
