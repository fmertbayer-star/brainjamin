import {FieldValue, getFirestore, type Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {DateTime} from "luxon";
import {mcqShuffle} from "../shared/mcqShuffle";

interface DailyQuestionDoc {
  qId: string;
  shuffledOptions: string[];
  shuffledCorrectIndex: number;
  category: string;
}

function isValidTimezone(timezone: unknown): timezone is string {
  if (typeof timezone !== "string") {
    return false;
  }
  return DateTime.now().setZone(timezone).isValid;
}

function parseDailyQuestionDoc(data: unknown): DailyQuestionDoc {
  if (!data || typeof data !== "object") {
    throw new HttpsError("failed-precondition", "invalid_daily_question_doc");
  }
  const raw = data as Record<string, unknown>;
  const qId = raw.qId;
  const shuffledOptions = raw.shuffledOptions;
  const shuffledCorrectIndex = raw.shuffledCorrectIndex;
  const category = raw.category;

  const optionsOk = Array.isArray(shuffledOptions) &&
    shuffledOptions.length === 4 &&
    shuffledOptions.every((o) => typeof o === "string");

  if (
    typeof qId !== "string" ||
    !optionsOk ||
    typeof shuffledCorrectIndex !== "number" ||
    !Number.isInteger(shuffledCorrectIndex) ||
    shuffledCorrectIndex < 0 ||
    shuffledCorrectIndex > 3 ||
    typeof category !== "string"
  ) {
    throw new HttpsError("failed-precondition", "invalid_daily_question_doc");
  }

  return {
    qId,
    shuffledOptions,
    shuffledCorrectIndex,
    category,
  };
}

export const selectDailyQuestion = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }
    const uid = request.auth.uid;

    const timezone = request.data?.timezone;
    if (!isValidTimezone(timezone)) {
      throw new HttpsError("invalid-argument", "invalid_timezone");
    }

    const localNow = DateTime.now().setZone(timezone);
    const dateKey = localNow.toISODate();
    if (!dateKey) {
      throw new HttpsError("failed-precondition", "invalid_date_key");
    }

    const db = getFirestore();
    const dailyRef = db.collection("daily_questions").doc(dateKey);
    let dailyQuestion: DailyQuestionDoc | null = null;

    const existingDailySnap = await dailyRef.get();
    if (existingDailySnap.exists) {
      dailyQuestion = parseDailyQuestionDoc(existingDailySnap.data());
    } else {
      await db.runTransaction(async (tx) => {
        const insideSnap = await tx.get(dailyRef);
        if (insideSnap.exists) {
          dailyQuestion = parseDailyQuestionDoc(insideSnap.data());
          return;
        }

        const poolQuery = db
          .collection("questions_public")
          .where("flagged", "==", false)
          .limit(50);
        let poolDocs = (await tx.get(poolQuery)).docs;
        if (poolDocs.length === 0) {
        // Backward-compatible fallback for older pool docs with no flagged field.
          const fallbackSnap = await tx.get(
            db.collection("questions_public").limit(50),
          );
          poolDocs = fallbackSnap.docs.filter((doc) => doc.get("flagged") !== true);
        }
        if (poolDocs.length === 0) {
          throw new HttpsError("failed-precondition", "no_questions_available");
        }

        const picked = poolDocs[Math.floor(Math.random() * poolDocs.length)];
        const pickedData = picked.data();
        const options = pickedData.options;
        const correctIndex = pickedData.correctIndex;
        const category = pickedData.category;

        if (
          !Array.isArray(options) ||
        options.some((o) => typeof o !== "string") ||
        typeof correctIndex !== "number" ||
        !Number.isInteger(correctIndex) ||
        typeof category !== "string"
        ) {
          throw new HttpsError("failed-precondition", "invalid_question_shape");
        }

        const {shuffledOptions, shuffledCorrectIndex} = mcqShuffle(
        options as string[],
        correctIndex,
        );

        const createdDaily: DailyQuestionDoc = {
          qId: picked.id,
          shuffledOptions,
          shuffledCorrectIndex,
          category,
        };

        tx.set(dailyRef, {
          ...createdDaily,
          selectedAt: FieldValue.serverTimestamp(),
        });
        dailyQuestion = createdDaily;
      });
    }

    if (!dailyQuestion) {
      const snap = await dailyRef.get();
      if (!snap.exists) {
        throw new HttpsError("failed-precondition", "daily_question_missing");
      }
      dailyQuestion = parseDailyQuestionDoc(snap.data());
    }

    const qSnap = await db.collection("questions_public").doc(dailyQuestion.qId).get();
    if (!qSnap.exists) {
      throw new HttpsError("failed-precondition", "question_not_found");
    }
    const questionText = qSnap.get("question");
    if (typeof questionText !== "string") {
      throw new HttpsError("failed-precondition", "invalid_question_text");
    }

    const answerRef = db.collection("daily_answers").doc(`${uid}_${dateKey}`);
    const answerSnap = await answerRef.get();
    const alreadyAnswered = answerSnap.exists;
    const answerData = answerSnap.data();

    await Promise.all([
      db.collection("used_questions")
        .doc(uid)
        .collection("seen")
        .doc(dailyQuestion.qId)
        .set(
          {
            seenAt: FieldValue.serverTimestamp(),
            source: "daily",
            dateKey,
          },
          {merge: true},
        ),
      db.collection("users").doc(uid).set(
        {
          timezone,
        },
        {merge: true},
      ),
    ]);

    if (!alreadyAnswered) {
      return {
        dateKey,
        qId: dailyQuestion.qId,
        questionText,
        options: dailyQuestion.shuffledOptions,
        category: dailyQuestion.category,
        alreadyAnswered: false,
      };
    }

    const selectedIndex = answerData?.selectedIndex;
    const isCorrect = answerData?.isCorrect;
    const xpAwarded = answerData?.xpAwarded;
    const submittedAt = answerData?.submittedAt;
    const submittedAtMs = submittedAt && typeof submittedAt === "object" &&
    "toMillis" in submittedAt &&
    typeof (submittedAt as Timestamp).toMillis === "function" ?
      (submittedAt as Timestamp).toMillis() :
      undefined;

    return {
      dateKey,
      qId: dailyQuestion.qId,
      questionText,
      options: dailyQuestion.shuffledOptions,
      category: dailyQuestion.category,
      alreadyAnswered: true,
      ...(typeof selectedIndex === "number" ? {selectedIndex} : {}),
      correctIndex: dailyQuestion.shuffledCorrectIndex,
      ...(typeof isCorrect === "boolean" ? {isCorrect} : {}),
      ...(typeof xpAwarded === "number" ? {xpAwarded} : {}),
      ...(typeof submittedAtMs === "number" ? {submittedAtMs} : {}),
    };
  },
);
