/**
 * createArena — HTTPS callable. Creates arenas/{arenaId} + creator participant row.
 */

import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";

import {
  ARENA_MAX_PER_DAY,
  assertCategoryOrTopic,
  assertWindow,
  isArenaMode,
  isArenaSourceType,
  utcDateKeyYyyyMmDd,
} from "./shared";
import {generateInviteCode} from "../shared/inviteCode";

type CreateArenaRequest = {
  mode?: unknown;
  name?: unknown;
  sourceType?: unknown;
  categoryId?: unknown;
  customTopic?: unknown;
  scheduledStartAt?: unknown;
};

function normalizeOptionalName(raw: unknown): string | null {
  if (raw === undefined || raw === null) {
    return null;
  }
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "invalid_name");
  }
  const t = raw.trim();
  if (t.length === 0) {
    return null;
  }
  if (t.length > 60) {
    throw new HttpsError("invalid-argument", "invalid_name_length");
  }
  return t;
}

export const createArena = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }

    const data = request.data as CreateArenaRequest | undefined;
    const modeRaw = data?.mode;
    const sourceTypeRaw = data?.sourceType;
    const scheduledRaw = data?.scheduledStartAt;

    if (!isArenaMode(modeRaw)) {
      throw new HttpsError("invalid-argument", "invalid_mode");
    }
    if (!isArenaSourceType(sourceTypeRaw)) {
      throw new HttpsError("invalid-argument", "invalid_source_type");
    }
    if (typeof scheduledRaw !== "number" || !Number.isFinite(scheduledRaw)) {
      throw new HttpsError("invalid-argument", "invalid_scheduled_start");
    }
    const scheduledStartMs = Math.round(scheduledRaw);

    const nowMs = Date.now();
    assertWindow(scheduledStartMs, nowMs);

    const {categoryId, customTopic} = assertCategoryOrTopic(
      sourceTypeRaw,
      data?.categoryId,
      data?.customTopic,
    );

    const name = normalizeOptionalName(data?.name);

    const db = getFirestore();
    const usersRef = db.collection("users").doc(uid);

    const userPre = await usersRef.get();
    if (userPre.exists && userPre.get("banned") === true) {
      throw new HttpsError("permission-denied", "banned");
    }

    const dateKey = utcDateKeyYyyyMmDd(nowMs);

    const arenaRef = db.collection("arenas").doc();
    const arenaId = arenaRef.id;

    let inviteCode = "";
    for (let attempt = 0; attempt < 5; attempt++) {
      inviteCode = generateInviteCode();
      const collision = await db
        .collection("arenas")
        .where("invite_code", "==", inviteCode)
        .limit(1)
        .get();
      if (collision.empty) {
        break;
      }
      if (attempt === 4) {
        logger.error("createArena invite code collision exhausted", {uid});
        throw new HttpsError("internal", "invite_code_generation_failed");
      }
    }

    try {
      await db.runTransaction(async (tx) => {
        const userSnap = await tx.get(usersRef);
        if (userSnap.exists && userSnap.get("banned") === true) {
          throw new HttpsError("permission-denied", "banned");
        }

        const dailyRaw = userSnap.get(`dailyArenaCount.${dateKey}`);
        const dailyCount =
          typeof dailyRaw === "number" && Number.isFinite(dailyRaw) ?
            dailyRaw :
            0;
        if (dailyCount >= ARENA_MAX_PER_DAY) {
          throw new HttpsError("resource-exhausted", "arena_daily_cap");
        }

        tx.set(arenaRef, {
          arena_id: arenaId,
          creator_id: uid,
          mode: modeRaw,
          name,
          source_type: sourceTypeRaw,
          category_id: categoryId,
          custom_topic: customTopic,
          invite_code: inviteCode,
          scheduled_start_at: Timestamp.fromMillis(scheduledStartMs),
          status: "preparing",
          participant_count: 1,
          created_at: FieldValue.serverTimestamp(),
          updated_at: FieldValue.serverTimestamp(),
        });

        const participantRef = db
          .collection("arena_participants")
          .doc(arenaId)
          .collection("users")
          .doc(uid);

        tx.set(participantRef, {
          arena_id: arenaId,
          uid,
          joined_at: FieldValue.serverTimestamp(),
          is_creator: true,
          status: "joined",
        });

        tx.set(
          usersRef,
          {
            dailyArenaCount: {
              [dateKey]: FieldValue.increment(1),
            },
          },
          {merge: true},
        );
      });
    } catch (err) {
      if (err instanceof HttpsError) {
        throw err;
      }
      logger.error("createArena transaction failed", {uid, error: String(err)});
      throw new HttpsError("internal", "create_arena_failed");
    }

    logger.info("createArena ok", {uid, arenaId, inviteCode});

    return {
      arena_id: arenaId,
      invite_code: inviteCode,
    };
  },
);
