/**
 * Creates `live_tournaments/{ltId}` stubs at T-24h. Independent of Classic:
 * does not read `tournaments/`, `category_rotation`, LLM, or `questions_public`.
 *
 * Uses `nextClassicSlotStartFromNow(..., 24)` so Live shares the same **slot
 * clock** as Classic (next 07:00 or 23:00 UTC start); only lifecycle/doc
 * creation is decoupled from Classic generation.
 */

import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import type {ClassicSlotKey} from "../shared/tournamentSlot";
import {liveSlotIdFromStartUtc, nextClassicSlotStartFromNow} from "../shared/tournamentSlot";

function slotKeyFromStartUtc(startUtc: Date): ClassicSlotKey {
  const h = startUtc.getUTCHours();
  if (h === 7) {
    return "07utc";
  }
  if (h === 23) {
    return "23utc";
  }
  throw new Error(`prepareLiveTournament: expected 07 or 23 UTC hour, got ${h}`);
}

export const prepareLiveTournament = onSchedule(
  {
    schedule: "0 7,23 * * *",
    timeZone: "Etc/UTC",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const {startUtc} = nextClassicSlotStartFromNow(new Date(), 24);
    const ltId = liveSlotIdFromStartUtc(startUtc);
    const slotKey = slotKeyFromStartUtc(startUtc);

    const liveRef = db.collection("live_tournaments").doc(ltId);
    const existing = await liveRef.get();
    if (existing.exists) {
      logger.info(
        `prepareLiveTournament: live_tournaments/${ltId} already exists, skip`,
      );
      return;
    }

    await liveRef.set({
      slot_id: ltId,
      slot_key: slotKey,
      mode: "live",
      status: "scheduled",
      starts_at: Timestamp.fromDate(startUtc),
      q_ids: [],
      current_question: null,
      reveal_active: false,
      late_join_closed: false,
      last_heartbeat_at: null,
      total_participants: 0,
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });
    logger.info(`prepareLiveTournament: created live_tournaments/${ltId}`);
  },
);
