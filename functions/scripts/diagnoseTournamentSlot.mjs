/**
 * Read-only diagnostic: dump one tournament doc + category rotation state.
 * Run: node functions/scripts/diagnoseTournamentSlot.mjs
 * Requires GOOGLE_APPLICATION_CREDENTIALS or gcloud ADC (same as other admin scripts).
 */

import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

initializeApp({credential: applicationDefault()});
const db = getFirestore();

const TOURNAMENT_ID = "classic_2026-05-10_07utc";

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

function printTournament(data) {
  console.log("--- tournaments/" + TOURNAMENT_ID + " ---");
  if (!data) {
    console.log("tournament doc not found");
    return;
  }
  for (const [key, raw] of Object.entries(data)) {
    if (key === "attempts_summary" && typeof raw === "string") {
      console.log(key + ":");
      try {
        const parsed = JSON.parse(raw);
        console.log(JSON.stringify(parsed, null, 2));
      } catch {
        console.log("(raw string, not valid JSON)\n" + raw);
      }
      continue;
    }
    const v = serializeValue(raw);
    console.log(key + ":", JSON.stringify(v, null, 2));
  }
}

async function main() {
  const tSnap = await db.collection("tournaments").doc(TOURNAMENT_ID).get();
  printTournament(tSnap.exists ? tSnap.data() : null);

  console.log("\n--- category_rotation/state ---");
  const rotSnap = await db.collection("category_rotation").doc("state").get();
  if (!rotSnap.exists) {
    console.log("rotation doc not found");
    process.exit(0);
    return;
  }
  const r = rotSnap.data();
  const idx =
    typeof r?.currentIndex === "number" ? Math.trunc(r.currentIndex) : null;
  const cats = r?.categories;
  const active =
    Array.isArray(cats) && idx !== null && idx >= 0 && idx < cats.length ?
      cats[idx] :
      null;

  console.log(
    "currentIndex:",
    JSON.stringify(serializeValue(r?.currentIndex)),
  );
  console.log(
    "lastRotatedAt:",
    JSON.stringify(serializeValue(r?.lastRotatedAt)),
  );
  console.log("updatedAt:", JSON.stringify(serializeValue(r?.updatedAt)));
  console.log(
    "categories[currentIndex]:",
    active === undefined || active === null ?
      "(missing or index out of range)" :
      JSON.stringify(active),
  );

  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
