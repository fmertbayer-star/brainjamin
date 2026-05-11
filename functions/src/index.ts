import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {setGlobalOptions} from "firebase-functions/v2";

import type {Category} from "./shared/categories";
import {isCategory} from "./shared/categories";
import type {Difficulty} from "./shared/difficulty";
import {isDifficulty} from "./shared/difficulty";
import {AI_SECRETS} from "./shared/secrets";
import {selectDailyQuestion} from "./callables/selectDailyQuestion";
import {submitDailyAnswer} from "./callables/submitDailyAnswer";
import {submitReport} from "./callables/submitReport";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

setGlobalOptions({region: "us-central1"});

export const ping = onCall(async (request) => {
  return {
    ok: true,
    echo: request.data ?? null,
    serverTime: Date.now(),
  };
});

export const generateQuestions = onCall(
  {
    region: "us-central1",
    secrets: AI_SECRETS,
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    // TODO(sprint-6): replace with isAdmin gate before any
    // pre-launch deploy. For pilot, any authenticated user can call.
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }

    const {category, difficulty, count} = request.data ?? {};
    if (!isCategory(category)) {
      throw new HttpsError(
        "invalid-argument",
        "category must be one of the 20 V1 categories.",
      );
    }
    if (!isDifficulty(difficulty)) {
      throw new HttpsError(
        "invalid-argument",
        "difficulty must be 1-5.",
      );
    }
    const c = typeof count === "number" ? count : 1;
    if (!Number.isInteger(c) || c < 1 || c > 25) {
      throw new HttpsError(
        "invalid-argument",
        "count must be an integer 1-25.",
      );
    }

    const persisted: Array<{id: string; attempts: number}> = [];
    const rejected: Array<{slot: number; attempts: unknown[]}> = [];
    const {generateOneQuestion} = await import("./shared/pipeline");
    for (let i = 0; i < c; i++) {
      const result = await generateOneQuestion(
        category as Category,
        difficulty as Difficulty,
      );
      if (result.persisted) {
        persisted.push({
          id: result.persisted.id,
          attempts: result.attempts.length,
        });
      } else {
        rejected.push({slot: i, attempts: result.attempts});
      }
      logger.info("generateQuestions slot complete", {
        slot: i,
        category,
        difficulty,
        persisted: !!result.persisted,
        attempts: result.attempts.length,
      });
    }

    return {
      requested: c,
      persistedCount: persisted.length,
      persisted,
      rejected,
    };
  },
);

export {selectDailyQuestion};
export {selectSelfTestQuestions} from "./callables/selectSelfTestQuestions";
export {submitDailyAnswer};
export {submitReport};
export {submitSelfTestSession} from "./callables/submitSelfTestSession";

// Sprint 3 — Duel
export {createDuel} from "./callables/createDuel";
export {joinDuel} from "./callables/joinDuel";
export {getDuelQuestions} from "./callables/getDuelQuestions";
export {submitDuelAnswers} from "./callables/submitDuelAnswers";
export {getClassicTournamentQuestions} from "./callables/getClassicTournamentQuestions";
export {submitClassicTournamentAnswers} from "./callables/submitClassicTournamentAnswers";
export {getClassicTournamentReveal} from "./callables/getClassicTournamentReveal";
export {getDuelLobbyStats} from "./callables/getDuelLobbyStats";

// Sprint 3.5 — Arena
export {createArena} from "./arena/createArena";
export {joinArena} from "./arena/joinArena";
export {checkCustomTopicViability} from "./arena/checkCustomTopicViability";
export {generateArenaQuestions} from "./arena/generateArenaQuestions";
export {submitArenaAnswers} from "./callables/submitArenaAnswers";
export {runArenaTournament} from "./scheduled/runArenaTournament";
export {finalizeArenaTournament} from "./scheduled/finalizeArenaTournament";

export {expireDuels} from "./scheduled/expireDuels";
export {generateClassicTournamentContent} from "./scheduled/generateClassicTournamentContent";
export {makeClassicTournamentVisible} from "./scheduled/makeClassicTournamentVisible";
export {finalizeClassicTournament} from "./scheduled/finalizeClassicTournament";
export {prepareLiveTournament} from "./scheduled/prepareLiveTournament";
export {joinLiveTournament} from "./callables/joinLiveTournament";
export {fastForwardLiveStart} from "./callables/fastForwardLiveStart";
export {submitLiveAnswers} from "./callables/submitLiveAnswers";
export {runLiveTournament} from "./scheduled/runLiveTournament";
export {finalizeLiveTournament} from "./scheduled/finalizeLiveTournament";
