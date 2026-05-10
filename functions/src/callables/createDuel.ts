import {randomBytes} from "crypto";
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {isCategory} from "../shared/categories";
import {
  generateDuelQuestionSet,
  readDuelQuestionIds,
  writePlayer2SeenBestEffort,
} from "../shared/duelQuestions";
import {resolveUsername} from "../shared/userIdentity";
type CreateDuelRequest = {
  type?: string;
  category?: string;
};
const ACTIVE_STATUSES = ["waiting", "matched", "player1_done", "player2_done"] as const;
const INVITE_CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
const INVITE_CODE_LENGTH = 6;
const MAX_ACTIVE_DUELS_PER_USER = 5;
const DUEL_INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const DUEL_RANDOM_TTL_MS = 24 * 60 * 60 * 1000;
const SAME_OPPONENT_DEDUP_WINDOW_MS = 24 * 60 * 60 * 1000;
const RANDOM_MATCH_LOOKUP_LIMIT = 20;
function generateInviteCode(): string {
  const bytes = randomBytes(INVITE_CODE_LENGTH);
  let out = "";
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    out += INVITE_CODE_ALPHABET[bytes[i] % INVITE_CODE_ALPHABET.length];
  }
  return out;
}
function candidateCreatedMs(doc: QueryDocumentSnapshot): number {
  const created = doc.get("created_at");
  if (created instanceof Timestamp) {
    return created.toMillis();
  }
  return 0;
}
function mergeRandomMatchCandidates(
  waitingDocs: QueryDocumentSnapshot[],
  player1DoneOpenDocs: QueryDocumentSnapshot[],
): QueryDocumentSnapshot[] {
  const merged = [...waitingDocs, ...player1DoneOpenDocs];
  merged.sort((a, b) => candidateCreatedMs(a) - candidateCreatedMs(b));
  return merged;
}
export const createDuel = onCall<CreateDuelRequest>(
  {
    cors: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    const type = request.data?.type;
    if (type !== "random" && type !== "invite") {
      throw new HttpsError(
        "invalid-argument",
        "type must be 'random' or 'invite'."
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
    const activeDuelsById = new Map<string, true>();
    for (const doc of activeAsPlayer1Snap.docs) {
      activeDuelsById.set(doc.id, true);
    }
    for (const doc of activeAsPlayer2Snap.docs) {
      activeDuelsById.set(doc.id, true);
    }
    if (activeDuelsById.size >= MAX_ACTIVE_DUELS_PER_USER) {
      if (type === "random") {
        logger.warn("createDuel random cap exceeded", {
          uid,
          activeCount: activeDuelsById.size,
        });
      } else {
        logger.warn("createDuel active cap reached", {
          uid,
          activeCount: activeDuelsById.size,
        });
      }
      throw new HttpsError(
        "resource-exhausted",
        "You have too many active duels. Finish or wait for some to expire."
      );
    }
    const categoryParam = request.data?.category;
    const categoryForGen =
      categoryParam && isCategory(categoryParam) ? categoryParam : null;
    if (type === "random") {
      const playerUsername = await resolveUsername(uid);
      const dedupCutoff = Timestamp.fromMillis(
        Date.now() - SAME_OPPONENT_DEDUP_WINDOW_MS
      );
      const recentOpponents = new Set<string>();
      const [asPlayer1Snap, asPlayer2Snap] = await Promise.all([
        db
          .collection("duels")
          .where("player1_id", "==", uid)
          .where("created_at", ">=", dedupCutoff)
          .get(),
        db
          .collection("duels")
          .where("player2_id", "==", uid)
          .where("created_at", ">=", dedupCutoff)
          .get(),
      ]);
      for (const d of asPlayer1Snap.docs) {
        const opp = d.get("player2_id");
        if (typeof opp === "string" && opp.length > 0) {
          recentOpponents.add(opp);
        }
      }
      for (const d of asPlayer2Snap.docs) {
        const opp = d.get("player1_id");
        if (typeof opp === "string" && opp.length > 0) {
          recentOpponents.add(opp);
        }
      }
      const [waitingSnap, player1DoneOpenSnap] = await Promise.all([
        db
          .collection("duels")
          .where("status", "==", "waiting")
          .where("type", "==", "random")
          .where("player1_id", "!=", uid)
          .orderBy("created_at", "asc")
          .limit(RANDOM_MATCH_LOOKUP_LIMIT)
          .get(),
        db
          .collection("duels")
          .where("status", "==", "player1_done")
          .where("type", "==", "random")
          .where("player2_id", "==", null)
          .where("player1_id", "!=", uid)
          .orderBy("created_at", "asc")
          .limit(RANDOM_MATCH_LOOKUP_LIMIT)
          .get(),
      ]);
      const waitingCandidates = mergeRandomMatchCandidates(
        waitingSnap.docs,
        player1DoneOpenSnap.docs,
      );
      for (const candidate of waitingCandidates) {
        const opponentId = candidate.get("player1_id");
        if (typeof opponentId !== "string" || opponentId.length === 0) {
          continue;
        }
        if (recentOpponents.has(opponentId)) {
          continue;
        }
        const matchResult = await db.runTransaction(async (tx) => {
          const duelRef = db.collection("duels").doc(candidate.id);
          const duelSnap = await tx.get(duelRef);
          if (!duelSnap.exists) {
            return null;
          }
          if (duelSnap.get("type") !== "random") {
            return null;
          }
          const p2Raw = duelSnap.get("player2_id");
          if (p2Raw !== null && p2Raw !== undefined) {
            return null;
          }
          const duelStatus = duelSnap.get("status");
          if (duelStatus !== "waiting" && duelStatus !== "player1_done") {
            return null;
          }
          const expiresAtSnap = duelSnap.get("expires_at");
          if (expiresAtSnap instanceof Timestamp &&
            expiresAtSnap.toMillis() < Date.now()) {
            return null;
          }
          const player1IdField = duelSnap.get("player1_id");
          const player1UsernameRaw = duelSnap.get("player1_username");
          const player1Username = typeof player1UsernameRaw === "string" ?
            player1UsernameRaw :
            "Anonymous Player";
          const patch: Record<string, unknown> = {
            player2_id: uid,
            player2_username: playerUsername,
            matched_at: FieldValue.serverTimestamp(),
          };
          if (duelStatus === "waiting") {
            patch.status = "matched";
          }
          tx.update(duelRef, patch);
          if (typeof player1IdField === "string" && player1IdField.length > 0) {
            tx.delete(db.collection("duel_queue").doc(player1IdField));
          }
          return {
            duelId: candidate.id,
            opponentId: typeof player1IdField === "string" ? player1IdField : null,
            opponentUsername: player1Username,
          };
        });
        if (matchResult) {
          logger.info("createDuel random matched", {
            uid,
            duelId: matchResult.duelId,
            opponentId: matchResult.opponentId,
          });
          let questionIds: string[] = [];
          try {
            questionIds = await readDuelQuestionIds(db, matchResult.duelId);
          } catch (error) {
            logger.warn("createDuel read question IDs failed", {
              uid,
              duelId: matchResult.duelId,
              error: String(error),
            });
          }
          await writePlayer2SeenBestEffort(
            db,
            uid,
            questionIds,
            "createDuel_random_matched"
          );
          return {
            duelId: matchResult.duelId,
            matched: true,
            opponentId: matchResult.opponentId,
            opponentUsername: matchResult.opponentUsername,
          };
        }
      }
      const expiresAt = Timestamp.fromMillis(Date.now() + DUEL_RANDOM_TTL_MS);
      const duelRef = db.collection("duels").doc();
      const batch = db.batch();
      batch.set(duelRef, {
        category: null,
        type: "random",
        status: "waiting",
        player1_id: uid,
        player1_username: playerUsername,
        player1_score: null,
        player1_correct_count: null,
        player1_time_ms: null,
        player1_done_at: null,
        player2_id: null,
        player2_username: null,
        player2_score: null,
        player2_correct_count: null,
        player2_time_ms: null,
        player2_done_at: null,
        invite_code: null,
        winner_id: null,
        created_at: FieldValue.serverTimestamp(),
        expires_at: expiresAt,
        matched_at: null,
        completed_at: null,
        questions_generated: true,
        questions_generated_at: FieldValue.serverTimestamp(),
      });
      await generateDuelQuestionSet({
        db,
        batch,
        duelId: duelRef.id,
        player1Id: uid,
        category: categoryForGen,
        logContext: {operation: "createDuel_random_unmatched"},
      });
      await batch.commit();
      await db.collection("duel_queue").doc(uid).set({
        duelId: duelRef.id,
        enteredAt: FieldValue.serverTimestamp(),
        expiresAt,
      });
      logger.info("createDuel random waiting", {uid, duelId: duelRef.id});
      return {
        duelId: duelRef.id,
        matched: false,
        expiresAt: expiresAt.toMillis(),
      };
    }
    let inviteCode: string | null = null;
    for (let i = 0; i < 5; i++) {
      const candidate = generateInviteCode();
      const collisionSnap = await db
        .collection("duels")
        .where("invite_code", "==", candidate)
        .where("status", "==", "waiting")
        .limit(1)
        .get();
      if (collisionSnap.empty) {
        inviteCode = candidate;
        break;
      }
    }
    if (!inviteCode) {
      logger.warn("createDuel invite code collision exhausted", {uid});
      throw new HttpsError("internal", "Invite code generation failed.");
    }
    const player1Username = await resolveUsername(uid);
    const expiresAt = Timestamp.fromMillis(Date.now() + DUEL_INVITE_TTL_MS);
    const duelRef = db.collection("duels").doc();
    const batch = db.batch();
    batch.set(duelRef, {
      category: null,
      type: "invite",
      status: "waiting",
      player1_id: uid,
      player1_username: player1Username,
      player1_score: null,
      player1_correct_count: null,
      player1_time_ms: null,
      player1_done_at: null,
      player2_id: null,
      player2_username: null,
      player2_score: null,
      player2_correct_count: null,
      player2_time_ms: null,
      player2_done_at: null,
      invite_code: inviteCode,
      winner_id: null,
      created_at: FieldValue.serverTimestamp(),
      expires_at: expiresAt,
      matched_at: null,
      completed_at: null,
      questions_generated: true,
      questions_generated_at: FieldValue.serverTimestamp(),
    });
    await generateDuelQuestionSet({
      db,
      batch,
      duelId: duelRef.id,
      player1Id: uid,
      category: categoryForGen,
      logContext: {operation: "createDuel_invite"},
    });
    await batch.commit();
    logger.info("createDuel invite created", {uid, duelId: duelRef.id, inviteCode});
    return {
      duelId: duelRef.id,
      inviteCode,
      expiresAt: expiresAt.toMillis(),
    };
  }
);

