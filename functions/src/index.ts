import {onCall} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";

setGlobalOptions({region: "us-central1"});

export const ping = onCall(async (request) => {
  return {
    ok: true,
    echo: request.data ?? null,
    serverTime: Date.now(),
  };
});
