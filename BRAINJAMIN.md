# BRAINJAMIN
Last reviewed: 2026-05-09 — Sprint 4.3 Steps 1+2a+2a-fix+2b+3a+3b+3c complete (backend + UI deployed); Step 2c (watchdog + T-5min push) parked; end-to-end smoke pending.

Single source of structural truth for Brainjamin. Architecture, product, data
model, security, design — locked decisions plus the implementation context
needed to keep them locked.

Day-to-day work belongs in `BRAINJAMIN_TODO.md`. Behavior rules + product
hard NOs live in Project Instructions. This document does not duplicate them.

---

## VISION

A global English-language trivia/quiz app with daily-habit + tournament loop,
monetized via ads. Mascot-led brand identity (Brainjamin = the character).
"Set up cleanly once, reduce maintenance burden to near-zero" architecture.
Mert hands development to Cursor and focuses on marketing/sales after launch.

Every decision serves this vision. If a proposal does not move Brainjamin
toward becoming a sustainable global trivia app with strong brand identity
and low operating cost, it is rejected — no matter how technically interesting.

---

## CORE BRAND DECISIONS (LOCKED)

### Identity
- **App name:** Brainjamin
- **Mascot:** Brainjamin — the character. Personality: encouraging mentor,
  slightly mischievous, broadly knowledgeable, world-cultures curious. Used
  in onboarding, push notifications, achievement unlocks, error/empty states,
  loading screens, level-up animations.
- **App Store subtitle format:** "Brainjamin: Trivia & Quiz Game"
- **Brand color:** `#F97316` (orange). `#FF9F04` BANNED everywhere — UI,
  code, prompts, comments. Stated only here in the doc.
- **Domain:** `brainjamin.com` (or `brainjamin.net` if `.com` unavailable);
  registered for 3 years on GoDaddy.

### Markets — Tier 1 only (6 countries)
USA, UK, Canada, Australia, Ireland, New Zealand.

USA is the primary market; UK/CA/AU are organic spillover; IE/NZ are niche.
All English-native, all high eCPM. Excluded: every non-Tier-1 country.
Reason: low eCPM dilutes ASO ranking, requires extra language/copy work,
and brings retention drag.

### Languages
EN-only at launch. ES (Spanish) and other languages explicitly **not** in
V1 scope. All user-facing strings via Flutter `intl` —
`lib/l10n/app_en.arb` only. No Turkish in user-facing surfaces.

Architecture supports `app_es.arb`, `app_fr.arb` etc. additions in V2
without refactor.

### Age Rating
- **13+** (App Store + Google Play). Apple replaced 12+ with 13+ in 2026.
- Onboarding includes a **neutral age gate** — birth year + month picker
  (not Yes/No). Under-13 users blocked from completing onboarding with EN
  message: "Brainjamin is for ages 13 and up."
- COPPA compliance: privacy policy explicitly states no knowing collection
  from under-13 users.
- UGC moderation pipeline (custom topic Arena → blocked_terms + Gemini
  self-check + moderation API + report flow + admin quality review +
  7-day stale cleanup) is documented for Apple Review. **Submission
  artifacts** (content rating answer matrix + Apple Review UGC paragraph
  + Apple Sign In identifiers) live in `BRAINJAMIN_TODO.md`
  § APPENDIX A.
- **LLM generator prompt constraint** (in Cursor brief for tournament +
  Arena CF prompts): "Avoid promoting alcohol, tobacco, or drug use.
  Historical or factual references acceptable (e.g., Prohibition Era
  questions) but no glamorization."

### Auth & Identity
- **Anonymous-first.** User can play everything without signing up — Daily,
  Self-Test, Arena (create + join), Duel (invite + queue), Classic and Live
  Tournaments. Anonymous users CANNOT: appear in leaderboards, earn
  achievements that require permanent account, or use friends features
  (V2-only anyway).
- 3 sign-in methods: Apple (mandatory on iOS per App Store rule), Google,
  Email + password.
- **No email verification mail** sent (reduces friction).
- **No phone verification anywhere.** No prizes → no need.
- Anonymous → permanent transition via Firebase `linkWithCredential`.
- **Anonymous users have NO `users_public/{uid}` doc.** Created lazily by
  auth trigger Cloud Function (`onUserConverted`) at conversion. All XP,
  streak, achievements, and history stored in `users/{uid}` from day one
  and survive the conversion intact.
- If account already exists on linking attempt: user is prompted with an
  explicit confirmation modal making the progress-loss tradeoff
  unavoidable. Anonymous progress is lost if they sign into the existing
  account. Copy: copywriter EN, Brainjamin-voiced.
- Sign-in method changeable post-conversion (Profile → Settings → "Add or
  change sign-in method").

#### Username rules

- **Format:** length 3–20 chars; charset `a-z`, `A-Z`, `0-9`, `_`. First
  character must be a letter (no leading digit/underscore).
  Case-insensitive uniqueness — `Brainjamin_Fan` and `brainjamin_fan`
  collide. `usernames/{lowercase}` doc id stores lowercase form; display
  preserves the case the user typed.
- **Block list (hybrid):** `bad-words` npm package as base + manual
  override list at `blocked_terms/usernames` (separate from
  `blocked_terms/{en}` which guards Arena custom topics). Mert maintains
  whitelist (false positives like "Scunthorpe") and blacklist
  (Brainjamin-specific bans). Block list checked at username
  creation/change time only; periodic sweeps are V2.
- **Change frequency:** at most once every 30 days.
  `users/{uid}.usernameChangedAt` is the rate-limit field read by
  `validateUsername` CF. Forced rename (admin moderation) bypasses
  cooldown.
- **Reservation:** permanent release on change — when a user changes,
  the old `usernames/{old}` doc is deleted immediately. No reservation TTL.
- **Single-field model:** one identifier — `displayName`. Brainjamin does
  NOT split into immutable username + mutable display name. Trivia
  category does not require @-mentions; friend system (V2) can use
  display-name search.
- **Anonymous user fallback:** anonymous users have no `users_public` doc
  and no display name. Opponent-side surfaces render the i18n string
  "Anonymous Player" (EN) for all anonymous opponents. Neutral fallback
  — no mascot voice rewrite.
- **Forced rename modal:** if Mert sets `users/{uid}.forceRename: true`
  (Console action), next app open shows non-dismissible modal blocking
  all gameplay until valid replacement username is accepted; on accept,
  `forceRename: false` and modal closes. Required for App Store / Play
  Store moderation compliance. Copy: copywriter EN, Brainjamin-voiced.

#### Anonymous user — Profile tab UX

Anonymous users see two layered nudges to convert; permanent users see
neither.

**Layer 1 — Dismissible top card on Profile tab.** Renders only when
`users/{uid}.isAnonymous == true`. Value prop: "without an account: streak
✓, XP ✓, leaderboards ✗." Primary CTA: "Save my account" → sign-in screen.
Secondary: 7-day dismissal via `users/{uid}.profileNudgeHiddenUntil`
(server-side, valid for anonymous via `users/{uid}` which exists from day
one). Card returns after 7 days.

**Layer 2 — Inline gate on Leaderboard tab.** Anonymous user tapping
Leaderboard sees a full-screen empty state instead of leaderboard. Title
explains the gate; primary CTA "Save my account" → sign-in screen;
secondary "Maybe later" → return to Profile tab.

**Achievement detail:** no inline gate. Top card already carries the
nudge; per-achievement gating becomes nag.

**Settings → Account section (anonymous):** persistent (non-dismissible)
prompt with the same value proposition + 3 sign-in buttons. Anonymous
progress preservation explicitly stated.

For permanent users this same Settings section becomes "Sign-in method —
add or change."

(All copy strings: copywriter EN, Brainjamin-voiced.)

### Monetization — V1
- **AdMob:** Banner + Interstitial only. Rewarded explicitly **deferred to V2**.
- **Banner placements:** Duel lobby, Classic results, Self-Test lobby.
  Refined post-launch with real navigation data.
- **Interstitial placement rule:** Shown after game completion / score
  display, not interrupting gameplay. Frequency cap: max one per ~3
  minutes; suppressed entirely during the user's first 3 game sessions
  (onboarding-friendly).
- **AdMob compliance:** UMP consent SDK (GDPR/CCPA), ATT (App Tracking
  Transparency) prompt before first ad. Both are launch-blockers.
- **Subscription "Brainjamin Plus" → V2.** All Plus-related infrastructure
  (RevenueCat, `syncRevenueCatEntitlement`, `expirePlusSubscribers`,
  billing grace period, `users.billingIssue` field,
  `ad_consent.subscriptionStatus` cross-reference) is excluded from V1.

#### ATT & UMP consent

**Sequence on first ad attempt** (after the 3-game onboarding suppression
window has passed):
1. **UMP consent prompt** (legally required for ad load — GDPR/CCPA).
   Uses Google's UMP UI; configured in AdMob console, not custom-coded.
2. **ATT soft primer** (Brainjamin-voiced) → if accepted, **iOS native
   ATT dialog**.
3. **Ad load.**

All three steps must complete before the first banner or interstitial
renders.

**ATT timing:** soft primer fires **just before the first ad load**, not
at app start, not in onboarding. By this point the user has completed at
least 3 game sessions and has a clear sense of what Brainjamin is.

**ATT soft primer copy** is Brainjamin-voiced ("better ads from
Brainjamin? not random spam — gameplay stays the same") with two CTAs:
"Sure, ask me" / "Not now." Copywriter authors final EN. UMP uses its
own dialog; no soft primer for UMP.

**Behavior on responses:**
- Soft primer "Not now" → 7-day cooldown; primer retried.
- iOS native ATT "deny" → app continues silently with non-personalized
  ads. No re-prompt (Apple permits ATT prompt only once per install).
  Settings → Privacy shows "Ad tracking disabled — change in iOS
  Settings" with a deep-link.

---

## PRODUCT — 6 GAME MODES

### User-driven (4)

**1. Daily Question**
- 1 question per day. EN.
- **Source:** `questions_public` (NO LLM call per day; pool is pre-seeded
  and continuously refilled by tournament engine).
- Reset: server-time authoritative, displayed in user's local timezone.
  Server stores `dateKey = serverTime.in(userTimezone).toISODate()`.
- **No time limit on the question itself.** Daily is a "think and answer
  in your own time" mode — pressure would harm streak motivation.
- Streak counter; 1-day forgiveness per week (auto-resets on local
  Monday 00:00 server-anchored). Forgive use is transparent — surface
  in profile as "🔥 12 days · 1 forgive available this week."
- Wrong answer does NOT break streak. XP awarded:
  - Correct: 50 XP + explanation
  - Wrong: 10 XP + explanation
- Push notification reminder at user's local 19:00 (service-category;
  Brainjamin-tone copy).
- No retroactive catch-up. Missed days consume forgive; running out
  breaks streak.

**2. Self-Test**
- 25 questions per session.
- User picks category.
- 10 sec per question.
- **Source:** `questions_public` only.
- Per-user dedup via `used_questions/{uid}/seen/{qId}` filtered to "seen
  in last 30 days" — beyond 30 days, questions can recycle. If a user
  exhausts a category within 30 days, UI suggests another category.
- **Leaderboard scope:** category-bucketed AND weekly-reset. Path:
  `self_test_leaderboard/{categoryId}_{weekKey}`. Top 100 + user's own
  rank. Ties broken by remaining ms.
- Global all-time leaderboard exists separately (XP-based, not
  Self-Test-specific).

**3. Arena** — invite-code group quiz
- User picks category OR types custom topic.
- 5–25 questions, user chooses count.
- 2 modes:
  - **List mode:** all answer all questions, score-ranked at end.
  - **Battle Arena mode:** wrong answer eliminates you. Eliminated user
    transitions to **spectator screen** — can watch remaining players
    real-time, sees who answered what, sees standings update live.
    Submit button is disabled. Spectator screen offers "Create new
    arena" CTA. Last standing wins; ties broken by remaining ms.

    **Battle Arena V1 polish:**
    - **Eliminate moment overlay:** 1–2 second full-screen "Eliminated"
      overlay (mascot worried expression, simple SVG/Lottie animation)
      before transitioning to spectator screen. Without this, the
      transition is jarring.
    - **Result push to eliminated participants** when arena ends.
      Service-category, standard cap. Copy: copywriter Brainjamin-voiced.

    **Battle Arena polish deferred to V2:** audio cues, share-result
    CTA + image generation, chat-style commentary in spectator,
    mascot reaction animation in spectator, "X people watching"
    indicator.
- Invite code generated (e.g. `BJ-7K2P`) + shareable link.
- Private only — no public/community arenas in V1.
- Anonymous users CAN create arenas.
- **Limit:** 10 arenas/day per user (Remote Config: `arena_max_per_day: 10`).
- **Minimum delay:** Arena's `scheduledStartAt` must be ≥ now + 10
  minutes. Validation enforced client-side AND server-side. Maximum:
  `scheduledStartAt ≤ now + 24 hours`.
- **Minimum players:** 1 (the creator). Even if no one joins, the arena
  is valid and runs solo at start time. Solo arena is intentionally
  allowed — content generation is paid for, ad surfaces appear,
  mechanic is consistent. `pruneStaleGames` does NOT cancel based on
  participant count.
- **3-step creation wizard:** (1) Basics — List vs Battle, optional
  name; (2) Details — Pre-set Categories vs Custom Topic, count slider
  5–25, start time picker, duration preview; (3) Summary + "Create" CTA.
- **Custom Topic narrow check (apriori):** Before generation, the LLM is
  asked whether 25 distinct, high-quality, in-depth questions can be
  generated for this topic. If no, UI warns user; user can still
  proceed; if generation yields fewer than requested, pool-fill from
  related category supplements.

**4. Duel** — async 1v1
- 10 questions, mixed categories (one per category for variety).
- 15 sec/question.
- **Source:** `questions_public` only — never LLM-generated per duel.
  Per-pair dedup uses player1's `used_questions` history at duel
  creation time. Player2 may see questions they have seen before;
  accepted Model A tradeoff (player2 history is unknown when the
  creator starts playing).
- **Async always — creator plays immediately.** The moment
  `createDuel` succeeds, the creator's 10 questions are written and
  the creator answers them at their own pace. There is no waiting
  screen. Opponent plays the same 10 questions whenever they match
  (random) or join (invite), independently of the creator's timing.
- Two methods:
  - **Random match:** `createDuel(type: "random")` either matches
    into an existing waiting/`player1_done` duel and the caller
    becomes player2, or creates a fresh duel and the caller is
    player1. Either way, the caller goes straight to the quiz
    screen. Background queue TTL: 24 hours via `expireDuels`.
  - **Invite link:** Creator gets a bare 6-char code (e.g.
    `J345TY`). Code is shared via the OS share sheet (deep linking
    is V2). Recipient enters the code in the in-app "Have a code
    from a friend?" flow → `joinDuel` attaches them as player2.
    Link/code expires after 7 days. If unused, the inviter
    receives 10 XP consolation.
- Both players answer same 10 questions, async (different times).
  Whichever player submits second triggers final scoring +
  `winner_id` + XP grant via `submitDuelAnswers`.
- **Same-opponent dedup:** A user is not matched against an
  opponent they faced within the last 24 hours.
- **No bots.** If queue is empty, the creator simply plays solo
  until someone matches.
- XP: Win +50, Draw +25, Loss +10.

### Auto-generated (2)

**5. Classic Tournament**
- 20 questions, 4-choice multiple choice.
- 24 hours open, async.
- Per-question correct answers revealed only after `status === "ended"`
  (collusion prevention).
- XP scale:
  - Rank 1: 500 XP
  - Rank 2-3: 300 XP
  - Rank 4-10: 200 XP
  - Rank 11-50: 100 XP
  - Anyone who completed (51+): 50 XP

**6. Live Tournament**
- 20 questions, real-time, 15 sec/question (~5 min total game; ~7 min
  including reveals + transitions).
- **Source:** `questions_public` only — never LLM-generated. At tournament
  start, Live pulls 20 questions from the pool with **5 difficulty levels
  (1–5), equal distribution: exactly 4 questions per level (4/4/4/4/4).**
  Categories
  are **not** bucketed — Live is mixed-category by design (contrast with
  Classic, which is single-category per slot).
- Synchronous — all players see same question at same instant, driven
  by server-side authoritative loop (no client clocks).
- **No registration.** Anyone in lobby at start time joins.
- **Late entry open through Q5 reveal**, then closes. Missed questions
  before joining auto-skip to 0 points. (`lateJoinClosed: true` flag set
  by server after Q5 reveal completes.)
- **Minimum participants: 1.** Lobby with 1+ joined player runs the
  tournament normally. Solo Live is intentionally allowed: the 20
  questions are drawn from `questions_public` at tournament start (see
  Source above), ad surfaces appear, mechanic
  is consistent with Arena's solo-allowed rule.
- **0 participants → no-op.** If lobby is empty at start, server loop
  does NOT begin. `live_tournaments/{ltId}.status` is set to
  `"no_participants"` and the watchdog skips this tournament. No
  follow-up "you missed it" push (would cross into marketing-tone Hard
  NO).
- **Solo Live UX:** results show "Rank 1 of 1" with no asterisk. The XP
  scale (1000 XP for rank 1) applies normally; the player still played
  under real-time pressure and earned the result.
- Push notification 5 minutes before start (Brainjamin-tone, service
  category, **exempt from quiet hours queue**).
- XP scale (2x classic because real-time pressure):
  - Rank 1: 1000 XP
  - Rank 2-3: 600 XP
  - Rank 4-10: 400 XP
  - Rank 11-50: 200 XP
  - Anyone who completed (51+): 100 XP

---

## TOURNAMENT ENGINE

The most critical auto-pilot module. Tournaments are not manually created.

### Schedule
- **Two trigger times daily:** 07:00 UTC (UK/IE morning, Sydney
  afternoon) and 23:00 UTC (NY/LA evening — primary US slot, London
  late-night, Sydney morning).
- **Classic idempotent slot id:** `classic_{YYYY-MM-DD}_{07utc|23utc}`.
- **Classic — generation + finalize (cron `0 7,23 * * *` UTC):**
  `generateClassicTournamentContent` builds/resumes the upcoming Classic
  slot; `finalizeClassicTournament` rolls up the Classic slot whose window
  just ended (rank, XP, `tournament_leaderboards/{slotId}`).
- **Classic — visibility (cron `0 11,19 * * *` UTC):**
  `makeClassicTournamentVisible` flips `ready` → `visible` for the slot
  entering its pre-start visibility window (T-12h before start).
- **LLM generation:** The **`generateClassicTournamentContent`** cron (and
  the Classic pipeline it invokes) is the **only** AI-driven source of new
  tournament question text. Live tournaments **never** invoke LLM generation
  for their 20 questions.
- **Live — doc creation (`prepareLiveTournament`):** Dedicated scheduled CF on
  cron **`0 7,23 * * *` UTC** creates `live_tournaments/{ltId}` idempotently
  (same slot clock as Classic; initial shape includes `status: "scheduled"`,
  `q_ids: []`, etc.). **Independent of Classic:** Live doc creation does **not**
  depend on Classic reaching `status: "ready"` or on Classic succeeding;
  Classic pipeline failure does **not** block Live.
- **Live — question binding:** **`q_ids` are populated from `questions_public`
  at tournament start** (server-side selection via `runLiveTournament`), not
  when the Live doc is first created and not via LLM at doc-create time.
- **Push:** Sent **5 minutes before** Live tournament start. Push is
  exempt from quiet hours queue (time-critical).

### Categories — 20 total, 10-day full rotation
**Classic only:** The list below is the human-readable map to canonical
category ids; **`category_rotation/state` applies only to Classic**
(single-category per Classic slot). **Live** is mixed-category by design
and does **not** participate in this rotation.

History, Geography, Movies & TV, Music, Sports, Science, Technology,
Literature, Art, Food & Drink, Animals, Nature, Pop Culture, Mythology,
Video Games, Fashion, Astrology, Health, Space, World Capitals.

Rotation index stored in `category_rotation/state` (single doc), Classic
tournaments only.

### Per-trigger output
- **Parallel jobs (not chained):** Each 07:00 UTC and 23:00 UTC clock tick
  schedules **two independent cron paths** that share only the slot timing:
  **(a)** Classic generation (LLM-driven, single-category), **(b)** Live doc
  preparation (`prepareLiveTournament`, no LLM). Neither waits on the other's
  outcome.
- **Classic — each trigger (07:00 UTC and 23:00 UTC):** **20 questions**
  (EN only), generated by LLM via `LLMService` (provider fallback chain —
  Gemini Flash → GPT-4o-mini → Claude Haiku). All 20 are written to
  `questions_public` (the global pool) and bound to the Classic
  `tournaments/{slotId}` for that slot. **One Classic tournament per
  trigger** → **40 LLM-generated questions/day** (2 triggers × 20). Live
  does **not** reuse Classic's `q_ids`.
- **Live — doc + questions:** `prepareLiveTournament` creates the Live doc for
  the slot (`q_ids` empty at create). Its **20 questions are not generated or
  chosen at doc-create time.** At **tournament start**, `runLiveTournament`
  will select 20 rows from `questions_public` (**equal 4/4/4/4/4 distribution
  across difficulties 1–5**; mixed-category). No LLM call for Live question text.
- → **4 tournaments per day** (2 Classic + 2 Live). **AI pipeline load for
  tournaments:** **40 new questions/day** from Classic generation only — not
  80.

### Bootstrap pool
- **Pre-launch seed: 4,000 questions** (20 categories × 200 each).
- Seed batch script runs ~1-2 weeks before launch. Quality gate:
  50-question pilot batch first → manual review → prompt calibration;
  full 4,000 batch only after pilot passes; per-category sample audit
  (20 questions per category, manually checked).
- **No "ghost tournament run."** Pool is fed organically post-launch by
  the engine itself (40 questions/day, ~1,200 questions/month).
- Total day-1 pool: ~4,000 questions. Sufficient for Self-Test, Duel,
  Arena pre-set category, and Daily Question across all 20 categories.

---

## AI PIPELINE — 2-LAYER VERIFICATION

Every AI-generated question goes through this pipeline via `LLMService`.

### Layer 1 — Generator
- **Primary:** Gemini 2.5 Flash. Failover chain: Gemini → OpenAI → Anthropic.
- **Output schema:** `{question, options[4], correctIndex, category, difficulty}`.
  No `explanation` field.
- **Generator prompt MUST instruct:** "If unsure of any date, figure,
  name, or source, do not generate the question." US English spelling
  is the default for all user-facing strings.
- **Content rating prompt constraint** (see Age Rating §): "Avoid
  promoting alcohol, tobacco, or drug use. Historical or factual
  references acceptable but no glamorization."
- On total provider failure (all three timeout / rate-limit / malformed
  JSON): write to Crashlytics, return null; calling function surfaces
  `error_question_load_failed`.

### Moderation
- **OpenAI Moderation API** (free tier).
- Categories checked: hate, sexual, violence, self-harm, illicit,
  political-extremism.
- Any flag → reject the question, do not retry, regenerate fresh.

### Layer 2 — Correctness verifier
- A **different provider** from the generator (failover chain skips the
  generator's provider for this call). Asymmetry enforced via
  `pickVerifierProvider` — verifier MUST differ from the generator that
  produced the candidate question for that specific call.
- Prompt: "Is the marked correct answer actually correct? Are the wrong
  answers genuinely wrong (not also correct)?"
- Verifier failure (network / API error) → reject question, regenerate.
- Verifier "incorrect" verdict → reject, regenerate.
- **No `verifierStatus: "skipped"` path. No flag-and-keep.**

### Semantic dedup
- **OpenAI `text-embedding-3-small`**.
- **Embed text construction (`buildEmbedText`):** the embedding input
  combines the question text, the correct answer, and all four options
  — not the question stem alone. Pilot testing showed stem-only
  embeddings produced false negatives (semantically distinct stems
  sharing overlapping answer sets cleared the threshold). Including
  options sharpens cluster separation for category-bucketed comparisons.
- Cosine threshold: **0.88** against existing `questions_public`
  embeddings of the same category. Calibrated against pre-launch pilot
  batch. With the enriched `buildEmbedText` shape, 0.92 was too
  permissive — richer vectors push natural similarity higher, so a
  lower threshold is needed to catch true near-duplicates without
  false rejects.
- Hit (≥0.88 similarity) → reject, regenerate.
- Threshold and embed-text shape are owned by
  `functions/src/shared/embeddings.ts` and
  `functions/src/shared/pipeline.ts`. Changes there must be reflected here.

### Reject policy is uniform
Any of moderation fail / verifier fail / dedup hit → discard and
regenerate. **No flag-and-keep. No retry of the same prompt** — the
next attempt is a fresh generation.

**Planned complement:** prompt-level dedup avoidance (e.g. feed last *N*
questions per category into the generator prompt so the LLM avoids
near-duplicate "popular" stems). Tracks alongside reactive embedding
dedup; see `BRAINJAMIN_TODO.md` § P1 (generator prompt dedup avoidance).

### Affected Cloud Functions
- `generateClassicTournamentContent` — uses LLMService + verifier + dedup
- `generateArenaQuestions` (custom topic path) — uses LLMService + verifier
- `selectDailyQuestion` — pool-only, no LLM
- `findOrCreateDuelMatch` — pool-only, no LLM

### Cost projection
- Per question: ~2 LLM calls (generator + correctness verifier) + 1
  embedding call. Per question ~$0.0002 (Gemini Flash dominant).
- Daily generation: ~40 questions (Classic tournament engine only) + ad-hoc Arena
  custom topics → ~50-100/day → **$0.50-2/day → $15-60/month** in
  steady state.
- **Live tournaments do not invoke the AI pipeline** — they consume from the
  existing pool. Cost projection is unchanged from prior versions.
- Seed batch (4,000 questions, one-time): ~$1-3.
- Provider fallback bursts in incident months: +$5-15.

---

## ANALYTICS

Hybrid event taxonomy: critical metrics are server-side and authoritative;
UI funnel events are client-side via Firebase Analytics SDK. **No BigQuery
dependency** — server-side events `FieldValue.increment()` directly to
`admin_metrics/{dateKey}`. Client-side events stay in default Firebase
Analytics dashboard, surfaced via deep-link from admin dashboard.

### Engagement DAU
DAU = users with at least one **gameplay action** on a given day (Daily,
Self-Test, Arena, Duel, Classic, or Live participation). Pure `app_open`
without engagement does NOT count toward DAU. Engagement DAU is the
canonical metric for retention.

### Cohort granularity
Retention measured at: **D1, D3, D7, D14, D30**. D3 surfaces onboarding
holdup; D14 surfaces streak motivation. Three-cohort (D1/D7/D30) alone is
too sparse for ASO iteration.

### Event taxonomy — 18 events
Distributed across 7 buckets: Lifecycle (3) — `app_open`,
`onboarding_complete`, `auth_converted`. Daily (2) — `daily_started`,
`daily_completed`. Self-Test (2). Arena (3) — `arena_created`,
`arena_joined`, `arena_completed`. Duel (3). Tournament (3) —
`tournament_joined`, `tournament_completed`, `live_late_joined`.
Monetization (2) — `ad_impression`, `ad_clicked`.

Server-side events (those that affect XP, scoring, conversion, or
retention) are authoritative — fire from CFs and increment
`admin_metrics/{dateKey}`. Client-side events fire from Firebase
Analytics SDK for UI funnel actions. Authoritative param schemas live
in `functions/src/analytics/` constants — query directly for exact names.

### Aggregation
`aggregateAdminMetrics` CF runs nightly (UTC 00:30) and rolls up the
previous day's server-side increments into `admin_metrics/{dateKey}`
for dashboard read. Server-side events also write directly to
`admin_metrics/{dateKey}.{counter}` via `FieldValue.increment(1)` at
fire time, so the dashboard has near-real-time counters during the day;
the nightly CF reconciles and computes derived metrics (retention
cohorts, conversion rates).

---

## NOTIFICATIONS & PUSH

### Push frequency budget — category-based caps

Per-user daily caps:

| Category | Hard cap | Notes |
|---|---|---|
| Daily reminder | 1/day | User's local 19:00 |
| Streak risk | 1/day | User's local 22:30, quiet-hours-exempt |
| Live tournament 5min | 2/day | Two slots (07/23 UTC), quiet-hours-exempt |
| Duel-related | 3/day | Most prone to multiplying for active users |
| Other game updates | 2/day | Arena complete, etc. |

Pushes that exceed the per-category cap are silently dropped at the FCM
dispatch layer **but** the corresponding event is still written to the
in-app notification center. User never loses information; they may miss
the OS notification. Streak-at-risk and Live-tournament-5min remain
quiet-hours-exempt.

### iOS / Android push permission — primer pattern

iOS push permission is requested **just after the user completes their
first Daily Question** — not at onboarding. A Brainjamin-voiced soft
primer is shown first, then the iOS native dialog. Soft primer "Not now"
→ 7-day cooldown, prompt retried.

**Android (API 33+)** uses the identical primer pattern in parallel —
runtime POST_NOTIFICATIONS permission is requested after first Daily
completion with the same soft primer.

### Quiet hours — default 22:00–08:00 user local

Pushes queued during this window flush at 08:00 (or are dropped if a
fresher duplicate arrives). Window is configurable per-user in V2; V1
ships the default only.

Quiet hours exempt list (delivered immediately regardless of time):
- Streak-at-risk push (22:30 local — just before midnight cutoff)
- Live tournament 5-minute warning (time-critical synchronous game)

### Settings — push category toggles (2 categories)

User-facing Settings exposes two toggles only:
1. **Daily & Streak** — Daily reminder + streak risk pushes.
2. **Game updates** — Duel/Live/Arena/etc.

Five-toggle granularity is V2; two categories are sufficient for V1
without overwhelming the user with choice. Off → all pushes in that
category suppressed at dispatch, and the in-app notification center
still receives the entries.

### In-app notification center — canonical surface

The in-app notification center is the canonical surface for all
notifications. Push delivery may be capped, deduplicated, or dropped
during quiet hours; the user always sees the full history in the app.

**Visible in center:** dropped/quiet-hours pushes; achievement unlocks;
duel match found / complete; tournament results (Classic + Live); Live
5-min reminder; Battle Arena result push.

**NOT visible in center:** Daily reminder (Daily mode itself surfaces
this); Streak risk (already exempt-fired during quiet hours window).

Notification center entries have a 7-day TTL — older entries are
automatically purged.

### Push tone

All push copy is Brainjamin-voiced. Copywriter authors final EN. Voice
direction lives in BRAINJAMIN_TODO.md § APPENDIX B (mascot brief).
Examples (baselines for copywriter):
- Daily: "Brainjamin's daily question is ready — bet you can crack it"
- Streak risk: "Brainjamin is worried! Your 12-day streak ends at midnight 🔥"
- Live 5min: "Brainjamin is warming up — Live tournament starts in 5"
- Duel match: "Brainjamin found you a worthy opponent 🥊"
- Battle Arena result: "Brainjamin's arena wrapped up — want to see how it ended?"

---

## ONBOARDING & TUTORIAL

### Onboarding flow — 3 screens

1. **Welcome + mascot intro** — single-sentence Brainjamin self-intro,
   mascot illustration prominent.
2. **Age gate** — neutral birth year + month picker. Under-13 blocks
   onboarding completion.
3. **Sign-in primer** — explains anonymous-first policy. 3 sign-in
   buttons (Apple/Google/Email) + "Skip — continue anonymous" link.

Push permission is **NOT** requested in onboarding; it's deferred to the
post-first-Daily primer. ATT prompt is also **not** in onboarding — it
fires before the first ad load.

### Mode-specific coach marks — lazy contextual pattern

No upfront full tutorial. Each game mode shows a 1-2 screen coach mark
on **first entry only**. Persistence: `users/{uid}.tutorialSeen.{mode}:
bool` (server-side for permanent users, local SharedPreferences for
anonymous, migrated server-side on conversion).

Coach mark count per mode:
- **Daily / Self-Test / Duel / Classic / Live:** 1 screen each
- **Arena:** 2 screens (List vs Battle distinction)

Total: **7 mini coach mark screens** across 6 modes. Each is dismissible
with a Skip button. Copy: copywriter EN, Brainjamin-voiced.

### Push primer pattern (referenced by other sections)

Pattern: Brainjamin-voiced soft prompt → user accepts → OS native dialog.
"Not now" on soft prompt → 7-day cooldown, retry. Used for:
- Push notification permission (after first Daily completion)
- ATT prompt (before first ad load — see Monetization § ATT & UMP)

Industry data: soft primer lifts opt-in roughly 25% → 50–60% range. iOS
deny is one-shot (Apple rule); reducing deny risk via primer preserves
AdMob eCPM.

### Mascot placeholder pattern (Sprint 1.3)

Until the AI-generated mascot deliverable lands, mascot in onboarding +
coach marks renders as a placeholder (geometric shape + brand orange +
"Brainjamin" text label). All copy is already in mascot voice; asset
swap (replace `assets/mascot/*`) does not require code refactor. Asset
spec: BRAINJAMIN_TODO.md § APPENDIX B.

---

## REPORTING & USER MODERATION

### Report button — placement and pattern

A "Report this question" entry sits behind a **3-dot overflow menu** on
every question card. Six surfaces require this:

1. Daily Question (question screen + result screen)
2. Self-Test (every question screen)
3. Arena (every question screen, list + battle modes)
4. Duel (every question screen)
5. Classic Tournament (every question screen + result screen)
6. Live Tournament (only on **reveal screen** — never during the active
   15s answer window, to avoid gameplay disruption)

The overflow menu also exposes "Copy answer" / "Show explanation" where
relevant; report is one entry within it. Pattern is consistent across
modes.

### Report submission form

Tap "Report" → modal with:
- **Reason dropdown** (single-select, required): Wrong answer marked
  correct / Question is wrong or unclear / Inappropriate content / Other
- **Free-text field** (optional, max 200 chars)
- **Submit button** → toast confirming receipt (no SLA promised in toast)

### Rate limits and dedup

- **Per-user cap:** 10 reports per day. 11th attempt → toast: "too many
  reports today, try tomorrow." Counter:
  `users/{uid}.dailyReports.{dateKey}` server-side, enforced in
  `submitReport` CF.
- **Same-question uniqueness:** A given user cannot report the same
  question twice. `reports/{reportId}` enforces composite uniqueness on
  `(userId, questionId)`.

### Triage SLA (internal, V1)

- **"Inappropriate content" reason:** triggers immediate FCM push to
  Mert's device via `submitReport` CF (Mert is the only V1 admin).
  Time-critical for child safety + Apple Review compliance.
- **All other reasons:** weekly batch review. Mert opens the `reports`
  collection in Firebase Console every Sunday during the first 4 launch
  weeks; thereafter as volume warrants.

The SLA is not surfaced to users.

### Triage actions (Console-only, V1)

Mert's three available actions, performed manually via Firebase Console:
1. **Delete question** — remove `questions_public/{qId}` doc. Past
   gameplay sessions retain references; UI does not break (questions
   already answered are not re-fetched).
2. **Flag question** — set `questions_public/{qId}.flagged: true`.
   Engine skips flagged questions; Mert later reviews/edits via
   `/admin/quality` (Sprint 7).
3. **Ban user** — set `users/{uid}.banned: true`. Security rules deny
   all reads/writes from banned users.

`/admin/quality` UI ships V1; finer triage UI (resolve/dismiss with
reason, audit log per report) is V2.

### Pool query exclusion

`flagged: true` questions are excluded from every pool query:
`questions_public.where('flagged', '==', false)` is a hard requirement
in `selectDailyQuestion`, `findOrCreateDuelMatch`, Self-Test category
queries, Arena pre-set queries, and tournament question selection.

---

## SUPPORT & HELP

### Settings → Help screen

Single screen, top to bottom:

1. **FAQ accordion** — 12 questions across 4 categories: Account (3),
   Gameplay (4), Issues (3), Legal/Privacy (2). Copywriter authors EN
   final.
2. **Contact Support** — `support@brainjamin.com` mailto link. Template
   pre-fills subject and includes device / OS / app-version info in
   body. For anonymous users, the Firebase anonymous UID is also
   auto-included so user identification is possible.
3. **Privacy Policy** link (renders from `legal_docs` or external to
   `brainjamin.com/privacy`).
4. **Terms of Service** link (same).
5. **App version + build number** (small gray text at bottom — useful
   when a user is asked for it during support triage).

### "Report a Bug" path

A separate "Report a Bug" CTA on the Help screen launches the same
mailto template but with subject "Brainjamin Bug Report" and a body
prefilled with `Device: ..., OS: ..., Version: ...` placeholders.
Funnels bug reports into a triageable inbox stream.

### Reply SLA — internal only

No user-facing SLA promise. Mert's internal target is best-effort within
~3 business days; auto-reply / first-response copy stays warm but
non-committal.

---

## QUESTION POOL GROWTH POLICY

### Year 1 trajectory and threshold
- Engine generates ~40 questions/day → ~1,200/month → ~14,400/year.
- Arena custom topics: estimated ~150–500/month additional.
- Year 1 estimate: **~24,000 questions** in `questions_public`.
- Year 3 projection: ~70,000.

Storage cost (Firestore $0.18/GiB·month) is negligible at any foreseeable
scale (~24MB at Year 1). The intervention threshold is set on
**per-category count**: 15K questions in any single category. Reactive
intervention only — no proactive optimization.

### Archive policy — V2 (no V1 logic)

V1 ships **no archive logic**. The 12-month-stale archive trigger does
not fire on a Year-1 pool, so writing the archive CF in V1 is wasted
work.

V2 implementation:
- **Archive trigger:** A question with `lastShownAt` older than 12
  months (or never shown after creation) is moved from `questions_public`
  to `archived_questions`.
- `questions_public/{qId}.lastShownAt: timestamp` is updated by every
  question-show event (Daily/Self-Test/Arena/Duel/Tournament read paths).
- `archived_questions` retains read-only access for past tournament
  sessions referencing archived qIds. `getQuestionById(qId)` lookup
  order: `questions_public` → `archived_questions`. Active gameplay
  queries remain restricted to `questions_public`.
- **Embeddings parallel:** archived embeddings move to
  `archived_embeddings` (kept in sync with question archive). Active
  dedup query stays restricted to `embeddings`.

### Sharding plan (V2+)

Three-stage escalation when a category exceeds 15K:

1. **Stage 1 (15K–30K/category):** add composite index `(category,
   flagged, lastShownAt)`. No structural change. Stage 1 indexes are
   pre-defined in V1's `firestore.indexes.json` so they ship with the
   first deploy — query plan is ready ahead of need, zero deploy delay
   when Stage 1 hits.
2. **Stage 2 (30K–50K/category):** add `archived: bool` filter; cold
   storage isolated. Active query becomes
   `where('archived', '==', false)`.
3. **Stage 3 (50K+/category):** subcollection sharding refactor —
   `questions_public/{categoryId}/items/{qId}`. Major migration; treated
   as V3-tier work.

### `ai_cache` TTL

`ai_cache` entries carry `expiresAt: timestamp` (90 days from creation).
Firestore TTL policy is configured on this field at deploy time —
expired entries are auto-deleted by Firestore with no CF needed.

---

## ARCHITECTURE — Single panel

### Hosting (Firebase Hosting)
| Surface | Site | Public path | Live domain |
|---|---|---|---|
| User app | `brainjamin-prod-user` | `build/web` | `app.brainjamin.com` (TBD) |
| Landing | `brainjamin-prod-landing` | `landing/public` | `brainjamin.com` |

Single user-app target. Admin lives **inside** the user app at
`/admin/quality` and `/admin/dashboard`, gated by `users/{uid}.isAdmin`.

### Entry points + routers
- `lib/main.dart` → single `AppRouter`
- `lib/router/app_router.dart` — go_router-based routing (post Sprint 1.4
  migration; the earlier `lib/core/routing/` path is superseded)
- `lib/core/bootstrap/app_bootstrap.dart` for Firebase init

### Stack
- **Frontend:** Flutter (single codebase → web bundle + iOS + Android)
- **Backend:** Firebase (Firestore, Cloud Functions, Hosting, Storage,
  Auth, Realtime Database for `.info/serverTimeOffset`, Crashlytics)
- **AI:** Gemini API primary; OpenAI + Anthropic fallback. OpenAI also
  for embeddings (`text-embedding-3-small`, 0.88 cosine for dedup).
- **Subscription billing:** None in V1. (V2: RevenueCat.)
- **Payment:** None in V1.
- **Domain registrar:** GoDaddy (`brainjamin.com`).

### Test devices
- Samsung SM-G990E (physical Android)
- iPhone (TBD — needs Apple Developer enrollment to provision)
- Android emulator API 35: BANNED (MainActivity bug — do not use)

---

## DATA MODEL — key collections

### Game content
- `tournaments/{slotId}` (Classic) — `slot_id`, `slot_key` (`07utc` \| `23utc`), `mode: "classic"`, `status` ∈ `generating` \| `ready` \| `visible` \| `ended` \| `generation_failed`, `category_id`, `starts_at`, `ends_at`, `q_ids[]`, `generated_count`, `ready_at`, `visible_at`, `ended_at`, `failed_at`, `failure_reason`, `failed_at_index`, `attempts_summary` (JSON string when generation aborts), `total_participants`, `created_at`, `updated_at`.
- `tournament_sessions/{sessionId}` — `session_id`, `slot_id`, `uid`, `status` ∈ `in_progress` \| `submitted`, `shuffled_questions[]`, `shuffled_correct_indices[]`, `client_questions_snapshot[]`, `question_ids[]`, `answers[]`, `correct_count`, `rank`, `xp_awarded`, `xp_granted_at`, `submitted_at`, `created_at`, `updated_at`.
- `tournament_leaderboards/{slotId}` — denormalized rollup after Classic finalize: `slot_id`, `ended_at`, `total_participants`, `top_100[{rank, uid, display_name, correct_count, submitted_at}]`, `created_at`.
- **Live (state machine)** — `live_tournaments/{ltId}`, `live_participants/{ltId}/users/{uid}`,
  `live_questions/{ltId}/q/{qIndex}`, `live_results/{ltId}/users/{uid}`. Driven by
  `runLiveTournament` / `finalizeLiveTournament`. **Created by `prepareLiveTournament`**
  (independent of Classic). **`q_ids` populated at tournament start** from
  `questions_public` (**equal 4/4/4/4/4 across difficulties 1–5**; mixed-category); not
  shared with Classic `q_ids`. `live_tournaments` includes `status` (e.g. `scheduled`,
  `running`, `ended`, `no_participants`, `no_pool_questions`, `generation_failed`),
  `starts_at`, `q_ids`, `current_question`, `reveal_active`, `late_join_closed`,
  `total_participants`, `last_heartbeat_at`, **`lock_holder`**, **`lock_expires_at`**
  (doc lease, Sprint 4.3 Step 2a-fix), **`finalized_at`**, **`top_100`** (rank rollup),
  **`total_finalized_participants`**, timestamps. **`live_questions/{ltId}/q/{qIndex}`:**
  `q_id`, `question_text`, `options` (4 strings), `difficulty`, `category`,
  `started_at`, **`correct_index`** (null until reveal). **`live_results/{ltId}/users/{uid}`:**
  `uid`, `correct_count`, `total_answer_ms`, `raw_answers`, `submitted_at`, `scored`,
  `rank`, `xp_awarded`, `xp_granted_at`.
- `arenas`, `arena_questions/{arenaId}/q/{qId}`, `arena_participants` —
  user-created arenas with `status: "preparing" | "scheduled" | "active"
  | "ended" | "expired"`
- `duels`, `duel_questions` — async 1v1 games. `duels/{duelId}.status`
  state machine: `waiting` (created, no opponent yet) → `matched`
  (opponent attached before creator finished) OR `player1_done`
  (creator finished solo before opponent attached) → `player2_done`
  or back to `player1_done` after first submit → `completed` after
  second submit. `expired` is terminal. The random matcher and
  invite join both accept `player2_id == null AND status IN
  (waiting, player1_done)` to allow attaching an opponent to a
  duel where the creator already finished. `duel_questions` are
  written at `createDuel` time (Model A), not lazily on first
  `getDuelQuestions` call.
- `duel_queue/{uid}` — matchmaking queue (no `_lang` segmentation; EN-only)
- `daily_questions/{dateKey}` — single document per day (no `_lang` suffix)
- `daily_answers` — user submissions
- `self_test_sessions` — per-user 25-Q self-test runs
- `self_test_leaderboard/{categoryId}_{weekKey}` — category × week buckets

### Question pipeline
- `questions_public` — global pool, the master collection
- `questions_public/{qId}.lastShownAt: timestamp` — updated on every
  question-show event (used by V2 archive trigger; V1 still writes it
  so V2 archive has data when it ships)
- `archived_questions` — V2 (cold storage for archived questions)
- `archived_embeddings` — V2 (cold storage for archived embeddings)
- `used_questions/{uid}/seen/{qId}` — per-user "seen in last 30 days"
  dedup (TTL semantics enforced at read time)
- `category_rotation/state` — single doc: `currentIndex`, `lastRotatedAt`, `updatedAt`, `categories[]` (20 canonical ids, snake_case — same order as `functions/src/shared/categories.ts`: history, geography, movies_tv, music, sports, science, technology, literature, art, food_drink, animals, nature, pop_culture, mythology, video_games, fashion, astrology, health, space, world_capitals)
- `blocked_terms/{en}` — content filter for custom Arena topics
- `blocked_terms/usernames` — content filter for username creation/change
- `ai_cache` — LLM response cache. Each entry has `expiresAt: timestamp`
  (90-day TTL via Firestore TTL policy).
- `embeddings/{qId}` — `text-embedding-3-small` vectors over
  `buildEmbedText` output (question + correct answer + all four
  options), 0.88 cosine threshold

### Identity + audience
- `users/{uid}` — main user doc (xp, level, streak, percentile, fcm_token,
  timezone, isAnonymous, isAdmin, banned, last_export_at,
  usernameChangedAt, forceRename, profileNudgeHiddenUntil,
  tutorialSeen.{mode}, dailyReports.{dateKey})
- `users_public/{uid}` — denormalized public profile (displayName, xp,
  level, country). **Created lazily on anonymous→permanent conversion.**
  Anonymous users have NO `users_public` doc.
- `usernames/{username}` — uniqueness reservation (lowercase doc id,
  atomic transaction in `validateUsername`). Permanent release on
  change (no TTL reservation hold).

### Leaderboards (V1)
- `leaderboards/global` — denormalized top 100 by total XP, rebuilt by
  `rebuildLeaderboards` CF
- `leaderboards/weekly_{weekKey}` — denormalized top 100 by weekly XP,
  rebuilt by `resetWeeklyLeaderboard` CF
- `self_test_leaderboard/{categoryId}_{weekKey}` — Self-Test specific
- `tournament_leaderboards/{slotId}` — Classic tournament top 100 after
  `finalizeClassicTournament` (see Game content)

### Achievements (V1)
- `achievements/{uid}/earned/{achievementId}` — per-user earned rozet
- Achievement definitions are **client-side static** (Dart enum + asset
  paths), not Firestore. Tasarım değişirse app update gerekir.
- **17 launch achievements:**
  - Streak (4): 3, 7, 30, 100 days
  - Volume (4): first question, 100, 1000, 10000 answered
  - Tournament (4): first joined, top-10, top-3, rank-1
  - Mode-specific (4): first duel win, Self-Test 25/25, first arena
    created, first Live joined
  - Special (1): launch-week early adopter

### Account lifecycle
- `deleted_accounts/{uid}` — 30-day soft delete queue (scheduledFor,
  originalEmail, originalUsername)

### Notifications (V1)
- `push_queue/{uid}/pending/{pushId}` — quiet hours queue. Each push
  has `respectQuietHours: bool` flag. Streak-at-risk and
  Live-tournament-5min push set this to `false` (delivered immediately).
- `notifications` — service-category push history + in-app notification
  center backing store. 7-day TTL on entries.

### Reports & moderation
- `reports/{reportId}` — user-submitted report on content. Composite
  uniqueness on `(userId, questionId)`. Apple Review requires this
  surface to exist and be reachable. Admin reads via Firebase Console
  in V1; UI in V2.

### Ops
- `session_secrets` — server-authoritative session timing
- `app_settings`, `ai_config`, `arena_config` — runtime configs
- `admin_metrics/{dateKey}` — daily aggregated snapshot for read-only
  admin analytics dashboard. Receives `FieldValue.increment()` writes
  from server-side analytics events plus nightly `aggregateAdminMetrics`
  reconciliation.
- `admin_broadcast_log` — admin actions audit
- `legal_docs` — Privacy Policy + ToS versioned content

### Anti-cheat / timing
- `live_tournaments/{ltId}` — server-authoritative timing fields include
  `current_question`, `reveal_active`, `late_join_closed`, `last_heartbeat_at`,
  `status`, plus lease fields `lock_holder`, `lock_expires_at` where applicable.
- `live_questions/{ltId}/q/{qIndex}.started_at` — server timestamps for question
  windows; per-question submits are scored server-side (`submitLiveAnswers`).
- `live_results/{ltId}/users/{uid}.submitted_at` — server timestamp on result rows.
- All score calculation is server-side (`finalizeLiveTournament` and
  `finalizeClassicTournament`). Client `score` value is candidate only.

---

## CLOUD FUNCTIONS

V1 Cloud Functions are organized into the groups below. Authoritative
list of exports lives in `functions/src/index.ts` — query the file
directly for exact names.

- **Tournament engine** — Classic: scheduled `generateClassicTournamentContent`,
  `makeClassicTournamentVisible`, `finalizeClassicTournament`; callables
  `getClassicTournamentQuestions`, `submitClassicTournamentAnswers`,
  `getClassicTournamentReveal`. **Live (deployed):** **`prepareLiveTournament`**
  (scheduled `0 7,23 * * *` UTC; idempotent doc creator for `live_tournaments/{ltId}`,
  no LLM, no Classic dependency). **`runLiveTournament`** (scheduled every minute;
  lease-protected server loop; at start pulls 20 questions from `questions_public`
  with **4/4/4/4/4** difficulty distribution). **`submitLiveAnswers`** (callable;
  server-side scoring; clamps per-answer elapsed to `[0, 15000]` ms). **`finalizeLiveTournament`**
  (scheduled every minute; lease-protected; competition ranking, XP grants, `top_100`
  rollup). **`joinLiveTournament`** (callable; idempotent join with banned-check).
  **`fastForwardLiveStart`** (admin-only callable; smoke helper; bumps `starts_at`
  forward by 1–60 minutes). Live question selection uses **no LLM** and **does not**
  share Classic's LLM path or Classic `q_ids`. **Parked (Step 2c):** watchdog stall
  recovery + T-5min push (see BRAINJAMIN_TODO.md). **Classic XP and rank** are
  written only in `finalizeClassicTournament`, not at submit time.
- **Daily / Self-Test / Duel** — pool-only selection + matchmaking
  callables (no LLM)
- **Arena** — callable: LLM for custom topic, pool for pre-set
  category; Battle Arena result push to eliminated participants on
  `status: "ended"`
- **Watchdog & cleanup** — Live tournament stall recovery, 7-day TTL
  prune for duels + arenas (arena-participant-count cancellation does
  NOT apply; solo arena is valid)
- **Leaderboards** — hourly rebuild (global + Self-Test category),
  weekly Sunday 23:59 UTC reset
- **Identity** — `validateUsername` atomic transaction across
  `usernames/`, `users.displayName`, `users_public.displayName`;
  enforces format, block list, 30-day cooldown
- **Achievements** — auth-trigger + game-event-trigger, idempotent
- **Notifications** — daily reminder (local 19:00), streak-at-risk
  (local 22:30, quiet-hours-exempt), duel/arena lifecycle pushes,
  queued push flush every 30 min, category-cap enforcement at dispatch
- **Account lifecycle** — soft delete (30-day queue), purge after 30
  days, GDPR/CCPA data export
- **Anonymous → permanent** — `onUserConverted` auth trigger, creates
  `users_public/{uid}` doc on first non-anonymous sign-in; fires
  `auth_converted` analytics event server-side
- **Admin / analytics** — daily metrics aggregation
  (`aggregateAdminMetrics`, UTC 00:30); report submission
  (`submitReport`) callable with FCM alert to Mert on "inappropriate
  content" reason
- **Embeddings / dedup** — generation (called from question creation
  flows) + backfill (admin-triggered for historical questions)
- **Cleanup utilities** — `wipeTestData`, `seedQuestions` (4k
  pre-launch seed), `seedLegalDocs`, one-shot launch asset functions

### Internal modules (not deployable functions)
- `LLMService` — provider fallback chain (Gemini → OpenAI → Claude)
- `ServerTimeService` — client-side time sync (Flutter)
- `pickVerifierProvider` — generator-vs-verifier asymmetry helper
- `semanticDedup` — embedding cosine check
- `mcqShuffle`, `mcqCorrectLetter` — answer shuffling utilities
- `aiJsonParse` — robust JSON extraction from LLM outputs

---

## SECURITY MODEL

### Server time authority
All temporally meaningful Firestore writes use
`FieldValue.serverTimestamp()`. `Timestamp.now()` (client clock) is
forbidden anywhere in the code path that affects scoring, streak, state
transitions, or game timing.

Client-side, the `ServerTimeService` Dart class syncs from Firebase
Realtime Database `.info/serverTimeOffset` once at app start; the
offset is cached in memory; all UI countdowns use
`ServerTimeService.now()`. Raw `DateTime.now()` is permitted only for
cosmetic UI elements (e.g. "Last updated 2 minutes ago" relative
timestamps).

Daily Question / streak day computation uses
`serverTime.in(userTimezone).toISODate()` (luxon or date-fns-tz on
Cloud Functions). Travel handling: when user changes timezones, CF uses
the **current** timezone for the day computation. No timezone-change
tracking needed.

### Auth & data access
- **Anonymous users CAN play everything.** Anonymous CANNOT: appear in
  leaderboards (no `users_public` doc), be friends (V2), subscribe (V2).
- **No phone verification gate** anywhere.
- **Firestore admin gate:** `isAdmin()` is a hybrid OR —
  `request.auth.token.admin` OR `token.isAdmin` OR
  `users/{uid}.isAdmin` (with `exists()` guard before `get()`).
- **`users` doc** currently auth-readable for leaderboard/profile
  compatibility. Long-term: split private fields (`fcm_token`) to
  `users_private/{uid}` — V2.

### App Check
NOT activated yet. Defer until iOS Apple Developer enrollment is
complete so iOS (DeviceCheck/App Attest) and Android (Play Integrity)
ship together. Activation plan (deferred):
1. Add `firebase_app_check` to pubspec
2. Wire Play Integrity (Gradle) + DeviceCheck (iOS)
3. Activate debug provider in main
4. Register SHA-256 in Firebase Console
5. Flip `enforceAppCheck: true` on critical user-facing callables first
   (`submitAnswers`, `submitLiveAnswer`, `joinLiveTournament`,
   `joinUserArena`, `submitDuelAnswers`, `validateUsername`,
   `findOrCreateDuelMatch`, `generateArenaQuestions`, `submitReport`,
   `softDeleteAccount`, `exportUserData`)
6. Verify on physical device
7. Flip remaining callables in second wave

Do NOT enable on admin/seed/debug functions.

### Tournament integrity
- **Classic:** `getResults` returns full questions only when
  `status === "ended"`. Active tournaments return summary only.
- **Live:** `runLiveTournament` is the single authority on question
  advancement. Clients are listeners only.
- **Live reveal:** `correct_index` on each `live_questions/{ltId}/q/{qIndex}` doc is
  **null** until the server sets `reveal_active` for that beat; clients observe the
  field flip from **null → 0..3** at reveal.

### Anti-cheat
- **Timing:** Server timestamps mandatory for any temporally meaningful
  write. Client clock manipulation cannot inflate streaks or scores.
- **Username uniqueness:** Atomic transaction across 3 documents
  (`usernames/{lower}`, `users/{uid}.displayName`,
  `users_public/{uid}.displayName`).
- **Username change rate limit:** 30-day cooldown enforced server-side
  in `validateUsername` via `users/{uid}.usernameChangedAt`. Forced
  rename bypasses cooldown.

### Moderation
- Custom Arena topics filtered through `blocked_terms/{en}`
  (pre-generation) AND moderation API (post-generation).
- Username creation/change filtered through `bad-words` package +
  `blocked_terms/usernames` override list.
- Reports queue + admin Quality Review for manual moderation.
- **User moderation:** `users/{uid}.banned: true` flag. Security rules
  read this flag and deny all writes/reads from banned users. UI for
  setting flag is Firebase Console only in V1.
- **Forced rename:** `users/{uid}.forceRename: true` flag triggers
  non-dismissible modal blocking gameplay until valid replacement name
  is accepted.

---

## ADMIN PANEL — V1

Two real screens, both inside the user app at `/admin/*` routes, gated
by `users/{uid}.isAdmin`:

1. **Quality Review** (`/admin/quality`)
   - Lists `questions_public` filtered by `flagged: true`
   - Per question: approve / delete / edit
   - Used during launch weeks for prompt calibration

2. **Read-only Analytics Dashboard** (`/admin/dashboard`)
   - Reads `admin_metrics/{dateKey}` documents (populated by
     `aggregateAdminMetrics` CF + server-side analytics increments)
   - Sections: User metrics (Engagement DAU, MAU, signups,
     anon→permanent conversion, retention D1/D3/D7/D14/D30); Game mode
     sessions; Tournament participation per slot + completion rate;
     Question pool size + generation count + flagged rate + verifier
     reject rate; AI cost per provider; AdMob impressions/revenue
     (deep-link to AdMob console for detail in V1; native pull V2);
     30-day trend lines per metric.
   - CSV export per table.
   - Deep-link out to Firebase Analytics dashboard for client-side
     event drill-down (no BigQuery dependency in V1).

3. **User moderation** — Firebase Console only (no UI). Set
   `users/{uid}.banned: true` directly. Mert is the only admin in V1.

4. **Reports queue** — Firebase Console only (no UI). Admin reads
   `reports` collection directly. UI added in V2 if volume demands.
   "Inappropriate content" reason triggers FCM push to Mert in V1.

Admin V2 roadmap: User moderation UI, Reports triage UI (with
resolve/dismiss + audit log), Live ops dashboard with real-time charts,
Manual content tools (add/edit `questions_public` from UI), Friend
system moderation (when Friends ships V2).

---

## DESIGN

- **Brand color:** see Identity §. Don't restate.
- **UI direction:** vivid gradients, mobile-first.
- **Mascot:** see Identity § for personality.
- **Tone:** EN-native, Brainjamin voice. No aggressive monetization
  copy, no Duolingo-style guilt-trip beyond mild mascot personification.
- **All strings via Flutter `intl`** — `lib/l10n/app_en.arb`.
- **Push tone:** see NOTIFICATIONS & PUSH § Push tone.

### Mascot surfaces

The mascot **must appear** (visually or in voice) at:
- Onboarding welcome screen
- Push notifications (in copy, not as an avatar)
- Achievement unlock animations
- Empty states (e.g., "No tournaments right now — Brainjamin is cooking
  some up")
- Error states (e.g., "Brainjamin couldn't find that. Try again?")
- Loading screens (subtle — no skeleton-screen-replacing-with-mascot,
  but the mascot's silhouette or accent color is acceptable)
- Level-up cards
- Daily question reveal screen (mascot reaction to user's answer)
- Battle Arena eliminate moment overlay (worried expression)
- Anonymous Profile-tab nudge card
- Leaderboard inline gate for anonymous users
- ATT soft primer (in copy)

The mascot **does NOT appear** in:
- Active gameplay screens (would distract)
- Settings pages (utility, not personality)
- Privacy Policy / ToS legal documents (legal must be clean)
- Opponent display name fallback ("Anonymous Player" — neutral, no
  mascot rewrite)

When a Cursor prompt creates a new user-facing surface, classify it
into the "mascot appears" or "mascot absent" bucket and state which
in the prompt.

The mascot character bible is owned outside Cursor (Mert's brief to the
AI image generation tool + EN copywriter). Don't invent mascot
personality traits beyond what's documented here. Asset specification
lives in BRAINJAMIN_TODO.md § APPENDIX B.

### Design pipeline (Figma → Claude → Cursor)

- **Tool:** Figma + Figma Make. Workspace + master file link added at
  Sprint 4 brief time.
- **Design pass timing:** Sprint 4 sonu = brief yazımı (tüm screen
  iskeleti, route'lar, state'ler kod tarafında oturduktan sonra);
  Sprint 5 = implementation (Profile + Ranking + Achievements zaten
  kapsamlı UI sprint'i — design pass o sprint'in içinde Cursor
  prompt'larıyla uygulanır). Daha erken brief eksik feature'lar
  üzerinden tasarım yapılmasına yol açar → refactor.
- **Brand differentiator = mascot + brand orange + tone.** UX paternleri
  trivia kategorisinin convention'larını takip eder (Trivia Crack,
  Quizizz, Kahoot reference paternleri). "Özgür ve özgün tasarım"
  yalnızca mascot expression'larında, transition animasyonlarında ve
  accent detaylarında çıkar — **ana flow'da convention'a sadık
  kalınır**. Sebep: kullanıcı, tanıdık paternleri zihninde önceden
  bildiği için onboarding drop-off azalır → D1 retention korunur.
- **Pipeline sıralaması:** (1) Figma Make app'in tüm screen yapısı +
  flow'larını tasarlar; (2) Mert tasarımı Figma workspace'inde gözden
  geçirir, ince ayar yapar; (3) **Claude Figma MCP entegrasyonu** ile
  Figma node'larını okur — design tokens, exact CSS values, typography
  scale, component variants. Tahmin değil, Figma'dan exact değerler;
  (4) Claude her ekran için kapsamlı Cursor prompt yazar (Flutter
  widget tree + token referansları + spacing/sizing/color tokens +
  animation curves); (5) Cursor prompt'a göre Flutter implement eder;
  (6) Quality gate: flutter analyze + Chrome smoke + Samsung smoke.
- **Risk:** Figma Make HTML/Tailwind export'u Brainjamin için
  kullanılmaz (Flutter codebase). Tek doğru yol: Claude Figma MCP →
  Cursor brief.

---

## OPERATIONAL CONSTANTS

### Code Quality Gate (per Cursor prompt that touches code)
- `flutter analyze` → 0 errors
- `npm run build` (if functions changed) → 0 errors
- Claude reviews `flutter analyze` output for genuine bug risks
  (e.g. `use_build_context_synchronously`, `unawaited_futures`,
  `unused_local_variable` near logic) and flags them, even if not
  strictly required to fix.
- **Live tournament lease (Sprint 4.3):** `LEASE_DURATION_MS = 90_000` (lock
  self-expiry on `live_tournaments`), `LEASE_RENEWAL_INTERVAL_MS = 30_000`
  (renewed on transactional advance writes). Owned by
  `functions/src/shared/tournamentLease.ts` — **any change there must be reflected
  here.**

**Bootstrap / startup smoke check:** Every Cursor prompt that touches
bootstrap, service initialization, platform-conditional code, or any
code that runs on app start MUST also include a `flutter run -d chrome`
startup verification step. Cursor reports whether the app reached the
expected first screen without console-red errors. (Reason: `flutter
analyze` does not catch runtime initialization bugs.) Prompts touching
only leaf-level UI widgets or pure-Dart utilities don't need it.

### Test devices
- Samsung SM-G990E (physical Android)
- iPhone (TBD pending Apple Developer enrollment)
- **Android emulator API 35: BANNED** (MainActivity bug)

### Arena minimum lead time
Arena's `scheduledStartAt` must be ≥ now + 10 minutes. No bypass — not
even for admin. Validation enforced client-side AND server-side.
Maximum: `scheduledStartAt ≤ now + 24 hours`.

(Live tournaments have no manual creation; engine is fully autopilot
on fixed 07:00 UTC and 23:00 UTC schedule.)

### Password minimum length
Email/password sign-up and sign-in require minimum **8 characters**
(stricter than Firebase's default 6, aligned with NIST 2024 password
guidance).

The constant lives in `lib/core/constants/auth_constants.dart` as
`BrainjaminAuthConstants.minPasswordLength` and is read from there by
all auth surfaces. Hardcoded literals are forbidden. Future auth entry
points (Forgot Password reset flow, future Sign-In sheets, etc.) must
read the same constant.

---

## REVENUE EXPECTATIONS (REALISTIC)

Trivia category is saturated globally (Trivia Crack, QuizDuel,
LearnClash, Kahoot, Quizizz). Solo organic launch with no paid
marketing:

- **Year 1:** 5–15K total downloads, 500–2K MAU
- **AdMob revenue:** $50–200/month (depends on Tier 1 user mix density)
- **Year 2–3:** Compound ASO effect may push to $500–1500/month if
  retention holds

Long-tail bet. The "low marginal maintenance" architecture exists
because the math only works if ongoing operating cost stays near zero.
Subscription V2 can add another $10-50/month after retention is proven.

---

## OPERATIONAL CONSTRAINTS

- Mert does not write code. All implementation goes through Cursor.
- Communication languages: Cursor prompts in English, Mert ↔ Claude in
  Turkish, user-facing UI in EN.
- Marketing budget: minimal. ASO is the primary growth lever.
- Mert commits to **30 min/day for 3 weeks post-launch** for ASO iteration.
- All copy edited by EN-native copywriter pre-launch.
- Mascot visual assets generated via AI image tool (Mert-driven), not
  hired illustrator. Asset spec: BRAINJAMIN_TODO.md § APPENDIX B.

---

## REPO PROVENANCE

- **Brainjamin repo:** local app at `C:\flutter_projects\brainjamin`;
  git initialized during Sprint 1. GitHub remote
  `github.com/fmertbayer-star/brainjamin` may or may not be configured
  — verify with `git remote -v`.

Stratech Dynamic FZCO is the publishing entity.

- **Package name (Android):** `com.stratech.brainjamin`
- **Bundle ID (iOS):** `com.stratech.brainjamin`
- **Firebase project ID:** `brainjamin-prod-app`
- **Apple App Store Connect App ID:** `6765467964` (created 2026-04-30)

(Apple Sign In Service ID, Team ID, key ID, .p8 path → see
BRAINJAMIN_TODO.md § APPENDIX A.)

---

## OPEN QUESTIONS

No open architectural questions. All D-/E-/F- questions closed in
2026-05-04 and 2026-05-07 sessions; closure notes integrated into
relevant sections above. Future open items will be listed here as
they arise.

---

*End of BRAINJAMIN.md*
