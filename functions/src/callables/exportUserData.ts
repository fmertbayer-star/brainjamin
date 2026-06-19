import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const EXPORT_COOLDOWN_MS = 30 * 24 * 60 * 60 * 1000;

type ExportPayload = {
  user: Record<string, unknown> | null;
  users_public: Record<string, unknown> | null;
  achievements: Record<string, unknown>;
  used_questions_seen_count: number;
  exported_at: string;
};

export const exportUserData = onCall(
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

    const lastExportAt = userSnap.get("last_export_at");
    if (lastExportAt instanceof Timestamp) {
      const elapsed = Date.now() - lastExportAt.toMillis();
      if (elapsed < EXPORT_COOLDOWN_MS) {
        throw new HttpsError("resource-exhausted", "cooldown");
      }
    }

    const [publicSnap, earnedSnap, seenSnap] = await Promise.all([
      db.collection("users_public").doc(uid).get(),
      db.collection("achievements").doc(uid).collection("earned").get(),
      db.collection("used_questions").doc(uid).collection("seen").get(),
    ]);

    const achievements: Record<string, unknown> = {};
    for (const doc of earnedSnap.docs) {
      achievements[doc.id] = doc.get("earnedAt") ?? null;
    }

    const exportData: ExportPayload = {
      user: userSnap.exists ? (userSnap.data() ?? null) : null,
      users_public: publicSnap.exists ? (publicSnap.data() ?? null) : null,
      achievements,
      used_questions_seen_count: seenSnap.size,
      exported_at: new Date().toISOString(),
    };

    await userRef.set(
      {
        exportData: JSON.stringify(exportData),
        last_export_at: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {ok: true, exportData};
  },
);
