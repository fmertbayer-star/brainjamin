/**
 * joinArena — HTTPS callable. Adds arena_participants doc + increments count.
 */

import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentReference,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import type {ArenaStatus} from "./shared";

type JoinArenaRequest = {
  invite_code?: unknown;
  arena_id?: unknown;
};

const LATE_JOIN_GRACE_MS = 5 * 60 * 1000;

export const joinArena = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }

    const data = request.data as JoinArenaRequest | undefined;
    const inviteRaw = data?.invite_code;
    const arenaIdRaw = data?.arena_id;

    const hasInvite =
      typeof inviteRaw === "string" && inviteRaw.trim().length > 0;
    const hasArenaId =
      typeof arenaIdRaw === "string" && arenaIdRaw.trim().length > 0;

    if (hasInvite === hasArenaId) {
      throw new HttpsError(
        "invalid-argument",
        "provide_invite_code_xor_arena_id",
      );
    }

    const db = getFirestore();
    const usersRef = db.collection("users").doc(uid);
    const userSnap = await usersRef.get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "banned");
    }

    let arenaRef: DocumentReference;

    if (hasArenaId) {
      if (typeof arenaIdRaw !== "string") {
        throw new HttpsError("invalid-argument", "invalid_arena_id");
      }
      arenaRef = db.collection("arenas").doc(arenaIdRaw.trim());
    } else {
      if (typeof inviteRaw !== "string") {
        throw new HttpsError("invalid-argument", "invalid_invite_code");
      }
      const normalized = inviteRaw.trim().toUpperCase();
      const q = await db
        .collection("arenas")
        .where("invite_code", "==", normalized)
        .limit(1)
        .get();
      if (q.empty) {
        throw new HttpsError("not-found", "arena_not_found");
      }
      arenaRef = q.docs[0].ref;
    }

    const nowMs = Date.now();

    let result!: {
      arena_id: string;
      status: ArenaStatus;
      participant_count: number;
    };

    await db.runTransaction(async (tx) => {
      const arenaSnap = await tx.get(arenaRef);
      if (!arenaSnap.exists) {
        throw new HttpsError("not-found", "arena_not_found");
      }

      const arenaData = arenaSnap.data()!;
      const st = arenaData.status as string | undefined;
      if (st === "ended" || st === "expired") {
        throw new HttpsError("failed-precondition", "arena_closed");
      }

      const scheduledRaw = arenaData.scheduled_start_at;
      if (!(scheduledRaw instanceof Timestamp)) {
        throw new HttpsError("failed-precondition", "arena_invalid_schedule");
      }
      const scheduledMs = scheduledRaw.toMillis();
      if (nowMs - scheduledMs > LATE_JOIN_GRACE_MS) {
        throw new HttpsError("failed-precondition", "arena_join_too_late");
      }

      const arenaIdStr =
        typeof arenaData.arena_id === "string" ?
          arenaData.arena_id :
          arenaRef.id;

      const participantRef = db
        .collection("arena_participants")
        .doc(arenaIdStr)
        .collection("users")
        .doc(uid);

      const partSnap = await tx.get(participantRef);
      if (partSnap.exists) {
        const pcRaw = arenaData.participant_count;
        const pc =
          typeof pcRaw === "number" && Number.isFinite(pcRaw) ?
            pcRaw :
            0;
        result = {
          arena_id: arenaIdStr,
          status: st as ArenaStatus,
          participant_count: pc,
        };
        return;
      }

      tx.set(participantRef, {
        arena_id: arenaIdStr,
        uid,
        joined_at: FieldValue.serverTimestamp(),
        is_creator: false,
        status: "joined",
      });

      tx.update(arenaRef, {
        participant_count: FieldValue.increment(1),
        updated_at: FieldValue.serverTimestamp(),
      });

      const prevPcRaw = arenaData.participant_count;
      const prevPc =
        typeof prevPcRaw === "number" && Number.isFinite(prevPcRaw) ?
          prevPcRaw :
          0;

      result = {
        arena_id: arenaIdStr,
        status: st as ArenaStatus,
        participant_count: prevPc + 1,
      };
    });

    return result;
  },
);
