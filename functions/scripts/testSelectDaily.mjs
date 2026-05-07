import {DateTime} from "luxon";

const API_KEY = "AIzaSyCT9dgF1sW8aa09c6zCOVLzEtibiKm5csA";
const PROJECT = "brainjamin-prod-app";
const REGION = "us-central1";
const FN = "selectDailyQuestion";
const TZ = "Europe/Istanbul";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function signInAnonymous() {
  const signUpUrl =
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`;
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

async function callSelectDaily(idToken) {
  const callableUrl = `https://${REGION}-${PROJECT}.cloudfunctions.net/${FN}`;
  const response = await fetch(callableUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${idToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      data: {timezone: TZ},
    }),
  });
  const raw = await response.text();
  if (!response.ok) {
    throw new Error(`Callable HTTP error: ${response.status} ${raw}`);
  }
  const parsed = JSON.parse(raw);
  return parsed.result ?? parsed;
}

const idToken = await signInAnonymous();
const first = await callSelectDaily(idToken);
const second = await callSelectDaily(idToken);

const expectedDateKey = DateTime.now().setZone(TZ).toISODate();
assert(typeof expectedDateKey === "string", "Failed to compute expected dateKey");

assert(first.dateKey === expectedDateKey, "First call dateKey mismatch");
assert(typeof first.qId === "string" && first.qId.length > 0, "First call missing qId");
assert(Array.isArray(first.options) && first.options.length === 4, "First call options must have length 4");
assert(first.alreadyAnswered === false, "First call should be not answered");
assert(first.correctIndex === undefined, "First call leaked correctIndex");

assert(second.dateKey === expectedDateKey, "Second call dateKey mismatch");
assert(second.qId === first.qId, "Second call should return same qId");

console.log("First call response:");
console.log(JSON.stringify(first, null, 2));
console.log("");
console.log("Second call response:");
console.log(JSON.stringify(second, null, 2));
