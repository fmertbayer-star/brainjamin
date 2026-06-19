/**
 * Weekly reset: zero weeklyXp on all active users_public rows and seed next
 * week's empty leaderboard doc.
 */

import {
  FieldValue,
  getFirestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {DateTime} from "luxon";

const BATCH_MAX_OPS = 500;

function nextUtcIsoWeekKey(date: Date = new Date()): string {
  return DateTime.fromJSDate(date, {zone: "utc"})
    .plus({weeks: 1})
    .toFormat("kkkk-'W'WW");
}

export const resetWeeklyLeaderboard = onSchedule(
  {
    schedule: "59 23 * * 0",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    const db = getFirestore();
    let resetCount = 0;
    let lastDoc: QueryDocumentSnapshot | undefined;
    let hasMore = true;

    while (hasMore) {
      let query = db
        .collection("users_public")
        .where("weeklyXp", ">", 0)
        .limit(BATCH_MAX_OPS);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snap = await query.get();
      if (snap.empty) {
        hasMore = false;
        continue;
      }

      const batch = db.batch();
      for (const doc of snap.docs) {
        batch.update(doc.ref, {weeklyXp: 0});
      }
      await batch.commit();
      resetCount += snap.size;
      lastDoc = snap.docs[snap.docs.length - 1];
      hasMore = snap.size >= BATCH_MAX_OPS;
    }

    const nextWeekKey = nextUtcIsoWeekKey();
    await db.collection("leaderboards").doc(`weekly_${nextWeekKey}`).set({
      resetAt: FieldValue.serverTimestamp(),
      entries: [],
    });

    logger.info("resetWeeklyLeaderboard ok", {
      resetCount,
      nextWeekKey,
    });
  },
);
