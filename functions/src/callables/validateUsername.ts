import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import Filter from "bad-words";

const USERNAME_FORMAT = /^[a-zA-Z][a-zA-Z0-9_]{2,19}$/;
const COOLDOWN_MS = 30 * 24 * 60 * 60 * 1000;
const profanityFilter = new Filter();

type ValidateUsernameRequest = {
  username?: unknown;
};

function isValidUsernameFormat(username: string): boolean {
  return USERNAME_FORMAT.test(username);
}

function isBlockedByTerms(lowerUsername: string, terms: unknown): boolean {
  if (!Array.isArray(terms)) {
    return false;
  }
  for (const term of terms) {
    if (typeof term !== "string" || term.length === 0) {
      continue;
    }
    const t = term.toLowerCase();
    if (lowerUsername === t || lowerUsername.includes(t)) {
      return true;
    }
  }
  return false;
}

export const validateUsername = onCall<ValidateUsernameRequest>(
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

    const usernameRaw = request.data?.username;
    if (typeof usernameRaw !== "string") {
      throw new HttpsError("invalid-argument", "username must be a string.");
    }
    const username = usernameRaw.trim();
    if (!isValidUsernameFormat(username)) {
      throw new HttpsError("invalid-argument", "invalid username format");
    }

    const lowerUsername = username.toLowerCase();
    const db = getFirestore();

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    const forceRename = userSnap.get("forceRename") === true;

    if (!forceRename) {
      const changedAt = userSnap.get("usernameChangedAt");
      if (changedAt instanceof Timestamp) {
        const elapsed = Date.now() - changedAt.toMillis();
        if (elapsed < COOLDOWN_MS) {
          throw new HttpsError("invalid-argument", "cooldown");
        }
      }
    }

    const blockedSnap = await db
      .collection("blocked_terms")
      .doc("usernames")
      .get();
    const manualTerms = blockedSnap.get("terms");
    if (
      isBlockedByTerms(lowerUsername, manualTerms) ||
      profanityFilter.isProfane(lowerUsername)
    ) {
      throw new HttpsError("invalid-argument", "blocked");
    }

    const oldDisplayName = userSnap.get("displayName");
    const oldLower =
      typeof oldDisplayName === "string" && oldDisplayName.trim().length > 0 ?
        oldDisplayName.trim().toLowerCase() :
        null;

    const usernameRef = db.collection("usernames").doc(lowerUsername);
    const publicRef = db.collection("users_public").doc(uid);

    await db.runTransaction(async (tx) => {
      const usernameSnap = await tx.get(usernameRef);
      if (usernameSnap.exists) {
        const existingUid = usernameSnap.get("uid");
        if (typeof existingUid === "string" && existingUid !== uid) {
          throw new HttpsError("already-exists", "taken");
        }
      }

      const publicSnap = await tx.get(publicRef);

      tx.set(
        usernameRef,
        {uid, reservedAt: FieldValue.serverTimestamp()},
        {merge: true},
      );
      tx.set(
        userRef,
        {
          displayName: username,
          usernameChangedAt: FieldValue.serverTimestamp(),
          forceRename: false,
        },
        {merge: true},
      );

      if (publicSnap.exists) {
        tx.set(publicRef, {displayName: username}, {merge: true});
      }

      if (oldLower !== null && oldLower !== lowerUsername) {
        tx.delete(db.collection("usernames").doc(oldLower));
      }
    });

    return {ok: true};
  },
);
