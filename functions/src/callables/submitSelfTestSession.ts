import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {DateTime} from "luxon";

function utcIsoWeekKey(nowMs: number): string {
  return DateTime.fromMillis(nowMs, {zone: "utc"}).toFormat("kkkk-'W'WW");
}

function isValidAnswer(v: unknown): v is number {
  return (
    typeof v === "number" &&
    Number.isInteger(v) &&
    (v === -1 || v === 0 || v === 1 || v === 2 || v === 3)
  );
}

function isValidRemainingMs(v: unknown): v is number {
  return (
    typeof v === "number" &&
    Number.isInteger(v) &&
    v >= 0 &&
    v <= 10_000
  );
}

export const submitSelfTestSession = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }
    const uid = request.auth.uid;

    const sessionId = request.data?.sessionId;
    const answersRaw = request.data?.answers;
    const perQuestionRemainingMsRaw = request.data?.perQuestionRemainingMs;

    if (typeof sessionId !== "string" || sessionId.length === 0) {
      throw new HttpsError("invalid-argument", "invalid_session_id");
    }
    if (!Array.isArray(answersRaw) || answersRaw.length !== 25) {
      throw new HttpsError("invalid-argument", "answers_must_be_length_25");
    }
    if (
      !Array.isArray(perQuestionRemainingMsRaw) ||
      perQuestionRemainingMsRaw.length !== 25
    ) {
      throw new HttpsError(
        "invalid-argument",
        "per_question_remaining_ms_must_be_length_25",
      );
    }

    const answers = answersRaw as unknown[];
    const perQuestionRemainingMs = perQuestionRemainingMsRaw as unknown[];

    for (let i = 0; i < 25; i++) {
      if (!isValidAnswer(answers[i])) {
        throw new HttpsError("invalid-argument", "invalid_answer_entry");
      }
      if (!isValidRemainingMs(perQuestionRemainingMs[i])) {
        throw new HttpsError(
          "invalid-argument",
          "invalid_per_question_remaining_ms",
        );
      }
    }

    const db = getFirestore();
    const sessionRef = db.collection("self_test_sessions").doc(sessionId);

    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      throw new HttpsError("permission-denied", "session_not_found");
    }
    const sessionData = sessionSnap.data();
    if (!sessionData || sessionData.uid !== uid) {
      throw new HttpsError("permission-denied", "session_not_owned");
    }
    if (sessionData.status !== "in_progress") {
      throw new HttpsError("permission-denied", "session_not_in_progress");
    }

    const shuffledCorrectIndices = sessionData.shuffledCorrectIndices as
      | unknown;
    const questionIds = sessionData.questionIds as unknown;
    if (
      !Array.isArray(shuffledCorrectIndices) ||
      shuffledCorrectIndices.length !== 25 ||
      !Array.isArray(questionIds) ||
      questionIds.length !== 25
    ) {
      throw new HttpsError("failed-precondition", "invalid_session_shape");
    }

    const correctIndices = shuffledCorrectIndices as number[];
    const qIds = questionIds as string[];

    let correctCount = 0;
    let totalRemainingMs = 0;
    for (let i = 0; i < 25; i++) {
      const a = answers[i] as number;
      const expected = correctIndices[i];
      if (
        typeof expected === "number" &&
        Number.isInteger(expected) &&
        a === expected
      ) {
        correctCount++;
      }
      totalRemainingMs += perQuestionRemainingMs[i] as number;
    }

    const weekKey = utcIsoWeekKey(Date.now());

    const usersPublicRef = db.collection("users_public").doc(uid);
    const leaderboardRef = db
      .collection("self_test_leaderboard")
      .doc(weekKey)
      .collection("sessions")
      .doc(sessionId);
    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
      const sessionTxSnap = await tx.get(sessionRef);
      if (!sessionTxSnap.exists) {
        throw new HttpsError("permission-denied", "session_not_found");
      }
      const s = sessionTxSnap.data();
      if (!s || s.uid !== uid || s.status !== "in_progress") {
        throw new HttpsError("permission-denied", "session_invalid");
      }

      const publicSnap = await tx.get(usersPublicRef);
      let displayName: string | null = null;
      if (publicSnap.exists) {
        const dn = publicSnap.get("displayName");
        displayName = typeof dn === "string" && dn.length > 0 ? dn : null;
      }

      tx.update(sessionRef, {
        status: "completed",
        completedAt: FieldValue.serverTimestamp(),
        correctCount,
        totalRemainingMs,
        answers,
        weekKey,
      });

      tx.set(leaderboardRef, {
        uid,
        displayName,
        correctCount,
        totalRemainingMs,
        completedAt: FieldValue.serverTimestamp(),
      });

      tx.set(
        userRef,
        {
          xp: FieldValue.increment(correctCount),
        },
        {merge: true},
      );

      for (const qId of qIds) {
        const seenRef = db
          .collection("used_questions")
          .doc(uid)
          .collection("seen")
          .doc(qId);
        tx.set(
          seenRef,
          {
            seenAt: FieldValue.serverTimestamp(),
            source: "self_test",
            sessionId,
          },
          {merge: true},
        );
      }
    });

    return {
      correctCount,
      totalRemainingMs,
      weekKey,
    };
  },
);
