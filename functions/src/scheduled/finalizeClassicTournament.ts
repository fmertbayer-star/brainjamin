/**
 * Scheduled finalize when a Classic tournament window closes (slot end instant).
 */

import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentReference,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {classicXpForRank} from "../shared/classicScoring";
import {nextClassicSlotStartFromNow} from "../shared/tournamentSlot";

const XP_BATCH_MAX_OPS = 400;

export const finalizeClassicTournament = onSchedule(
  {
    schedule: "0 7,23 * * *",
    timeZone: "UTC",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    const db = getFirestore();
    const {slotId} = nextClassicSlotStartFromNow(new Date(), -24);
    const ref = db.collection("tournaments").doc(slotId);
    const snap = await ref.get();

    if (!snap.exists) {
      logger.warn(
        `finalizeClassicTournament: slot ${slotId} not found; skipping`,
      );
      return;
    }

    const st = snap.data()?.status;
    if (st !== "visible") {
      logger.warn(
        `finalizeClassicTournament: finalize called on slot ${slotId} with status ${String(st)}; skipping`,
      );
      return;
    }

    const sessionsSnap = await db
      .collection("tournament_sessions")
      .where("slot_id", "==", slotId)
      .where("status", "==", "submitted")
      .orderBy("correct_count", "desc")
      .orderBy("submitted_at", "asc")
      .get();

    if (sessionsSnap.empty) {
      await ref.update({
        status: "ended",
        ended_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
        total_participants: 0,
      });
      logger.info(`finalize ${slotId}: 0 participants, marked ended`);
      return;
    }

    type Row = {
      ref: DocumentReference;
      uid: string;
      correctCount: number;
      submittedAt: Timestamp;
    };

    const rows: Row[] = sessionsSnap.docs.map((doc) => {
      const d = doc.data();
      const uid = d.uid as string;
      const submittedAt = d.submitted_at as Timestamp;
      const cc = d.correct_count;
      const correctCount = typeof cc === "number" ? cc : 0;
      return {
        ref: doc.ref,
        uid,
        correctCount,
        submittedAt,
      };
    });

    const totalParticipants = rows.length;

    const top100Slice = rows.slice(0, 100);
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

    const top100 = top100Slice.map((r, idx) => ({
      rank: idx + 1,
      uid: r.uid,
      display_name: displayByUid.get(r.uid) ?? "Anonymous Player",
      correct_count: r.correctCount,
      submitted_at: r.submittedAt,
    }));

    const lbRef = db.collection("tournament_leaderboards").doc(slotId);
    await lbRef.set({
      slot_id: slotId,
      ended_at: FieldValue.serverTimestamp(),
      total_participants: totalParticipants,
      top_100: top100,
      created_at: FieldValue.serverTimestamp(),
    });

    let batch = db.batch();
    let batchOps = 0;

    const commitBatch = async () => {
      if (batchOps > 0) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      }
    };

    for (let i = 0; i < rows.length; i++) {
      const rank = i + 1;
      const row = rows[i]!;
      const sd = sessionsSnap.docs[i]!.data();
      if (sd?.xp_granted_at != null) {
        continue;
      }
      const xp = classicXpForRank(rank);
      const userRef = db.collection("users").doc(row.uid);
      batch.set(
        userRef,
        {xp: FieldValue.increment(xp)},
        {merge: true},
      );
      batchOps++;
      batch.update(row.ref, {
        rank,
        xp_awarded: xp,
        xp_granted_at: FieldValue.serverTimestamp(),
      });
      batchOps++;
      if (batchOps >= XP_BATCH_MAX_OPS) {
        await commitBatch();
      }
    }
    await commitBatch();

    await ref.update({
      status: "ended",
      ended_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
      total_participants: totalParticipants,
    });

    logger.info(
      `finalize ${slotId}: ${totalParticipants} participants, leaderboard + XP committed`,
    );
  },
);
