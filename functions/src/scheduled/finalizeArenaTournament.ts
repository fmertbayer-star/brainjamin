/**
 * After `arenas/{arenaId}` reaches status `ended`, ranks scored players from
 * `arena_results`, grants XP, writes `arena_leaderboards/{arenaId}`, and sets
 * `finalized_at` on the arena doc. Mirrors `finalizeLiveTournament`.
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

import {ARENA_XP_BY_RANK} from "../arena/shared";
import {
  leaseValid,
  releaseLeaseAborted,
  renewHeldLeaseIfDue,
  tryAcquireLease,
} from "../shared/tournamentLease";

const FINALIZE_LOG_TAG = "finalizeArenaTournament";

const XP_BATCH_MAX_OPS = 400;

function arenaXpForRank(rank: number): number {
  if (rank === 1) {
    return ARENA_XP_BY_RANK.rank1;
  }
  if (rank === 2 || rank === 3) {
    return ARENA_XP_BY_RANK.rank2to3;
  }
  return ARENA_XP_BY_RANK.rankRest;
}

type RankedRow = {
  resultRef: DocumentReference;
  uid: string;
  correctCount: number;
  totalAnswerMs: number;
  rank: number;
  skipXp: boolean;
};

async function finalizeOneArena(
  db: Firestore,
  doc: QueryDocumentSnapshot,
): Promise<void> {
  const arenaId = doc.id;
  const arenaRef = doc.ref;
  let holderIdForCleanup: string | undefined;
  const lastLeaseRenewalMs = {value: Date.now()};

  try {
    const lease = await tryAcquireLease(
      db,
      arenaRef,
      arenaId,
      FINALIZE_LOG_TAG,
    );
    if (!lease.acquired) {
      logger.info(
        `[finalizeArenaTournament] arenaId=${arenaId} skipped (leased by ${lease.heldByShort})`,
      );
      return;
    }
    const holderId = lease.lockHolderId;
    holderIdForCleanup = holderId;

    const fresh = await arenaRef.get();
    if (fresh.get("finalized_at") != null) {
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        holderId,
        FINALIZE_LOG_TAG,
      );
      return;
    }

    const resultsSnap = await db
      .collection("arena_results")
      .doc(arenaId)
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
      const uid = typeof data.uid === "string" ? data.uid : d.id;
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

    const pcRaw = fresh.get("participant_count");
    const totalParticipants =
      typeof pcRaw === "number" && Number.isFinite(pcRaw) ?
        Math.trunc(pcRaw) :
        0;

    if (ranked.length === 0 && totalParticipants > 0) {
      logger.info(
        `[finalizeArenaTournament] arenaId=${arenaId} no scored results yet ` +
        "(participant_count=" + totalParticipants +
        "); releasing lease without finalize, will retry next tick",
      );
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        holderId,
        FINALIZE_LOG_TAG,
      );
      return;
    }

    let sumXpAwarded = 0;
    for (const r of ranked) {
      sumXpAwarded += arenaXpForRank(r.rank);
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
      const xp = arenaXpForRank(row.rank);
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
          arenaRef,
          holderId,
          lastLeaseRenewalMs,
          arenaId,
          FINALIZE_LOG_TAG,
        );
        if (!ok) {
          logger.warn(
            `[finalizeArenaTournament] arenaId=${arenaId} lease lost mid-finalize before batch commit`,
          );
          await releaseLeaseAborted(
            db,
            arenaRef,
            arenaId,
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
      arenaRef,
      holderId,
      lastLeaseRenewalMs,
      arenaId,
      FINALIZE_LOG_TAG,
    );
    if (!okFinal) {
      logger.warn(
        `[finalizeArenaTournament] arenaId=${arenaId} lease lost mid-finalize before terminal commit`,
      );
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        holderId,
        FINALIZE_LOG_TAG,
      );
      return;
    }

    await commitBatch();

    const lbRef = db.collection("arena_leaderboards").doc(arenaId);

    let leaseLostTerminal = false;
    await db.runTransaction(async (tx) => {
      const s = await tx.get(arenaRef);
      const nowMs = Date.now();
      if (!leaseValid(s, holderId, nowMs)) {
        leaseLostTerminal = true;
        return;
      }
      if (s.get("finalized_at") != null) {
        tx.update(arenaRef, {
          lock_holder: null,
          lock_expires_at: null,
          updated_at: FieldValue.serverTimestamp(),
        });
        return;
      }
      tx.set(
        lbRef,
        {
          arena_id: arenaId,
          finalized_at: FieldValue.serverTimestamp(),
          total_finalized_participants: ranked.length,
          top_100: top100Rollup,
        },
        {merge: true},
      );
      tx.update(arenaRef, {
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
        `[finalizeArenaTournament] arenaId=${arenaId} lease lost mid-loop, aborting`,
      );
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        holderId,
        FINALIZE_LOG_TAG,
      );
      return;
    }

    logger.info(
      `[finalizeArenaTournament] arenaId=${arenaId} finalized count=${ranked.length} xp_total=${sumXpAwarded}`,
    );
  } catch (e) {
    logger.error(`[finalizeArenaTournament] arenaId=${arenaId} error`, e);
    if (holderIdForCleanup) {
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        holderIdForCleanup,
        FINALIZE_LOG_TAG,
      );
    }
  }
}

export const finalizeArenaTournament = onSchedule(
  {
    schedule: "* * * * *",
    timeZone: "Etc/UTC",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    const db = getFirestore();
    const endedSnap = await db
      .collection("arenas")
      .where("status", "==", "ended")
      .get();

    for (const doc of endedSnap.docs) {
      const finalizedAt = doc.get("finalized_at");
      if (finalizedAt != null) {
        continue;
      }
      await finalizeOneArena(db, doc);
    }
  },
);
