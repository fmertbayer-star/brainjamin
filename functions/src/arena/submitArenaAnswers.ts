/**
 * submitArenaAnswers — HTTPS callable. Scores participant; may finalize arena.
 */

import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";

import {ARENA_QUESTION_COUNT} from "./shared";
import {finalizeArena} from "./finalizeArena";

const QUESTION_TIME_MS = 15 * 1000;
const SCORE_DENOM = ARENA_QUESTION_COUNT * QUESTION_TIME_MS;

type AnswerIn = {
  q_index?: unknown;
  selected_option?: unknown;
  time_ms?: unknown;
};

function asTimestamp(v: unknown): Timestamp | null {
  if (v instanceof Timestamp) {
    return v;
  }
  return null;
}

export const submitArenaAnswers = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }

    const data = request.data as {arena_id?: unknown; answers?: unknown} | undefined;
    const arenaIdRaw = data?.arena_id;
    if (typeof arenaIdRaw !== "string" || arenaIdRaw.trim().length === 0) {
      throw new HttpsError("invalid-argument", "invalid_arena_id");
    }
    const arenaId = arenaIdRaw.trim();

    const answersRaw = data?.answers;
    if (!Array.isArray(answersRaw) || answersRaw.length !== ARENA_QUESTION_COUNT) {
      throw new HttpsError(
        "invalid-argument",
        `answers must be an array of length ${ARENA_QUESTION_COUNT}.`,
      );
    }

    const db = getFirestore();
    const usersRef = db.collection("users").doc(uid);
    const userSnap = await usersRef.get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "banned");
    }

    const arenaRef = db.collection("arenas").doc(arenaId);
    const participantRef = db
      .collection("arena_participants")
      .doc(arenaId)
      .collection("users")
      .doc(uid);

    const partPre = await participantRef.get();
    if (!partPre.exists) {
      throw new HttpsError("permission-denied", "not_a_participant");
    }

    const submittedPre = asTimestamp(partPre.get("submitted_at"));
    if (submittedPre != null) {
      const arenaSnap = await arenaRef.get();
      const status = arenaSnap.get("status");
      const finalized = status === "ended";
      return {
        arena_id: arenaId,
        correct_count: partPre.get("correct_count") ?? 0,
        total_remaining_ms: partPre.get("total_remaining_ms") ?? 0,
        score: partPre.get("score") ?? 0,
        finalized,
        xp_awarded:
          typeof partPre.get("xp_awarded") === "number" ?
            partPre.get("xp_awarded") :
            undefined,
      };
    }

    const arenaSnap = await arenaRef.get();
    if (!arenaSnap.exists) {
      throw new HttpsError("not-found", "arena_not_found");
    }

    const statusPre = arenaSnap.get("status") as string | undefined;
    if (statusPre === "preparing") {
      throw new HttpsError("failed-precondition", "arena_status_invalid");
    }
    if (statusPre === "expired") {
      throw new HttpsError("failed-precondition", "arena_status_invalid");
    }
    if (statusPre === "ended") {
      throw new HttpsError("failed-precondition", "arena_status_invalid");
    }

    const scheduledStart = arenaSnap.get("scheduled_start_at");
    if (!(scheduledStart instanceof Timestamp)) {
      throw new HttpsError("failed-precondition", "arena_invalid_schedule");
    }

    const now = Timestamp.now();
    if (statusPre === "scheduled" && scheduledStart.toMillis() > now.toMillis()) {
      throw new HttpsError("failed-precondition", "arena_not_started");
    }

    const seen = new Set<number>();
    const normalized: Array<{
      qIndex: number;
      selectedOption: number;
      timeMs: number;
    }> = [];

    for (let i = 0; i < answersRaw.length; i++) {
      const a = answersRaw[i] as AnswerIn;
      const qi = a?.q_index;
      const so = a?.selected_option;
      const tm = a?.time_ms;
      if (
        !Number.isInteger(qi) ||
        typeof qi !== "number" ||
        !Number.isInteger(so) ||
        typeof so !== "number" ||
        !Number.isInteger(tm) ||
        typeof tm !== "number"
      ) {
        throw new HttpsError("invalid-argument", `answers[${i}] malformed`);
      }
      if (qi < 0 || qi >= ARENA_QUESTION_COUNT) {
        throw new HttpsError("invalid-argument", "answers_q_index_range");
      }
      if (so < -1 || so > 3) {
        throw new HttpsError("invalid-argument", "answers_selected_option_range");
      }
      if (tm < 0) {
        throw new HttpsError("invalid-argument", "answers_time_ms_negative");
      }
      if (seen.has(qi)) {
        throw new HttpsError("invalid-argument", "answers_duplicate_q_index");
      }
      seen.add(qi);
      normalized.push({
        qIndex: qi,
        selectedOption: so,
        timeMs: Math.min(tm, QUESTION_TIME_MS),
      });
    }

    for (let i = 0; i < ARENA_QUESTION_COUNT; i++) {
      if (!seen.has(i)) {
        throw new HttpsError("invalid-argument", "answers_missing_q_index");
      }
    }

    normalized.sort((x, y) => x.qIndex - y.qIndex);

    const qCol = db
      .collection("arena_questions")
      .doc(arenaId)
      .collection("q");
    const qSnap = await qCol.get();
    const correctByIndex = new Map<number, number>();
    for (const doc of qSnap.docs) {
      const idx = Number.parseInt(doc.id, 10);
      const ci = doc.get("correct_index");
      if (
        Number.isInteger(idx) &&
        idx >= 0 &&
        idx < ARENA_QUESTION_COUNT &&
        typeof ci === "number" &&
        Number.isInteger(ci) &&
        ci >= 0 &&
        ci <= 3
      ) {
        correctByIndex.set(idx, ci);
      }
    }

    for (let i = 0; i < ARENA_QUESTION_COUNT; i++) {
      if (!correctByIndex.has(i)) {
        throw new HttpsError("failed-precondition", "arena_questions_not_ready");
      }
    }

    let correctCount = 0;
    let totalRemainingMs = 0;

    for (const ans of normalized) {
      const correctIdx = correctByIndex.get(ans.qIndex) as number;
      const remainingMs = Math.max(0, QUESTION_TIME_MS - ans.timeMs);
      totalRemainingMs += remainingMs;
      if (ans.selectedOption >= 0 && ans.selectedOption === correctIdx) {
        correctCount++;
      }
    }

    const score =
      correctCount + totalRemainingMs / SCORE_DENOM;

    await db.runTransaction(async (tx) => {
      const aSnap = await tx.get(arenaRef);
      const pSnap = await tx.get(participantRef);
      if (!aSnap.exists || !pSnap.exists) {
        throw new HttpsError("not-found", "arena_not_found");
      }

      if (asTimestamp(pSnap.get("submitted_at")) != null) {
        return;
      }

      const st = aSnap.get("status") as string | undefined;
      if (st === "preparing" || st === "expired" || st === "ended") {
        throw new HttpsError("failed-precondition", "arena_status_invalid");
      }

      const sched = aSnap.get("scheduled_start_at");
      if (!(sched instanceof Timestamp)) {
        throw new HttpsError("failed-precondition", "arena_invalid_schedule");
      }

      const nowTs = Timestamp.now();
      const updates: Record<string, unknown> = {};

      if (st === "scheduled") {
        if (sched.toMillis() > nowTs.toMillis()) {
          throw new HttpsError("failed-precondition", "arena_not_started");
        }
        updates.status = "active";
        updates.updated_at = FieldValue.serverTimestamp();
      } else if (st !== "active") {
        throw new HttpsError("failed-precondition", "arena_status_invalid");
      }

      tx.update(participantRef, {
        correct_count: correctCount,
        total_remaining_ms: totalRemainingMs,
        score,
        submitted_at: FieldValue.serverTimestamp(),
        status: "submitted",
      });

      if (Object.keys(updates).length > 0) {
        tx.update(arenaRef, updates);
      }
    });

    const allSnap = await db
      .collection("arena_participants")
      .doc(arenaId)
      .collection("users")
      .get();

    let allSubmitted = true;
    for (const d of allSnap.docs) {
      if (asTimestamp(d.get("submitted_at")) == null) {
        allSubmitted = false;
        break;
      }
    }

    let finalized = false;
    let xpAwarded: number | undefined;

    if (allSubmitted) {
      await finalizeArena(arenaId);
      finalized = true;
    }

    const postPart = await participantRef.get();
    const postArena = await arenaRef.get();
    finalized = postArena.get("status") === "ended";

    const xpRaw = postPart.get("xp_awarded");
    if (typeof xpRaw === "number") {
      xpAwarded = xpRaw;
    }

    logger.info("submitArenaAnswers ok", {
      uid,
      arenaId,
      correctCount,
      finalized,
    });

    return {
      arena_id: arenaId,
      correct_count: correctCount,
      total_remaining_ms: totalRemainingMs,
      score,
      finalized,
      xp_awarded: xpAwarded,
    };
  },
);
