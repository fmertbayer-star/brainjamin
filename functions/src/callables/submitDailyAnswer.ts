import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {DateTime} from "luxon";
import {isValidTimezone} from "../shared/timezone";

interface DailyQuestionDoc {
  qId: string;
  shuffledCorrectIndex: number;
}

interface UserDailyState {
  streak: number;
  lastAnsweredDateKey: string | null;
  forgivesAvailableThisWeek: number;
  lastForgiveResetWeekKey: string | null;
  xp: number;
}

function isValidSelectedIndex(value: unknown): value is 0 | 1 | 2 | 3 {
  return value === 0 || value === 1 || value === 2 || value === 3;
}

function parseDailyQuestionDoc(data: unknown): DailyQuestionDoc {
  if (!data || typeof data !== "object") {
    throw new HttpsError("failed-precondition", "invalid_daily_question_doc");
  }
  const raw = data as Record<string, unknown>;
  if (
    typeof raw.qId !== "string" ||
    typeof raw.shuffledCorrectIndex !== "number" ||
    !Number.isInteger(raw.shuffledCorrectIndex) ||
    raw.shuffledCorrectIndex < 0 ||
    raw.shuffledCorrectIndex > 3
  ) {
    throw new HttpsError("failed-precondition", "invalid_daily_question_doc");
  }
  return {
    qId: raw.qId,
    shuffledCorrectIndex: raw.shuffledCorrectIndex,
  };
}

function parseUserDailyState(data: unknown): UserDailyState {
  if (!data || typeof data !== "object") {
    return {
      streak: 0,
      lastAnsweredDateKey: null,
      forgivesAvailableThisWeek: 1,
      lastForgiveResetWeekKey: null,
      xp: 0,
    };
  }
  const raw = data as Record<string, unknown>;
  return {
    streak: typeof raw.streak === "number" ? raw.streak : 0,
    lastAnsweredDateKey:
      typeof raw.lastAnsweredDateKey === "string" ? raw.lastAnsweredDateKey : null,
    forgivesAvailableThisWeek:
      raw.forgivesAvailableThisWeek === 0 || raw.forgivesAvailableThisWeek === 1 ?
        raw.forgivesAvailableThisWeek :
        1,
    lastForgiveResetWeekKey:
      typeof raw.lastForgiveResetWeekKey === "string" ?
        raw.lastForgiveResetWeekKey :
        null,
    xp: typeof raw.xp === "number" ? raw.xp : 0,
  };
}

export const submitDailyAnswer = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }
    const uid = request.auth.uid;
    const selectedIndex = request.data?.selectedIndex;
    const timezone = request.data?.timezone;

    if (!isValidSelectedIndex(selectedIndex)) {
      throw new HttpsError("invalid-argument", "invalid_selected_index");
    }
    if (!isValidTimezone(timezone)) {
      throw new HttpsError("invalid-argument", "invalid_timezone");
    }

    const localNow = DateTime.now().setZone(timezone);
    const dateKey = localNow.toISODate();
    if (!dateKey) {
      throw new HttpsError("failed-precondition", "invalid_date_key");
    }
    const weekKey = localNow.toFormat("kkkk-'W'WW");

    const db = getFirestore();
    const dailyRef = db.collection("daily_questions").doc(dateKey);
    const answerRef = db.collection("daily_answers").doc(`${uid}_${dateKey}`);
    const userRef = db.collection("users").doc(uid);

    const dailySnap = await dailyRef.get();
    if (!dailySnap.exists) {
      throw new HttpsError("failed-precondition", "daily_not_initialized");
    }
    const daily = parseDailyQuestionDoc(dailySnap.data());

    const txResult = await db.runTransaction(async (tx) => {
      const existingAnswerSnap = await tx.get(answerRef);
      if (existingAnswerSnap.exists) {
        throw new HttpsError("already-exists", "already_answered");
      }

      const userSnap = await tx.get(userRef);
      const current = parseUserDailyState(userSnap.data());

      let forgivesAvailableThisWeek = current.forgivesAvailableThisWeek;
      let lastForgiveResetWeekKey = current.lastForgiveResetWeekKey;
      if (lastForgiveResetWeekKey !== weekKey) {
        forgivesAvailableThisWeek = 1;
        lastForgiveResetWeekKey = weekKey;
      }

      let newStreak = 1;
      if (current.lastAnsweredDateKey === null) {
        newStreak = 1;
      } else {
        const gapDays = DateTime.fromISO(dateKey, {zone: timezone})
          .diff(DateTime.fromISO(current.lastAnsweredDateKey, {zone: timezone}), "days")
          .days;
        const roundedGapDays = Math.round(gapDays);

        if (roundedGapDays === 1) {
          newStreak = current.streak + 1;
        } else if (roundedGapDays === 0) {
          throw new HttpsError("internal", "invalid_same_day_gap");
        } else if (roundedGapDays === 2) {
          if (forgivesAvailableThisWeek === 1) {
            newStreak = current.streak + 1;
            forgivesAvailableThisWeek = 0;
          } else {
            newStreak = 1;
          }
        } else {
          newStreak = 1;
        }
      }

      const isCorrect = selectedIndex === daily.shuffledCorrectIndex;
      const xpAwarded = isCorrect ? 50 : 10;
      const totalXp = current.xp + xpAwarded;

      tx.set(answerRef, {
        uid,
        qId: daily.qId,
        dateKey,
        weekKey,
        selectedIndex,
        isCorrect,
        xpAwarded,
        submittedAt: FieldValue.serverTimestamp(),
      });

      tx.set(userRef, {
        streak: newStreak,
        lastAnsweredDateKey: dateKey,
        forgivesAvailableThisWeek,
        lastForgiveResetWeekKey,
        xp: FieldValue.increment(xpAwarded),
      }, {merge: true});

      return {
        isCorrect,
        correctIndex: daily.shuffledCorrectIndex,
        xpAwarded,
        streak: newStreak,
        forgivesAvailableThisWeek,
        totalXp,
      };
    });

    return txResult;
  },
);
