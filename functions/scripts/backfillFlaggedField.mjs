import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

initializeApp({credential: applicationDefault()});
const db = getFirestore();

async function main() {
  const snap = await db.collection("questions_public").get();
  let scanned = 0;
  let updated = 0;
  let skipped = 0;
  let batch = db.batch();
  let opsInBatch = 0;
  for (const doc of snap.docs) {
    scanned++;
    const flagged = doc.get("flagged");
    if (flagged === undefined || flagged === null) {
      batch.set(doc.ref, {flagged: false}, {merge: true});
      updated++;
      opsInBatch++;
      if (opsInBatch >= 200) {
        await batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    } else {
      skipped++;
    }
  }
  if (opsInBatch > 0) {
    await batch.commit();
  }
  console.log(JSON.stringify({scanned, updated, skipped}, null, 2));
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
