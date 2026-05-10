/**
 * Scheduled generation for Classic tournament question sets (T-24h).
 */

import {
  FieldValue,
  getFirestore,
  Timestamp,
  type Firestore,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

import type {Category} from "../shared/categories";
import {isCategory} from "../shared/categories";
import {difficultyForSlotIndex} from "../shared/difficultyDistribution";
import {generateOneQuestion} from "../shared/pipeline";
import {AI_SECRETS} from "../shared/secrets";
import type {ClassicSlotKey} from "../shared/tournamentSlot";
import {nextClassicSlotStartFromNow} from "../shared/tournamentSlot";

function slotKeyFromStartUtc(startUtc: Date): ClassicSlotKey {
  const h = startUtc.getUTCHours();
  if (h === 7) {
    return "07utc";
  }
  if (h === 23) {
    return "23utc";
  }
  throw new Error(`slotKeyFromStartUtc: expected 07 or 23 UTC hour, got ${h}`);
}

function summarizeAttempts(attempts: unknown): string {
  const s = JSON.stringify(attempts);
  return s.length > 12000 ? `${s.slice(0, 12000)}…` : s;
}

async function advanceCategoryRotation(db: Firestore): Promise<void> {
  const rotRef = db.collection("category_rotation").doc("state");
  await db.runTransaction(async (tx) => {
    const rotSnap = await tx.get(rotRef);
    if (!rotSnap.exists) {
      throw new Error("category_rotation/state missing during rotation advance");
    }
    const r = rotSnap.data()!;
    const idx =
      typeof r.currentIndex === "number" ? ((r.currentIndex % 20) + 20) % 20 : 0;
    const nextIdx = (idx + 1) % 20;
    tx.update(rotRef, {
      currentIndex: nextIdx,
      lastRotatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

export const generateClassicTournamentContent = onSchedule(
  {
    schedule: "0 7,23 * * *",
    timeZone: "UTC",
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: AI_SECRETS,
  },
  async () => {
    const db = getFirestore();
    const {slotId, startUtc} = nextClassicSlotStartFromNow(new Date(), 24);
    const ref = db.collection("tournaments").doc(slotId);
    const snap = await ref.get();

    const endsAt = Timestamp.fromMillis(
      startUtc.getTime() + 24 * 60 * 60 * 1000,
    );
    const slotKey = slotKeyFromStartUtc(startUtc);

    if (!snap.exists) {
      const rotRef = db.collection("category_rotation").doc("state");
      const rotSnap = await rotRef.get();
      if (!rotSnap.exists) {
        logger.error(
          "generateClassicTournamentContent: category_rotation/state missing",
        );
        return;
      }
      const rot = rotSnap.data()!;
      const categories = rot.categories as unknown;
      const ci =
        typeof rot.currentIndex === "number" ? rot.currentIndex % 20 : 0;
      if (!Array.isArray(categories) || categories.length < 20) {
        logger.error(
          "generateClassicTournamentContent: invalid categories on rotation state",
        );
        return;
      }
      const catRaw = categories[ci];
      if (typeof catRaw !== "string" || !isCategory(catRaw)) {
        logger.error(
          "generateClassicTournamentContent: invalid category at currentIndex",
          {currentIndex: ci},
        );
        return;
      }
      const categoryId = catRaw;

      await ref.set({
        slot_id: slotId,
        slot_key: slotKey,
        mode: "classic",
        status: "generating",
        category_id: categoryId,
        starts_at: Timestamp.fromDate(startUtc),
        ends_at: endsAt,
        q_ids: [],
        generated_count: 0,
        ready_at: null,
        visible_at: null,
        ended_at: null,
        failed_at: null,
        failure_reason: null,
        failed_at_index: null,
        created_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
      });
      logger.info(`generateClassicTournamentContent: created slot ${slotId}`);
    } else {
      const data = snap.data()!;
      const st = data.status;
      if (st === "ready" || st === "visible" || st === "ended") {
        logger.info(
          `generateClassicTournamentContent: slot ${slotId} ` +
            `already finalized in prior state ${st}, skipping`,
        );
        return;
      }
      if (st === "generation_failed") {
        logger.info(
          `generateClassicTournamentContent: slot ${slotId} ` +
            "already finalized in prior state generation_failed, skipping",
        );
        return;
      }
      if (st === "generating") {
        const gc = data.generated_count;
        const gcn = typeof gc === "number" ? gc : 0;
        if (gcn === 20) {
          logger.info(
            `generateClassicTournamentContent: slot ${slotId} already complete (idempotent skip)`,
          );
          return;
        }
        logger.info(
          `generateClassicTournamentContent: resuming slot ${slotId} from index ${gcn}`,
        );
      } else {
        logger.warn(
          `generateClassicTournamentContent: slot ${slotId} unexpected status ${String(st)}, skipping`,
        );
        return;
      }
    }

    const fresh = await ref.get();
    if (!fresh.exists) {
      logger.error(
        `generateClassicTournamentContent: slot ${slotId} missing after create`,
      );
      return;
    }

    const docData = fresh.data()!;
    const categoryRaw = docData.category_id;
    if (typeof categoryRaw !== "string" || !isCategory(categoryRaw)) {
      logger.error(
        "generateClassicTournamentContent: invalid category_id on " + slotId,
      );
      return;
    }
    const categoryId = categoryRaw as Category;

    const generatedCount =
      typeof docData.generated_count === "number" ? docData.generated_count : 0;

    for (let slotIndex = generatedCount; slotIndex < 20; slotIndex++) {
      const difficulty = difficultyForSlotIndex(slotIndex);
      const result = await generateOneQuestion(categoryId, difficulty);

      if (result.persisted) {
        await ref.update({
          q_ids: FieldValue.arrayUnion(result.persisted.id),
          generated_count: FieldValue.increment(1),
          updated_at: FieldValue.serverTimestamp(),
        });
        logger.info(
          `generateClassicTournamentContent: slot ${slotId} progress: ${slotIndex + 1}/20`,
        );
      } else {
        await ref.update({
          status: "generation_failed",
          failed_at: FieldValue.serverTimestamp(),
          failure_reason: "pipeline_persisted_null",
          failed_at_index: slotIndex,
          attempts_summary: summarizeAttempts(result.attempts),
          updated_at: FieldValue.serverTimestamp(),
        });
        logger.error(
          `generateClassicTournamentContent: slot ${slotId} aborted at index ` +
            `${slotIndex}: pipeline returned null after MAX_ATTEMPTS`,
          {attempts: result.attempts},
        );
        return;
      }
    }

    await ref.update({
      status: "ready",
      ready_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });

    try {
      await advanceCategoryRotation(db);
      logger.info(
        `generateClassicTournamentContent: slot ${slotId} ready, rotation advanced`,
      );
    } catch (e) {
      logger.error(
        "generateClassicTournamentContent: rotation advance failed after ready",
        e,
      );
    }
  },
);
