/**
 * Hourly rebuild of denormalized global + weekly XP leaderboards.
 */

import {
  FieldValue,
  getFirestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {DateTime} from "luxon";

type LeaderboardEntry = {
  rank: number;
  uid: string;
  displayName: string;
  xp: number;
  level: number;
};

function utcIsoWeekKey(date: Date = new Date()): string {
  return DateTime.fromJSDate(date, {zone: "utc"}).toFormat("kkkk-'W'WW");
}

function entryFromDoc(
  doc: QueryDocumentSnapshot,
  rank: number,
  xpField: "xp" | "weeklyXp",
): LeaderboardEntry {
  const data = doc.data();
  const displayName = data.displayName;
  const xpRaw = data[xpField];
  const level = data.level;
  return {
    rank,
    uid: doc.id,
    displayName:
      typeof displayName === "string" && displayName.length > 0 ?
        displayName :
        "",
    xp: typeof xpRaw === "number" && Number.isFinite(xpRaw) ? Math.trunc(xpRaw) : 0,
    level:
      typeof level === "number" && Number.isFinite(level) ?
        Math.trunc(level) :
        0,
  };
}

export const rebuildLeaderboards = onSchedule(
  {
    schedule: "0 * * * *",
    timeZone: "UTC",
    region: "us-central1",
  },
  async () => {
    const db = getFirestore();
    const weekKey = utcIsoWeekKey();

    const [globalSnap, weeklySnap] = await Promise.all([
      db.collection("users_public").orderBy("xp", "desc").limit(100).get(),
      db
        .collection("users_public")
        .orderBy("weeklyXp", "desc")
        .limit(100)
        .get(),
    ]);

    const globalEntries = globalSnap.docs.map((doc, index) =>
      entryFromDoc(doc, index + 1, "xp"),
    );
    const weeklyEntries = weeklySnap.docs.map((doc, index) =>
      entryFromDoc(doc, index + 1, "weeklyXp"),
    );

    await Promise.all([
      db.collection("leaderboards").doc("global").set({
        updatedAt: FieldValue.serverTimestamp(),
        entries: globalEntries,
      }),
      db.collection("leaderboards").doc(`weekly_${weekKey}`).set({
        updatedAt: FieldValue.serverTimestamp(),
        entries: weeklyEntries,
      }),
    ]);

    logger.info("rebuildLeaderboards ok", {
      weekKey,
      globalCount: globalEntries.length,
      weeklyCount: weeklyEntries.length,
    });
  },
);
