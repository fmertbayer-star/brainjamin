/**
 * Internal helper: rank participants, grant XP, write leaderboard, end arena.
 * Invoked from submitArenaAnswers when all participants have submitted.
 */

import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentReference,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions/v2";

import {ARENA_XP_BY_RANK} from "./shared";

type ParticipantRow = {
  ref: DocumentReference;
  uid: string;
  correctCount: number;
  totalRemainingMs: number;
  score: number;
  submittedAt: Timestamp;
};

function xpForRank(rank: number): number {
  if (rank === 1) {
    return ARENA_XP_BY_RANK.rank1;
  }
  if (rank === 2 || rank === 3) {
    return ARENA_XP_BY_RANK.rank2to3;
  }
  return ARENA_XP_BY_RANK.rankRest;
}

export async function finalizeArena(arenaId: string): Promise<void> {
  const db = getFirestore();
  const arenaRef = db.collection("arenas").doc(arenaId);

  const arenaPre = await arenaRef.get();
  if (arenaPre.exists && arenaPre.get("status") === "ended") {
    logger.info("finalizeArena noop already ended", {arenaId});
    return;
  }

  const usersCol = db.collection("arena_participants").doc(arenaId).collection("users");

  const snap = await usersCol.get();
  const rows: ParticipantRow[] = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    const uid = typeof d.uid === "string" ? d.uid : doc.id;
    const cc = d.correct_count;
    const tr = d.total_remaining_ms;
    const sc = d.score;
    const sub = d.submitted_at;
    if (
      typeof cc !== "number" ||
      typeof tr !== "number" ||
      typeof sc !== "number" ||
      !(sub instanceof Timestamp)
    ) {
      logger.warn("finalizeArena skip incomplete participant", {
        arenaId,
        uid,
      });
      continue;
    }
    rows.push({
      ref: doc.ref,
      uid,
      correctCount: cc,
      totalRemainingMs: tr,
      score: sc,
      submittedAt: sub,
    });
  }

  if (rows.length === 0) {
    logger.error("finalizeArena no scored participants", {arenaId});
    return;
  }

  rows.sort((a, b) => {
    if (b.correctCount !== a.correctCount) {
      return b.correctCount - a.correctCount;
    }
    return b.totalRemainingMs - a.totalRemainingMs;
  });

  const batch = db.batch();
  const top100: Array<Record<string, unknown>> = [];
  const displayCache = new Map<string, string>();

  async function displayNameFor(uid: string): Promise<string> {
    if (displayCache.has(uid)) {
      return displayCache.get(uid)!;
    }
    const pub = await db.collection("users_public").doc(uid).get();
    const dn = pub.get("displayName");
    const name =
      typeof dn === "string" && dn.trim().length > 0 ?
        dn.trim() :
        "Anonymous Player";
    displayCache.set(uid, name);
    return name;
  }

  for (let i = 0; i < rows.length; i++) {
    const rank = i + 1;
    const row = rows[i]!;
    const xp = xpForRank(rank);
    const name = await displayNameFor(row.uid);

    batch.update(row.ref, {
      rank,
      xp_awarded: xp,
      xp_granted_at: FieldValue.serverTimestamp(),
    });

    const userRef = db.collection("users").doc(row.uid);
    batch.set(
      userRef,
      {
        xp: FieldValue.increment(xp),
      },
      {merge: true},
    );

    top100.push({
      rank,
      uid: row.uid,
      display_name: name,
      correct_count: row.correctCount,
      total_remaining_ms: row.totalRemainingMs,
      score: row.score,
      submitted_at: row.submittedAt,
    });
  }

  const lbRef = db.collection("arena_leaderboards").doc(arenaId);
  batch.set(lbRef, {
    arena_id: arenaId,
    ended_at: FieldValue.serverTimestamp(),
    total_participants: rows.length,
    top_100: top100.slice(0, 100),
  });

  batch.update(arenaRef, {
    status: "ended",
    ended_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  });

  await batch.commit();
  logger.info("finalizeArena complete", {arenaId, n: rows.length});
}
