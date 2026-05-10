/**
 * Self-Test seed: anonymous Auth + generateQuestions (100 calls: 5 DL × 20 categories).
 *
 * Run from functions/: FIREBASE_API_KEY=<key> node scripts/runSelfTestSeed.mjs
 *
 * API key: process.env.FIREBASE_API_KEY or functions/.env.pilot (same as runSelfTestPilot.mjs).
 */

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadApiKey() {
  const fromEnv = process.env.FIREBASE_API_KEY;
  if (fromEnv && fromEnv.trim()) {
    return fromEnv.trim();
  }
  try {
    const envPath = path.join(__dirname, "..", ".env.pilot");
    const raw = fs.readFileSync(envPath, "utf8");
    for (const line of raw.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const m = trimmed.match(/^FIREBASE_API_KEY\s*=\s*(.+)$/);
      if (m) {
        return m[1].trim().replace(/^["']|["']$/g, "");
      }
    }
  } catch (_) {
    /* optional file */
  }
  return null;
}

const API_KEY = loadApiKey();
const PROJECT = "brainjamin-prod-app";
const REGION = "us-central1";

const URL_GENERATE =
  `https://${REGION}-${PROJECT}.cloudfunctions.net/generateQuestions`;

/** Duplicates functions/src/shared/categories.ts CATEGORIES (pilot stays dependency-free). */
const SEED_CATEGORIES = [
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
];

const PAIR_COUNT = 5 * SEED_CATEGORIES.length;

function parseCallableJson(rawBody) {
  let parsed;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    return {callableError: "invalid_json", result: null};
  }
  if (parsed.error) {
    return {callableError: parsed.error, result: null};
  }
  const result = parsed.result !== undefined ? parsed.result : parsed;
  return {callableError: null, result};
}

function delay(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

if (!API_KEY) {
  console.error(
    "Missing API key: set FIREBASE_API_KEY or add functions/.env.pilot",
  );
  process.exit(1);
}

const signUpUrl =
  `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`;

const signRes = await fetch(signUpUrl, {
  method: "POST",
  headers: {"Content-Type": "application/json"},
  body: JSON.stringify({returnSecureToken: true}),
});

if (!signRes.ok) {
  const t = await signRes.text();
  console.error("Anonymous signUp failed", signRes.status, t);
  process.exit(1);
}

const signJson = await signRes.json();
const idToken = signJson.idToken;
if (!idToken) {
  console.error("No idToken in signUp response", signJson);
  process.exit(1);
}

const seededIds = [];
const failures = [];
let successCount = 0;
let callNum = 0;

for (let d = 1; d <= 5; d++) {
  for (const c of SEED_CATEGORIES) {
    if (callNum > 0) {
      await delay(500);
    }
    callNum++;

    const callRes = await fetch(URL_GENERATE, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${idToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        data: {
          category: c,
          difficulty: d,
          count: 1,
        },
      }),
    });

    const rawBody = await callRes.text();
    let N = 0;
    let A = 0;
    let R = 0;

    if (!callRes.ok) {
      failures.push({
        category: c,
        difficulty: d,
        reason: `HTTP ${callRes.status}`,
      });
      console.log(`DL${d} ${c}: persisted ${N}, attempts ${A}, rejected ${R}`);
      continue;
    }

    const {callableError, result} = parseCallableJson(rawBody);
    if (callableError) {
      failures.push({
        category: c,
        difficulty: d,
        reason:
          typeof callableError === "object" ?
            JSON.stringify(callableError) :
            String(callableError),
      });
      console.log(`DL${d} ${c}: persisted ${N}, attempts ${A}, rejected ${R}`);
      continue;
    }

    const persisted = Array.isArray(result?.persisted) ? result.persisted : [];
    const rejected = Array.isArray(result?.rejected) ? result.rejected : [];
    N = persisted.length;
    R = rejected.length;

    if (persisted.length > 0) {
      A = typeof persisted[0].attempts === "number" ? persisted[0].attempts : 0;
      for (const p of persisted) {
        if (typeof p.id === "string") {
          seededIds.push(p.id);
        }
      }
    } else if (rejected.length > 0) {
      const att = rejected[0]?.attempts;
      A = Array.isArray(att) ? att.length : 0;
    }

    if (N >= 1) {
      successCount++;
    } else {
      failures.push({
        category: c,
        difficulty: d,
        reason: "persisted_count_0",
      });
    }

    console.log(`DL${d} ${c}: persisted ${N}, attempts ${A}, rejected ${R}`);
  }
}

const outPath = path.join(__dirname, ".selftest-seed-ids.json");
fs.writeFileSync(outPath, `${JSON.stringify(seededIds)}\n`, "utf8");

console.log("");
console.log(
  `Seeded ${seededIds.length} questions across ${PAIR_COUNT} (difficulty × category) pairs. IDs written to functions/scripts/.selftest-seed-ids.json`,
);

const ok = successCount >= 80;
if (!ok) {
  console.error("");
  console.error(
    `FAILED: only ${successCount}/${PAIR_COUNT} calls persisted >= 1 (need >= 80).`,
  );
  console.error("Failed or zero-persist pairs:");
  for (const f of failures) {
    console.error(`  DL${f.difficulty} ${f.category}: ${f.reason}`);
  }
  process.exit(1);
}

process.exit(0);
