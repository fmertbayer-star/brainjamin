/**
 * Daily purge of soft-deleted accounts past their 30-day grace period.
 */

import {
  getFirestore,
  Timestamp,
  type CollectionReference,
  type Firestore,
  type Query,
} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

const USERS_PER_RUN_BATCH = 10;
const SUBCOLLECTION_DELETE_BATCH = 500;

async function deleteQueryBatch(
  db: Firestore,
  query: Query,
): Promise<number> {
  const snap = await query.limit(SUBCOLLECTION_DELETE_BATCH).get();
  if (snap.empty) {
    return 0;
  }
  const batch = db.batch();
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
  return snap.size;
}

async function deleteAllInCollection(
  db: Firestore,
  collectionRef: CollectionReference,
): Promise<void> {
  let deleted = SUBCOLLECTION_DELETE_BATCH;
  while (deleted >= SUBCOLLECTION_DELETE_BATCH) {
    deleted = await deleteQueryBatch(db, collectionRef);
  }
}

async function purgeUser(db: Firestore, uid: string): Promise<void> {
  const userSnap = await db.collection("users").doc(uid).get();
  const displayName = userSnap.get("displayName");
  if (typeof displayName === "string" && displayName.trim().length > 0) {
    const usernameRef = db
      .collection("usernames")
      .doc(displayName.trim().toLowerCase());
    const usernameSnap = await usernameRef.get();
    if (usernameSnap.exists && usernameSnap.get("uid") === uid) {
      await usernameRef.delete();
    }
  }

  await deleteAllInCollection(
    db,
    db.collection("achievements").doc(uid).collection("earned"),
  );
  await deleteAllInCollection(
    db,
    db.collection("used_questions").doc(uid).collection("seen"),
  );

  await Promise.all([
    db.collection("users").doc(uid).delete(),
    db.collection("users_public").doc(uid).delete(),
  ]);

  await getAuth().deleteUser(uid);
  await db.collection("deleted_accounts").doc(uid).delete();
}

export const purgeDeletedAccounts = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "UTC",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const db = getFirestore();
    const now = Timestamp.now();
    let totalPurged = 0;
    let hasMore = true;

    while (hasMore) {
      const snap = await db
        .collection("deleted_accounts")
        .where("scheduledFor", "<=", now)
        .limit(USERS_PER_RUN_BATCH)
        .get();

      if (snap.empty) {
        hasMore = false;
        continue;
      }

      for (const doc of snap.docs) {
        const uid = doc.id;
        try {
          await purgeUser(db, uid);
          totalPurged++;
          logger.info("purgeDeletedAccounts purged user", {uid});
        } catch (err) {
          logger.error("purgeDeletedAccounts failed for user", {uid, err});
        }
      }

      hasMore = snap.size >= USERS_PER_RUN_BATCH;
    }

    logger.info("purgeDeletedAccounts run complete", {totalPurged});
  },
);
