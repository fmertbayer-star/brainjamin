/**
 * Mini seed (1000 questions, 50 per category, 10 per difficulty per category).
 * Pre-launch smoke for tournament engine.
 *
 * Run (full seed, all 20 categories):
 *   node functions/scripts/runMiniSeedV1.mjs
 *
 * Run a subset of categories only:
 *   node functions/scripts/runMiniSeedV1.mjs --only=movies_tv,art,nature
 *
 * Estimated wall time: 60-180 minutes (full). Estimated cost: ~$0.20.
 *
 * Auth: anonymous Firebase token (~1h TTL). The script refreshes proactively
 * before 50 minutes elapses and retries once per bucket on HTTP 401.
 */

const API_KEY = "AIzaSyCT9dgF1sW8aa09c6zCOVLzEtibiKm5csA";
const PROJECT = "brainjamin-prod-app";
const REGION = "us-central1";
const FN = "generateQuestions";

/** Proactive refresh interval (ms) — before Firebase ~1h anonymous token expiry. */
const AUTH_REFRESH_INTERVAL_MS = 50 * 60 * 1000;

/** Mirror of functions/src/shared/categories.ts (dependency-free). */
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

const CATEGORY_SET = new Set(CATEGORIES);

const DIFFICULTIES = [1, 2, 3, 4, 5];
const PER_DIFFICULTY_PER_CATEGORY = 10;
const TOTAL_PER_CATEGORY =
  DIFFICULTIES.length * PER_DIFFICULTY_PER_CATEGORY;
const TOTAL_TARGET = 1000;

if (TOTAL_PER_CATEGORY !== 50) {
  console.error("Sanity check failed: TOTAL_PER_CATEGORY !== 50");
  process.exit(1);
}
if (CATEGORIES.length * TOTAL_PER_CATEGORY !== TOTAL_TARGET) {
  console.error("Sanity check failed: categories × per-category !== TOTAL_TARGET");
  process.exit(1);
}

const signUpUrl =
  `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`;

const callableUrl =
  `https://${REGION}-${PROJECT}.cloudfunctions.net/${FN}`;

/** @type {string | undefined} */
let idToken;
/** @type {number} */
let lastAuthAtMs = 0;

function parseOnlyArg() {
  for (const arg of process.argv.slice(2)) {
    if (arg.startsWith("--only=")) {
      return arg.slice("--only=".length)
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
    }
  }
  return null;
}

function resolveCategoriesToSeed() {
  const only = parseOnlyArg();
  if (only === null) {
    return { filtered: false, onlyArg: "", categories: [...CATEGORIES] };
  }
  if (only.length === 0) {
    console.error("--only must list at least one category (e.g. --only=history,art)");
    process.exit(1);
  }
  const unknown = only.filter((c) => !CATEGORY_SET.has(c));
  if (unknown.length > 0) {
    const allowed = CATEGORIES.join(", ");
    console.error(
      `Unknown category: ${unknown.join(", ")}. Allowed: ${allowed}`,
    );
    process.exit(1);
  }
  return {
    filtered: true,
    onlyArg: only.join(","),
    categories: only,
  };
}

/**
 * Anonymous sign-up; updates module idToken + lastAuthAtMs.
 * @returns {Promise<string>}
 */
async function refreshAuth() {
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
  const token = signJson.idToken;
  if (!token) {
    console.error("No idToken in signUp response", signJson);
    process.exit(1);
  }

  idToken = token;
  lastAuthAtMs = Date.now();
  console.log(
    `[seed] auth refreshed at ${new Date(lastAuthAtMs).toISOString()}`,
  );
  return token;
}

async function maybeProactiveRefresh() {
  if (
    idToken &&
    Date.now() - lastAuthAtMs > AUTH_REFRESH_INTERVAL_MS
  ) {
    await refreshAuth();
  }
}

function httpError(status, message) {
  const e = new Error(`HTTP ${status}: ${message}`);
  e.status = status;
  return e;
}

async function callGenerateQuestionsOnce(category, difficulty, count) {
  const callRes = await fetch(callableUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${idToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      data: {
        category,
        difficulty,
        count,
      },
    }),
  });

  const rawBody = await callRes.text();
  let parsed;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    throw new Error(
      `Invalid JSON from callable (HTTP ${callRes.status}): ${rawBody.slice(0, 500)}`,
    );
  }

  if (!callRes.ok) {
    const msg = parsed?.error?.message ?? parsed?.error ?? rawBody;
    throw httpError(callRes.status, msg);
  }

  if (parsed.error) {
    const msg =
      typeof parsed.error === "object" && parsed.error.message ?
        parsed.error.message :
        JSON.stringify(parsed.error);
    throw new Error(msg);
  }

  const result = parsed.result !== undefined ? parsed.result : parsed;
  return result;
}

async function invokeGenerateQuestions(category, difficulty, count) {
  await maybeProactiveRefresh();

  try {
    return await callGenerateQuestionsOnce(category, difficulty, count);
  } catch (err) {
    const status = err && typeof err === "object" && "status" in err ?
      err.status :
      undefined;
    if (status === 401) {
      console.log("[seed] 401 detected, re-authenticating...");
      await refreshAuth();
      return await callGenerateQuestionsOnce(category, difficulty, count);
    }
    throw err;
  }
}

const {filtered, onlyArg, categories: categoriesToSeed} =
  resolveCategoriesToSeed();

if (filtered) {
  console.log(`[seed] Run mode: filtered (--only=${onlyArg})`);
} else {
  console.log("[seed] Run mode: full (all 20 categories)");
}
console.log(
  `[seed] Running for ${categoriesToSeed.length} categories: ${categoriesToSeed.join(", ")}`,
);

await refreshAuth();

const wallStart = Date.now();
let totalPersisted = 0;
let totalRejectedSlots = 0;
let totalErroredBuckets = 0;

for (const category of categoriesToSeed) {
  let catPersisted = 0;
  let catRejected = 0;
  let catErrored = 0;

  for (const difficulty of DIFFICULTIES) {
    const bucketStart = Date.now();
    try {
      const result = await invokeGenerateQuestions(
        category,
        difficulty,
        PER_DIFFICULTY_PER_CATEGORY,
      );

      const persistedCount =
        typeof result.persistedCount === "number" ? result.persistedCount : 0;
      const rejectedArr = Array.isArray(result.rejected) ?
        result.rejected :
        [];
      const rejectedCount = rejectedArr.length;

      totalPersisted += persistedCount;
      totalRejectedSlots += rejectedCount;
      catPersisted += persistedCount;
      catRejected += rejectedCount;

      const elapsedSec = ((Date.now() - bucketStart) / 1000).toFixed(1);
      console.log(
        `[seed] ${category} D${difficulty}: requested ${PER_DIFFICULTY_PER_CATEGORY}, ` +
          `persisted ${persistedCount}, rejected ${rejectedCount}, elapsed ${elapsedSec}s`,
      );
    } catch (err) {
      totalErroredBuckets += 1;
      catErrored += 1;
      const message = err instanceof Error ? err.message : String(err);
      console.log(
        `[seed] ERROR ${category} D${difficulty}: ${message}`,
      );
    }
  }

  console.log(
    `[seed] CATEGORY ${category} done: persisted ${catPersisted} / ` +
      `rejected ${catRejected} / errored ${catErrored}`,
  );
}

const wallSec = ((Date.now() - wallStart) / 1000).toFixed(1);
const finalTag = filtered ?
  `(filtered: ${onlyArg})` :
  "(full)";
console.log(
  `[seed] FINAL ${finalTag}: persisted=${totalPersisted} rejectedSlots=${totalRejectedSlots} ` +
    `erroredBuckets=${totalErroredBuckets} wallTime=${wallSec}s`,
);

process.exit(0);
