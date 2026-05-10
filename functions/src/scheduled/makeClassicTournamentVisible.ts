/**
 * Scheduled visibility flip for Classic tournaments (T-12h before slot start).
 */

import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {nextClassicSlotStartFromNow} from "../shared/tournamentSlot";

export const makeClassicTournamentVisible = onSchedule(
  {
    schedule: "0 11,19 * * *",
    timeZone: "UTC",
  },
  async () => {
    const db = getFirestore();
    const {slotId} = nextClassicSlotStartFromNow(new Date(), 12);
    const ref = db.collection("tournaments").doc(slotId);
    const snap = await ref.get();

    if (!snap.exists) {
      logger.warn(
        "makeClassicTournamentVisible: slot " +
          `${slotId} not found at T-12h visibility tick; ` +
          "possibly generation_failed earlier",
      );
      return;
    }

    const data = snap.data()!;
    const st = data.status;

    if (st === "ready") {
      await ref.update({
        status: "visible",
        visible_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      });
      logger.info(`makeClassicTournamentVisible: slot ${slotId} now visible`);
      return;
    }

    if (st === "generation_failed") {
      logger.warn(
        `makeClassicTournamentVisible: slot ${slotId} generation_failed, skipping`,
      );
      return;
    }

    if (st === "generating") {
      logger.error(
        `makeClassicTournamentVisible: slot ${slotId} not ready by T-12h, leaving as-is`,
      );
      return;
    }

    if (st === "visible" || st === "ended") {
      logger.info(
        `makeClassicTournamentVisible: slot ${slotId} already visible/ended (${st}), skipping`,
      );
      return;
    }

    logger.warn(
      `makeClassicTournamentVisible: slot ${slotId} unexpected status ${String(st)}, skipping`,
    );
  },
);
