/**
 * One-off: delete all docs under used_questions/{TARGET_UID}/seen (dedup pool for that user).
 *
 * Run from functions/: node scripts/clearTestUserSeen.mjs
 *
 * Requires: gcloud auth application-default login
 */

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { createInterface } from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";

const TARGET_UID = "4cUTLpjl9OhVjFfklYFtOLaIgQh2"; // info@stratechdynamic.net (Stratech admin)

try {
  initializeApp({
    credential: applicationDefault(),
    projectId: "brainjamin-prod-app",
  });
} catch (err) {
  console.error(
    "Failed to initialize firebase-admin. Have you run `gcloud auth application-default login`?",
  );
  console.error(err);
  process.exit(1);
}

const db = getFirestore();

async function main() {
  try {
    const seenRef = db
      .collection("used_questions")
      .doc(TARGET_UID)
      .collection("seen");
    const snap = await seenRef.get();
    const docs = snap.docs;
    const N = docs.length;

    console.log(`Found ${N} seen entries for UID ${TARGET_UID}`);

    if (N === 0) {
      console.log("Nothing to clean. Exiting.");
      process.exit(0);
    }

    const rl = createInterface({ input, output });
    const answer = await rl.question(
      `Delete ${N} seen entries? Type 'yes' to confirm: `,
    );
    await rl.close();

    if (answer.trim().toLowerCase() !== "yes") {
      console.log("Cancelled.");
      process.exit(0);
    }

    const refs = docs.map((d) => d.ref);
    const batchSize = 500;
    const M = Math.ceil(refs.length / batchSize);
    let k = 0;

    for (let i = 0; i < refs.length; i += batchSize) {
      k += 1;
      const chunk = refs.slice(i, i + batchSize);
      const batch = db.batch();
      for (const ref of chunk) {
        batch.delete(ref);
      }
      await batch.commit();
      console.log(
        `Deleted batch ${k} of ${M} (${chunk.length} docs)...`,
      );
    }

    console.log(
      `Deleted ${N} seen entries for UID ${TARGET_UID}. Pool dedup window cleared.`,
    );
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

await main();
