import admin from "firebase-admin";

admin.initializeApp({ projectId: "brainjamin-prod-app" });
const db = admin.firestore();

const IDS = [
  "UZgyFGUFN3kFfvfKUn5s",
  "XgXkxJHSlyG2ZQntsPNU",
  "N9R4pGC8OfZBIi3zlHLb",
  "pA3AmcVg4SYEumh0qeIv",
  "ACsxdbvF64fq9b4WqD0H",
];

function cosine(a, b) {
  if (a.length !== b.length) return null;
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  const denom = Math.sqrt(na) * Math.sqrt(nb);
  return denom === 0 ? 0 : dot / denom;
}

console.log("=== questions ===");
const docs = {};
for (const id of IDS) {
  const snap = await db.collection("questions_public").doc(id).get();
  const d = snap.data() || {};
  console.log(`${id} (${d.category}, diff=${d.difficulty})`);
  console.log(`  Q: ${d.question}`);
  console.log(`  A[${d.correctIndex}]: ${d.options?.[d.correctIndex]}`);
  console.log(`  Options: ${(d.options || []).join(" | ")}`);
  const emb = d.embedding;
  if (Array.isArray(emb) && emb.length === 1536 && emb.every(n => typeof n === "number")) {
    docs[id] = { vector: emb, question: d.question };
  } else {
    console.log(`  WARN: embedding malformed`);
  }
}

console.log("\n=== pairwise cosine similarity (NEW embed format: Q+A+Options) ===");
const ids = Object.keys(docs);
const sims = [];
for (let i = 0; i < ids.length; i++) {
  for (let j = i + 1; j < ids.length; j++) {
    const a = docs[ids[i]];
    const b = docs[ids[j]];
    const sim = cosine(a.vector, b.vector);
    sims.push(sim);
    const flag = sim >= 0.92 ? "  <-- HIT >=0.92" : "";
    console.log(`${sim.toFixed(4)}${flag}`);
    console.log(`    A: "${a.question}"`);
    console.log(`    B: "${b.question}"`);
  }
}

console.log("\n=== summary ===");
console.log(`pairs: ${sims.length}`);
console.log(`min:   ${Math.min(...sims).toFixed(4)}`);
console.log(`max:   ${Math.max(...sims).toFixed(4)}`);
console.log(`mean:  ${(sims.reduce((a,b)=>a+b,0)/sims.length).toFixed(4)}`);

process.exit(0);
