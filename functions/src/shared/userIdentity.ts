import {getFirestore} from "firebase-admin/firestore";

/**
 * Resolve a user's public display name. Anonymous users (no users_public doc)
 * fall back to the literal "Anonymous Player" string. V1 EN-only — i18n
 * wrapping comes in Sprint 5.
 */
export async function resolveUsername(uid: string): Promise<string> {
  const snap = await getFirestore().collection("users_public").doc(uid).get();
  const displayName = snap.get("displayName");
  if (typeof displayName === "string" && displayName.trim().length > 0) {
    return displayName.trim();
  }
  return "Anonymous Player";
}
