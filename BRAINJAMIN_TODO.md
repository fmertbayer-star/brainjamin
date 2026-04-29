# BRAINJAMIN TODO
Last updated: 2026-04-29

---

## NEXT UP — Active Thread

**Cursor sprint 1 has not started yet.** Architecture phase is complete
(16 architectural decisions closed in the 2026-04-29 session — see
RECENTLY DONE). Before Cursor sprint 1 begins, three things must be in
place:

1. Repo initialized (`flutter create brainjamin`)
2. Domain registered (`brainjamin.com` purchase confirmed)
3. Firebase project created (`brainjamin-prod`)

Sprint 1 itself will be **"Bootstrap + Auth + Main shell"** — the same
scope Flit's Session 1 covered, scoped to Brainjamin's narrower V1
(no brand panel, no admin web target).

---

## 🔴 IMMEDIATE (Launch Blocker — all must be done before App Store submission)

### Identity & accounts
- **Domain registration** — `brainjamin.com` (or `.net` if `.com` taken) on
  GoDaddy, 3-year, WHOIS privacy ON, Tam Alan Adi Korumasi OFF, Kurumsal
  E-posta Pro Light OFF. **Mert handles this directly, not via Cursor.**
- **Apple Developer enrollment under Stratech FZCO** — already enrolled per
  Flit; verify Brainjamin is set up as a separate App Store Connect record,
  not a Flit variant.
- **Google Play Console** — Brainjamin listing under Stratech FZCO. Same
  verification.
- **Firebase project creation** — `brainjamin-prod` (or similar). Enable:
  Auth (Anonymous + Apple + Google + Email/password), Firestore, Cloud
  Functions, Hosting (single target initially: `brainjamin-prod-user`),
  Storage, Realtime Database (for `.info/serverTimeOffset`), Crashlytics.

### Apple-mandatory pre-launch
- **App Check activation deferred** until iOS Apple Developer enrollment
  fully completes — same posture as Flit. Plan: (1) add `firebase_app_check`
  to pubspec, (2) wire Play Integrity (Gradle) + DeviceCheck (iOS), (3)
  activate debug provider in main, (4) register SHA-256 in Firebase Console,
  (5) flip `enforceAppCheck: true` on critical user-facing callables first
  (`submitAnswers`, `submitLiveAnswer`, `joinLiveTournament`,
  `joinUserArena`, `submitDuelAnswers`, `validateUsername`,
  `findOrCreateDuelMatch`, `generateArenaQuestions`, `submitReport`,
  `softDeleteAccount`, `exportUserData`), (6) verify on physical device,
  (7) flip remaining callables in second wave. Do NOT enable on
  admin/seed/debug functions.
- **ATT (App Tracking Transparency) prompt** — Apple's stricter 2024+
  enforcement requires this be shown before first ad load if any tracking
  occurs. Copy + timing must be drafted by EN copywriter.
- **UMP consent SDK** — Google's User Messaging Platform for GDPR/CCPA.
  Brainjamin's Tier 1 includes UK + IE (GDPR), CA + USA (CCPA / state
  privacy laws). Mandatory before AdMob serves ads.
- **Privacy Policy + Terms of Service** — drafted with COPPA + GDPR + CCPA
  + UK GDPR + Australia Privacy Act + Apple/Google compliance. Hosted at
  `brainjamin.com/privacy` and `brainjamin.com/terms`. Linked in:
  - App Store listing
  - Play Store listing
  - In-app Settings → Legal
  - Onboarding age gate screen
- **Age rating questionnaire** — completed in App Store Connect targeting
  13+ rating; UGC moderation pipeline documented in submission notes.

### Pre-launch content
- **4,000 seed questions** — batch Gemini script, 20 categories × 200 each.
  Quality gate: 50-question pilot first → manual review → prompt
  calibration → full batch. Per-category sample audit (20 questions/cat
  manual review). NOT delegated to Cursor — this is a content ops task.
- **EN-native copywriter** — store description, promotional text,
  screenshot captions, in-app strings polish, **Brainjamin character bible**
  (mascot voice guide), push notification templates, error/empty state
  copy.
- **Brainjamin mascot character design** — illustrator brief includes:
  - Personality (encouraging mentor, slightly mischievous, broadly
    knowledgeable, world-cultures curious)
  - Visual style (works at 1024×1024 app icon size + small in-app
    contexts)
  - Brand color integration (#F97316)
  - Multiple expressions (curious, encouraging, surprised, celebrating,
    worried — for streak risk pushes)
  - File deliverables: SVG + multiple PNG sizes + icon set
- **App icon** — features Brainjamin mascot face/silhouette. Distinctive
  in App Store grid. 1024×1024 master + all required platform sizes.
- **Screenshot template design** — 8 screenshots, brand orange gradient,
  EN copy, mascot present in at least 4. Mobile-first.
- **Preview video production** — 15-30 sec, EN, muted auto-play optimized.

### Anthropic / OpenAI / Gemini provisioning
- **OpenAI account + API key + initial credit** — for fallback chain (V1.12
  C.9) + embeddings (text-embedding-3-small). Add to Firebase Cloud Secret
  Manager.
- **Anthropic account + API key + initial credit** — for fallback chain.
  Add to Firebase Cloud Secret Manager.
- **Gemini API key** (Google Cloud) — primary generator. Add to Cloud Secret
  Manager.
- **`luxon` or `date-fns-tz` dependency** added to Cloud Functions
  package.json (PR-10 timezone math).
- **`firebase_database` Flutter dependency** confirmed for
  `.info/serverTimeOffset` access.

### Trademark
- **Trademark check on "Brainjamin"** — invented compound word, low risk
  but verify USPTO + EUIPO no conflicts. Stratech FZCO legal counsel
  (1-2 hour billable). Pre-Cursor-sprint task.

---

## 🟡 P1 (Pre-Launch — to be solved before public launch but not Sprint-1
blocking)

These are open architectural questions and pre-launch items that can be
handled in parallel with early Cursor sprints, but must close before
public launch.

### Open architectural questions (D / E / F categories carried from V1.12
patch — not closed in 2026-04-29 architecture session)

- **D-2: Question pool unbounded growth** — pool will grow ~1,200
  questions/month from engine alone, plus ad-hoc Arena custom topics.
  Year 1 estimate: 15-25K questions. Storage cost is negligible at this
  scale, but query performance for `used_questions` filter degrades. Plan:
  (1) define archive policy for questions older than 18 months with
  zero-use, (2) consider sharded `questions_public` by category if needed.
  Not Sprint-1 blocking.

- **D-3: Profile-tab anonymous warning card copy + placement** — anonymous
  user opens Profile tab. What copy + CTA? Brainjamin-voiced. Options:
  card at top vs prompt on tap of streak/leaderboard/settings. Decide
  before Sprint 5 (Profile + Ranking).

- **E-1: Push cap overflow** — user is owed 5 pushes after 8 hours of
  quiet hours. What happens at flush time? Options: (a) collapse to one
  digest "You missed 5 things — open Brainjamin to see", (b) release all
  5 individually (annoying), (c) drop all but the most recent. Decide
  before Sprint 6 (Push + ASO).

- **E-2: Battle Arena spectator screen polish** — base spectator screen
  is in scope (see CONTEXT § Arena). Polish layer (audio cue when player
  eliminated, share-result CTA, chat-style commentary) is open. Decide
  whether any polish ships V1 or all defers to V2.

- **F-1: Locale fallback for non-EN devices** — user in Turkey or Brazil
  somehow downloads the app (Tier 1 distribution doesn't fully prevent
  this — VPN, sideload, family sharing). What does the OS-locale-EN-fallback
  feel like? Plan: explicit "This app is in English" splash on first
  launch if device locale is non-EN, give user "Continue in English" or
  "Close" option. Decide before App Store submission.

- **F-2: App Store Connect content rating questionnaire — exact answers**
  drafted but not validated against the 2026 questionnaire UI (Apple
  changed the questionnaire). Final answers must be reviewed against the
  current Connect interface during submission prep. Not Sprint-1 blocking.

- **F-3: ATT prompt copy + timing** — drafted by EN copywriter but final
  copy must comply with Apple's 2024+ stricter enforcement. Reject = app
  cannot use IDFA = lower AdMob eCPM. Frame copy to maximize opt-in
  without misleading. Pre-submission task.

### Pre-launch ops
- **Domain DNS configuration** — once GoDaddy purchase completes, point
  apex `brainjamin.com` to Firebase Hosting landing target. SSL
  provisioning via Firebase. Subdomain `app.brainjamin.com` if user app
  needs a non-apex URL (vs in-app hosting only).
- **Email infrastructure** — `support@brainjamin.com`,
  `legal@brainjamin.com`, `privacy@brainjamin.com`. Cloudflare Email
  Routing (free) forwards to Mert's personal email. Avoid the GoDaddy
  Kurumsal E-posta upsell.
- **Crashlytics setup** — automatically wired through `firebase_crashlytics`
  Flutter plugin; verify reports flowing during Sprint 1 testing.
- **Cloud Logs retention policy** — default 30 days for Cloud Functions
  logs is fine for V1.

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

Lower-priority items that can ship after V1 launch:

- **Master spec doc** — single canonical spec for Brainjamin. Lower
  priority since CONTEXT.md serves the same purpose for the architecture
  team of one (Mert + Claude). Build only if a third stakeholder enters.
- **Test brand cleanup** — N/A for Brainjamin (no brands)
- **XP system audit post-launch** — verify XP scale across all 6 modes
  feels balanced; rebalance if Live tournaments dominate or Self-Test
  feels under-rewarded.
- **Onboarding flow A/B test** — V1 ships single flow; A/B variants are
  V2.
- **Load / stress test** — capacity test for Live tournament before any
  scaled marketing push (synthetic 1K, 5K, 10K concurrent users in Live).
- **Centralized callable security middleware** — replace per-function
  `assertNotAnonymous`-style checks with a single `protectedCallable(
  handler, {requireAuth, requireNonAnon, requireAdmin, rateLimit})`
  wrapper. Refactor task. (Carry over hygiene from Flit P2.)
- **Code-only collections audit** — `ai_cache`, `live_push_reminders`,
  `daily_questions`, `blocked_terms`, `embeddings` may be referenced in
  CF code without explicit Firestore rules — default deny. Verify CF-only
  access (admin SDK) or add explicit rules where client reads/writes.
- **`fcm_token` exposure (LOW/P2)** — `fcm_token` is currently inside
  `users/{uid}` which is auth-readable. Long-term fix: split to
  `users_private/{uid}/fcm_token`. V2.
- **Analytics dashboard polish** — V1 admin dashboard reads
  `admin_metrics/{dateKey}` via simple list/chart. Polished interactive
  dashboard with date-range pickers, drill-downs, segmentation: V2.
- **Cross-tournament question dedup per user** — `used_questions` is
  global; per-user history fetched at generation. Already designed
  (CONTEXT § Question pipeline). Verify it works as designed during
  Sprint 4 (Tournament Engine).
- **Soru kategorilerinin gözden geçirilmesi** — 20 kategori sabitlenmis
  (CONTEXT § Tournament Engine). Eger pre-launch seed sirasinda bir
  kategori "fazla genis" veya "fazla dar" cikarsa kategori isimlerini
  yeniden gozden gecir. Sprint-2 ile paralel.
- **Soru kalitesi feedback loop** — `flagged: true` sorulari ve user
  reports'lari prompt calibration'a geri besle. Lansman sonrasi 4 hafta
  ozellikle kritik. Manuel surec V1; otomasyon V2.
- **"Müşahede paneli" pattern for admin** — Flit'te admin panelinde
  "Admin müdahalesi" labeling + audit log style. Brainjamin'de admin
  zaten cok minimal, V1'de bu pattern'a gerek yok. V2 kapsaminda admin
  panel buyutulurse bu pattern uygulanir.

---

## 🟢 V2 (Post-Launch — explicitly deferred)

Items that were explicitly deferred from V1 in the architecture session.
Listed here so they don't get lost.

### Subscription
- **Brainjamin Plus** — $1.99/month, $9.99/year, 3-day trial, ad-free
  only, RevenueCat-driven. Architecture supports it (entitlement flag,
  ad-free path); V2 turns it on.
- **Plus billing grace period** — V1.12 C.12; depends on Plus existing.

### Friends + social
- **Friends system** — friend requests, accepts, blocks, friend
  leaderboards, friend invite for Duel, Arena friend-only mode.
- **Username search** — required for friends.
- **Social push triggers** — friend request received, friend accepted.
  Adds 3rd push toggle category "Social".

### Rewarded ads
- **Rewarded ad integrations** — extra hayat (Battle Arena), soru atlama
  (Self-Test), ikinci sans, bonus XP. Server-side reward verification
  (CF callable, idempotent + signed receipt). Hile riski analizi sart.

### Multilingual
- **ES (Spanish)** — second language. Doubles AI generation cost,
  doubles tournament count. Decide based on V1 retention data.
- **Other languages** based on download data.

### Admin panel expansion
- User moderation UI
- Reports triage UI
- Live ops dashboard with real-time charts
- Manual content tools (add/edit `questions_public` from UI)
- Friend system moderation tools

### Architecture hygiene
- `users_private/{uid}` split for `fcm_token` etc.
- Centralized callable security middleware
- Code-only collections explicit rules
- Old question archival policy

---

## 📋 CURSOR SPRINT SEQUENCE (proposed)

Following the same shape Flit used (Session 1-6 architectural sessions
mapped to Cursor sprint sequence), Brainjamin's sprints:

1. **Sprint 1 — Bootstrap + Auth + Main shell**
   - `flutter create brainjamin`
   - Firebase initialize, multi-platform setup (iOS, Android, Web)
   - Anonymous auth on app start
   - Apple + Google + Email auth via `linkWithCredential`
   - Onboarding flow (welcome → age gate → optional sign-in → main shell)
   - 5-tab main shell (Home/Tournaments, Self-Test, Arena, Duel, Profile)
   - Empty state mascot artwork
   - Internationalization (`intl` + `app_en.arb`)
   - Theme + color tokens (#F97316)
   - `ServerTimeService` Dart class
   - Crashlytics wiring

2. **Sprint 2 — Daily Question + Self-Test**
   - `selectDailyQuestion` CF
   - Daily Question UI + streak + forgive
   - Self-Test category picker, 25-Q loop, 10-sec timer
   - `self_test_leaderboard/{categoryId}_{weekKey}`
   - Pool dedup (`used_questions/{uid}/seen/{qId}`)
   - Push: daily reminder + streak risk + quiet hours queue infrastructure

3. **Sprint 3 — Arena + Duel**
   - 3-step Arena wizard
   - List mode + Battle Arena mode (with spectator screen base)
   - `generateArenaQuestions` CF (LLM for custom, pool for category)
   - Apriori narrow topic check
   - Solo arena (1+ player) support
   - `findOrCreateDuelMatch` CF
   - Duel queue (active 30-sec + 24-hour background)
   - Same-opponent 24-hour dedup
   - Invite link with 7-day expiry

4. **Sprint 4 — Tournament Engine (Classic + Live)**
   - 20-category rotation state
   - `generateTournamentContent` (T-24h)
   - `makeTournamentVisible` (T-12h)
   - `startLiveTournament` + `runLiveTournament` (server loop)
   - Late-entry-through-Q5 logic
   - `liveTournamentWatchdog`
   - `finalizeLiveTournament` (post-Q20) + `finalizeClassicTournament`
     (T+24h)
   - LLMService implementation (Gemini → OpenAI → Claude fallback)
   - 3-layer verification (generator + correctness + language)
   - Semantic dedup via embeddings (0.92 cosine)
   - Live tournament real-time UI driven by `live_tournaments/{ltId}`
     listener
   - Score calculation (server-side, `15000 - (submittedAt - startedAt)`)

5. **Sprint 5 — Profile + Ranking + Achievements**
   - Profile tab (XP, level, streak, achievements grid)
   - Anonymous warning card (copy from D-3 decision)
   - Username creation flow + atomic transaction
   - `validateUsername` CF
   - Global + weekly leaderboards (`rebuildLeaderboards`,
     `resetWeeklyLeaderboard`)
   - 17 achievements + `checkAchievements` CF
   - Achievement unlock animation (mascot)
   - Settings (sign-in change, push toggles, language, legal links,
     "Export my data", "Delete my account")
   - Account lifecycle (`softDeleteAccount`, `purgeDeletedAccounts`,
     `exportUserData`)

6. **Sprint 6 — AdMob + Push + ASO assets**
   - Banner integration (3 placements: Duel lobby, Classic results,
     Self-Test lobby)
   - Interstitial integration (post-game, frequency cap, 3-game
     onboarding suppression)
   - UMP consent SDK
   - ATT prompt
   - Push notification full set (5 triggers + 1 inline duel-match-found)
   - Push tone: Brainjamin voice
   - Quiet hours queue + flush + critical-push exemptions
   - App icon final
   - 8 screenshots final
   - Promo video final
   - Privacy Policy + ToS final
   - App Store / Play Store submission prep

7. **Sprint 7 — Admin + Reports + final hardening**
   - `/admin/quality` Quality Review screen
   - `/admin/dashboard` read-only analytics dashboard
   - `aggregateAdminMetrics` CF
   - `submitReport` CF + report button on every relevant surface
     (custom topic Arena, Duel, etc.)
   - `wipeTestData` CF
   - `seedQuestions` CF (the 4,000-question seed runner)
   - Final security pass (App Check enable plan stays staged for
     post-Apple-enrollment)
   - Crashlytics dashboard review
   - Cloud Functions cost monitoring setup

8. **Sprint 8 — Beta + soft launch**
   - TestFlight + Internal Testing tracks
   - 10-20 beta users, 1 week feedback
   - Hotfix sprint
   - Public launch (App Store + Play Store, Tier 1 only)

---

## ✅ RECENTLY DONE

### 2026-04-29 — Architecture phase complete (16 decisions closed)

A full architecture session in this conversation closed the following
decisions, all of which are now reflected in BRAINJAMIN_CONTEXT.md and
BRAINJAMIN_RULES.md:

1. **Subscription Plus → V2** (deferred from V1)
2. **Ads V1: Banner + Interstitial only** (Rewarded → V2)
3. **Markets: Tier 1 only** (USA, UK, CA, AU, IE, NZ — 6 countries)
4. **AI verification: 3-layer** (generator + correctness + language) +
   semantic dedup, language layer advisory only
5. **Bootstrap pool: 4,000 seed questions** (no ghost tournament run)
6. **Account lifecycle: 30-day soft delete + data export V1**
7. **Leaderboard V1 + Achievements V1** (17 rozet) **+ Friends V2**
8. **Live tournament times: 07:00 UTC + 23:00 UTC** (US-primary slot
   23:00); **quiet hours queue with per-push exemption flag**
9. **Admin: Quality Review + read-only Analytics Dashboard** + Firebase
   Console for moderation + reports collection
10. **Onboarding: hızlı 3-screen flow** + 5-tab main shell + anonymous
    full-play + context-aware permission asks
11. **Daily Question: 1 question/day, no time limit, transparent forgive
    UI, +50 XP correct / +10 XP wrong + explanation**
12. **Self-Test, Arena, Duel detail decisions:**
    - Self-Test: kategori-haftalik leaderboard, 30-day pool recycling
    - Arena: 1+ player valid (no minimum), spectator screen, apriori
      narrow topic check
    - Duel: 7-day invite expiry, 24-hour background queue, 24-hour same-
      opponent dedup
13. **Name + Domain: Brainjamin** + `brainjamin.com` (3-year, GoDaddy)
14. **Anonymous → permanent: option A** — no `users_public` doc until
    conversion; `onUserConverted` auth trigger creates it lazily
15. **Age rating: 13+** (not 12+ — Apple replaced 12+ with 13+ in 2026
    update); neutral age gate (birth year + month picker); COPPA privacy
    maddesi; UGC moderation pipeline documented for Apple Review
16. **Push tone: Brainjamin voice throughout** (mascot character bible
    owned by EN-native copywriter outside Cursor); EN-only

### Bonus context decisions (confirmed in same session)
- Repo + project naming: `brainjamin` repo, `com.stratech.brainjamin`
  (iOS bundle + Android package), `brainjamin-prod` Firebase project
- App Store subtitle format: "Brainjamin: Trivia & Quiz Game"
- Stratech Dynamic FZCO is the publishing entity (same as Flit)
- 32 Cloud Functions in V1 (down from V1.12 patch's 35 because Plus's 2
  CFs and rewarded ad's 1 CF deferred to V2)

---

## 📁 CODEBASE SNAPSHOT

**Repo not yet initialized.** This section will populate after Sprint 1
(`flutter create brainjamin` + initial commit). Expected structure
(adapted from Flit, B2B parts removed):

```
lib/
  core/
    bootstrap/
      app_bootstrap.dart
    services/
      server_time_service.dart       ← new in Brainjamin (PR-10)
      llm_service_client.dart        ← thin client; logic is in CF
    constants/
      app_colors.dart                ← #F97316 only
      categories.dart                ← 20-category list
  features/
    onboarding/
      welcome_screen.dart
      age_gate_screen.dart           ← neutral birth year + month
      sign_in_screen.dart
    home/
      home_tab.dart                  ← tournament cards
    daily/
      daily_question_screen.dart
    self_test/
      self_test_lobby.dart
      self_test_session.dart
      self_test_leaderboard.dart
    arena/
      create_arena_wizard/
        step_1_basics.dart
        step_2_details.dart
        step_3_summary.dart
      arena_lobby.dart
      arena_session.dart
      battle_spectator_screen.dart   ← Battle Arena spectator
    duel/
      duel_lobby.dart
      duel_match_screen.dart
      duel_results.dart
    tournament/
      classic/
      live/
        live_tournament_screen.dart  ← real-time listener
        live_question_screen.dart
        live_results_screen.dart
    profile/
      profile_tab.dart
      anonymous_warning_card.dart
      achievements_grid.dart
      settings_screen.dart
    admin/
      quality_review_screen.dart     ← /admin/quality
      analytics_dashboard.dart       ← /admin/dashboard
  l10n/
    app_en.arb                       ← EN-only (V1)
  router/
    app_router.dart                  ← single router (no brand/admin split)
  firebase_options.dart
  main.dart                          ← single entry point

functions/src/
  index.ts
  config.ts
  authGuards.ts                      ← assertNotAnonymous etc., NO phone
  shared/
    aiProviders.ts                   ← LLMService fallback chain
    aiModelsLoader.ts
    sessionQuestions.ts
    secrets.ts
  embeddings/
    openaiEmbeddings.ts
    semanticDedup.ts
  tournament/
    generateTournamentContent.ts
    makeTournamentVisible.ts
    startLiveTournament.ts
    runLiveTournament.ts             ← server loop, 540s timeout
    sendLiveTournamentPush.ts
    finalizeClassicTournament.ts
    finalizeLiveTournament.ts        ← triggered post-Q20
    liveTournamentWatchdog.ts
  daily/
    selectDailyQuestion.ts
  arena/
    generateArenaQuestions.ts
  duel/
    findOrCreateDuelMatch.ts
  cleanup/
    pruneStaleGames.ts
  leaderboards/
    rebuildLeaderboards.ts
    resetWeeklyLeaderboard.ts
  identity/
    validateUsername.ts
    onUserConverted.ts               ← auth trigger
  achievements/
    checkAchievements.ts
  notifications/
    sendDailyReminder.ts
    sendStreakAtRiskReminder.ts
    notifyDuelInvite.ts
    notifyDuelComplete.ts
    flushQueuedPushes.ts
  account/
    softDeleteAccount.ts
    purgeDeletedAccounts.ts
    exportUserData.ts
  admin/
    aggregateAdminMetrics.ts
    submitReport.ts
    wipeTestData.ts
  seed/
    seedQuestions.ts                 ← 4,000-question seed runner
    seedLegalDocs.ts
    setBrainjaminLogo.ts

landing/
  public/                            ← Brainjamin landing page assets
  index.html
  privacy.html
  terms.html

web/
  favicon.png
  icons/
  index.html
  manifest.json
```

Files explicitly NOT carried over from Flit (do not port):
- `main_brand.dart`, `main_admin.dart`
- All `lib/features/brand/*`
- All `functions/src/brand*.ts`, `prediction*.ts`, `survey*.ts`,
  `phoneVerification*.ts`, `prize*.ts`, `discount*.ts`, `seedBrands.ts`
- All hosting target configurations except `brainjamin-prod-user` and
  `brainjamin-prod-landing`

---

*End of BRAINJAMIN_TODO.md*
