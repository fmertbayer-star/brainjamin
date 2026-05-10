import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {DateTime} from "luxon";
import {isValidTimezone} from "../shared/timezone";

const REPORT_REASONS = [
  "wrong_answer",
  "wrong_or_unclear",
  "inappropriate_content",
  "other",
] as const;
type ReportReason = (typeof REPORT_REASONS)[number];

const GAME_MODES = [
  "daily",
  "self_test",
  "arena",
  "duel",
  "classic",
  "live",
] as const;
type GameMode = (typeof GAME_MODES)[number];

function isReportReason(value: unknown): value is ReportReason {
  return typeof value === "string" &&
    (REPORT_REASONS as readonly string[]).includes(value);
}

function isGameMode(value: unknown): value is GameMode {
  return typeof value === "string" &&
    (GAME_MODES as readonly string[]).includes(value);
}

export const submitReport = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }
    const uid = request.auth.uid;

    const questionIdRaw = request.data?.questionId;
    if (typeof questionIdRaw !== "string" || questionIdRaw.trim().length === 0) {
      throw new HttpsError("invalid-argument", "invalid_question_id");
    }
    const questionId = questionIdRaw.trim();

    const reasonRaw = request.data?.reason;
    if (!isReportReason(reasonRaw)) {
      throw new HttpsError("invalid-argument", "invalid_reason");
    }
    const reason = reasonRaw;

    const freeTextRaw = request.data?.freeText;
    let freeText: string | null = null;
    if (freeTextRaw !== undefined) {
      if (typeof freeTextRaw !== "string") {
        throw new HttpsError("invalid-argument", "invalid_free_text");
      }
      const trimmed = freeTextRaw.trim();
      if (trimmed.length > 200) {
        throw new HttpsError("invalid-argument", "invalid_free_text");
      }
      freeText = trimmed.length > 0 ? trimmed : null;
    }

    const timezone = request.data?.timezone;
    if (!isValidTimezone(timezone)) {
      throw new HttpsError("invalid-argument", "invalid_timezone");
    }

    const gameModeRaw = request.data?.gameMode;
    let gameMode: GameMode | null = null;
    if (gameModeRaw !== undefined) {
      if (!isGameMode(gameModeRaw)) {
        throw new HttpsError("invalid-argument", "invalid_game_mode");
      }
      gameMode = gameModeRaw;
    }

    const dateKey = DateTime.now().setZone(timezone).toISODate();
    if (!dateKey) {
      throw new HttpsError("failed-precondition", "invalid_date_key");
    }

    const db = getFirestore();
    const usersRef = db.collection("users").doc(uid);
    const reportId = `${uid}_${questionId}`;
    const reportRef = db.collection("reports").doc(reportId);

    try {
      await db.runTransaction(async (tx) => {
        const userSnap = await tx.get(usersRef);
        const reportSnap = await tx.get(reportRef);

        const dailyCount = userSnap.get(`dailyReports.${dateKey}`);
        if (typeof dailyCount === "number" && dailyCount >= 10) {
          throw new HttpsError("failed-precondition", "daily_cap_reached");
        }

        if (reportSnap.exists) {
          throw new HttpsError("already-exists", "already_reported");
        }

        tx.create(reportRef, {
          userId: uid,
          questionId,
          reason,
          freeText,
          gameMode,
          timezone,
          dateKey,
          createdAt: FieldValue.serverTimestamp(),
          resolved: false,
        });

        tx.set(usersRef, {
          dailyReports: {
            [dateKey]: FieldValue.increment(1),
          },
        }, {merge: true});
      });
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      logger.error("submitReport transaction failed", {uid, questionId, error});
      throw new HttpsError("internal", "submit_failed");
    }

    if (reason === "inappropriate_content") {
      try {
        const adminsSnap = await db
          .collection("users")
          .where("isAdmin", "==", true)
          .get();

        logger.info("submitReport push: admin query", {
          questionId,
          reportId,
          adminDocCount: adminsSnap.size,
        });

        if (adminsSnap.empty) {
          logger.warn(
            "submitReport: no admins found for inappropriate_content alert",
          );
        } else {
          const tokens = adminsSnap.docs
            .map((doc) => doc.data().fcm_token)
            .filter(
              (token): token is string =>
                typeof token === "string" && token.trim().length > 0,
            );

          logger.info("submitReport push: tokens after filter", {
            questionId,
            reportId,
            tokenCount: tokens.length,
          });

          if (tokens.length > 0) {
            const response = await getMessaging().sendEachForMulticast({
              tokens,
              notification: {
                title: "[BJ] Inappropriate content report",
                body: `Question ${questionId} reported. Tap to review in Console.`,
              },
              data: {
                type: "report_alert",
                questionId,
                reportId,
              },
            });
            logger.info("submitReport push result", {
              questionId,
              reportId,
              successCount: response.successCount,
              failureCount: response.failureCount,
              failures: response.responses
                .map((r, i) =>
                  r.success ? null : {index: i, code: r.error?.code, message: r.error?.message})
                .filter((x): x is {index: number; code: string | undefined; message: string | undefined} =>
                  x !== null),
            });
          }
        }
      } catch (error) {
        logger.warn("submitReport push alert failed", {questionId, reportId, error});
      }
    }

    return {ok: true, reportId};
  },
);
