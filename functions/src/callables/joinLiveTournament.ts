import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {checkAchievements} from "./checkAchievements";

type JoinLiveRequest = {ltId?: string};

type JoinLiveResponse = {success: true; late_joined: boolean};

export const joinLiveTournament = onCall<JoinLiveRequest, Promise<JoinLiveResponse>>(
  {
    region: "us-central1",
    cors: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const ltId = request.data?.ltId?.trim();
    if (!ltId) {
      throw new HttpsError("invalid-argument", "ltId is required.");
    }

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "Account is banned.");
    }

    const liveRef = db.collection("live_tournaments").doc(ltId);
    const partRef = db
      .collection("live_participants")
      .doc(ltId)
      .collection("users")
      .doc(uid);

    const response = await db.runTransaction(async (tx) => {
      const liveSnap = await tx.get(liveRef);
      if (!liveSnap.exists) {
        throw new HttpsError("not-found", "live_tournament_not_found");
      }
      const live = liveSnap.data()!;
      const st = live.status;
      if (st === "ended" || st === "no_participants" || st === "generation_failed") {
        throw new HttpsError("failed-precondition", "live_tournament_not_joinable");
      }
      const lateJoinClosed = live.late_join_closed === true;
      if (st === "running" && lateJoinClosed) {
        throw new HttpsError("failed-precondition", "late_join_closed");
      }

      const partSnap = await tx.get(partRef);
      if (partSnap.exists) {
        const data = partSnap.data()!;
        return {
          success: true as const,
          late_joined: data.late_joined === true,
        };
      }

      const lateJoined = st === "running";
      tx.set(partRef, {
        uid,
        joined_at: FieldValue.serverTimestamp(),
        late_joined: lateJoined,
      });
      tx.update(liveRef, {
        total_participants: FieldValue.increment(1),
        updated_at: FieldValue.serverTimestamp(),
      });
      return {success: true as const, late_joined: lateJoined};
    });

    void checkAchievements(uid, {trigger: "live_join", payload: {}}).catch(
      (err) => logger.error("checkAchievements", err),
    );

    return response;
  },
);
