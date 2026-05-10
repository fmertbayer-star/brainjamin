/**
 * checkCustomTopicViability — HTTPS callable. LLM assesses custom topic richness.
 */

import {getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {generateWithProviders} from "../shared/aiProviders";
import {AI_SECRETS} from "../shared/secrets";
import {buildCustomTopicViabilityPrompt} from "../shared/prompts";
import type {ArenaViabilityResult} from "./shared";
import {
  ARENA_CUSTOM_TOPIC_MAX_LEN,
  ARENA_CUSTOM_TOPIC_MIN_LEN,
} from "./shared";

type RequestData = {
  topic?: unknown;
};

function stripJsonFences(raw: string): string {
  let s = raw.trim();
  if (s.startsWith("```")) {
    const firstNl = s.indexOf("\n");
    if (firstNl !== -1) {
      s = s.slice(firstNl + 1);
    }
    const fenceEnd = s.lastIndexOf("```");
    if (fenceEnd !== -1) {
      s = s.slice(0, fenceEnd);
    }
  }
  return s.trim();
}

function parseViabilityJson(parsed: unknown): ArenaViabilityResult | null {
  if (!parsed || typeof parsed !== "object") {
    return null;
  }
  const r = parsed as Record<string, unknown>;
  if (typeof r.viable !== "boolean") {
    return null;
  }
  const out: ArenaViabilityResult = {viable: r.viable};
  if (typeof r.reason === "string") {
    out.reason = r.reason;
  }
  if (r.suggestion === null) {
    return out;
  }
  if (typeof r.suggestion === "string") {
    out.suggestion = r.suggestion;
  }
  return out;
}

export const checkCustomTopicViability = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: AI_SECRETS,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "auth_required");
    }

    const data = request.data as RequestData | undefined;
    const topicRaw = data?.topic;
    if (typeof topicRaw !== "string") {
      throw new HttpsError("invalid-argument", "topic_invalid");
    }
    const topic = topicRaw.trim();
    if (
      topic.length < ARENA_CUSTOM_TOPIC_MIN_LEN ||
      topic.length > ARENA_CUSTOM_TOPIC_MAX_LEN
    ) {
      throw new HttpsError("invalid-argument", "topic_invalid");
    }

    const usersRef = getFirestore().collection("users").doc(uid);
    const userSnap = await usersRef.get();
    if (userSnap.exists && userSnap.get("banned") === true) {
      throw new HttpsError("permission-denied", "banned");
    }

    const {systemPrompt, userPrompt} = buildCustomTopicViabilityPrompt(topic);

    let raw: string;
    try {
      const res = await generateWithProviders(userPrompt, {
        systemPrompt,
        responseFormat: "json_object",
      });
      raw = res.raw;
    } catch {
      return {viable: true};
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(stripJsonFences(raw));
    } catch {
      return {viable: true};
    }

    const viability = parseViabilityJson(parsed);
    if (viability == null) {
      return {viable: true};
    }

    return viability;
  },
);
