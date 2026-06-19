import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

export const softDeleteAccount = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    const auth = request.auth;
    if (!auth?.uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }
    const uid = auth.uid;

    const signInProvider = auth.token.firebase?.sign_in_provider;
    if (signInProvider === "anonymous") {
      throw new HttpsError("unauthenticated", "anonymous_not_allowed");
    }

    const db = getFirestore();
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const displayName = userSnap.get("displayName");
    const originalUsername =
      typeof displayName === "string" && displayName.trim().length > 0 ?
        displayName.trim() :
        null;

    const authUser = await getAuth().getUser(uid);
    const scheduledFor = Timestamp.fromMillis(Date.now() + THIRTY_DAYS_MS);

    await db.collection("deleted_accounts").doc(uid).set({
      uid,
      scheduledFor,
      originalEmail: authUser.email ?? null,
      originalUsername,
      deletedAt: FieldValue.serverTimestamp(),
    });

    await userRef.set({banned: true}, {merge: true});

    return {ok: true};
  },
);
