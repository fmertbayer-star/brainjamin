import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";

export const getDuelLobbyStats = onCall(
  {
    cors: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const db = getFirestore();
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      logger.warn("getDuelLobbyStats banned user blocked", {uid});
      throw new HttpsError("permission-denied", "Account is banned.");
    }

    const aggregateSnap = await db
      .collection("duels")
      .where("status", "==", "waiting")
      .where("type", "==", "random")
      .count()
      .get();

    const randomQueueSize = aggregateSnap.data().count;
    logger.info("getDuelLobbyStats", {uid, randomQueueSize});
    return {randomQueueSize};
  }
);
