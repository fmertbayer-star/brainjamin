/**
 * Reset a stuck scheduled arena + question docs for a clean tick retry.
 * Run: node functions/scripts/cleanup_arena.mjs [arenaId]
 * Default arenaId: uKYh0qHrwwulBK9skfJA
 */

import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {initializeApp, applicationDefault} from "firebase-admin/app";

const ARENA_ID =
  process.argv[2] ?? "uKYh0qHrwwulBK9skfJA";
const Q_COUNT = 10;

initializeApp({
  credential: applicationDefault(),
  projectId: "brainjamin-prod-app",
});
const db = getFirestore();

async function main() {
  console.log("cleanup arena_id:", ARENA_ID);

  const batch = db.batch();
  const arenaRef = db.collection("arenas").doc(ARENA_ID);

  for (let i = 0; i < Q_COUNT; i++) {
    const qRef = db
      .collection("arena_questions")
      .doc(ARENA_ID)
      .collection("q")
      .doc(String(i));
    const snap = await qRef.get();
    if (!snap.exists) {
      console.log("skip missing", "q/" + i);
      continue;
    }
    const surf = snap.get("correct_index");
    const server = snap.get("correct_index_server");
    const updates = {};

    if (surf == null && typeof server === "number") {
      updates.correct_index = server;
    }
    if (server !== undefined && server !== null) {
      updates.correct_index_server = FieldValue.delete();
    }
    if (snap.get("started_at") !== undefined && snap.get("started_at") !== null) {
      updates.started_at = FieldValue.delete();
    }

    if (Object.keys(updates).length > 0) {
      batch.update(qRef, updates);
      console.log("q/" + i, "patch", Object.keys(updates));
    } else {
      console.log("q/" + i, "no question changes");
    }
  }

  batch.update(arenaRef, {
    lock_holder: null,
    lock_expires_at: null,
    q_ids: null,
    current_question: null,
    reveal_active: null,
    late_join_closed: null,
    last_heartbeat_at: null,
    updated_at: FieldValue.serverTimestamp(),
  });

  await batch.commit();
  console.log("arena patch: cleared lease/runtime fields (status + scheduled_start_at unchanged)");
  console.log("done");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
