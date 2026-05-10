# BRAINJAMIN TODO
Last updated: 2026-05-10 — Sprint 4.3 closed (positive). Live engine + UI deployed and validated end-to-end on Samsung SM-G990E. Race-condition finalize fix shipped (rev 00002-cuh). Three Live UX fixes shipped (scroll, players label, result-screen redesign). Multi-user / load issues to be surfaced in V1 launch testing.

Operational state of the project. Sprint priorities and the active work
thread. Recently-done log lives in `git log`. Codebase snapshot lives in
the codebase itself (`functions/src/index.ts`, `lib/features/**`,
`firestore.rules`).

---

## NEXT UP — Active Thread

- **DEDUP_THRESHOLD restore** — currently 0.95 (smoke-only). Restore to **0.88** + redeploy `generateClassicTournamentContent`. **Highest priority — blocks production correctness** (Classic generator).

- **Generator prompt dedup avoidance (avoid-list fix)** — feed last N questions per category into the generator prompt so dense categories do not repeat into `dedup_hit` death spirals. Without this, pool growth keeps Classic generation unstable. Pre-launch blocking (detail + smoke evidence in § P1 · Backend tech debt).

---

## 🔴 IMMEDIATE (Launch Blocker — open items)

### Identity & accounts
- **Google Play Console** — Brainjamin listing under Stratech FZCO. Same
  verification as Apple.

### Apple-mandatory pre-launch
- **App Check activation deferred** until iOS Apple Developer enrollment
  fully completes. Plan staged in BRAINJAMIN.md § Security Model § App Check.
- **ATT prompt copy** — soft primer copy locked in BRAINJAMIN.md § ATT &
  UMP consent. EN copywriter polishes pre-submission. Sequence: UMP →
  ATT primer → ATT native → ad load.
- **UMP consent SDK** — Google's UMP, configured in AdMob console (no
  custom UI). Mandatory before AdMob serves ads.
- **Privacy Policy + Terms of Service** — drafted with COPPA + GDPR +
  CCPA + UK GDPR + Australia Privacy Act + Apple/Google compliance.
  Hosted at `brainjamin.com/privacy` and `brainjamin.com/terms`. Linked
  in: App Store listing, Play Store listing, in-app Settings → Help,
  Onboarding age gate screen.
- **Age rating questionnaire** — see APPENDIX A. "Drug Use" answer is
  **Infrequent/Mild** pending pre-launch seed audit (revise to None if
  zero references found in 4k seed). Validate against 2026 Connect UI
  at submission time.
- **Apple Review submission notes** — UGC paragraph in APPENDIX A. Mert
  pastes verbatim into Connect "Review Notes" field at submission.

### Pre-launch content
- **4,000 seed questions** — batch Gemini script, 20 categories × 200
  each. Quality gate: 50-question pilot first → manual review → prompt
  calibration → full batch. Per-category sample audit (20 questions/cat
  manual review). NOT delegated to Cursor — content ops task.
- **Brainjamin Character Bible** (Notion or Google Doc, owned by Mert)
  — single source-of-truth shared with EN copywriter AND used by Mert
  later when authoring AI image-tool prompts. Contents: APPENDIX B.
- **EN-native copywriter brief** — store description, promotional text,
  screenshot captions, in-app strings polish, 6 push notification
  templates, error/empty state copy, ATT soft primer copy polish, push
  permission soft primer copy polish, **12 FAQ entries** (Account 3,
  Gameplay 4, Issues 3, Legal/Privacy 2), "Account already exists"
  modal copy, anonymous warning card EN, forced-rename modal copy,
  7 coach mark screens.
- **Mascot AI-generated assets** — see APPENDIX B. Done by Mert via AI
  image tool (no illustrator engaged); prompt-writing is a future
  Claude session.
- **App icon** — features Brainjamin mascot face/silhouette.
  Distinctive in App Store grid.
- **Screenshot template design** — 8 screenshots, brand orange
  gradient, EN copy, mascot present in at least 4. Mobile-first.
- **Preview video production** — 15-30 sec, EN, muted auto-play optimized.

### Pre-launch ops
- **`brainjamin.com` DNS** — point apex/domain to **Firebase Hosting**;
  wire **Cloudflare Email Routing** (or equivalent) for `support@` /
  `legal@` / `privacy@` forwards. Schedule with Sprint 6/7 unless Mert
  pulls it forward.

### Backend dependencies
- **`luxon` or `date-fns-tz`** added to Cloud Functions package.json
  (timezone math).
- **`firebase_database` Flutter dependency** confirmed for
  `.info/serverTimeOffset` access.
- **`firestore.rules` baştan yazılmalı** — şu an sadece global
  default-deny + Sprint 2 sonu eklenmiş `users/{uid}` self-managed
  allowlist (fcm_token, fcm_token_updated_at, pushPrimerCooldownUntil,
  tutorialSeen, profileNudgeHiddenUntil) var. Diğer tüm collection'lar
  (daily_answers, usernames, users_public, arenas, arena_questions,
  arena_participants, duels, duel_questions, duel_queue, tournaments,
  tournament_sessions, live_tournaments, live_participants,
  live_questions, live_results, self_test_sessions,
  self_test_leaderboard, daily_questions, questions_public, embeddings,
  ai_cache, used_questions, leaderboards, achievements,
  deleted_accounts, notifications, push_queue, reports, blocked_terms,
  category_rotation, session_secrets, app_settings, ai_config,
  arena_config, admin_metrics, admin_broadcast_log, legal_docs)
  tamamen kapalı. Spec ref: BRAINJAMIN.md § DATA MODEL + § SECURITY
  MODEL. Sprint 5 öncesi (ideal: Sprint 3 başında, Arena/Duel
  açılmadan) tek seferde yazılıp deploy edilmeli; aksi halde Sprint
  3+ feature'ları çalışmaz.

### Trademark
- **Trademark check on "Brainjamin"** — invented compound word, low
  risk but verify USPTO + EUIPO no conflicts. Stratech FZCO legal
  counsel (1-2 hour billable). Pre-Cursor-sprint task.

---

## 🟡 P1 (Pre-Launch — parallel with early Cursor sprints)

### Pre-launch ops
- **Crashlytics setup** — automatically wired through
  `firebase_crashlytics` Flutter plugin; verify reports flowing during
  Sprint 1 testing.
- **Cloud Logs retention policy** — default 30 days for Cloud Functions
  logs is fine for V1.
- **Firestore TTL policies (deploy-time)** — configure TTL on
  `ai_cache.expiresAt` (90-day auto-delete) and
  `notifications.expiresAt` (7-day in-app notification center cleanup).
  Both per BRAINJAMIN.md. Enabled at Sprint 4/5 deploy.
- **Stage 1 composite indexes pre-defined** — `firestore.indexes.json`
  ships with `(category, flagged, lastShownAt)` composite index for
  `questions_public` from V1 (per BRAINJAMIN.md § Sharding plan Stage
  1). Zero benefit at Year 1 scale, zero cost; ready when needed.

### Backend tech debt
- **`questions_public.flagged` backfill** — **Done (Sprint 4.1)** via seed / migration scripts. Verify `selectDailyQuestion` primary query path (remove in-memory fallback if still present).
- **Generator prompt dedup avoidance** — LLM converges on popular questions in dense categories (history, geography). Smoke-test surfaced this: multiple attempts can hit the 0.88 cosine threshold against the existing pool. Fix: feed last N questions per category into the generator prompt as "do not generate questions similar to:". Without this, categories with established "classic" trivia are unstable as the pool grows. Pre-launch fix recommended.
  - Sprint 4.3 smoke (2026-05-09): manual Classic trigger on `geography` aborted at index 0 with 5/5 attempts rejected as `dedup_hit`, similarity 0.997 / 0.983 / 0.998 / 0.999 / 0.999. Confirms the failure mode in dense categories. Avoid-list fix is now blocking, not nice-to-have, before launch.
- **DEDUP_THRESHOLD restore** — currently 0.95 (smoke-only). Restore to **0.88** + redeploy `generateClassicTournamentContent`. **Highest priority — blocks production correctness** (Classic generator).
- **`mcqShuffle` util doc sync** — BRAINJAMIN.md § CLOUD FUNCTIONS §
  Internal modules listesinde `mcqShuffle` zaten yer alıyor; commit
  `d4656ac` ile `functions/src/shared/mcqShuffle.ts` artık gerçekten
  var. Doc tarafında ek aksiyon yok, sadece teyit notu.

### Marketing / ASO
- **App Store keyword research** — ASO research targeting EN search
  terms (trivia, quiz, brain, daily quiz, tournament, multiplayer
  trivia, etc). Document keyword list + difficulty + relevance scores.
  Pre-submission task.
- **Screenshot copy** — short, benefit-driven captions per screenshot.
  EN-native copywriter handles.
- **Promo video script** — 30-sec video script, EN, mascot featured.

---

## 🟡 P2 (Parallel with Launch — Docs & Ops)

- **Deploy `generateQuestions` + pilot run** — `firebase deploy --only
  functions` + `node functions/scripts/runPilot.mjs` ile 5 soru;
  sonuçları doğrula.
- **Flutter-side category mirror** — `lib/core/constants/categories.dart`
  matching `functions/src/shared/categories.ts`.
- **Astrology prompts — pilot validation** — `prompts.ts` özel çerçeve;
  pilot batch ile verifier döngüsü kontrol et.
- **XP system audit post-launch** — verify XP scale across all 6 modes
  feels balanced; rebalance if Live tournaments dominate or Self-Test
  feels under-rewarded.
- **Onboarding flow A/B test** — V1 ships single flow; A/B variants V2.
- **Load / stress test** — capacity test for Live tournament before any
  scaled marketing push (synthetic 1K, 5K, 10K concurrent users).
- **Centralized callable security middleware** — replace per-function
  `assertNotAnonymous`-style checks with a single
  `protectedCallable(handler, {requireAuth, requireNonAnon, requireAdmin,
  rateLimit})` wrapper. Refactor task.
- **Anonymous → permanent SharedPreferences migration helper** —
  client-side, runs on `linkWithCredential` success in
  `lib/core/services/auth_service.dart`. Single helper that migrates
  every anonymous-local state key into `users/{uid}` Firestore. V1
  tracked keys: `tutorial_seen_daily` (Daily coach mark),
  `bj_push_primer_cooldown_until` (push primer cooldown). Future keys
  for additional coach marks and primers register here. Currently
  patched per-feature (each feature reads anon-prefs OR perm-Firestore
  inline) — sustainable only at V1 scale; consolidation is V2 hygiene.
- **Code-only collections audit** — `ai_cache`, `live_push_reminders`,
  `daily_questions`, `blocked_terms`, `embeddings` may be referenced in
  CF code without explicit Firestore rules — default deny. Verify
  CF-only access (admin SDK) or add explicit rules where client
  reads/writes.
- **`fcm_token` exposure (LOW/P2)** — `fcm_token` is currently inside
  `users/{uid}` which is auth-readable. Long-term fix: split to
  `users_private/{uid}/fcm_token`. V2.
- **Analytics dashboard polish** — V1 admin dashboard reads
  `admin_metrics/{dateKey}` via simple list/chart. Polished interactive
  dashboard with date-range pickers, drill-downs, segmentation: V2.
- **Cross-tournament question dedup per user** — `used_questions` is
  global; per-user history fetched at generation. Already designed.
  Verify it works as designed during Sprint 4.
- **Soru kategorilerinin gözden geçirilmesi** — 20 kategori sabitlenmiş.
  Eğer pre-launch seed sırasında bir kategori "fazla geniş" veya "fazla
  dar" çıkarsa kategori isimlerini yeniden gözden geçir. Sprint-2 ile
  paralel.
- **Soru kalitesi feedback loop** — `flagged: true` soruları ve user
  reports'ları prompt calibration'a geri besle. Lansman sonrası 4
  hafta özellikle kritik. Manuel süreç V1; otomasyon V2. **Proaktif
  tamamlayıcı:** generator prompt avoid-list (§ P1 "Generator prompt
  dedup avoidance") yoğun kategorilerde tekrarlayan üretimi azaltır.
- **ai_config/models Firestore doc seed** — pipeline currently falls back to in-memory defaults. Seed before launch so model strings can be hot-swapped without redeploy. Sprint 7 candidate.
- **firebase-functions package upgrade** — currently `^6.6.0` with deprecation warnings on every deploy. Sprint 7 hygiene; breaking changes need careful test.
- **Sign-in screen RenderFlex overflow** — at narrow viewports the four
  sign-in buttons Column overflows by 90–110px on the right. Cosmetic,
  observed during Sprint 1.6 smoke. Defer to Sprint 5 (Profile + final
  polish).
- **`firestore.rules` banned-check null-safety pattern.** `/duels`, `/duel_questions`, `/duel_queue` were updated to use `data.get('banned', false) != true` after the original `data.banned != true` triggered a rules evaluator error when `users/{uid}` doc lacked a `banned` field. Other rule blocks that may use the same banned-check pattern (when added in future sprints) should adopt the same null-safe accessor. Pattern note for Sprint 4+.
- **Duel invite code `BJ` strip false-positive.** `duel_join_code_screen` defensively strips a leading `BJ-` or `BJ` prefix to tolerate legacy share text. Codes that genuinely begin with `BJ` (rare per backend `crypto.randomBytes` alphabet, ~1/676) would be mis-stripped to a 4-char code and fail join. Pre-launch hygiene: tighten strip to `^BJ-` (dash required) only.
- **Duel deep linking is V2.** Invite share message contains `https://brainjamin.com/duel/{code}` as a stub; tapping opens browser to a 404. Universal links / Android App Links / Firebase Dynamic Links to be added in V2 so the link opens the app and pre-fills the join code.
- **Duel "My Duels" UI is V2.** No surface to view past or in-flight duels exists in V1. `DuelService.listenMyDuels` is implemented and reserved for the V2 surface.
- **Switch-account UI is V2.** No in-app sign-out + sign-in flow. Anonymous → permanent conversion exists via `linkWithCredential`, but switching between two anonymous test accounts requires Settings → Apps → Storage → Clear data on Android. V1 launch does not need this; mention in V2 admin tooling planning.
- **Sprint 4.3 Step 2c — Live watchdog + T-5min push.** Watchdog: scheduled CF every minute checks `live_tournaments` where `status == running` AND `last_heartbeat_at < now - 180s` AND `lock_holder` is stale; resets so the next `runLiveTournament` tick can recover. T-5min push: scheduled CF at `*/1 * * * *` checks Live docs starting in [4, 6) minutes and sends FCM to opted-in users; quiet-hours-exempt per BRAINJAMIN.md.
- **Live `submitLiveAnswers` typed exception polish** — current implementation throws generic `LiveSubmitException` enum. Future polish: distinguish `notEnded` / `notParticipant` / `alreadyScored` cleanly with i18n-ready user copy.
- **Live end-to-end smoke automation** — currently requires (a) `prepareLiveTournament` tick or manual delete of stale Live doc, (b) UI Lobby join, (c) `fastForwardLiveStart` callable. Wrap into a single admin CF (`seedLiveSmoke`) that prepares a fresh Live doc, joins N synthetic participants, fast-forwards `starts_at` — for repeated test cycles without UI. V2 hygiene; not a launch blocker.

### Post-launch operational rhythms
- **Reports triage** — for first 4 launch weeks, Mert opens `reports`
  collection in Firebase Console weekly (Sundays). "Inappropriate
  content" reason auto-pushes via FCM to Mert's device — handle ASAP.
- **Retention dashboard review** — D1/D3/D7/D14/D30 cohort tracking
  reviewed weekly during ASO iteration period. Triggers prompt
  calibration if D3 drops materially.

---

## 🟢 V2 (Post-Launch — explicitly deferred)

### Subscription
- **Brainjamin Plus** — $1.99/month, $9.99/year, 3-day trial, ad-free
  only, RevenueCat-driven. Architecture supports it (entitlement flag,
  ad-free path); V2 turns it on.
- **Plus billing grace period** — depends on Plus existing.

### Friends + social
- **Friends system** — friend requests, accepts, blocks, friend
  leaderboards, friend invite for Duel, Arena friend-only mode.
- **Username search** — required for friends.
- **Social push triggers** — friend request received, friend accepted.
  Adds 3rd push toggle category "Social" to the V1's 2-toggle Daily/Streak
  + Game updates split.

### Rewarded ads
- **Rewarded ad integrations** — extra hayat (Battle Arena), soru
  atlama (Self-Test), ikinci şans, bonus XP. Server-side reward
  verification (CF callable, idempotent + signed receipt). Hile riski
  analizi şart.

### Multilingual
- **ES (Spanish)** — second language. Doubles AI generation cost,
  doubles tournament count. Decide based on V1 retention data.
- **Other languages** based on download data.

### Battle Arena spectator polish
- Audio cue when player eliminated (subtle "uhh" sound)
- Audio cue when other player eliminated (ping)
- Share-result CTA (image generate + share sheet)
- Brainjamin-voiced chat-style commentary in spectator
- Mascot reaction animation in spectator (idle)
- Live spectator count indicator

### Question pool lifecycle
- **Archive policy implementation** — `archiveStaleQuestions` scheduled
  CF (monthly), 12-month-stale criterion. Triggered when:
  - Any single category exceeds 15K questions, OR
  - Query P95 latency on `used_questions` filters crosses 500ms
- `archived_questions` + `archived_embeddings` collections created at
  trigger time; `getQuestionById` fallback chain implemented.
- **Stage 2 sharding** (30K-50K per category): introduce `archived: bool`
  filter + cold storage isolation.
- **Stage 3 sharding** (50K+): subcollection refactor —
  `questions_public/{categoryId}/items/{qId}`. V3-tier.

### Username moderation
- **Periodic block list sweep** — monthly scheduled CF tarar tüm
  username'leri current `blocked_terms/usernames` listesine karşı.
  Match → forced rename flag.

### Admin panel expansion
- User moderation UI
- Reports triage UI (replace Console-only V1 workflow)
- Live ops dashboard with real-time charts
- Manual content tools (add/edit `questions_public` from UI)
- Friend system moderation tools

### Notification center polish
- User-facing read/unread state per item
- Inbox-style swipe to delete
- Per-category filter

### Architecture hygiene
- `users_private/{uid}` split for `fcm_token` etc.
- Centralized callable security middleware
- Code-only collections explicit rules

---

## 📋 CURSOR SPRINT SEQUENCE

Sprint plan, compressed. Architectural detail lives in BRAINJAMIN.md.
Each sprint is a deliverable list; references "per BRAINJAMIN.md § X"
for the rationale.

### Sprint 1 — Bootstrap + Auth + Main shell (5 sub-sprints)

**1.1 Bootstrap** ✅ in progress
- `flutter create brainjamin --org com.stratech --platforms=ios,android,web`
- Pubspec: firebase_core, firebase_auth, cloud_firestore,
  firebase_storage, firebase_database, firebase_crashlytics,
  firebase_analytics, intl
- `flutterfire configure --project=brainjamin-prod-app`
- `lib/core/bootstrap/app_bootstrap.dart`
- Smoke-test screen (#F97316 Material 3)

**1.2 Theme + i18n + ServerTimeService**
- `lib/core/constants/app_colors.dart` (#F97316; #FF9F04 banned)
- ThemeData (Material 3, brand color, typography scale)
- `intl` + `flutter_localizations` + `app_en.arb` skeleton
- `lib/core/services/server_time_service.dart` syncs
  `.info/serverTimeOffset`, exposes `.now()`

**1.3 Anonymous auth + onboarding (3 screens)**
- Anonymous sign-in on app start (auto, silent)
- 3-screen onboarding (Welcome / Age gate / Sign-in primer) per
  BRAINJAMIN.md § ONBOARDING. Mascot placeholder pattern.
- NO upfront tutorial; NO push permission prompt; NO ATT prompt.
- `tutorialSeen.{mode}` flag infrastructure; SharedPreferences
  fallback for anonymous, server migration on conversion.

**1.4 5-tab main shell**
- Bottom nav: Home/Tournaments, Self-Test, Arena, Duel, Profile
- Empty-state placeholders per tab
- Single `AppRouter` (go_router)

**1.5 Apple + Google + Email providers + linkWithCredential**
- iOS Developer Console: App ID, Service ID, Sign in with Apple key
  (manual, Mert) — IDs in APPENDIX A
- Firebase Console: enable Apple, Google, Email/password providers
- `linkWithCredential` flow for anonymous → permanent
- "Account already exists" branch confirmation modal
- NO email verification; NO phone verification

### Sprint 2 — Daily + Self-Test + Push + Reports skeleton

- Daily Question UI + streak + forgive
- Self-Test category picker, 25-Q loop, 10-sec timer
- `selectDailyQuestion` CF
- `self_test_leaderboard/{categoryId}_{weekKey}`
- Pool dedup (`used_questions/{uid}/seen/{qId}`)
- Coach marks: Daily 1 screen, Self-Test 1 screen on first entry
- Push permission soft primer (after first Daily completion, both iOS
  and Android 13+); 7-day cooldown on "Not now"
- Quiet hours infrastructure: 22:00–08:00 default,
  `push_queue/{uid}/pending/{pushId}` with `respectQuietHours` field,
  `flushQuietHoursQueue` every 30 min
- Push category 2-toggle Settings (Daily & Streak / Game updates)
- In-app notification center with 7-day TTL
- Daily reminder push (local 19:00, respects quiet hours)
- Streak-at-risk push (local 22:30, quiet-hours-exempt)
- Report button infrastructure (3-dot overflow menu) on Daily +
  Self-Test surfaces
- `submitReport` CF skeleton (10/day cap, `(userId, questionId)`
  uniqueness)
- Analytics events server-side: `daily_completed`, `self_test_completed`,
  `auth_converted`. Client-side: `app_open`, `onboarding_complete`,
  `daily_started`, `self_test_started`

### Sprint 3 — Arena + Duel

**Duel: complete (Model A async).** Backend (`createDuel`, `joinDuel`,
`getDuelQuestions`, `submitDuelAnswers`, `getDuelLobbyStats`,
`expireDuels`) deployed; UI (`/duel`, `/duel/match-type`,
`/duel/quiz`, `/duel/result`, `/duel/invite-share`, `/duel/join`)
shipped; firestore.rules `/duels`, `/duel_questions`, `/duel_queue`
use null-safe banned-check + null-guarded `player2_id` predicate;
composite indexes for the broadened matcher + invite lookup
deployed; result screen completed-state stats block (accuracy /
total time / score + categories+difficulty summary line) shipped;
smoke tested end-to-end on Samsung SM-G990E (creator-solo →
opponent-match → completed; invite create → share → join via
in-app code entry → completed).

**Arena: not started.** Sprint 3 originally scoped Arena + Duel
in parallel; the Duel async refactor consumed the sprint.
Arena work — `firestore.rules` for `arenas` / `arena_questions` /
`arena_participants`, 3-step wizard, Battle Arena eliminate
overlay, spectator screen, ended-push, `generateArenaQuestions`
CF — moves to Sprint 3.5 OR is folded into a future sprint per
Mert's call.

Reference architecture: BRAINJAMIN.md § PRODUCT § Arena, § DATA
MODEL, § CLOUD FUNCTIONS.

### Sprint 4 — Tournament Engine (Classic + Live)

- **Sprint 4.1:** ✅ rules + indexes + 20-category migration + `category_rotation` init + dead-category cleanup (40 questions deleted).
- **Sprint 4.2a:** ✅ `generateClassicTournamentContent` + `makeClassicTournamentVisible` + `finalizeClassicTournament` (status-flip only; finalize rollup added in 4.2b). Scheduled cron live.
- **Sprint 4.2b:** ✅ `getClassicTournamentQuestions` + `submitClassicTournamentAnswers` callables. Eager session, snake_case fields. `finalizeClassicTournament` rollup logic added (leaderboard write + XP grant + rank). `tournament_leaderboards` collection rule + composite index deployed.
- **Sprint 4.3:** ✅ Live engine + Live UI — shipped (`finalizeLiveTournament` race-condition fix rev 00002-cuh; Live quiz scroll + players label + result-screen redesign; end-to-end smoke on Samsung SM-G990E). Multi-user / load validation → V1 launch testing.
- **Sprint 4.4a:** ✅ TournamentsTab live list + `CountdownTicker` reusable widget.
- **Sprint 4.4b-i:** ✅ Tournament detail screen + `/tournament/:slotId` route + status-aware CTA + XP tier constants.
- **Sprint 4.4b-ii-1:** ✅ Classic quiz screen + `/tournament/:slotId/quiz` + draft persistence (`shared_preferences`).
- **Sprint 4.4b-ii-2:** ✅ `getClassicTournamentReveal` callable + Classic result screen + `/tournament/:slotId/result` + auto pending→finalized transition.

### Sprint 5 — Profile + Ranking + Achievements + Settings

- Profile tab (XP, level, streak, achievements grid)
- Anonymous warning card on Profile tab (7-day dismissible,
  `profileNudgeHiddenUntil` field; permanent users skip)
- Leaderboard inline gate for anonymous users (full-screen empty state)
- Username creation flow (3-20 char, charset rules, leading letter,
  case-insensitive uniqueness, block list, 30-day cooldown, permanent
  release on change, "Anonymous Player" fallback)
- `validateUsername` CF (atomic transaction across 3 docs + cooldown +
  block list)
- Forced rename modal infrastructure (`forceRename: true` →
  non-dismissible modal)
- Global + weekly leaderboards (`rebuildLeaderboards`,
  `resetWeeklyLeaderboard`)
- 17 achievements + `checkAchievements` CF
- Achievement unlock animation (mascot, no inline anonymous gate)
- Settings → Help screen (12-FAQ accordion, Contact Support mailto with
  device/OS/version + anonymous UID auto-fill, Report a Bug CTA,
  Privacy Policy + ToS links, app version + build number)
- Settings → Account section (permanent: "Sign-in method"; anonymous:
  persistent prompt with progress preservation note)
- Settings → Push toggles (2 categories)
- Settings → Language, Legal links, Export, Delete
- Account lifecycle: `softDeleteAccount`, `purgeDeletedAccounts`,
  `exportUserData`

### Sprint 6 — AdMob + Push + ASO assets

- Banner integration (3 placements: Duel lobby, Classic results,
  Self-Test lobby)
- Interstitial integration (post-game, frequency cap, 3-game onboarding
  suppression)
- UMP → ATT primer → ATT native → ad load sequence
- ATT soft primer fires just before first ad load (NOT in onboarding)
- ATT deny: non-personalized ads + Settings link to iOS Settings
- Push notification full set (6 triggers: Daily, Streak, Duel matched,
  Duel complete, Live 5-min, Battle Arena ended)
- App icon final
- 8 screenshots final
- Promo video final
- Privacy Policy + ToS final + 12-FAQ EN copy ship
- App Store / Play Store submission prep (use APPENDIX A artifacts)

### Sprint 7 — Admin + Reports + final hardening

- `/admin/quality` Quality Review screen
- `/admin/dashboard` read-only analytics dashboard
- `aggregateAdminMetrics` CF (Engagement DAU rollup, D1/D3/D7/D14/D30
  cohorts, server-side increment reconciliation, derived metrics
  nightly UTC 00:30)
- `submitReport` CF "inappropriate_content" → immediate FCM push to Mert
- `wipeTestData` CF
- `seedQuestions` CF (4,000-question seed runner)
- Final security pass (App Check enable plan stays staged for
  post-Apple-enrollment)
- Crashlytics dashboard review
- Cloud Functions cost monitoring setup

### Sprint 8 — Beta + soft launch

- TestFlight + Internal Testing tracks
- 10-20 beta users, 1 week feedback
- Hotfix sprint
- Public launch (App Store + Play Store, Tier 1 only)

---

## APPENDIX A — APPLE SUBMISSION ARTIFACTS

One-time use at App Store Connect submission. Not structural truth;
parked here so BRAINJAMIN.md stays clean.

### Apple Sign In identifiers (locked)

- **App ID:** `com.stratech.brainjamin`
- **Service ID:** `com.stratech.brainjamin.signin`
- **Apple Team ID:** `J863Y2PK9U` (Stratech Dynamic FZCO)
- **Authorized callback URL:**
  `https://brainjamin-prod-app.firebaseapp.com/__/auth/handler`
- **Authorized domain:** `brainjamin-prod-app.firebaseapp.com`
- **Apple Sign In Key ID:** `L2K726P8TK`
- **Apple `.p8` private key:** stored locally on Mert's machine outside
  repo (`C:\flutter_projects\secrets\brainjamin\AuthKey_L2K726P8TK.p8`).
  Server-side use deferred — not in V1 scope. If a future feature
  requires `.p8` (e.g., `revokeUserAccount`), it must be moved to
  **Firebase Cloud Secret Manager** at that time.

### App Store Connect content rating — answer matrix

| Category | Answer | Rationale |
|---|---|---|
| Cartoon or Fantasy Violence | None | Trivia, no violence |
| Realistic Violence | None | — |
| Prolonged Graphic or Sadistic Realistic Violence | None | — |
| Profanity or Crude Humor | None | EN copywriter standard: clean |
| Mature/Suggestive Themes | None | — |
| Horror/Fear Themes | None | — |
| Medical/Treatment Information | None | "Health" category is education-level, never treatment advice |
| Alcohol, Tobacco, or Drug Use | **Infrequent/Mild** | History / Pop Culture may contain factual references (e.g., Prohibition Era). Revise to **None** at submission time if pre-launch seed audit confirms zero references |
| Sexual Content or Nudity | None | Block list + moderation API enforced |
| Gambling | None | "No prizes" Hard NO compliant |
| Contests | None | XP-only tournaments do not meet Apple's "contest" definition (no money/prize) |
| Unrestricted Web Access | No | No in-app browser |
| Gambling and Contests Simulated | None | — |
| User Generated Content | **Yes** | Custom-topic Arena. Moderation pipeline documented in submission notes (below) |

### Apple Review submission notes — UGC paragraph (template)

Pasted by Mert into App Store Connect "Review Notes" field at submission:

> Brainjamin is a global trivia/quiz app for ages 13+ with six game modes
> including a feature where users can create custom-topic Arena quizzes.
> All user-generated topic input goes through:
> 1. A blocked-terms filter (`blocked_terms` collection) that rejects
>    offensive or inappropriate topics before generation.
> 2. An LLM-driven topic appropriateness check — the model is instructed
>    to refuse generating questions for inappropriate, harmful, or
>    non-trivia topics.
> 3. OpenAI's Moderation API on every generated question (categories:
>    hate, sexual, violence, self-harm, illicit, political-extremism).
>    Flagged questions are rejected and regenerated.
> 4. A user-facing report flow on every question surface (`reports`
>    collection). Reports for "inappropriate content" trigger an
>    immediate admin alert; other reasons are reviewed weekly.
> 5. Stale custom-topic Arena content is cleaned up after 7 days.
>
> User accounts include a neutral age gate (birth year + month picker)
> at onboarding; users under 13 cannot complete onboarding. Display
> names go through profanity filtering, and admins can force a rename
> if a violation is detected.

---

## APPENDIX B — MASCOT GENERATION BRIEF

Reference for AI image-tool prompt-writing when Mert is ready to produce
visual assets (Midjourney, DALL-E, Stable Diffusion, Imagine, etc.).
Prompt-writing happens in a future chat session; this section captures
the inputs.

### Form / character direction

- **Primary direction: "yüzlü beyin" (faced brain) — abstract /
  imaginative form.**
- Justification: "Brainjamin" name references brain; trivia category is
  saturated with animal mascots (Trivia Crack / Quizizz / Kahoot
  patterns). Abstract form differentiates and integrates brand orange
  naturally.
- **Risk to flag in prompt:** avoid Pixar Inside Out resemblance —
  prompt must include "warm but distinct from Pixar properties."
- **Alternative direction (if Mert prefers animal):** owl with academic
  mentor tone, warm orange + large-eyed, NOT mystical/occult-styled
  (avoids Duolingo comparison).

### 8 expressions — core set

Each expression rendered from the same base character:

1. **Idle / Friendly** — neutral mentor (loading, empty states, default)
2. **Curious** — Daily reveal, "ready to play?" prompts
3. **Encouraging** — onboarding welcome, daily reminder push
4. **Celebrating** — achievement unlock, level-up, win
5. **Surprised** — high score, unexpected outcome
6. **Worried** — streak risk, eliminate moment, error states
7. **Mischievous** — tricky question, ATT prompt, "bet you can crack it"
8. **Thoughtful** — Self-Test category picker, Arena custom topic creation

### Asset deliverables (3 groups)

**Group A — Master assets:**
- 8 vector SVG, one per expression
- 8 PNG export at 1024×1024, transparent background

**Group B — App icon:**
- 1024×1024 master PNG (mascot face/silhouette + brand orange background)
- Auto-generated platform sizes (Apple required: 20, 29, 40, 58, 60, 76,
  80, 87, 120, 152, 167, 180, 1024)
- Android adaptive icon: foreground SVG/PNG (mascot) + solid `#F97316`
  background, 512×512 Play Store icon

**Group C — Push notification icon (Android):**
- Monochrome silhouette, 96×96 master, white-on-transparent (Android
  Material requirement)

### Color rules

- **Mascot body:** primary `#F97316` (brand orange) dominant.
- **Accents:** white, neutral dark navy (e.g., `#1E293B`), light
  cream-orange (e.g., `#FFF7ED`).
- **BANNED everywhere:** `#FF9F04`. State this explicitly in any
  generation prompt.
- **Background:** mascot ships with transparent BG; app applies bg
  layer separately.
- **Outlines:** stylistic choice — if used, must be consistent across
  all 8 expressions.

### Voice / persona — shared with copywriter

The same source-of-truth document is shared with the EN copywriter (for
push templates, error states, achievement copy). Persona / do-don't list:

- **DO:** warm but smart, slightly playful, world-curious, occasional
  gentle teasing
- **DON'T:** condescending, baby-talk, aggressive, guilt-trippy
  (Hard NO), corporate-formal, EN-only humor that doesn't translate

### Reference inspirations

- **Pattern (NOT visual) reference:** Duolingo Duo for mascot
  personality + behavior pattern.
- **Visual warmth/wit reference:** New Yorker cartoonist tradition
  (flat shapes, expressive minimalism).
- **Avoid:** Pixar Inside Out (similarity risk on faced-brain form),
  any Disney/Marvel/Nintendo IP, generic "smart owl" tropes.

When Mert returns to draft the actual image-generation prompts, this
section provides all inputs.

---

*End of BRAINJAMIN_TODO.md*
