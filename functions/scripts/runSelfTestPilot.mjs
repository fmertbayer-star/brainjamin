/**
 * Self-Test backend pilot: anonymous Auth + selectSelfTestQuestions +
 * submitSelfTestSession.
 *
 * Run from repo root or functions/: node functions/scripts/runSelfTestPilot.mjs
 *
 * Requires FIREBASE_API_KEY in env, or functions/.env.pilot with FIREBASE_API_KEY=...
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

const URL_SELECT =
  `https://${REGION}-${PROJECT}.cloudfunctions.net/selectSelfTestQuestions`;
const URL_SUBMIT =
  `https://${REGION}-${PROJECT}.cloudfunctions.net/submitSelfTestSession`;

function parseCallableJson(rawBody) {
  let parsed;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    return {callableError: null, result: null, raw: rawBody, parseError: true};
  }
  if (parsed.error) {
    return {callableError: parsed.error, result: null, raw: rawBody};
  }
  const result = parsed.result !== undefined ? parsed.result : parsed;
  return {callableError: null, result, raw: rawBody};
}

function fail(step, msg) {
  console.error("");
  console.error(`FAILED: ${step}${msg ? ` — ${msg}` : ""}`);
  process.exit(1);
}

if (!API_KEY) {
  console.error(
    "Missing API key: set FIREBASE_API_KEY or add functions/.env.pilot",
  );
  fail("env", "no FIREBASE_API_KEY");
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
  fail("anonymous_signUp", String(signRes.status));
}

const signJson = await signRes.json();
const idToken = signJson.idToken;
if (!idToken) {
  console.error("No idToken in signUp response", signJson);
  fail("anonymous_signUp", "no idToken");
}

/* --- selectSelfTestQuestions --- */

const selectRes = await fetch(URL_SELECT, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${idToken}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({data: {}}),
});

const selectRaw = await selectRes.text();
console.log(`selectSelfTestQuestions HTTP status: ${selectRes.status}`);

if (!selectRes.ok) {
  console.error(selectRaw);
  fail("selectSelfTestQuestions", `HTTP ${selectRes.status}`);
}

const selectParsed = parseCallableJson(selectRaw);
if (selectParsed.parseError) {
  console.error("Invalid JSON:", selectRaw);
  fail("selectSelfTestQuestions", "invalid JSON");
}
if (selectParsed.callableError) {
  console.error(JSON.stringify(selectParsed.callableError, null, 2));
  fail("selectSelfTestQuestions", "callable error object");
}

const selectResult = selectParsed.result;
const sessionId = selectResult?.sessionId;
const questions = selectResult?.questions;

if (
  typeof sessionId !== "string" ||
  !Array.isArray(questions) ||
  questions.length !== 25
) {
  console.error("Unexpected result:", JSON.stringify(selectResult, null, 2));
  fail("selectSelfTestQuestions", "missing sessionId or 25 questions");
}

const dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
for (const q of questions) {
  const d = q.difficulty;
  if (typeof d === "number" && d >= 1 && d <= 5) {
    dist[d]++;
  }
}
console.log(`sessionId: ${sessionId}`);
console.log(`questions returned: ${questions.length}`);
const distLine =
  `DL1: ${dist[1]}, DL2: ${dist[2]}, DL3: ${dist[3]}, DL4: ${dist[4]}, DL5: ${dist[5]}`;
console.log(distLine);

const q0 = questions[0];
console.log(
  "first question — qId:",
  q0?.qId,
  "category:",
  q0?.category,
  "difficulty:",
  q0?.difficulty,
);
console.log(
  "first question — options:",
  q0?.options?.[0],
  q0?.options?.[1],
  q0?.options?.[2],
  q0?.options?.[3],
  "correctIndex:",
  q0?.correctIndex,
);

const answers = [];
for (let i = 0; i < 25; i++) {
  const ci = questions[i].correctIndex;
  if (typeof ci !== "number" || ci < 0 || ci > 3) {
    console.error("Bad correctIndex at index", i, questions[i]);
    fail("build_answers", "invalid correctIndex");
  }
  if (i < 13) {
    answers.push(ci);
  } else {
    answers.push((ci + 1) % 4);
  }
}

const perQuestionRemainingMs = Array(25).fill(5000);

/* --- submitSelfTestSession --- */

const submitRes = await fetch(URL_SUBMIT, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${idToken}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    data: {
      sessionId,
      answers,
      perQuestionRemainingMs,
    },
  }),
});

const submitRaw = await submitRes.text();
console.log(`submitSelfTestSession HTTP status: ${submitRes.status}`);

if (!submitRes.ok) {
  console.error(submitRaw);
  fail("submitSelfTestSession", `HTTP ${submitRes.status}`);
}

const submitParsed = parseCallableJson(submitRaw);
if (submitParsed.parseError) {
  console.error("Invalid JSON:", submitRaw);
  fail("submitSelfTestSession", "invalid JSON");
}
if (submitParsed.callableError) {
  console.error(JSON.stringify(submitParsed.callableError, null, 2));
  fail("submitSelfTestSession", "callable error object");
}

const sub = submitParsed.result;
const correctCount = sub?.correctCount;
const totalRemainingMs = sub?.totalRemainingMs;
const weekKey = sub?.weekKey;

console.log(
  "submit result:",
  "correctCount:",
  correctCount,
  "totalRemainingMs:",
  totalRemainingMs,
  "weekKey:",
  weekKey,
);

const pass = correctCount === 13;
console.log(pass ? "PASS" : "FAIL");

if (!pass) {
  fail("verify", `correctCount ${correctCount} !== 13`);
}

process.exit(0);
