import {initializeApp, applicationDefault} from "firebase-admin/app";
import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";

initializeApp({credential: applicationDefault()});
const db = getFirestore();

async function main() {
  const past = Timestamp.fromMillis(Date.now() - 60 * 60 * 1000);
  const future = Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);
  const created = [];

  const duelsToCreate = [
    {label: "expired_random_waiting", type: "random", status: "waiting", expires_at: past, includeQueue: true},
    {label: "expired_invite_waiting", type: "invite", status: "waiting", expires_at: past, includeQueue: false},
    {label: "expired_matched", type: "invite", status: "matched", expires_at: past, includeQueue: false},
    {label: "expired_player1_done", type: "invite", status: "player1_done", expires_at: past, includeQueue: false},
    {label: "fresh_random_waiting", type: "random", status: "waiting", expires_at: future, includeQueue: true},
    {label: "fresh_invite_waiting", type: "invite", status: "waiting", expires_at: future, includeQueue: false},
    {label: "completed_old", type: "invite", status: "completed", expires_at: past, includeQueue: false},
  ];

  for (const d of duelsToCreate) {
    const ref = db.collection("duels").doc();
    const player1Id = "test_expireDuels_" + d.label;
    await ref.set({
      category: null,
      type: d.type,
      status: d.status,
      player1_id: player1Id,
      player1_username: "Test Player",
      player2_id: d.status !== "waiting" ? "test_p2_" + d.label : null,
      player2_username: d.status !== "waiting" ? "Test Player 2" : null,
      invite_code: d.type === "invite" ? "TST" + Math.floor(Math.random() * 1000) : null,
      winner_id: null,
      created_at: FieldValue.serverTimestamp(),
      expires_at: d.expires_at,
      matched_at: null,
      completed_at: null,
    });
    if (d.includeQueue) {
      await db.collection("duel_queue").doc(player1Id).set({
        duelId: ref.id,
        enteredAt: FieldValue.serverTimestamp(),
        expiresAt: d.expires_at,
      });
    }
    created.push({label: d.label, duelId: ref.id, player1Id});
  }
  console.log(JSON.stringify(created, null, 2));
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
