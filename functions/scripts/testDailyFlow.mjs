import {DateTime} from "luxon";

const PROJECT = "brainjamin-prod-app";
const REGION = "us-central1";
const TZ = "Europe/Istanbul";
const SELECT_FN = "selectDailyQuestion";
const SUBMIT_FN = "submitDailyAnswer";
const FIREBASE_WEB_API_KEY = process.env.FIREBASE_WEB_API_KEY;

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function signInAnonymous() {
  assert(
    typeof FIREBASE_WEB_API_KEY === "string" && FIREBASE_WEB_API_KEY.length > 0,
    "Missing FIREBASE_WEB_API_KEY env var",
  );
  const signUpUrl =
    "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" +
    FIREBASE_WEB_API_KEY;
  const signRes = await fetch(signUpUrl, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({returnSecureToken: true}),
  });
  if (!signRes.ok) {
    throw new Error(`Anonymous signUp failed: ${signRes.status} ${await signRes.text()}`);
  }
  const signJson = await signRes.json();
  const idToken = signJson.idToken;
  assert(typeof idToken === "string" && idToken.length > 0, "Missing idToken");
  return idToken;
}

async function callCallable(idToken, fnName, data) {
  const callableUrl = `https://${REGION}-${PROJECT}.cloudfunctions.net/${fnName}`;
  const response = await fetch(callableUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${idToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({data}),
  });
  const raw = await response.text();
  let parsed;
  try {
    parsed = raw.length > 0 ? JSON.parse(raw) : {};
  } catch {
    throw new Error(`${fnName} invalid JSON response: ${raw}`);
  }

  if (!response.ok) {
    const errPayload = parsed?.error ?? {};
    const message = errPayload.message ?? raw;
    const status = errPayload.status ?? `HTTP_${response.status}`;
    const error = new Error(`${fnName} failed: ${status} ${message}`);
    error.status = status;
    error.messageCode = message;
    throw error;
  }
  return parsed.result ?? parsed;
}

const idToken = await signInAnonymous();
const expectedDateKey = DateTime.now().setZone(TZ).toISODate();
assert(typeof expectedDateKey === "string", "Failed to compute expected dateKey");

const selectBefore = await callCallable(idToken, SELECT_FN, {timezone: TZ});
assert(selectBefore.dateKey === expectedDateKey, "selectBefore dateKey mismatch");
assert(typeof selectBefore.qId === "string" && selectBefore.qId.length > 0, "selectBefore missing qId");
assert(Array.isArray(selectBefore.options) && selectBefore.options.length === 4, "selectBefore options length must be 4");
assert(selectBefore.alreadyAnswered === false, "selectBefore must be not answered");

const submitOnce = await callCallable(idToken, SUBMIT_FN, {selectedIndex: 0, timezone: TZ});
assert(typeof submitOnce.correctIndex === "number", "submitOnce missing correctIndex");
assert(submitOnce.xpAwarded === 10 || submitOnce.xpAwarded === 50, "submitOnce invalid xpAwarded");
assert(typeof submitOnce.streak === "number" && submitOnce.streak >= 1, "submitOnce invalid streak");
assert(
  submitOnce.forgivesAvailableThisWeek === 0 || submitOnce.forgivesAvailableThisWeek === 1,
  "submitOnce invalid forgivesAvailableThisWeek",
);
assert(
  typeof submitOnce.totalXp === "number" && submitOnce.totalXp >= submitOnce.xpAwarded,
  "submitOnce invalid totalXp",
);

let submitAgainError = null;
try {
  await callCallable(idToken, SUBMIT_FN, {selectedIndex: 0, timezone: TZ});
} catch (err) {
  submitAgainError = err;
}
assert(submitAgainError instanceof Error, "Second submit must fail");
assert(submitAgainError.status === "ALREADY_EXISTS", "Second submit must be ALREADY_EXISTS");
assert(submitAgainError.messageCode === "already_answered", "Second submit message must be already_answered");

const selectAfter = await callCallable(idToken, SELECT_FN, {timezone: TZ});
assert(selectAfter.alreadyAnswered === true, "selectAfter must be answered");
assert(typeof selectAfter.correctIndex === "number", "selectAfter missing correctIndex");
assert(typeof selectAfter.selectedIndex === "number", "selectAfter missing selectedIndex");
assert(typeof selectAfter.isCorrect === "boolean", "selectAfter missing isCorrect");
assert(selectAfter.xpAwarded === 10 || selectAfter.xpAwarded === 50, "selectAfter invalid xpAwarded");
assert(typeof selectAfter.submittedAtMs === "number", "selectAfter missing submittedAtMs");

console.log("Call 1: selectDailyQuestion (before submit)");
console.log(JSON.stringify(selectBefore, null, 2));
console.log("");
console.log("Call 2: submitDailyAnswer");
console.log(JSON.stringify(submitOnce, null, 2));
console.log("");
console.log("Call 3: submitDailyAnswer again (expected error)");
console.log(JSON.stringify({
  status: submitAgainError.status,
  messageCode: submitAgainError.messageCode,
  message: submitAgainError.message,
}, null, 2));
console.log("");
console.log("Call 4: selectDailyQuestion (after submit)");
console.log(JSON.stringify(selectAfter, null, 2));
console.log("");
console.log("Assertions: PASS");
