/**
 * Firestore doc lease for single-writer tournament workers (Live run/finalize).
 * Self-expires via lock_expires_at; callers renew inside their write loops.
 */

import {randomUUID} from "crypto";

import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

export const LEASE_DURATION_MS = 90_000;
export const LEASE_RENEWAL_INTERVAL_MS = 30_000;

export function shortLeaseId(id: string): string {
  return id.slice(0, 8);
}

export function leaseValid(
  snap: DocumentSnapshot,
  lockHolderId: string,
  nowMs: number,
): boolean {
  const data = snap.data();
  if (!data) {
    return false;
  }
  const holder = data.lock_holder as string | null | undefined;
  const exp = data.lock_expires_at as Timestamp | null | undefined;
  if (holder !== lockHolderId) {
    return false;
  }
  if (exp == null) {
    return false;
  }
  return exp.toMillis() > nowMs;
}

/** Piggyback lock_expires_at extension onto an existing Live-doc patch when due. */
export function appendLeaseRenewalIfDue(
  contextId: string,
  patch: Record<string, unknown>,
  lastLeaseRenewalMs: {value: number},
  logTag: string,
): void {
  const now = Date.now();
  if (now - lastLeaseRenewalMs.value < LEASE_RENEWAL_INTERVAL_MS) {
    return;
  }
  patch.lock_expires_at = Timestamp.fromMillis(now + LEASE_DURATION_MS);
  lastLeaseRenewalMs.value = now;
  logger.info(`[${logTag}] ltId=${contextId} lease renewed`);
}

export async function tryAcquireLease(
  db: Firestore,
  liveRef: DocumentReference,
  contextId: string,
  logTag: string,
): Promise<
  | {acquired: true; lockHolderId: string; holderShort: string}
  | {acquired: false; heldByShort: string}
> {
  const lockHolderId = randomUUID();
  const holderShort = shortLeaseId(lockHolderId);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(liveRef);
    const data = snap.data();
    const now = Date.now();
    const currentHolder =
      (data?.lock_holder as string | null | undefined) ?? null;
    const exp = data?.lock_expires_at as Timestamp | null | undefined;
    const expiresAtMs = exp?.toMillis() ?? 0;
    const isFree = currentHolder === null || expiresAtMs < now;
    if (!isFree) {
      return {acquired: false as const, heldBy: currentHolder!};
    }
    tx.update(liveRef, {
      lock_holder: lockHolderId,
      lock_expires_at: Timestamp.fromMillis(now + LEASE_DURATION_MS),
      updated_at: FieldValue.serverTimestamp(),
    });
    return {acquired: true as const};
  });

  if (!result.acquired) {
    return {
      acquired: false,
      heldByShort: shortLeaseId(result.heldBy),
    };
  }
  logger.info(
    `[${logTag}] ltId=${contextId} lease acquired holder=${holderShort}`,
  );
  return {acquired: true, lockHolderId, holderShort};
}

/** Clears lease only if this holder still holds a valid lease (crash / abort). */
export async function releaseLeaseAborted(
  db: Firestore,
  liveRef: DocumentReference,
  contextId: string,
  lockHolderId: string,
  logTag: string,
): Promise<void> {
  let cleared = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(liveRef);
    const nowMs = Date.now();
    if (!leaseValid(snap, lockHolderId, nowMs)) {
      return;
    }
    cleared = true;
    tx.update(liveRef, {
      lock_holder: null,
      lock_expires_at: null,
      updated_at: FieldValue.serverTimestamp(),
    });
  });
  if (cleared) {
    logger.info(`[${logTag}] ltId=${contextId} lease released (aborted)`);
  }
}

/**
 * Standalone renewal between long-running steps (e.g. finalize batches).
 * Returns false if the lease is no longer held by lockHolderId.
 */
export async function renewHeldLeaseIfDue(
  db: Firestore,
  liveRef: DocumentReference,
  lockHolderId: string,
  lastLeaseRenewalMs: {value: number},
  contextId: string,
  logTag: string,
): Promise<boolean> {
  const now = Date.now();
  if (now - lastLeaseRenewalMs.value < LEASE_RENEWAL_INTERVAL_MS) {
    return true;
  }

  let lost = false;
  let renewed = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(liveRef);
    const nowMs = Date.now();
    if (!leaseValid(snap, lockHolderId, nowMs)) {
      lost = true;
      return;
    }
    tx.update(liveRef, {
      lock_expires_at: Timestamp.fromMillis(nowMs + LEASE_DURATION_MS),
      updated_at: FieldValue.serverTimestamp(),
    });
    renewed = true;
  });
  if (lost) {
    return false;
  }
  if (renewed) {
    lastLeaseRenewalMs.value = Date.now();
    logger.info(`[${logTag}] ltId=${contextId} lease renewed`);
  }
  return true;
}
