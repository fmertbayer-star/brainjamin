import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";

type FastForwardLiveStartRequest = {
  ltId?: string;
  minutesFromNow?: unknown;
};

type FastForwardLiveStartResponse = {
  success: true;
  ltId: string;
  newStartsAtMs: number;
  previousStartsAtMs: number | null;
};

const BLOCKED_STATUSES = new Set([
  "running",
  "ended",
  "no_participants",
  "no_pool_questions",
  "generation_failed",
]);

function isCallableAdmin(
  token: Record<string, unknown> | undefined,
  userDocIsAdmin: boolean,
): boolean {
  if (token?.admin === true || token?.isAdmin === true) {
    return true;
  }
  return userDocIsAdmin;
}

export const fastForwardLiveStart = onCall<
  FastForwardLiveStartRequest,
  Promise<FastForwardLiveStartResponse>
>(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    const userDocIsAdmin =
      userSnap.exists && userSnap.get("isAdmin") === true;
    const token = request.auth?.token as Record<string, unknown> | undefined;
    if (!isCallableAdmin(token, userDocIsAdmin)) {
      throw new HttpsError("permission-denied", "Admin only.");
    }

    const ltIdRaw = request.data?.ltId;
    const ltId =
      typeof ltIdRaw === "string" ? ltIdRaw.trim() : "";
    if (!ltId || !ltId.startsWith("live_")) {
      throw new HttpsError(
        "invalid-argument",
        "ltId must be a non-empty string starting with \"live_\".",
      );
    }

    const rawMinutes = request.data?.minutesFromNow;
    if (typeof rawMinutes !== "number" || !Number.isFinite(rawMinutes)) {
      throw new HttpsError(
        "invalid-argument",
        "minutesFromNow must be a finite number.",
      );
    }
    if (!Number.isInteger(rawMinutes)) {
      throw new HttpsError(
        "invalid-argument",
        "minutesFromNow must be an integer.",
      );
    }
    const minutesFromNow = Math.min(60, Math.max(1, rawMinutes));

    const liveRef = db.collection("live_tournaments").doc(ltId);
    const liveSnap = await liveRef.get();
    if (!liveSnap.exists) {
      throw new HttpsError("not-found", "live_tournament_not_found");
    }

    const live = liveSnap.data()!;
    const st = live.status;
    if (typeof st === "string" && BLOCKED_STATUSES.has(st)) {
      throw new HttpsError(
        "failed-precondition",
        `live_tournament_not_scheduled:status=${st}`,
      );
    }

    const prevRaw = live.starts_at;
    let previousStartsAtMs: number | null = null;
    if (prevRaw instanceof Timestamp) {
      previousStartsAtMs = prevRaw.toMillis();
    }

    const newMs = Date.now() + minutesFromNow * 60_000;
    const newStartsAt = Timestamp.fromMillis(newMs);

    await liveRef.update({
      starts_at: newStartsAt,
      updated_at: FieldValue.serverTimestamp(),
    });

    logger.info(
      `[fastForwardLiveStart] uid=${uid} ltId=${ltId} ` +
      `previous=${previousStartsAtMs ?? "null"} new=${newMs}`,
    );

    return {
      success: true,
      ltId,
      newStartsAtMs: newMs,
      previousStartsAtMs,
    };
  },
);
