/**
 * Live tournament tick: advances scheduled → running → ended (or no_participants /
 * no_pool_questions). Single-doc fan-out on `live_tournaments/{ltId}`; per-question
 * writes under `live_questions/{ltId}/q/{qIndex}`.
 *
 * // live_questions/{ltId}/q/{qIndex} fields (qIndex 0..19):
 * //   q_id: string                    -- reference to questions_public/{q_id}
 * //   question_text: string
 * //   options: string[4]
 * //   difficulty: number              -- 1..5
 * //   category: string
 * //   started_at: Timestamp           -- server time the answer window opened
 * //   correct_index: number | null    -- null until reveal, then 0..3
 *
 * questions_public uses `difficulty` as integer 1–5 and `flagged: boolean` (see
 * functions/src/shared/difficulty.ts and pipeline persist path).
 */

import {createHash} from "crypto";

import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentReference,
  type Firestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  appendLeaseRenewalIfDue,
  leaseValid,
  releaseLeaseAborted,
  tryAcquireLease,
} from "../shared/tournamentLease";

const LIVE_LEASE_LOG_TAG = "runLiveTournament";

const ANSWER_WINDOW_MS = 15_000;
/** TODO Step 2c: make reveal duration configurable */
const REVEAL_DISPLAY_MS = 3000;
const QUESTIONS_PER_TOURNAMENT = 20;
const PER_LEVEL = 4;
const LEVELS = [1, 2, 3, 4, 5] as const;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Deterministic shuffle for stable retries (same ltId → same order). */
function mulberry32(seed: number): () => number {
  return () => {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function seedFromString(s: string): number {
  const buf = createHash("sha256").update(s).digest();
  return buf.readUInt32BE(0);
}

function deterministicShuffleStrings(ids: string[], ltId: string): string[] {
  const rnd = mulberry32(seedFromString(`${ltId}:qids`));
  const arr = [...ids];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function deterministicPickFourDocs(
  docs: QueryDocumentSnapshot[],
  ltId: string,
  level: number,
): QueryDocumentSnapshot[] {
  const rnd = mulberry32(seedFromString(`${ltId}:lvl:${level}`));
  const arr = [...docs];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr.slice(0, PER_LEVEL);
}

async function pullTwentyQuestionIds(
  db: Firestore,
  ltId: string,
): Promise<{ids: string[]} | {fail: string}> {
  const collected: string[] = [];
  for (const level of LEVELS) {
    const snap = await db
      .collection("questions_public")
      .where("difficulty", "==", level)
      .where("flagged", "==", false)
      .limit(50)
      .get();
    if (snap.size < PER_LEVEL) {
      return {fail: `insufficient_questions_at_difficulty_${level}`};
    }
    const picked = deterministicPickFourDocs(snap.docs, ltId, level);
    for (const d of picked) {
      collected.push(d.id);
    }
  }
  const ordered = deterministicShuffleStrings(collected, ltId);
  return {ids: ordered};
}

function liveQuestionRef(db: Firestore, ltId: string, qIndex: number) {
  return db.collection("live_questions").doc(ltId).collection("q").doc(String(qIndex));
}

async function advanceAfterReveal(
  db: Firestore,
  ltId: string,
  liveRef: DocumentReference,
  cq: number,
  qids: string[],
  lockHolderId: string,
  lastLeaseRenewalMs: {value: number},
): Promise<{ended: boolean; leaseLost: boolean}> {
  if (cq === QUESTIONS_PER_TOURNAMENT - 1) {
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
      const fresh = await tx.get(liveRef);
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
      tx.update(liveRef, terminalPatch);
      committed = true;
    });
    if (leaseLost) {
      return {ended: false, leaseLost: true};
    }
    if (!committed) {
      return {ended: false, leaseLost: false};
    }
    logger.info(`[runLiveTournament] ltId=${ltId} ended after Q20`);
    logger.info(`[runLiveTournament] ltId=${ltId} lease released (terminal)`);
    return {ended: true, leaseLost: false};
  }

  const next = cq + 1;
  const nextQid = qids[next]!;
  const poolSnap = await db.collection("questions_public").doc(nextQid).get();
  const pdata = poolSnap.data()!;
  const question = pdata.question as string;
  const options = pdata.options as string[];
  const difficulty = pdata.difficulty as number;
  const category = pdata.category as string;

  const qRef = liveQuestionRef(db, ltId, next);
  const livePatch: Record<string, unknown> = {
    current_question: next,
    reveal_active: false,
    last_heartbeat_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  };
  if (cq === 4) {
    livePatch.late_join_closed = true;
    logger.info(`[runLiveTournament] ltId=${ltId} late_join_closed at Q5`);
  }
  appendLeaseRenewalIfDue(ltId, livePatch, lastLeaseRenewalMs, LIVE_LEASE_LOG_TAG);

  let leaseLost = false;
  let committed = false;
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(liveRef);
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
    tx.set(qRef, {
      q_id: nextQid,
      question_text: question,
      options,
      difficulty,
      category,
      started_at: FieldValue.serverTimestamp(),
      correct_index: null,
    });
    tx.update(liveRef, livePatch);
    committed = true;
  });
  if (leaseLost) {
    return {ended: false, leaseLost: true};
  }
  if (!committed) {
    return {ended: false, leaseLost: false};
  }
  logger.info(`[runLiveTournament] ltId=${ltId} advanced to Q${next + 1}`);
  return {ended: false, leaseLost: false};
}

async function runLiveGameLoop(
  db: Firestore,
  ltId: string,
  liveRef: DocumentReference,
  lockHolderId: string,
  lastLeaseRenewalMs: {value: number},
): Promise<void> {
  for (;;) {
    const liveSnap = await liveRef.get();
    const d = liveSnap.data();
    if (!d || d.status !== "running") {
      return;
    }

    const cqRaw = d.current_question;
    const cq =
      typeof cqRaw === "number" && Number.isInteger(cqRaw) ? cqRaw : null;
    const ra = d.reveal_active === true;
    const qids = d.q_ids as unknown;

    if (!Array.isArray(qids) || qids.length !== QUESTIONS_PER_TOURNAMENT) {
      logger.error(
        `[runLiveTournament] ltId=${ltId} invalid q_ids`,
      );
      await releaseLeaseAborted(
        db,
        liveRef,
        ltId,
        lockHolderId,
        LIVE_LEASE_LOG_TAG,
      );
      return;
    }
    if (cq === null || cq < 0 || cq > QUESTIONS_PER_TOURNAMENT - 1) {
      logger.error(
        `[runLiveTournament] ltId=${ltId} invalid current_question`,
      );
      await releaseLeaseAborted(
        db,
        liveRef,
        ltId,
        lockHolderId,
        LIVE_LEASE_LOG_TAG,
      );
      return;
    }

    const qDocRef = liveQuestionRef(db, ltId, cq);

    if (!ra) {
      const qSnap = await qDocRef.get();
      if (!qSnap.exists) {
        logger.error(
          `[runLiveTournament] ltId=${ltId} missing live_questions q/${cq}`,
        );
        await releaseLeaseAborted(
          db,
          liveRef,
          ltId,
          lockHolderId,
          LIVE_LEASE_LOG_TAG,
        );
        return;
      }
      const startedAt = qSnap.get("started_at") as Timestamp | undefined;
      if (!startedAt) {
        logger.error(
          `[runLiveTournament] ltId=${ltId} missing started_at on q/${cq}`,
        );
        await releaseLeaseAborted(
          db,
          liveRef,
          ltId,
          lockHolderId,
          LIVE_LEASE_LOG_TAG,
        );
        return;
      }
      const elapsed = Timestamp.now().toMillis() - startedAt.toMillis();
      const remaining = ANSWER_WINDOW_MS - elapsed;
      if (remaining > 0) {
        await sleep(remaining);
      }

      const qid = qids[cq] as string;
      const poolSnap = await db.collection("questions_public").doc(qid).get();
      const correctRaw = poolSnap.get("correctIndex");
      if (
        typeof correctRaw !== "number" ||
        correctRaw < 0 ||
        correctRaw > 3
      ) {
        logger.error(
          `[runLiveTournament] ltId=${ltId} invalid correctIndex on pool ${qid}`,
        );
        await releaseLeaseAborted(
          db,
          liveRef,
          ltId,
          lockHolderId,
          LIVE_LEASE_LOG_TAG,
        );
        return;
      }

      const revealPatch: Record<string, unknown> = {
        reveal_active: true,
        last_heartbeat_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      };
      appendLeaseRenewalIfDue(
        ltId,
        revealPatch,
        lastLeaseRenewalMs,
        LIVE_LEASE_LOG_TAG,
      );

      let leaseLostReveal = false;
      let revealCommitted = false;
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(liveRef);
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
        tx.update(liveRef, revealPatch);
        tx.update(qDocRef, {correct_index: correctRaw});
        revealCommitted = true;
      });
      if (leaseLostReveal) {
        logger.info(
          `[runLiveTournament] ltId=${ltId} lease lost mid-loop, aborting`,
        );
        return;
      }
      if (!revealCommitted) {
        continue;
      }

      logger.info(
        `[runLiveTournament] ltId=${ltId} reveal started for Q${cq + 1}`,
      );

      // TODO Step 2c: make reveal duration configurable
      await sleep(REVEAL_DISPLAY_MS);

      const adv = await advanceAfterReveal(
        db,
        ltId,
        liveRef,
        cq,
        qids,
        lockHolderId,
        lastLeaseRenewalMs,
      );
      if (adv.leaseLost) {
        logger.info(
          `[runLiveTournament] ltId=${ltId} lease lost mid-loop, aborting`,
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
      const revealRem = REVEAL_DISPLAY_MS -
        (Timestamp.now().toMillis() - hb.toMillis());
      if (revealRem > 0) {
        await sleep(revealRem);
      }
    } else {
      await sleep(REVEAL_DISPLAY_MS);
    }

    const adv = await advanceAfterReveal(
      db,
      ltId,
      liveRef,
      cq,
      qids,
      lockHolderId,
      lastLeaseRenewalMs,
    );
    if (adv.leaseLost) {
      logger.info(
        `[runLiveTournament] ltId=${ltId} lease lost mid-loop, aborting`,
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
  ltId: string,
  liveRef: DocumentReference,
  lockHolderId: string,
): Promise<void> {
  const lastLeaseRenewalMs = {value: Date.now()};
  const partSnap = await db
    .collection("live_participants")
    .doc(ltId)
    .collection("users")
    .limit(1)
    .get();

  if (partSnap.empty) {
    await liveRef.update({
      status: "no_participants",
      lock_holder: null,
      lock_expires_at: null,
      updated_at: FieldValue.serverTimestamp(),
      last_heartbeat_at: FieldValue.serverTimestamp(),
    });
    logger.info(`[runLiveTournament] ltId=${ltId} lease released (terminal)`);
    logger.info(`[runLiveTournament] ltId=${ltId} skipped (no participants)`);
    return;
  }

  const pulled = await pullTwentyQuestionIds(db, ltId);
  if ("fail" in pulled) {
    await liveRef.update({
      status: "no_pool_questions",
      failure_reason: pulled.fail,
      lock_holder: null,
      lock_expires_at: null,
      updated_at: FieldValue.serverTimestamp(),
      last_heartbeat_at: FieldValue.serverTimestamp(),
    });
    logger.error(
      `[runLiveTournament] ltId=${ltId} ${pulled.fail}`,
    );
    logger.info(`[runLiveTournament] ltId=${ltId} lease released (terminal)`);
    return;
  }

  const orderedIds = pulled.ids;
  logger.info(
    `[runLiveTournament] ltId=${ltId} q_ids loaded (${orderedIds.length} ids)`,
  );

  const firstId = orderedIds[0]!;
  const pool0 = await db.collection("questions_public").doc(firstId).get();
  const pdata = pool0.data();
  if (
    !pdata ||
    typeof pdata.question !== "string" ||
    !Array.isArray(pdata.options) ||
    pdata.options.length !== 4 ||
    typeof pdata.difficulty !== "number" ||
    typeof pdata.category !== "string"
  ) {
    logger.error(
      `[runLiveTournament] ltId=${ltId} invalid pool doc ${firstId}`,
    );
    await releaseLeaseAborted(
      db,
      liveRef,
      ltId,
      lockHolderId,
      LIVE_LEASE_LOG_TAG,
    );
    return;
  }

  const q0Ref = liveQuestionRef(db, ltId, 0);
  const startPatch: Record<string, unknown> = {
    status: "running",
    q_ids: orderedIds,
    current_question: 0,
    reveal_active: false,
    late_join_closed: false,
    last_heartbeat_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  };
  appendLeaseRenewalIfDue(
    ltId,
    startPatch,
    lastLeaseRenewalMs,
    LIVE_LEASE_LOG_TAG,
  );

  let leaseLostStart = false;
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(liveRef);
    const nowMs = Date.now();
    if (!leaseValid(fresh, lockHolderId, nowMs)) {
      leaseLostStart = true;
      return;
    }
    if (fresh.get("status") !== "scheduled") {
      return;
    }
    tx.update(liveRef, startPatch);
    tx.set(q0Ref, {
      q_id: firstId,
      question_text: pdata.question,
      options: pdata.options,
      difficulty: pdata.difficulty,
      category: pdata.category,
      started_at: FieldValue.serverTimestamp(),
      correct_index: null,
    });
  });
  if (leaseLostStart) {
    logger.info(
      `[runLiveTournament] ltId=${ltId} lease lost mid-loop, aborting`,
    );
    return;
  }

  logger.info(`[runLiveTournament] ltId=${ltId} start`);

  await runLiveGameLoop(db, ltId, liveRef, lockHolderId, lastLeaseRenewalMs);
}

async function handleOneTournament(
  db: Firestore,
  doc: QueryDocumentSnapshot,
): Promise<void> {
  const ltId = doc.id;
  const liveRef = doc.ref;
  const status = doc.get("status");

  try {
    if (status === "scheduled") {
      const lease = await tryAcquireLease(
        db,
        liveRef,
        ltId,
        LIVE_LEASE_LOG_TAG,
      );
      if (!lease.acquired) {
        logger.info(
          `[runLiveTournament] ltId=${ltId} skipped (leased by ${lease.heldByShort})`,
        );
        return;
      }
      await handleScheduled(db, ltId, liveRef, lease.lockHolderId);
    } else if (status === "running") {
      const lease = await tryAcquireLease(
        db,
        liveRef,
        ltId,
        LIVE_LEASE_LOG_TAG,
      );
      if (!lease.acquired) {
        logger.info(
          `[runLiveTournament] ltId=${ltId} skipped (leased by ${lease.heldByShort})`,
        );
        return;
      }
      const lastLeaseRenewalMs = {value: Date.now()};
      await runLiveGameLoop(
        db,
        ltId,
        liveRef,
        lease.lockHolderId,
        lastLeaseRenewalMs,
      );
    }
  } catch (e) {
    logger.error(`[runLiveTournament] ltId=${ltId} error`, e);
    throw e;
  }
}

export const runLiveTournament = onSchedule(
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
      .collection("live_tournaments")
      .where("status", "==", "scheduled")
      .where("starts_at", "<=", now)
      .get();

    const runningSnap = await db
      .collection("live_tournaments")
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
      await handleOneTournament(db, doc);
    }
  },
);
