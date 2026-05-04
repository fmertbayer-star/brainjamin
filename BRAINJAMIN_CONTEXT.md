# BRAINJAMIN — PROJECT CONTEXT
Last reviewed: 2026-04-30

Structural truth of Brainjamin. Updated only when major architectural decisions
change. Day-to-day work belongs in BRAINJAMIN_TODO.md. Behavior + project rules
belong in BRAINJAMIN_RULES.md.

Brainjamin is a global B2C trivia/quiz app. The Turkish B2B product (Flit) and
Brainjamin are independent — different repos, different stores, different
audiences. Flit continues in Türkiye; Brainjamin targets EN-only, US-first.

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
- **Brand color:** `#F97316` (orange, carried over from Flit). `#FF9F04` is
  BANNED everywhere — UI, code, prompts, comments (PR-1).
- **Domain:** `brainjamin.com` (or `brainjamin.net` if `.com` unavailable);
  registered for 3 years on GoDaddy.
- **Codebase:** New repo, clean copy of Flit user-side. B2B parts removed
  before first commit. NOT a feature flag fork.

### Markets — Tier 1 only (6 countries)
USA, UK, Canada, Australia, Ireland, New Zealand.

USA is the primary market; UK/CA/AU are organic spillover; IE/NZ are niche.
All English-native, all high eCPM. Excluded: every non-Tier-1 country.
Reason: low eCPM dilutes ASO ranking, requires extra language/copy work,
and brings retention drag.

### Languages
EN-only at launch. ES (Spanish) and other languages are explicitly **not**
in V1 scope. All user-facing strings via Flutter `intl` —
`lib/l10n/app_en.arb` only. No Turkish in user-facing surfaces.

### Age Rating
- **13+** (App Store + Google Play). 2026 Apple update replaced 12+ with 13+.
- Onboarding includes a **neutral age gate** — birth year + month picker (not
  Yes/No). Under-13 users are blocked from completing onboarding with a
  message: "Brainjamin is for ages 13 and up."
- COPPA compliance: privacy policy explicitly states no knowing collection
  from under-13 users.
- UGC moderation pipeline (custom topic Arena → blocked_terms + Gemini
  self-check + report flow + admin quality review + 7-day stale cleanup) is
  documented for Apple Review.

### Auth & Identity
- **Anonymous-first.** User can play everything without signing up — Daily,
  Self-Test, Arena (create + join), Duel (invite + queue), Classic and Live
  Tournaments. Anonymous users CANNOT: appear in leaderboards, earn
  achievements that require permanent account, or use friends features
  (V2-only anyway).
- 3 sign-in methods: Apple (mandatory on iOS per App Store rule), Google,
  Email + password.
- **No email verification mail** sent (reduces friction).
- **No phone verification** (no prizes, no need — Flit had it, removed in
  Brainjamin).
- Anonymous → permanent transition via Firebase `linkWithCredential`.
- **Anonymous users have NO `users_public/{uid}` doc.** It is created lazily
  by an auth trigger Cloud Function the moment the user converts to
  permanent. All XP, streak, achievements, and history are stored in
  `users/{uid}` from day one and survive the conversion intact.
- If account already exists on linking attempt: user is prompted; anonymous
  progress is lost if they sign into the existing account.
- Sign-in method changeable post-conversion (Profile → Settings → "Add or
  change sign-in method").

#### Apple Sign In identifiers (locked)

- **App ID:** `com.stratech.brainjamin`
- **Service ID:** `com.stratech.brainjamin.signin`
- **Apple Team ID:** `J863Y2PK9U` (Stratech Dynamic FZCO, shared with Flit)
- **Authorized callback URL:** `https://brainjamin-prod-app.firebaseapp.com/__/auth/handler`
- **Authorized domain:** `brainjamin-prod-app.firebaseapp.com`
- **Apple Sign In Key ID:** `L2K726P8TK`
- **Apple `.p8` private key** stored locally on Mert's machine outside repo (`C:\flutter_projects\secrets\brainjamin\AuthKey_L2K726P8TK.p8`). Server-side use deferred — not in V1 scope. If a future feature requires `.p8` (e.g., `revokeUserAccount`), it must be moved to **Firebase Cloud Secret Manager** at that time.

### Monetization — V1
- **AdMob:** Banner + Interstitial only. Rewarded explicitly **deferred to
  V2**.
- **Banner placements:** Duel lobby, Classic results, Self-Test lobby
  (carry over from Flit). Refined post-launch with real navigation data.
- **Interstitial placement rule:** Shown after game completion / score
  display, not interrupting gameplay. Frequency cap: max one per ~3
  minutes; suppressed entirely during the user's first 3 game sessions
  (onboarding-friendly).
- **AdMob compliance:** UMP consent SDK (GDPR/CCPA), ATT (App Tracking
  Transparency) prompt before first ad. Both are launch-blockers.
- **Subscription "Brainjamin Plus" → V2.** All Plus-related infrastructure
  (RevenueCat, `syncRevenueCatEntitlement`, `expirePlusSubscribers`,
  billing grace period from V1.12 C.12, `users.billingIssue` field,
  `ad_consent.subscriptionStatus` cross-reference) is excluded from V1.

---

## PRODUCT — 6 GAME MODES

### User-driven (4)

**1. Daily Question**
- 1 question per day. EN.
- **Source:** `questions_public` (NO LLM call per day; pool is pre-seeded
  and continuously refilled by tournament engine — see V1.12 A.1).
- Reset: server-time authoritative, displayed in user's local timezone.
  Server stores `dateKey = serverTime.in(userTimezone).toISODate()`.
- **No time limit on the question itself.** Daily is a "think and answer
  in your own time" mode — pressure would harm streak motivation.
- Streak counter; 1-day forgiveness per week (auto-resets on local Monday
  00:00 server-anchored). Forgive use is transparent — surface in profile
  as "🔥 12 days · 1 forgive available this week."
- Wrong answer does NOT break streak (per V1.2 rule). XP awarded:
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
- **Leaderboard scope:** category-bucketed AND weekly-reset.
  Path: `self_test_leaderboard/{categoryId}_{weekKey}`. Top 100 + user's
  own rank. Ties broken by remaining ms.
- Global all-time leaderboard exists separately (see Leaderboards section)
  but is XP-based, not Self-Test-specific.

**3. Arena** — invite-code group quiz
- User picks category OR types custom topic.
- 5–25 questions, user chooses count.
- 2 modes:
  - **List mode:** all answer all questions, score-ranked at end.
  - **Battle Arena mode:** wrong answer eliminates you. Eliminated user
    transitions to **spectator screen** — can watch remaining players in
    real-time, sees who answered what, sees standings update live. Submit
    button is disabled. Spectator screen offers "Create new arena" CTA.
    Last standing wins; ties broken by remaining ms.
- Invite code generated (e.g. `BJ-7K2P`) + shareable link.
- Private only — no public/community arenas in V1.
- Anonymous users CAN create arenas.
- **Limit:** 10 arenas/day per user (Remote Config: `arena_max_per_day: 10`).
- **Minimum delay:** Arena's `scheduledStartAt` must be ≥ now + 10 minutes.
  Validation enforced client-side AND server-side. Maximum:
  `scheduledStartAt ≤ now + 24 hours`.
- **Minimum players:** 1 (the creator). Even if no one joins, the arena is
  valid and runs solo at start time. Solo arena is intentionally allowed
  — content generation is paid for, ad surfaces appear, mechanic is
  consistent. `pruneStaleGames` does NOT cancel based on participant count.
- **3-step creation wizard** (Flit-derived):
  - Step 1 — Basics: List vs Battle, optional arena name
  - Step 2 — Details: Pre-set Categories vs Custom Topic toggle, category
    grid (when pre-set), question count slider (5–25), start time picker
    (calendar + time), estimated duration preview
  - Step 3 — Summary: Final review + "Create Arena" CTA
- **Custom Topic narrow check (apriori):** Before generation, the LLM is
  asked: "Can 25 distinct, high-quality, in-depth questions be generated
  for this topic?" If the answer is no, UI warns the user: "This topic
  may be too narrow. Try fewer questions or a broader topic." User can
  still proceed; if generation yields fewer than requested, pool-fill
  from related category supplements.

**4. Duel** — async 1v1
- 10 questions, mixed categories (one per category for variety).
- 15 sec/question.
- **Source:** `questions_public` only — never LLM-generated per duel.
  Per-pair dedup uses both players' `used_questions` history merged so
  neither has seen the questions.
- Two methods:
  - **Random match:** First 30 sec is active waiting screen ("Finding
    opponent..."). After 30 sec, transitions to background mode — user
    can close app, will receive push when matched. Background queue TTL:
    24 hours. After 24 hours unmatched, user dropped from queue with
    push: "No opponent found in 24 hours. Try again or send an invite link."
  - **Invite link:** User shares link, opponent plays when ready. Link
    expires after 7 days. If unused, the inviter receives 10 XP
    consolation.
- Both players answer same 10 questions, async (different times).
- **Same-opponent dedup:** A user is not matched against an opponent they
  faced within the last 24 hours.
- **No bots.** If queue is empty, user waits.
- XP: Win +50, Draw +25, Loss +10.

### Auto-generated (2 — engine new in Brainjamin, did not exist in Flit)

**5. Classic Tournament**
- 20 questions, 4-choice multiple choice.
- 24 hours open, async (Flit-style).
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
- Synchronous — all players see same question at same instant, driven by
  server-side authoritative loop (no client clocks).
- **No registration.** Anyone in lobby at start time joins.
- **Late entry open through Q5 reveal**, then closes. Missed questions
  before joining auto-skip to 0 points. (`lateJoinClosed: true` flag set
  by server after Q5 reveal completes.)
- Push notification 5 minutes before start (Brainjamin-tone, service
  category, **exempt from quiet hours queue**).
- XP scale (2x classic because real-time pressure):
  - Rank 1: 1000 XP
  - Rank 2-3: 600 XP
  - Rank 4-10: 400 XP
  - Rank 11-50: 200 XP
  - Anyone who completed (51+): 100 XP

### Removed from Flit (DO NOT PORT)
- Brand panel (`main_brand.dart`, BrandRouter)
- Brand registration, brand_users, brand_invites
- Brand analytics, brand_monthly_reports
- Sponsored tournaments (no cash/digital prizes — XP only)
- Prediction Contest (originally planned for Brainjam, removed)
- Surveys (brand-driven, no equivalent)
- `prize_claims`, `live_prizes`, `user_discounts`
- Domain splitting (3 hosting targets → 1 user app + admin route inside
  user app, gated by `users.isAdmin`)
- Phone verification gates
- Sponsors tab
- Brand demo request flow (`brand_demo_requests`, `brandDemoFunctions.ts`)
- Landing page brand-side rewrites (Brainjamin landing is consumer-only)

---

## TOURNAMENT ENGINE (NEW IN BRAINJAMIN)

The most critical new module. Flit's tournaments were brand-created manually.
Brainjamin's run on autopilot.

### Schedule
- **Two trigger times daily:** 07:00 UTC and 23:00 UTC.
  - 07:00 UTC: London/Dublin morning, NY late-night (ineffective for US),
    Sydney late-afternoon
  - 23:00 UTC: NY/LA evening (PRIMARY US slot), London late-night, Sydney
    morning
  - 23:00 UTC slot is the primary US-targeting slot; 07:00 UTC serves
    non-US Tier 1 (UK/IE morning, Sydney afternoon).
- **Lead time:** Content generated **24 hours before** tournament start
  (`generateTournamentContent` at T-24h).
- **Visibility:** Tournament becomes visible **12 hours before** start
  (`makeTournamentVisible` at T-12h).
- **Push:** Sent **5 minutes before** Live tournament start. Push is exempt
  from quiet hours queue (time-critical).

### Categories — 20 total, 10-day full rotation
History, Geography, Movies & TV, Music, Sports, Science, Technology,
Literature, Art, Food & Drink, Animals, Nature, Pop Culture, Mythology,
Video Games, Fashion, Astrology, Health, Space, World Capitals.

Rotation index stored in `category_rotation/state` (single doc).

### Per-trigger output
- **20 questions total** (EN only). Generated by LLM via `LLMService`
  (provider fallback chain — Gemini Flash → GPT-4o-mini → Claude Haiku).
- All 20 questions written to `questions_public` (the global pool).
- Same 20 questions used as the tournament's question set.
- **Two tournaments created per trigger:** 1 Classic + 1 Live (sharing
  the same 20 questions).
- → **4 tournaments per 12h** (07:00 UTC classic + live, 23:00 UTC classic
  + live).

### Bootstrap pool
- **Pre-launch seed: 4,000 questions** (20 categories × 200 each).
- Seed batch script runs ~1-2 weeks before launch. Quality gate:
  - 50-question pilot batch first → manual review → prompt calibration
  - Full 4,000 batch only after pilot passes
  - Per-category sample audit (20 questions per category, manually checked
    for accuracy and tone)
- **No "ghost tournament run."** Pool is fed organically post-launch by the
  engine itself (40 questions/day, ~1,200 questions/month).
- Total day-1 pool: ~4,000 questions. Sufficient for Self-Test, Duel,
  Arena pre-set category, and Daily Question across all 20 categories.

---

## AI PIPELINE — 3-LAYER VERIFICATION

Brainjamin's AI architecture combines Flit's verifier asymmetry pattern with
the V1.12 patch fallback chain.

### Layer 1 — Generator
`LLMService.generate()` — internal Cloud Functions module. Cascading retry:
- Gemini 2.5 Flash (primary)
- GPT-4o-mini (fallback 1)
- Claude Haiku (fallback 2)

Each provider has its own prompt template. On failure (timeout, rate limit,
malformed JSON), advance to next. If all three fail: write to Crashlytics,
return null; calling function surfaces `error_question_load_failed`.

### Layer 2 — Correctness verifier
For each generated question, a **different provider** verifies:
- Is the marked correct answer actually correct?
- Are the wrong answers genuinely wrong (not also correct)?

Generator-vs-verifier provider asymmetry is enforced via `pickVerifierProvider`
(generator must NOT be reused). Verifier failures are graceful: question is
still saved, but flagged with `verifierStatus: "skipped"` and logged. Apple
Review-acceptable because the moderation chain continues.

### Layer 3 — Language/clarity verifier (V1, advisory only)
Third distinct provider scores the question for grammar, clarity, and tone
(1-5 scale). Low-scoring questions are saved to pool with `flagged: true`
but **not blocked from use**. Admin Quality Review screen surfaces flagged
questions for manual review. This is intentionally **advisory, not blocking**:
- Pool growth never throttled by Layer 3 rejection
- Bad questions become learning data for prompt calibration
- Admin (Mert) can manually delete or correct over time

### Semantic dedup
Embedding-based check (OpenAI text-embedding-3-small). Cosine threshold:
**0.92** (carried from Flit). Candidate question compared against existing
`questions_public` of the same category. Above 0.92 = duplicate, regenerate.

### Affected Cloud Functions
- `generateTournamentContent` — uses LLMService + verifier + dedup
- `generateArenaQuestions` (custom topic path) — uses LLMService + verifier
- `selectDailyQuestion` — pool-only, no LLM
- `findOrCreateDuelMatch` — pool-only, no LLM

### Cost projection
- Per question: ~3 LLM calls (gen + correctness + language) + ~1 embedding
  call. Per question cost ~$0.0003 (Gemini Flash dominant).
- Daily generation: ~40 questions (tournament engine) + ad-hoc Arena custom
  topics → ~50-100 questions/day → **$1-3/day → $30-90/month** in steady
  state.
- Seed batch (4,000 questions, one-time): ~$2-5.
- Provider fallback bursts in incident months: +$5-20.

---

## ARCHITECTURE — Single panel (no panel split)

### Hosting (Firebase Hosting)
| Surface | Site | Public path | Live domain |
|---|---|---|---|
| User app | `brainjamin-prod-user` | `build/web` | `app.brainjamin.com` (TBD) |
| Landing | `brainjamin-prod-landing` | `landing/public` | `brainjamin.com` |

Single user-app target. Admin lives **inside** the user app at
`/admin/quality` and `/admin/dashboard`, gated by `users/{uid}.isAdmin`.
Brand-side hosting (Flit had brand + admin separate targets) is removed.

### Entry points + routers
- `lib/main.dart` → `AppRouter` (single router; no separate brand/admin
  routers like Flit had)
- `lib/core/bootstrap/app_bootstrap.dart` for Firebase init (carry over
  pattern from Flit, simplified)

### Stack
- **Frontend:** Flutter (single codebase → web bundle + iOS + Android)
- **Backend:** Firebase (Firestore, Cloud Functions, Hosting, Storage,
  Auth, Realtime Database for `.info/serverTimeOffset`, Crashlytics)
- **AI:** Gemini API primary; OpenAI + Anthropic fallback. OpenAI also for
  embeddings (text-embedding-3-small, 0.92 cosine for dedup).
- **Subscription billing:** None in V1. (V2: RevenueCat.)
- **Payment:** None in V1.
- **Domain registrar:** GoDaddy (`brainjamin.com`).
- **Stripe / payment processor:** None.

### Test devices
- Samsung SM-G990E (physical Android) — carry over from Flit
- iPhone (TBD — needs Apple Developer enrollment to provision)
- Android emulator API 35: BANNED (MainActivity bug, see PR-2)

---

## DATA MODEL — key collections

### Game content
- `tournaments`, `tournament_sessions` — Classic tournaments + per-user sessions
- `live_tournaments`, `live_participants/{tid}/users/{uid}`, `live_questions`,
  `live_results` — Live tournament state machine, driven by
  `runLiveTournament` server loop
- `arenas`, `arena_questions/{arenaId}/q/{qId}`, `arena_participants` —
  user-created arenas with `status: "preparing" | "scheduled" | "active" |
  "ended" | "expired"`
- `duels`, `duel_questions` — async 1v1 games
- `duel_queue/{uid}` — matchmaking queue (no `_lang` segmentation; EN-only)
- `daily_questions/{dateKey}` — single document per day (no `_lang` suffix)
- `daily_answers` — user submissions
- `self_test_sessions` — per-user 25-Q self-test runs
- `self_test_leaderboard/{categoryId}_{weekKey}` — category × week buckets

### Question pipeline
- `questions_public` — global pool, the master collection
- `used_questions/{uid}/seen/{qId}` — per-user "seen in last 30 days"
  dedup (TTL semantics enforced at read time)
- `category_rotation/state` — single doc, rotation index for tournament
  engine
- `blocked_terms/{en}` — content filter for custom Arena topics
- `ai_cache` — LLM response cache (carry over from Flit)
- `embeddings/{qId}` — text-embedding-3-small vectors, 0.92 cosine threshold
  (Flit's `semanticDedup.ts` pattern)

### Identity + audience
- `users/{uid}` — main user doc (xp, level, streak, percentile, fcm_token,
  timezone, isAnonymous, isAdmin, banned, last_export_at)
- `users_public/{uid}` — denormalized public profile (displayName, xp,
  level, country). **Created lazily on anonymous→permanent conversion.**
  Anonymous users have NO `users_public` doc.
- `usernames/{username}` — uniqueness reservation (lowercase doc id, atomic
  transaction in `validateUsername` — see V1.12 B.6)

### Leaderboards (V1)
- `leaderboards/global` — denormalized top 100 by total XP, rebuilt by
  `rebuildLeaderboards` CF
- `leaderboards/weekly_{weekKey}` — denormalized top 100 by weekly XP,
  rebuilt by `resetWeeklyLeaderboard` CF
- `self_test_leaderboard/{categoryId}_{weekKey}` — Self-Test specific
  (already listed under Game content above)

### Achievements (V1)
- `achievements/{uid}/earned/{achievementId}` — per-user earned rozet
- Achievement definitions are **client-side static** (Dart enum + asset
  paths), not Firestore. Tasarim degisirse app update gerekir.
- 17 launch achievements:
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
- `push_queue/{uid}/pending/{pushId}` — quiet hours queue. Each push has
  `respectQuietHours: bool` flag. Streak-at-risk and Live-tournament-5min
  push set this to `false` (delivered immediately).
- `notifications` — service-category push history (PR-6)

### Reports & moderation
- `reports/{reportId}` — user-submitted report on content (custom topic
  Arena, etc.). Apple Review requires this surface to exist and be
  reachable. Admin reads via Firebase Console in V1; UI in V2.

### Ops
- `session_secrets` — server-authoritative session timing (carry over)
- `app_settings`, `ai_config`, `arena_config` — runtime configs
- `admin_metrics/{dateKey}` — daily aggregated snapshot for read-only
  admin analytics dashboard
- `admin_broadcast_log` — admin actions audit
- `legal_docs` — Privacy Policy + ToS versioned content

### Anti-cheat / timing
- `live_tournaments/{ltId}` includes: `currentQuestion`, `revealActive`,
  `lateJoinClosed`, `lastHeartbeatAt`
- `live_questions/{ltId}/q/{qIndex}.startedAt: serverTimestamp`
- `live_results/.../answers/{qIndex}.submittedAt: serverTimestamp`
- All score calculation is server-side (`finalizeLiveTournament` and
  `finalizeClassicTournament`). Client `score` value is candidate only.
- `ServerTimeService` Dart class syncs from `.info/serverTimeOffset` once
  at app start; offset cached in memory; all UI countdowns use
  `ServerTimeService.now()`. `DateTime.now()` is forbidden in any code
  path that affects scoring, streak, or state transitions.

---

## CLOUD FUNCTIONS — V1 list (32 total)

### Tournament engine (6)
1. `generateTournamentContent` (T-24h scheduled)
2. `makeTournamentVisible` (T-12h scheduled)
3. `startLiveTournament` (T-0 scheduled — kicks off `runLiveTournament`)
4. `runLiveTournament` (long-running loop, 540s timeout, drives clients
   via `live_tournaments/{ltId}` state listener — V1.12 A.4)
5. `sendLiveTournamentPush` (T-5min scheduled, quiet-hours-exempt)
6. `finalizeClassicTournament` (T+24h scheduled)
   `finalizeLiveTournament` is triggered dynamically by `runLiveTournament`
   after Q20 reveal (~T+7) — not on a static schedule (V1.12 B.7).

### Daily Question (1)
7. `selectDailyQuestion` (scheduled, daily 23:00 UTC, pool-only — V1.12 A.1)

### Arena (1)
8. `generateArenaQuestions` (callable; LLM for custom topic, pool for
   pre-set category — V1.12 A.2)

### Duel (1)
9. `findOrCreateDuelMatch` (callable, atomic transaction with queue +
   pool dedup — V1.12 A.3)

### Watchdog & cleanup (2)
10. `liveTournamentWatchdog` (every 1 min, recovers stalled tournaments —
    V1.12 C.10)
11. `pruneStaleGames` (daily 03:00 UTC, 7-day TTL on duels + arenas —
    V1.12 C.11; arena participant-count cancellation rule REMOVED, solo
    arena is valid)

### Leaderboards (2)
12. `rebuildLeaderboards` (scheduled, hourly — global + Self-Test category)
13. `resetWeeklyLeaderboard` (scheduled, weekly Sunday 23:59 UTC)

### Identity (1)
14. `validateUsername` (callable, atomic transaction across `usernames/`,
    `users.displayName`, `users_public.displayName` — V1.12 B.6)

### Achievements (1)
15. `checkAchievements` (auth-triggered + game-event-triggered, idempotent)

### Notifications (5)
16. `sendDailyReminder` (scheduled per user local 19:00)
17. `sendStreakAtRiskReminder` (scheduled per user local 22:30,
    quiet-hours-exempt)
18. `notifyDuelInvite` (called from `findOrCreateDuelMatch` and invite
    accept paths)
19. `notifyDuelComplete` (game finalize trigger)
20. `flushQueuedPushes` (scheduled, every 30 min — releases queued
    pushes whose `releaseAt` has passed and `respectQuietHours == true`)

### Account lifecycle (3)
21. `softDeleteAccount` (callable, marks user for 30-day deletion)
22. `purgeDeletedAccounts` (scheduled daily, hard-deletes after 30 days)
23. `exportUserData` (callable, returns JSON of user's full data — GDPR
    Article 20 / UK GDPR / CCPA)

### Anonymous → permanent (1)
24. `onUserConverted` (auth trigger, creates `users_public/{uid}` doc on
    first non-anonymous sign-in, populates from `users/{uid}`)

### Admin / analytics (2)
25. `aggregateAdminMetrics` (scheduled daily, writes
    `admin_metrics/{dateKey}` snapshot for admin dashboard)
26. `submitReport` (callable, writes to `reports/{reportId}`)

### Embeddings / dedup (2)
27. `generateEmbedding` (callable, internal — used during
    `generateTournamentContent` and `generateArenaQuestions` flows)
28. `embeddingsBackfill` (scheduled or admin-triggered, fills missing
    embeddings for historical questions)

### Cleanup utilities (4)
29. `wipeTestData` (admin-only callable, wipes seed/test data)
30. `seedQuestions` (admin-only callable, runs the 4,000-question pre-launch
    seed)
31. `seedLegalDocs` (admin-only, populates Privacy + ToS)
32. `setBrainjaminLogo` (admin-only, one-shot at launch — populates default
    avatar / mascot images for users without a profile picture)

### Internal modules (not deployable functions)
- `LLMService` — provider fallback chain (Gemini → OpenAI → Claude)
- `ServerTimeService` — client-side time sync (Flutter)
- `pickVerifierProvider`, `pickLanguageVerifierProvider` — generator
  asymmetry helpers (carry over from Flit)
- `semanticDedup` — embedding cosine check
- `mcqShuffle`, `mcqCorrectLetter` — answer shuffling utilities
- `aiJsonParse` — robust JSON extraction from LLM outputs
- `phoneVerificationShared` — REMOVED (no phone gates in Brainjamin)
- `prizeExpiryReminderScheduled` — REMOVED (no prizes)
- `monthlyBrandReportScheduled` — REMOVED (no brands)
- `brandQuizCounters`, `brandFunctions`, `brandDemoFunctions` — REMOVED

### Removed from Flit (do not port)
- All brand-related CFs (~10 functions)
- `predictionAutomation`, `predictionFunctions`, `predictionShared` (no
  Predictions in Brainjamin)
- `surveyFunctions` (no Surveys)
- All `prize_*` and `discount_*` CFs

---

## SECURITY MODEL

- **Anonymous users CAN play everything** (Brainjamin differs from Flit
  here — no prize regulation pressure). Anonymous CANNOT: appear in
  leaderboards (no `users_public` doc), be friends (V2), subscribe (V2).
- **No phone verification gate** anywhere.
- **Firestore admin gate:** `isAdmin()` is a hybrid OR —
  `request.auth.token.admin` OR `token.isAdmin` OR
  `users/{uid}.isAdmin` (with `exists()` guard before `get()`). Carry
  over from Flit.
- **`users` doc** currently auth-readable for leaderboard/profile
  compatibility. Long-term: split private fields (`fcm_token`) to
  `users_private/{uid}`. V2.
- **App Check:** NOT activated yet. Defer until iOS Apple Developer
  enrollment is complete so iOS (DeviceCheck/App Attest) and Android
  (Play Integrity) ship together. Same posture as Flit.
- **Classic tournament integrity:** `getResults` returns full questions
  only when `status === "ended"`. Active tournaments return summary only.
- **Live tournament integrity:** `runLiveTournament` is the single
  authority on question advancement. Clients are listeners only.
- **Content moderation:** Custom Arena topics filtered through
  `blocked_terms/{en}` (pre-generation) AND Layer-3 language verifier
  (post-generation, advisory). Reports queue + admin Quality Review for
  manual moderation.
- **Anti-cheat — timing:** Server timestamps mandatory for any temporally
  meaningful write. Client clock manipulation cannot inflate streaks or
  scores (V1.12 B.5, B.8).
- **Anti-cheat — username uniqueness:** Atomic transaction across 3
  documents (V1.12 B.6).
- **User moderation:** `users/{uid}.banned: true` flag. Security rules
  read this flag and deny all writes/reads from banned users. UI for
  setting flag is Firebase Console only in V1.

---

## ADMIN PANEL — V1

Two real screens, both inside the user app at `/admin/*` routes, gated by
`users/{uid}.isAdmin`:

1. **Quality Review** (`/admin/quality`)
   - Lists `questions_public` filtered by `flagged: true`
   - Per question: approve / delete / edit
   - Used during launch weeks for prompt calibration

2. **Read-only Analytics Dashboard** (`/admin/dashboard`)
   - Reads `admin_metrics/{dateKey}` documents (populated by
     `aggregateAdminMetrics` CF, daily)
   - Sections:
     - User metrics: DAU, MAU, new signups (day/week/month), anonymous→
       permanent conversion rate, retention (D1, D7, D30)
     - Game mode: sessions per mode (Daily, Self-Test, Arena, Duel,
       Classic, Live)
     - Tournament: Live participation per slot (07 UTC vs 23 UTC),
       Classic completion rate, average leaderboard depth
     - Question pool: pool size by category, daily generation count,
       `flagged: true` rate, verifier reject rate
     - AI cost: daily LLM calls per provider, embedding cost
     - Ads: AdMob impression/revenue (deep-link to AdMob console for
       detail in V1; native pull V2)
     - 30-day trend lines per metric
   - CSV export per table

3. **User moderation** — Firebase Console only (no UI). Set
   `users/{uid}.banned: true` directly. Mert is the only admin in V1.

4. **Reports queue** — Firebase Console only (no UI). Admin reads
   `reports` collection directly. UI added in V2 if volume demands.

Admin V2 roadmap items (NOT in V1):
- User moderation UI
- Reports triage UI
- Live ops dashboard with real-time charts
- Manual content tools (add/edit `questions_public` from UI)
- Friend system moderation (when Friends ships V2)

---

## DESIGN

- **Brand color:** `#F97316`. `#FF9F04` BANNED (PR-1).
- **UI direction:** vivid gradients, mobile-first.
- **Mascot:** Brainjamin character appears in onboarding, push copy,
  achievement unlock animations, error/empty states, loading screens,
  level-up cards.
- **Tone:** EN-native, Brainjamin voice — encouraging mentor, slightly
  mischievous, broadly knowledgeable. No agressive monetization copy,
  no Duolingo-style guilt-trip beyond the mild mascot personification.
- **All strings via Flutter `intl`** — `lib/l10n/app_en.arb`. Architecture
  supports adding `app_es.arb` etc. in V2 without refactor.
- **AI explanation max length:** 100 characters per question, truncate +
  warn (PR-8 from Flit).
- **Push tone:** Brainjamin-voiced. Examples:
  - Daily: "Brainjamin's daily question is ready — bet you can crack it"
  - Streak risk: "Brainjamin is worried! Your 12-day streak ends at midnight 🔥"
  - Live 5min: "Brainjamin is warming up — Live tournament starts in 5"
  - Duel match: "Brainjamin found you a worthy opponent 🥊"
  - Duel complete: "Brainjamin's verdict is in — see who won"

### Design pipeline (Figma → Claude → Cursor)

- **Tasarım aracı:** Figma + Figma Make (AI design tool). Workspace +
  master file link Sprint 4 sonu brief'inde eklenecek.
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
  accent detaylarında çıkar — **ana flow'da convention'a sadık kalınır**.
  Sebep: kullanıcı, tanıdık paternleri zihninde önceden bildiği için
  onboarding drop-off azalır → D1 retention korunur.
- **Pipeline sıralaması:**
  1. Figma Make app'in tüm screen yapısı + flow'larını tasarlar
  2. Mert tasarımı Figma workspace'inde gözden geçirir, ince ayar
     yapar
  3. **Claude Figma MCP entegrasyonu** ile Figma node'larını okur:
     design tokens, exact CSS values, typography scale, component
     variants. Tahmin değil, Figma'dan exact değerler.
  4. Claude her ekran için kapsamlı Cursor prompt yazar (Flutter
     widget tree + token referansları + spacing/sizing/color tokens
     + animation curves)
  5. Cursor prompt'a göre Flutter implement eder
  6. Quality gate: flutter analyze + Chrome smoke + Samsung smoke
- **Risk yönetimi:** Figma Make HTML/Tailwind export'u Brainjamin için
  kullanılmaz (Flutter codebase). Tek doğru yol: Claude Figma MCP →
  Cursor brief.

---

## OPERATIONAL CONSTRAINTS

- Mert does not write code. All implementation goes through Cursor (CB-2).
- Quality gate per Cursor prompt: `flutter analyze` → 0 errors;
  `npm run build` if functions changed → 0 errors (PR-3).
- Communication languages: Cursor prompts in English, Mert ↔ Claude in
  Turkish, user-facing UI in EN.
- Marketing budget: minimal. ASO is the primary growth lever.
- Mert commits to **30 min/day for 3 weeks post-launch** for ASO iteration.
- Live tournament minimum lead time: there is no manual creation in
  Brainjamin (engine-driven only); the 48h Flit rule does not apply.
- Arena minimum lead time: 10 minutes (PR-7-Brainjamin).
- All copy edited by EN-native copywriter pre-launch.

---

## REVENUE EXPECTATIONS (REALISTIC)

Trivia category is saturated globally (Trivia Crack, QuizDuel, LearnClash,
Kahoot, Quizizz). Solo organic launch with no paid marketing:

- **Year 1:** 5–15K total downloads, 500–2K MAU
- **AdMob revenue:** $50–200/month (depends on Tier 1 user mix density)
- **Year 2–3:** Compound ASO effect may push to $500–1500/month if
  retention holds

This is a long-tail bet. The "low marginal maintenance" architecture
exists because the math only works if ongoing operating cost stays near
zero. Subscription V2 can add another $10-50/month after retention is
proven.

---

## REPO PROVENANCE

- **Flit repo:** `github.com/fmertbayer-star/flit` (local:
  `C:\flutter_projects\flit`)
- **Brainjamin repo:** local app at `C:\flutter_projects\brainjamin`; git
  initialized during Sprint 1. GitHub remote
  `github.com/fmertbayer-star/brainjamin` may or may not be configured —
  verify with `git remote -v`.

The two codebases are **fully independent**. No shared code, no shared
Firebase project. Brainjamin uses its own Firebase project, App Store /
Play listings, Apple Developer / Google Play Console entries.

Stratech Dynamic FZCO is the publishing entity for both.

- **Package name (Android):** `com.stratech.brainjamin`
- **Bundle ID (iOS):** `com.stratech.brainjamin`
- **Firebase project ID:** `brainjamin-prod-app`
- **Apple App Store Connect App ID:** `6765467964` (Brainjamin / iOS,
  created 2026-04-30)

---

## OPEN ARCHITECTURAL QUESTIONS

These were not closed in the architecture phase and remain in
BRAINJAMIN_TODO.md for resolution before Cursor sprint 1:

- D-2: Question pool unbounded growth strategy (storage cost ceiling, archive
  policy for very old questions)
- D-3: Profile-tab anonymous warning card copy + placement
- E-1: Push cap overflow handling (what happens if a user is owed 5
  pushes after 8 hours of quiet hours — collapse, queue, or drop?)
- E-2: Live tournament Battle Arena spectator screen polish (audio,
  animation, share-result CTA)
- F-1: Locale fallback for non-EN devices (user in Turkey downloading the
  app — what does the OS-locale-EN-fallback feel like?)
- F-2: App Store Connect content rating questionnaire — exact answers
  drafted but not validated against 2026 questionnaire UI
- F-3: ATT (App Tracking Transparency) prompt copy + timing — must comply
  with Apple's 2024 stricter enforcement

---

*End of BRAINJAMIN_CONTEXT.md*
