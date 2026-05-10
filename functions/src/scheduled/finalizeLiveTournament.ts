/**
 * After `live_tournaments/{ltId}` reaches status `ended`, ranks scored players,
 * grants XP (atomic per user with live_results row), and writes `top_100` + `finalized_at`.
 */

import {
  FieldValue,
  getFirestore,
  type DocumentReference,
  type Firestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {liveXpForRank} from "../shared/liveScoring";
import {
  leaseValid,
  releaseLeaseAborted,
  renewHeldLeaseIfDue,
  tryAcquireLease,
} from "../shared/tournamentLease";

const FINALIZE_LOG_TAG = "finalizeLiveTournament";

/** Stay under Firestore 500 ops/batch; two writes per ranked user (result + user xp). */
const XP_BATCH_MAX_OPS = 400;

type RankedRow = {
  resultRef: DocumentReference;
  uid: string;
  correctCount: number;
  totalAnswerMs: number;
  rank: number;
  skipXp: boolean;
};

async function finalizeOneTournament(
  db: Firestore,
  doc: QueryDocumentSnapshot,
): Promise<void> {
  const ltId = doc.id;
  const liveRef = doc.ref;
  /** Set after lease acquisition; used only for cleanup on error/abort. */
  let holderIdForCleanup: string | undefined;
  const lastLeaseRenewalMs = {value: Date.now()};

  try {
    const lease = await tryAcquireLease(
      db,
      liveRef,
      ltId,
      FINALIZE_LOG_TAG,
    );
    if (!lease.acquired) {
      logger.info(
        `[finalizeLiveTournament] ltId=${ltId} skipped (leased by ${lease.heldByShort})`,
      );
      return;
    }
    const holderId = lease.lockHolderId;
    holderIdForCleanup = holderId;

    const fresh = await liveRef.get();
    if (fresh.get("finalized_at") != null) {
      await releaseLeaseAborted(
        db,
        liveRef,
        ltId,
        holderId,
        FINALIZE_LOG_TAG,
      );
      return;
    }

    const resultsSnap = await db
      .collection("live_results")
      .doc(ltId)
      .collection("users")
      .where("scored", "==", true)
      .get();

    type SortRow = {
      resultRef: DocumentReference;
      uid: string;
      correctCount: number;
      totalAnswerMs: number;
      skipXp: boolean;
    };

    const sortRows: SortRow[] = resultsSnap.docs.map((d) => {
      const data = d.data();
      const uid = data.uid as string;
      const ccRaw = data.correct_count;
      const tamRaw = data.total_answer_ms;
      const correctCount =
        typeof ccRaw === "number" && Number.isFinite(ccRaw) ? ccRaw : 0;
      const totalAnswerMs =
        typeof tamRaw === "number" && Number.isFinite(tamRaw) ? tamRaw : 0;
      return {
        resultRef: d.ref,
        uid,
        correctCount,
        totalAnswerMs,
        skipXp: d.get("xp_granted_at") != null,
      };
    });

    sortRows.sort((a, b) => {
      if (b.correctCount !== a.correctCount) {
        return b.correctCount - a.correctCount;
      }
      if (a.totalAnswerMs !== b.totalAnswerMs) {
        return a.totalAnswerMs - b.totalAnswerMs;
      }
      return a.uid.localeCompare(b.uid);
    });

    /**
     * Competition ranking (1,2,2,4,...): ties share the same rank; the next
     * distinct score pair advances to position index + 1.
     */
    const ranked: RankedRow[] = [];
    let currentRank = 1;
    for (let i = 0; i < sortRows.length; i++) {
      const row = sortRows[i]!;
      if (i > 0) {
        const prev = sortRows[i - 1]!;
        if (
          row.correctCount !== prev.correctCount ||
          row.totalAnswerMs !== prev.totalAnswerMs
        ) {
          currentRank = i + 1;
        }
      }
      ranked.push({
        resultRef: row.resultRef,
        uid: row.uid,
        correctCount: row.correctCount,
        totalAnswerMs: row.totalAnswerMs,
        rank: currentRank,
        skipXp: row.skipXp,
      });
    }

    /**
     * Race-with-submitLiveAnswers retry behavior: runLive can set status ended and
     * release the finalize lease before submitLiveAnswers commits scored:true on
     * live_results. Skip finalized_at when someone joined (total_participants > 0)
     * but no scored rows yet so the next cron tick retries.
     */
    const tpRaw = fresh.get("total_participants");
    const totalParticipants =
      typeof tpRaw === "number" && Number.isFinite(tpRaw) ?
        Math.trunc(tpRaw) :
        0;

    if (ranked.length === 0 && totalParticipants > 0) {
      logger.info(
        `[finalizeLiveTournament] ltId=${ltId} no scored results yet ` +
        "(total_participants=" + totalParticipants +
        "); releasing lease without finalize, will retry next tick",
      );
      await releaseLeaseAborted(
        db,
        liveRef,
        ltId,
        holderId,
        FINALIZE_LOG_TAG,
      );
      return;
    }

    let sumXpAwarded = 0;
    for (const r of ranked) {
      sumXpAwarded += liveXpForRank(r.rank);
    }

    const top100Slice = ranked.slice(0, 100);
    const displayByUid = new Map<string, string>();
    const chunkSize = 30;
    for (let i = 0; i < top100Slice.length; i += chunkSize) {
      const chunk = top100Slice.slice(i, i + chunkSize);
      const pubSnaps = await db.getAll(
        ...chunk.map((r) => db.collection("users_public").doc(r.uid)),
      );
      for (let j = 0; j < chunk.length; j++) {
        const r = chunk[j]!;
        const ps = pubSnaps[j];
        if (ps.exists) {
          const dn = ps.get("displayName");
          const label =
            typeof dn === "string" && dn.length > 0 ?
              dn :
              "Anonymous Player";
          displayByUid.set(r.uid, label);
        } else {
          displayByUid.set(r.uid, "Anonymous Player");
        }
      }
    }

    const top100Rollup = top100Slice.map((r) => ({
      rank: r.rank,
      uid: r.uid,
      display_name: displayByUid.get(r.uid) ?? "Anonymous Player",
      correct_count: r.correctCount,
      total_answer_ms: r.totalAnswerMs,
    }));

    let batch = db.batch();
    let batchOps = 0;

    const commitBatch = async () => {
      if (batchOps > 0) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      }
    };

    for (const row of ranked) {
      if (row.skipXp) {
        continue;
      }
      const xp = liveXpForRank(row.rank);
      const userRef = db.collection("users").doc(row.uid);
      batch.set(
        userRef,
        {xp: FieldValue.increment(xp)},
        {merge: true},
      );
      batchOps++;
      batch.update(row.resultRef, {
        rank: row.rank,
        xp_awarded: xp,
        xp_granted_at: FieldValue.serverTimestamp(),
      });
      batchOps++;

      if (batchOps >= XP_BATCH_MAX_OPS) {
        const ok = await renewHeldLeaseIfDue(
          db,
          liveRef,
          holderId,
          lastLeaseRenewalMs,
          ltId,
          FINALIZE_LOG_TAG,
        );
        if (!ok) {
          logger.warn(
            `[finalizeLiveTournament] ltId=${ltId} lease lost mid-finalize before batch commit`,
          );
          await releaseLeaseAborted(
            db,
            liveRef,
            ltId,
            holderId,
            FINALIZE_LOG_TAG,
          );
          return;
        }
        await commitBatch();
      }
    }

    const okFinal = await renewHeldLeaseIfDue(
      db,
      liveRef,
      holderId,
      lastLeaseRenewalMs,
      ltId,
      FINALIZE_LOG_TAG,
    );
    if (!okFinal) {
      logger.warn(
        `[finalizeLiveTournament] ltId=${ltId} lease lost mid-finalize before terminal commit`,
      );
      await releaseLeaseAborted(
        db,
        liveRef,
        ltId,
        holderId,
        FINALIZE_LOG_TAG,
      );
      return;
    }

    await commitBatch();

    let leaseLostTerminal = false;
    await db.runTransaction(async (tx) => {
      const s = await tx.get(liveRef);
      const nowMs = Date.now();
      if (!leaseValid(s, holderId, nowMs)) {
        leaseLostTerminal = true;
        return;
      }
      if (s.get("finalized_at") != null) {
        tx.update(liveRef, {
          lock_holder: null,
          lock_expires_at: null,
          updated_at: FieldValue.serverTimestamp(),
        });
        return;
      }
      tx.update(liveRef, {
        finalized_at: FieldValue.serverTimestamp(),
        total_finalized_participants: ranked.length,
        top_100: top100Rollup,
        lock_holder: null,
        lock_expires_at: null,
        updated_at: FieldValue.serverTimestamp(),
      });
    });

    if (leaseLostTerminal) {
      logger.warn(
        `[finalizeLiveTournament] ltId=${ltId} lease lost mid-loop, aborting`,
      );
      await releaseLeaseAborted(
        db,
        liveRef,
        ltId,
        holderId,
        FINALIZE_LOG_TAG,
      );
      return;
    }

    logger.info(
      `[finalizeLiveTournament] ltId=${ltId} finalized count=${ranked.length} xp_total=${sumXpAwarded}`,
    );
  } catch (e) {
    logger.error(`[finalizeLiveTournament] ltId=${ltId} error`, e);
    if (holderIdForCleanup) {
      await releaseLeaseAborted(
        db,
        liveRef,
        ltId,
        holderIdForCleanup,
        FINALIZE_LOG_TAG,
      );
    }
  }
}

export const finalizeLiveTournament = onSchedule(
  {
    schedule: "* * * * *",
    timeZone: "Etc/UTC",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    const db = getFirestore();
    const endedSnap = await db
      .collection("live_tournaments")
      .where("status", "==", "ended")
      .get();

    for (const doc of endedSnap.docs) {
      const finalizedAt = doc.get("finalized_at");
      if (finalizedAt != null) {
        continue;
      }
      await finalizeOneTournament(db, doc);
    }
  },
);
