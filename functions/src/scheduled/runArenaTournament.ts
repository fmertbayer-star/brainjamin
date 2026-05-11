/**
 * Arena tournament tick: advances scheduled → running → ended (or no_participants).
 * Mirrors `runLiveTournament` (lease, heartbeat, reveal pacing). Questions are
 * pre-written under `arena_questions/{arenaId}/q/{0..9}` by generateArenaQuestions;
 * this job only drives timing and reveal.
 *
 * Option C (reveal secrecy without changing 3.5b generators):
 * On the first transition `scheduled` → `running`, for each question doc we copy
 * the generator-written `correct_index` into `correct_index_server`, set
 * `correct_index: null`, and set `started_at` to null (except Q0, which opens
 * immediately with `started_at: serverTimestamp()`). Each answer window ends with
 * reveal: `correct_index` is restored from `correct_index_server` and
 * `reveal_active` is set on `arenas/{arenaId}`. Clients therefore see
 * `correct_index: null` until reveal for the active question.
 *
 * Idempotency: pre-check and start transaction accept either `correct_index` or
 * `correct_index_server` as the canonical answer. We only write
 * `correct_index_server` when it is missing; we always clear client-visible
 * `correct_index` to null for the run. Q0 `started_at` is set only if absent.
 */

import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  ARENA_ANSWER_WINDOW_MS,
  ARENA_LATE_JOIN_CLOSE_AT_Q_INDEX,
  ARENA_REVEAL_DISPLAY_MS,
  QUESTIONS_PER_ARENA,
} from "../arena/shared";
import {
  appendLeaseRenewalIfDue,
  leaseValid,
  releaseLeaseAborted,
  tryAcquireLease,
} from "../shared/tournamentLease";

const ARENA_LEASE_LOG_TAG = "runArenaTournament";

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function arenaQuestionRef(db: Firestore, arenaId: string, qIndex: number) {
  return db
    .collection("arena_questions")
    .doc(arenaId)
    .collection("q")
    .doc(String(qIndex));
}

function trustedCorrectForReveal(qSnap: DocumentSnapshot): number | null {
  return trustedCorrectIndexAny(qSnap);
}

/** Surface first, then server — used for reveal grading and Option C pre-check. */
function trustedCorrectIndexAny(qSnap: DocumentSnapshot): number | null {
  const ciSurface = qSnap.get("correct_index");
  if (
    typeof ciSurface === "number" &&
    Number.isInteger(ciSurface) &&
    ciSurface >= 0 &&
    ciSurface <= 3
  ) {
    return ciSurface;
  }
  const ciServer = qSnap.get("correct_index_server");
  if (
    typeof ciServer === "number" &&
    Number.isInteger(ciServer) &&
    ciServer >= 0 &&
    ciServer <= 3
  ) {
    return ciServer;
  }
  return null;
}

async function advanceAfterReveal(
  db: Firestore,
  arenaId: string,
  arenaRef: DocumentReference,
  cq: number,
  lockHolderId: string,
  lastLeaseRenewalMs: {value: number},
): Promise<{ended: boolean; leaseLost: boolean}> {
  if (cq === QUESTIONS_PER_ARENA - 1) {
    let leaseLost = false;
    let committed = false;
    const terminalPatch: Record<string, unknown> = {
      status: "ended",
      current_question: null,
      reveal_active: false,
      ended_at: FieldValue.serverTimestamp(),
      last_heartbeat_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
      lock_holder: null,
      lock_expires_at: null,
    };
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(arenaRef);
      const nowMs = Date.now();
      if (!leaseValid(fresh, lockHolderId, nowMs)) {
        leaseLost = true;
        return;
      }
      if (fresh.get("status") !== "running") {
        return;
      }
      if (fresh.get("current_question") !== cq) {
        return;
      }
      tx.update(arenaRef, terminalPatch);
      committed = true;
    });
    if (leaseLost) {
      return {ended: false, leaseLost: true};
    }
    if (!committed) {
      return {ended: false, leaseLost: false};
    }
    logger.info(`[runArenaTournament] arenaId=${arenaId} ended after Q${QUESTIONS_PER_ARENA}`);
    logger.info(`[runArenaTournament] arenaId=${arenaId} lease released (terminal)`);
    return {ended: true, leaseLost: false};
  }

  const next = cq + 1;
  const nextQRef = arenaQuestionRef(db, arenaId, next);
  const arenaPatch: Record<string, unknown> = {
    current_question: next,
    reveal_active: false,
    last_heartbeat_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  };
  if (cq === ARENA_LATE_JOIN_CLOSE_AT_Q_INDEX) {
    arenaPatch.late_join_closed = true;
    logger.info(
      `[runArenaTournament] arenaId=${arenaId} late_join_closed after Q${cq + 1} reveal`,
    );
  }
  appendLeaseRenewalIfDue(
    arenaId,
    arenaPatch,
    lastLeaseRenewalMs,
    ARENA_LEASE_LOG_TAG,
  );

  let leaseLost = false;
  let committed = false;
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(arenaRef);
    const nowMs = Date.now();
    if (!leaseValid(fresh, lockHolderId, nowMs)) {
      leaseLost = true;
      return;
    }
    if (fresh.get("status") !== "running") {
      return;
    }
    if (fresh.get("current_question") !== cq) {
      return;
    }
    if (fresh.get("reveal_active") !== true) {
      return;
    }
    tx.update(nextQRef, {
      started_at: FieldValue.serverTimestamp(),
    });
    tx.update(arenaRef, arenaPatch);
    committed = true;
  });
  if (leaseLost) {
    return {ended: false, leaseLost: true};
  }
  if (!committed) {
    return {ended: false, leaseLost: false};
  }
  logger.info(`[runArenaTournament] arenaId=${arenaId} advanced to Q${next + 1}`);
  return {ended: false, leaseLost: false};
}

async function runArenaGameLoop(
  db: Firestore,
  arenaId: string,
  arenaRef: DocumentReference,
  lockHolderId: string,
  lastLeaseRenewalMs: {value: number},
): Promise<void> {
  for (;;) {
    const arenaSnap = await arenaRef.get();
    const d = arenaSnap.data();
    if (!d || d.status !== "running") {
      return;
    }

    const cqRaw = d.current_question;
    const cq =
      typeof cqRaw === "number" && Number.isInteger(cqRaw) ? cqRaw : null;
    const ra = d.reveal_active === true;

    if (cq === null || cq < 0 || cq > QUESTIONS_PER_ARENA - 1) {
      logger.error(
        `[runArenaTournament] arenaId=${arenaId} invalid current_question`,
      );
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        lockHolderId,
        ARENA_LEASE_LOG_TAG,
      );
      return;
    }

    const qDocRef = arenaQuestionRef(db, arenaId, cq);

    if (!ra) {
      const qSnap = await qDocRef.get();
      if (!qSnap.exists) {
        logger.error(
          `[runArenaTournament] arenaId=${arenaId} missing arena_questions q/${cq}`,
        );
        await releaseLeaseAborted(
          db,
          arenaRef,
          arenaId,
          lockHolderId,
          ARENA_LEASE_LOG_TAG,
        );
        return;
      }
      const startedAt = qSnap.get("started_at") as Timestamp | undefined | null;
      if (!startedAt) {
        logger.error(
          `[runArenaTournament] arenaId=${arenaId} missing started_at on q/${cq}`,
        );
        await releaseLeaseAborted(
          db,
          arenaRef,
          arenaId,
          lockHolderId,
          ARENA_LEASE_LOG_TAG,
        );
        return;
      }
      const elapsed = Timestamp.now().toMillis() - startedAt.toMillis();
      const remaining = ARENA_ANSWER_WINDOW_MS - elapsed;
      if (remaining > 0) {
        await sleep(remaining);
      }

      const correctRaw = trustedCorrectForReveal(qSnap);
      if (
        correctRaw === null
      ) {
        logger.error(
          `[runArenaTournament] arenaId=${arenaId} invalid correct index on q/${cq}`,
        );
        await releaseLeaseAborted(
          db,
          arenaRef,
          arenaId,
          lockHolderId,
          ARENA_LEASE_LOG_TAG,
        );
        return;
      }

      const revealPatch: Record<string, unknown> = {
        reveal_active: true,
        last_heartbeat_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      };
      appendLeaseRenewalIfDue(
        arenaId,
        revealPatch,
        lastLeaseRenewalMs,
        ARENA_LEASE_LOG_TAG,
      );

      let leaseLostReveal = false;
      let revealCommitted = false;
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(arenaRef);
        const nowMs = Date.now();
        if (!leaseValid(fresh, lockHolderId, nowMs)) {
          leaseLostReveal = true;
          return;
        }
        if (fresh.get("status") !== "running") {
          return;
        }
        if (fresh.get("current_question") !== cq) {
          return;
        }
        if (fresh.get("reveal_active") === true) {
          return;
        }
        tx.update(arenaRef, revealPatch);
        tx.update(qDocRef, {correct_index: correctRaw});
        revealCommitted = true;
      });
      if (leaseLostReveal) {
        logger.info(
          `[runArenaTournament] arenaId=${arenaId} lease lost mid-loop, aborting`,
        );
        return;
      }
      if (!revealCommitted) {
        continue;
      }

      logger.info(
        `[runArenaTournament] arenaId=${arenaId} reveal started for Q${cq + 1}`,
      );

      await sleep(ARENA_REVEAL_DISPLAY_MS);

      const adv = await advanceAfterReveal(
        db,
        arenaId,
        arenaRef,
        cq,
        lockHolderId,
        lastLeaseRenewalMs,
      );
      if (adv.leaseLost) {
        logger.info(
          `[runArenaTournament] arenaId=${arenaId} lease lost mid-loop, aborting`,
        );
        return;
      }
      if (adv.ended) {
        return;
      }
      continue;
    }

    const hb = d.last_heartbeat_at as Timestamp | undefined;
    if (hb) {
      const revealRem =
        ARENA_REVEAL_DISPLAY_MS -
        (Timestamp.now().toMillis() - hb.toMillis());
      if (revealRem > 0) {
        await sleep(revealRem);
      }
    } else {
      await sleep(ARENA_REVEAL_DISPLAY_MS);
    }

    const adv = await advanceAfterReveal(
      db,
      arenaId,
      arenaRef,
      cq,
      lockHolderId,
      lastLeaseRenewalMs,
    );
    if (adv.leaseLost) {
      logger.info(
        `[runArenaTournament] arenaId=${arenaId} lease lost mid-loop, aborting`,
      );
      return;
    }
    if (adv.ended) {
      return;
    }
  }
}

async function handleScheduled(
  db: Firestore,
  arenaId: string,
  arenaRef: DocumentReference,
  lockHolderId: string,
): Promise<void> {
  const lastLeaseRenewalMs = {value: Date.now()};
  const partSnap = await db
    .collection("arena_participants")
    .doc(arenaId)
    .collection("users")
    .limit(1)
    .get();

  if (partSnap.empty) {
    await arenaRef.update({
      status: "no_participants",
      lock_holder: null,
      lock_expires_at: null,
      updated_at: FieldValue.serverTimestamp(),
      last_heartbeat_at: FieldValue.serverTimestamp(),
    });
    logger.info(`[runArenaTournament] arenaId=${arenaId} lease released (terminal)`);
    logger.info(`[runArenaTournament] arenaId=${arenaId} skipped (no participants)`);
    return;
  }

  const qIds: string[] = [];
  for (let i = 0; i < QUESTIONS_PER_ARENA; i++) {
    const ref = arenaQuestionRef(db, arenaId, i);
    const s = await ref.get();
    if (!s.exists) {
      logger.error(
        `[runArenaTournament] arenaId=${arenaId} missing question doc q/${i}`,
      );
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        lockHolderId,
        ARENA_LEASE_LOG_TAG,
      );
      return;
    }
    const qix = s.get("q_index");
    if (typeof qix !== "number" || qix !== i) {
      logger.error(
        `[runArenaTournament] arenaId=${arenaId} invalid q_index on q/${i}`,
      );
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        lockHolderId,
        ARENA_LEASE_LOG_TAG,
      );
      return;
    }
    if (trustedCorrectIndexAny(s) === null) {
      logger.error(
        `[runArenaTournament] arenaId=${arenaId} invalid correct_index / correct_index_server on q/${i} before strip`,
      );
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        lockHolderId,
        ARENA_LEASE_LOG_TAG,
      );
      return;
    }
    qIds.push(String(i));
  }

  logger.info(
    `[runArenaTournament] arenaId=${arenaId} q_ids loaded (${qIds.length} ids)`,
  );

  const startPatch: Record<string, unknown> = {
    status: "running",
    q_ids: qIds,
    current_question: 0,
    reveal_active: false,
    late_join_closed: false,
    last_heartbeat_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  };
  appendLeaseRenewalIfDue(
    arenaId,
    startPatch,
    lastLeaseRenewalMs,
    ARENA_LEASE_LOG_TAG,
  );

  let leaseLostStart = false;
  try {
    await db.runTransaction(async (tx) => {
      const qRefs = Array.from({length: QUESTIONS_PER_ARENA}, (_, i) =>
        arenaQuestionRef(db, arenaId, i),
      );
      // One read phase: arena + all question docs (no reads after writes).
      const allSnaps = await tx.getAll(arenaRef, ...qRefs);
      const fresh = allSnaps[0]!;
      if (!fresh.exists) {
        throw new Error("arena_missing");
      }
      const nowMs = Date.now();
      if (!leaseValid(fresh, lockHolderId, nowMs)) {
        leaseLostStart = true;
        return;
      }
      if (fresh.get("status") !== "scheduled") {
        return;
      }
      const qSnaps = allSnaps.slice(1);

      const qWrites: Array<{
        ref: DocumentReference;
        data: Record<string, unknown>;
      }> = [];

      for (let i = 0; i < QUESTIONS_PER_ARENA; i++) {
        const qSnap = qSnaps[i]!;
        if (!qSnap.exists) {
          throw new Error(`missing_q_${i}`);
        }
        const surfRaw = qSnap.get("correct_index");
        const serverRaw = qSnap.get("correct_index_server");
        const hasSurf =
          typeof surfRaw === "number" &&
          Number.isInteger(surfRaw) &&
          surfRaw >= 0 &&
          surfRaw <= 3;
        const hasServer =
          typeof serverRaw === "number" &&
          Number.isInteger(serverRaw) &&
          serverRaw >= 0 &&
          serverRaw <= 3;
        if (!hasSurf && !hasServer) {
          throw new Error(`invalid_correct_index_q_${i}`);
        }
        const trusted = hasSurf ? surfRaw : (serverRaw as number);
        const patch: Record<string, unknown> = {
          correct_index: null,
        };
        if (!hasServer) {
          patch.correct_index_server = trusted;
        }
        if (i === 0) {
          const startedAt = qSnap.get("started_at");
          if (!(startedAt instanceof Timestamp)) {
            patch.started_at = FieldValue.serverTimestamp();
          }
        } else {
          patch.started_at = null;
        }
        qWrites.push({ref: qRefs[i]!, data: patch});
      }

      tx.update(arenaRef, startPatch);
      for (const w of qWrites) {
        tx.update(w.ref, w.data);
      }
    });
  } catch (e) {
    logger.error(`[runArenaTournament] arenaId=${arenaId} start transaction failed`, e);
    await releaseLeaseAborted(
      db,
      arenaRef,
      arenaId,
      lockHolderId,
      ARENA_LEASE_LOG_TAG,
    );
    return;
  }

  if (leaseLostStart) {
    await releaseLeaseAborted(
      db,
      arenaRef,
      arenaId,
      lockHolderId,
      ARENA_LEASE_LOG_TAG,
    );
    logger.info(
      `[runArenaTournament] arenaId=${arenaId} lease lost before start txn commit, released`,
    );
    return;
  }

  const verify = await arenaRef.get();
  const nowCheck = Date.now();
  if (verify.get("status") !== "running") {
    if (leaseValid(verify, lockHolderId, nowCheck)) {
      await releaseLeaseAborted(
        db,
        arenaRef,
        arenaId,
        lockHolderId,
        ARENA_LEASE_LOG_TAG,
      );
    }
    return;
  }

  logger.info(`[runArenaTournament] arenaId=${arenaId} start`);

  await runArenaGameLoop(db, arenaId, arenaRef, lockHolderId, lastLeaseRenewalMs);
}

async function handleOneArena(
  db: Firestore,
  doc: QueryDocumentSnapshot,
): Promise<void> {
  const arenaId = doc.id;
  const arenaRef = doc.ref;
  const status = doc.get("status");

  try {
    if (status === "generation_failed") {
      return;
    }
    if (status === "scheduled") {
      const lease = await tryAcquireLease(
        db,
        arenaRef,
        arenaId,
        ARENA_LEASE_LOG_TAG,
      );
      if (!lease.acquired) {
        logger.info(
          `[runArenaTournament] arenaId=${arenaId} skipped (leased by ${lease.heldByShort})`,
        );
        return;
      }
      await handleScheduled(db, arenaId, arenaRef, lease.lockHolderId);
    } else if (status === "running") {
      const lease = await tryAcquireLease(
        db,
        arenaRef,
        arenaId,
        ARENA_LEASE_LOG_TAG,
      );
      if (!lease.acquired) {
        logger.info(
          `[runArenaTournament] arenaId=${arenaId} skipped (leased by ${lease.heldByShort})`,
        );
        return;
      }
      const lastLeaseRenewalMs = {value: Date.now()};
      await runArenaGameLoop(
        db,
        arenaId,
        arenaRef,
        lease.lockHolderId,
        lastLeaseRenewalMs,
      );
    }
  } catch (e) {
    logger.error(`[runArenaTournament] arenaId=${arenaId} error`, e);
    throw e;
  }
}

export const runArenaTournament = onSchedule(
  {
    schedule: "* * * * *",
    timeZone: "Etc/UTC",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const db = getFirestore();
    const now = Timestamp.now();

    const scheduledSnap = await db
      .collection("arenas")
      .where("status", "==", "scheduled")
      .where("scheduled_start_at", "<=", now)
      .get();

    const runningSnap = await db
      .collection("arenas")
      .where("status", "==", "running")
      .get();

    const seen = new Set<string>();
    const docs: QueryDocumentSnapshot[] = [];
    for (const d of scheduledSnap.docs) {
      if (!seen.has(d.id)) {
        seen.add(d.id);
        docs.push(d);
      }
    }
    for (const d of runningSnap.docs) {
      if (!seen.has(d.id)) {
        seen.add(d.id);
        docs.push(d);
      }
    }

    for (const doc of docs) {
      await handleOneArena(db, doc);
    }
  },
);
