import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";
const EXPIRABLE_STATUSES = ["waiting", "matched", "player1_done", "player2_done"] as const;
const MAX_BATCH_OPS = 250;
export const expireDuels = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "UTC",
  },
  async () => {
    const db = getFirestore();
    const nowTs = Timestamp.now();
    // TODO(sprint-6): send push notification to player1 of expired random
    // waiting duels: "We couldn't find you a match this time. Try again?"
    // Push infra wiring lives in Sprint 6; for now expire silently.
    const snap = await db
      .collection("duels")
      .where("status", "in", EXPIRABLE_STATUSES)
      .where("expires_at", "<=", nowTs)
      .limit(MAX_BATCH_OPS)
      .get();
    if (snap.empty) {
      logger.info("expireDuels no expired duels", {now: nowTs.toMillis()});
      return;
    }
    const batch = db.batch();
    let queueCleanupCount = 0;
    for (const doc of snap.docs) {
      const duelType = doc.get("type");
      const player1Id = doc.get("player1_id");
      const player2Id = doc.get("player2_id");
      batch.update(doc.ref, {
        status: "expired",
        expired_at: FieldValue.serverTimestamp(),
      });
      const player2Unset =
        player2Id === null ||
        player2Id === undefined ||
        (typeof player2Id === "string" && player2Id.length === 0);
      if (
        duelType === "random" &&
        player2Unset &&
        typeof player1Id === "string" &&
        player1Id.length > 0
      ) {
        batch.delete(db.collection("duel_queue").doc(player1Id));
        queueCleanupCount++;
      }
    }
    await batch.commit();
    logger.info("expireDuels run", {
      expiredCount: snap.size,
      queueCleanupCount,
      hitMaxBatchCap: snap.size === MAX_BATCH_OPS,
    });
    if (snap.size === MAX_BATCH_OPS) {
      logger.warn("expireDuels hit max batch cap; more expired duels may exist", {
        nextRunWillContinue: true,
      });
    }
  }
);

