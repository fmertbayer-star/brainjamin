/**
 * Dump arenas/{id}, arena_questions/{id}/q/0..9, arena_participants users.
 * Run from repo root: node functions/scripts/diagnose_arena.mjs [arenaId]
 * Requires GOOGLE_APPLICATION_CREDENTIALS or gcloud application-default credentials.
 */

import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

const ARENA_ID =
  process.argv[2] ?? "uKYh0qHrwwulBK9skfJA";
const Q_COUNT = 10;

initializeApp({
  credential: applicationDefault(),
  projectId: "brainjamin-prod-app",
});
const db = getFirestore();

function serializeValue(v) {
  if (v === null || v === undefined) {
    return v;
  }
  if (v instanceof Timestamp) {
    return {__type: "Timestamp", iso: v.toDate().toISOString(), millis: v.toMillis()};
  }
  if (Array.isArray(v)) {
    return v.map(serializeValue);
  }
  if (typeof v === "object" && v.constructor === Object) {
    const out = {};
    for (const [k, val] of Object.entries(v)) {
      out[k] = serializeValue(val);
    }
    return out;
  }
  return v;
}

async function main() {
  console.log("arena_id:", ARENA_ID);

  const arenaSnap = await db.collection("arenas").doc(ARENA_ID).get();
  console.log("\n--- arenas/" + ARENA_ID + " ---");
  console.log(JSON.stringify(serializeValue(arenaSnap.data()), null, 2));

  console.log("\n--- arena_questions/" + ARENA_ID + "/q ---");
  for (let i = 0; i < Q_COUNT; i++) {
    const qSnap = await db
      .collection("arena_questions")
      .doc(ARENA_ID)
      .collection("q")
      .doc(String(i))
      .get();
    const label = `q/${i}`;
    if (!qSnap.exists) {
      console.log(label, "MISSING");
      continue;
    }
    console.log(label, JSON.stringify(serializeValue(qSnap.data()), null, 2));
  }

  const usersSnap = await db
    .collection("arena_participants")
    .doc(ARENA_ID)
    .collection("users")
    .get();
  console.log("\n--- arena_participants/" + ARENA_ID + "/users (" + usersSnap.size + " docs) ---");
  for (const d of usersSnap.docs) {
    console.log("user", d.id, JSON.stringify(serializeValue(d.data()), null, 2));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
