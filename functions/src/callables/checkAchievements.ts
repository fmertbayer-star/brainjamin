import {FieldValue, getFirestore} from "firebase-admin/firestore";

export type AchievementCheckContext = {
  trigger: string;
  payload: Record<string, unknown>;
};

const ALL_ACHIEVEMENT_IDS = [
  "streak_3",
  "streak_7",
  "streak_30",
  "streak_100",
  "first_question",
  "questions_100",
  "questions_1000",
  "questions_10000",
  "tournament_first",
  "tournament_top10",
  "tournament_top3",
  "tournament_rank1",
  "first_duel_win",
  "selftest_perfect",
  "first_arena",
  "first_live",
  "early_adopter",
] as const;

const ANSWER_SUBMISSION_TRIGGERS = new Set([
  "daily_answer",
  "selftest",
  "duel",
]);

function payloadNumber(
  payload: Record<string, unknown>,
  key: string,
): number | null {
  const value = payload[key];
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  return null;
}

function payloadBoolean(
  payload: Record<string, unknown>,
  key: string,
): boolean {
  return payload[key] === true;
}

function shouldUnlock(
  achievementId: string,
  trigger: string,
  payload: Record<string, unknown>,
  user: {streak: number; totalAnswered: number},
): boolean {
  switch (achievementId) {
  case "first_question":
    return ANSWER_SUBMISSION_TRIGGERS.has(trigger);
  case "questions_100":
    return user.totalAnswered >= 100;
  case "questions_1000":
    return user.totalAnswered >= 1000;
  case "questions_10000":
    return user.totalAnswered >= 10000;
  case "streak_3":
    return user.streak >= 3;
  case "streak_7":
    return user.streak >= 7;
  case "streak_30":
    return user.streak >= 30;
  case "streak_100":
    return user.streak >= 100;
  case "first_duel_win":
    return trigger === "duel" && payloadBoolean(payload, "won");
  case "selftest_perfect": {
    if (trigger !== "selftest") {
      return false;
    }
    const correctCount = payloadNumber(payload, "correctCount");
    const total = payloadNumber(payload, "total");
    return correctCount === 25 && total === 25;
  }
  case "tournament_first":
    return trigger === "tournament_join";
  case "tournament_top10": {
    const rank = payloadNumber(payload, "rank");
    return trigger === "tournament_join" && rank !== null && rank <= 10;
  }
  case "tournament_top3": {
    const rank = payloadNumber(payload, "rank");
    return trigger === "tournament_join" && rank !== null && rank <= 3;
  }
  case "tournament_rank1": {
    const rank = payloadNumber(payload, "rank");
    return trigger === "tournament_join" && rank === 1;
  }
  case "first_arena":
    return trigger === "arena_create";
  case "first_live":
    return trigger === "live_join";
  case "early_adopter":
    return payloadBoolean(payload, "isEarlyAdopter");
  default:
    return false;
  }
}

/**
 * Idempotent achievement unlock check. Writes `achievements/{uid}/earned/{id}` for
 * newly met conditions; returns only ids earned in this invocation.
 */
export async function checkAchievements(
  uid: string,
  context: AchievementCheckContext,
): Promise<string[]> {
  const db = getFirestore();
  const earnedCol = db.collection("achievements").doc(uid).collection("earned");

  const [earnedSnap, userSnap] = await Promise.all([
    earnedCol.get(),
    db.collection("users").doc(uid).get(),
  ]);

  const alreadyEarned = new Set(earnedSnap.docs.map((doc) => doc.id));
  const userData = userSnap.data() ?? {};
  const streak =
    typeof userData.streak === "number" ? Math.trunc(userData.streak) : 0;
  const totalAnswered =
    typeof userData.totalAnswered === "number" ?
      Math.trunc(userData.totalAnswered) :
      0;
  const user = {streak, totalAnswered};

  const newlyEarned: string[] = [];

  for (const achievementId of ALL_ACHIEVEMENT_IDS) {
    if (alreadyEarned.has(achievementId)) {
      continue;
    }
    if (
      !shouldUnlock(
        achievementId,
        context.trigger,
        context.payload,
        user,
      )
    ) {
      continue;
    }
    await earnedCol.doc(achievementId).set({
      earnedAt: FieldValue.serverTimestamp(),
      trigger: context.trigger,
    });
    alreadyEarned.add(achievementId);
    newlyEarned.push(achievementId);
  }

  return newlyEarned;
}
