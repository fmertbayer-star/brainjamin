import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {readDuelQuestionIds, writePlayer2SeenBestEffort} from "../shared/duelQuestions";
import {resolveUsername} from "../shared/userIdentity";
type JoinDuelRequest = {
  duelId?: string;
  inviteCode?: string;
};
const ACTIVE_STATUSES = ["waiting", "matched", "player1_done", "player2_done"] as const;
const MATCHABLE_INVITE_STATUSES = new Set(["waiting", "player1_done"]);
const MAX_ACTIVE_DUELS_PER_USER = 5;
export const joinDuel = onCall<JoinDuelRequest>(
  {
    cors: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const duelId = request.data?.duelId?.trim();
    const inviteCodeRaw = request.data?.inviteCode?.trim();
    const inviteCode = inviteCodeRaw ? inviteCodeRaw.toUpperCase() : undefined;
    const via = duelId ? "duelId" : "inviteCode";
    if (!duelId && !inviteCode) {
      throw new HttpsError(
        "invalid-argument",
        "Either duelId or inviteCode must be provided."
      );
    }
    const db = getFirestore();
    const [activeAsPlayer1Snap, activeAsPlayer2Snap] = await Promise.all([
      db
        .collection("duels")
        .where("player1_id", "==", uid)
        .where("status", "in", ACTIVE_STATUSES)
        .get(),
      db
        .collection("duels")
        .where("player2_id", "==", uid)
        .where("status", "in", ACTIVE_STATUSES)
        .get(),
    ]);
    const activeDuelsById = new Set<string>();
    for (const doc of activeAsPlayer1Snap.docs) {
      activeDuelsById.add(doc.id);
    }
    for (const doc of activeAsPlayer2Snap.docs) {
      activeDuelsById.add(doc.id);
    }
    if (activeDuelsById.size >= MAX_ACTIVE_DUELS_PER_USER) {
      logger.warn("joinDuel cap exceeded", {uid, activeCount: activeDuelsById.size});
      throw new HttpsError(
        "resource-exhausted",
        "You have too many active duels. Finish or wait for some to expire."
      );
    }
    let targetRef;
    let targetSnap;
    if (duelId) {
      targetRef = db.collection("duels").doc(duelId);
      targetSnap = await targetRef.get();
      if (!targetSnap.exists) {
        logger.info("joinDuel duelId not found", {uid, duelId});
        throw new HttpsError("not-found", "Duel not found.");
      }
    } else {
      const inviteCodeForQuery = inviteCode as string;
      const inviteSnap = await db
        .collection("duels")
        .where("invite_code", "==", inviteCodeForQuery)
        .where("type", "==", "invite")
        .where("status", "in", ["waiting", "player1_done"])
        .where("player2_id", "==", null)
        .limit(1)
        .get();
      if (inviteSnap.empty) {
        logger.info("joinDuel invite not found", {uid, inviteCode});
        throw new HttpsError("not-found", "Invite code not found or already used.");
      }
      targetSnap = inviteSnap.docs[0];
      targetRef = targetSnap.ref;
    }
    const duelType = targetSnap.get("type");
    if (duelType !== "invite") {
      logger.info("joinDuel wrong duel type", {
        uid,
        duelId: targetSnap.id,
        type: duelType,
      });
      throw new HttpsError("failed-precondition", "This duel cannot be joined by invite.");
    }
    const player1Id = targetSnap.get("player1_id");
    if (player1Id === uid) {
      logger.info("joinDuel self match prevented", {uid, duelId: targetSnap.id});
      throw new HttpsError("failed-precondition", "You cannot join your own duel.");
    }
    const status = targetSnap.get("status");
    if (!MATCHABLE_INVITE_STATUSES.has(status)) {
      logger.info("joinDuel not accepting players", {uid, duelId: targetSnap.id, status});
      throw new HttpsError("failed-precondition", "This duel is no longer accepting players.");
    }
    const player2Vacant = targetSnap.get("player2_id");
    if (
      player2Vacant !== null &&
      player2Vacant !== undefined &&
      !(typeof player2Vacant === "string" && player2Vacant.length === 0)
    ) {
      logger.info("joinDuel already has player2", {uid, duelId: targetSnap.id});
      throw new HttpsError("failed-precondition", "This duel is no longer accepting players.");
    }
    const expiresAt = targetSnap.get("expires_at");
    if (expiresAt instanceof Timestamp && expiresAt.toMillis() < Date.now()) {
      logger.info("joinDuel invite expired", {uid, duelId: targetSnap.id});
      throw new HttpsError("deadline-exceeded", "This invite has expired.");
    }
    const player2Username = await resolveUsername(uid);
    const matchResult = await db.runTransaction(async (tx) => {
      const txSnap = await tx.get(targetRef);
      if (!txSnap.exists) {
        throw new HttpsError("not-found", "Duel not found.");
      }
      const txStatus = txSnap.get("status");
      if (!MATCHABLE_INVITE_STATUSES.has(txStatus)) {
        logger.info("joinDuel race lost", {uid, duelId: targetRef.id, status: txStatus});
        throw new HttpsError(
          "failed-precondition",
          "This duel is no longer accepting players."
        );
      }
      const p2Vacant = txSnap.get("player2_id");
      if (
        p2Vacant !== null &&
        p2Vacant !== undefined &&
        !(typeof p2Vacant === "string" && p2Vacant.length === 0)
      ) {
        logger.info("joinDuel race lost player2 occupied", {uid, duelId: targetRef.id});
        throw new HttpsError(
          "failed-precondition",
          "This duel is no longer accepting players."
        );
      }
      const txExpires = txSnap.get("expires_at");
      if (
        txExpires instanceof Timestamp &&
        txExpires.toMillis() < Date.now()
      ) {
        throw new HttpsError("deadline-exceeded", "This invite has expired.");
      }
      const txPlayer1Id = txSnap.get("player1_id");
      if (txPlayer1Id === uid) {
        throw new HttpsError("failed-precondition", "You cannot join your own duel.");
      }
      const attachPatch: Record<string, unknown> = {
        player2_id: uid,
        player2_username: player2Username,
        matched_at: FieldValue.serverTimestamp(),
      };
      if (txStatus === "waiting") {
        attachPatch.status = "matched";
      }
      tx.update(targetRef, attachPatch);
      const player1UsernameRaw = txSnap.get("player1_username");
      return {
        duelId: targetRef.id,
        opponentId: typeof txPlayer1Id === "string" ? txPlayer1Id : "",
        opponentUsername: typeof player1UsernameRaw === "string" ?
          player1UsernameRaw :
          "Anonymous Player",
      };
    });
    logger.info("joinDuel matched", {
      uid,
      duelId: matchResult.duelId,
      opponentId: matchResult.opponentId,
      via,
    });
    try {
      const questionIds = await readDuelQuestionIds(db, matchResult.duelId);
      await writePlayer2SeenBestEffort(db, uid, questionIds, "joinDuel_invite");
    } catch (error) {
      logger.warn("joinDuel player2 seen sync failed outer", {
        uid,
        duelId: matchResult.duelId,
        error: String(error),
      });
    }
    return matchResult;
  }
);

