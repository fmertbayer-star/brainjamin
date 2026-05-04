/**
 * Pilot runner: anonymous Auth + generateQuestions callable (Sprint 2.2.b).
 * Run after deploy. No deploy from CI — Mert runs locally.
 *
 * Usage: node functions/scripts/runPilot.mjs [--category X] [--difficulty N] [--count N]
 */

const API_KEY = "AIzaSyCT9dgF1sW8aa09c6zCOVLzEtibiKm5csA";
const PROJECT = "brainjamin-prod-app";
const REGION = "us-central1";
const FN = "generateQuestions";

/** Duplicates V1 list in functions/src/shared/categories.ts (pilot stays dependency-free). */
const CATEGORIES = [
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

function parseArgs() {
  const argv = process.argv.slice(2);
  let category = "history";
  let difficulty = 3;
  let count = 5;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--category" && argv[i + 1] !== undefined) {
      category = argv[++i];
    } else if (a === "--difficulty" && argv[i + 1] !== undefined) {
      difficulty = Number(argv[++i]);
    } else if (a === "--count" && argv[i + 1] !== undefined) {
      count = Number(argv[++i]);
    }
  }
  return {category, difficulty, count};
}

const {category, difficulty, count} = parseArgs();

if (!CATEGORIES.includes(category)) {
  console.error(
    `Invalid --category "${category}". Must be one of the 20 V1 categories.`,
  );
  process.exit(1);
}

if (
  !Number.isInteger(difficulty) ||
  difficulty < 1 ||
  difficulty > 5
) {
  console.error("Invalid --difficulty: must be integer 1-5.");
  process.exit(1);
}

if (!Number.isInteger(count) || count < 1 || count > 25) {
  console.error("Invalid --count: must be integer 1-25.");
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

const callableUrl =
  `https://${REGION}-${PROJECT}.cloudfunctions.net/${FN}`;

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

if (!callRes.ok) {
  console.error("Callable HTTP error", callRes.status);
  console.error(rawBody);
  process.exit(1);
}

let parsed;
try {
  parsed = JSON.parse(rawBody);
} catch (e) {
  console.error("Invalid JSON from callable:", rawBody);
  process.exit(1);
}

const result = parsed.result !== undefined ? parsed.result : parsed;

console.log(JSON.stringify(result, null, 2));

const persistedCount = result.persistedCount ?? 0;
const persistedIds = Array.isArray(result.persisted) ?
  result.persisted.map((p) => p.id) :
  [];

const rejectedDigest = Array.isArray(result.rejected) ?
  result.rejected.map((r) => ({
    slot: r.slot,
    attempts: Array.isArray(r.attempts) ? r.attempts.length : 0,
    reasons: Array.isArray(r.attempts) ?
      r.attempts.map((log) =>
        log.reason ?? (log.rejected === false ? "OK" : "?"),
      ) :
      [],
  })) :
  [];

console.log("");
console.log(`persistedCount: ${persistedCount}`);
console.log(`persisted IDs: ${JSON.stringify(persistedIds)}`);
console.log(
  "rejected:",
  JSON.stringify(rejectedDigest, null, 2),
);

process.exit(0);
