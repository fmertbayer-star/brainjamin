# BRAINJAMIN TODO
Last updated: 2026-04-30

---

## NEXT UP — Active Thread

**Sprints 1.4.5, 1.5, and 1.5.5 are code-complete on disk; Sprint 1
closes after the deferred smoke-test pass.**

Sprint **1.5 + 1.5.5**: auth providers + `linkWithCredential`, recovery,
`Info.plist` URL scheme, ARB verification — merged to `main`-ready
workspace. **Smoke test pending** (not run this session).

**First task next session — 8-scenario smoke plan** (closes Sprint 1 when
all pass):

**Chrome — Tests 1–6**

1. **Google sign-in** — Anonymous → permanent link (no account conflict).
2. **Email** — Sign-up flow for a **new** email (no prior Firebase account).
3. **“Account already exists”** — Same email as an existing Brainjamin user:
   validate **Cancel** (stay anonymous) and **Switch accounts** (destructive
   path) both behave as designed.
4. **Anonymous path** — “Continue without signing in” completes onboarding and
   lands on MainShell.
5. **Reload persistence** — After completing onboarding + auth choices,
   hard reload; user should not replay onboarding incorrectly.
6. **Apple on web** — Expect graceful failure / `authAppleUnavailableWeb`
   messaging (Apple web not wired in Sprint 1.5).

**Samsung SM-G990E — Tests 7–8**

7. **Google sign-in** — Native Android Google flow (`google_sign_in` +
   Firebase).
8. **Apple sign-in on Android** — Document actual behavior (`isAvailable` /
   graceful messaging); acceptable outcomes include “not available” UX.

After **all eight** pass → **Sprint 1 fully closed**. **Sprint 2** (Daily
Question + Self-Test) becomes next.

Sprint 1 sub-sprint status:

| Sub-sprint | Scope | Status |
|---|---|---|
| 1.1 | Bootstrap | ✅ done |
| 1.2 | Theme + i18n + ServerTimeService | ✅ done |
| 1.3 | Anonymous auth + onboarding (UI only) | ✅ done + smoke-tested |
| 1.4 | go_router + 5-tab main shell + empty states | ✅ done + smoke-tested |
| 1.4.5 | 4-tab MainShell + Home cards + standalone routes | ✅ done + smoke-tested (Chrome, 7 scenarios, prior session on 5-tab→4-tab refactor path) |
| 1.5 | Apple + Google + Email + `linkWithCredential` | ✅ done code-complete; quality gates clean; **awaiting** 8-scenario smoke above |
| 1.5.5 | Recovery + `Info.plist` + ARB verification | ✅ done |
| **Sprint 1 close** | **8-scenario smoke (Chrome 1–6 + Samsung 7–8)** | **first task — next session** |

Mascot artwork is NOT a Sprint 1 dependency — placeholder
`CircleAvatar(brandOrange) + Icons.psychology` ships in 1.3 (already)
and 1.4. Real mascot integrates in Sprint 5 (Profile + achievements) or
via a patch sprint when the illustrator deliverable arrives. TODO
markers are present in `welcome_screen.dart`, `age_gate_screen.dart`
(blocked screen), and `sign_in_screen.dart` to flag the placeholders.

---

## 🔴 IMMEDIATE (Launch Blocker — all must be done before App Store submission)

### Identity & accounts
- ~~**Domain registration** — `brainjamin.com` (or `.net` if `.com` taken) on
  GoDaddy, 3-year, WHOIS privacy ON, Tam Alan Adi Korumasi OFF, Kurumsal
  E-posta Pro Light OFF. **Mert handles this directly, not via Cursor.**~~
  ✅ Done 2026-04-30.
- ~~**Apple Developer enrollment under Stratech FZCO** — verify Brainjamin is set
  up as a separate App Store Connect record under existing Stratech FZCO Apple
  Developer Program (Team ID `J863Y2PK9U`), not a Flit variant. App Store
  Connect App ID `6765467964` created.~~ ✅ Done 2026-04-30.
- **Google Play Console** — Brainjamin listing under Stratech FZCO. Same
  verification.
- ~~**Firebase project creation** — `brainjamin-prod` (or similar). Enable:
  Auth (Anonymous + Apple + Google + Email/password), Firestore, Cloud
  Functions, Hosting (single target initially: `brainjamin-prod-user`),
  Storage, Realtime Database (for `.info/serverTimeOffset`), Crashlytics.~~
  ✅ Done 2026-04-30. Project ID: `brainjamin-prod-app` (`brainjamin-prod`
  was unavailable). Region: `us-central1`. Plan: Blaze with $25/month
  budget alert. Services enabled: Auth (Anonymous only — Apple + Google
  + Email defer to Sprint 1.5), Firestore, Storage, RTDB, Hosting (default
  site only), Crashlytics. Cloud Functions ready (Blaze) but `firebase
  init functions` runs in a later sub-sprint.

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

### Pre-launch ops (DNS + email routing — still open)

- **`brainjamin.com` DNS** — Point apex/domain to **Firebase Hosting**; wire
  **Cloudflare Email Routing** (or equivalent) for `support@` / `legal@` /
  `privacy@` forwards per P1 ops notes. **Not done yet —** schedule with
  **Sprint 6/7** (build + submission sprint) unless Mert pulls it forward.

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

1. **Sprint 1 — Bootstrap + Auth + Main shell** (split into 5 sub-sprints)

   1.1 **Bootstrap** (next)
       - `flutter create brainjamin --org com.stratech --platforms=ios,android,web`
       - Pubspec dependencies: firebase_core, firebase_auth, cloud_firestore,
         firebase_storage, firebase_database, firebase_crashlytics,
         firebase_analytics, intl
       - `flutterfire configure --project=brainjamin-prod-app` →
         registers iOS, Android, Web apps in Firebase Console
       - `lib/core/bootstrap/app_bootstrap.dart` (Firebase.initializeApp +
         Crashlytics handlers)
       - Smoke-test screen (#F97316 Material 3 theme, "Brainjamin /
         Firebase ready" centered)
       - Quality gate: `flutter analyze` → No issues found

   1.2 **Theme + i18n + ServerTimeService**
       - `lib/core/constants/app_colors.dart` (#F97316 only; #FF9F04 banned
         per PR-1)
       - Polished ThemeData (Material 3, brand color, typography scale)
       - `intl` + `flutter_localizations` + `app_en.arb` skeleton with 3-5
         starter keys
       - `lib/core/services/server_time_service.dart` — syncs
         `.info/serverTimeOffset` once at app start, exposes `.now()` (PR-10)

   1.3 **Anonymous auth + onboarding flow (UI only)**
       - Anonymous sign-in on app start (auto, silent)
       - Welcome screen
       - Age gate screen — neutral birth year + month picker, blocks <13
         (PR-11)
       - Sign-in screen — UI placeholders for Apple/Google/Email buttons
         (handlers wired in Sprint 1.5; for now they show a "coming soon"
         snackbar)

   1.4 **5-tab main shell**
       - Bottom nav: Home/Tournaments, Self-Test, Arena, Duel, Profile
       - Empty-state placeholder per tab (no real content; mascot
         placeholders are plain icons until illustrator deliverable lands)
       - Single `AppRouter` (no brand/admin split per CONTEXT § Architecture)

   1.5 **Apple + Google + Email providers + linkWithCredential**
       - iOS Developer Console: create App ID `com.stratech.brainjamin`,
         Service ID, Sign in with Apple key (manual, Mert)
       - Firebase Console: enable Apple, Google, Email/password providers
       - Google: register SHA-256 fingerprint, wire OAuth client
       - `linkWithCredential` flow for anonymous → permanent
       - "Account already exists" branch handled with explicit user prompt
         (anonymous progress is lost on existing-account sign-in per
         CONTEXT § Auth)
       - NO email verification mail (per CONTEXT)
       - NO phone verification anywhere (per PR-5)

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

### 2026-04-30 (akşam) — Sprint 1.5.5 closed (auth recovery + verification)

Three tasks: ARB baseline diff (could not execute — no Sprint 1.4.5 commit in
git history because all sprints in this session were uncommitted; flagged
correctly per CB-8, no fabrication), Info.plist CFBundleURLTypes added with
REVERSED_CLIENT_ID
`com.googleusercontent.apps.1047648611720-36o7lult2k7iob1f397q89tn1puesm08`
(top-level sibling, well-formed XML), 21 Sprint 1.5 ARB keys verified present
(the 24 in spec was a count-error — `accountExists*` 4 + `authError*` 6 +
email sheet/UI 11 = 21, and `authErrorGeneric` was double-counted in spec).

Quality gates: `flutter analyze` → No issues found. `flutter test` → 2/2 passed.
`git grep "FF9F04"` / `"DateTime.now()"` / `"_showComingSoon"` → 0 hits each.

### 2026-04-30 (akşam) — flutterfire configure regen + Firebase Console SHA setup (Mert manual)

- `flutterfire configure --project=brainjamin-prod-app --platforms=ios,android,web --yes` ran successfully on Mert's machine after Cursor failed in MINGW64 (interactive auth issue).
- `GoogleService-Info.plist` downloaded manually from Firebase Console → `ios/Runner/GoogleService-Info.plist` (CLI didn't write the iOS plist on Windows host — known issue).
- Android debug keystore SHA-1 (`A1:7C:F0:BC:BF:96:DC:AF:F5:87:EB:97:42:4C:00:FF:64:AE:04:30`) and SHA-256 (`0E:58:53:E0:60:19:58:EA:DB:73:9A:8B:E3:5B:92:45:74:B1:24:7B:F6:1A:EA:D4:CD:5D:DE:FE:C6:57:8C:55`) added to Firebase Console → Brainjamin (`android`) app fingerprints.
- `flutterfire configure` rerun → `google-services.json` now has `oauth_client` populated (2 OAuth clients in first client object).
- Release keystore SHA fingerprints deferred to Sprint 8 (Beta + soft launch). Debug keystore is sufficient for Sprint 1 + dev work.

### 2026-04-30 (akşam) — Sprint 1.5 code-complete (auth providers + linkWithCredential)

Goals: Apple + Google + Email/Password providers + linkWithCredential-first
conversion preserving anonymous progress per CONTEXT § Auth.

Files created:

- `lib/core/services/auth_result.dart` — sealed `AuthResult` sum type (`AuthSuccess`, `AuthLinkedToExistingAccount`, `AuthFailure`, `AuthCancelled`)
- `lib/core/utils/auth_error_localizations.dart` — Firebase error code → ARB key mapping
- `lib/features/onboarding/email_sign_in_sheet.dart` — email/password bottom sheet with `fetchSignInMethodsForEmail`-based disambiguation + segmented Sign up/Sign in fallback
- `ios/Runner/Runner.entitlements` — Sign In with Apple capability (Default)

Files modified:

- `pubspec.yaml` — `sign_in_with_apple` ^7.0.1, `google_sign_in` ^7.2.0, `crypto` ^3.0.6 added
- `lib/core/services/auth_service.dart` — `linkOrSignInWithApple`, `linkOrSignInWithGoogle`, `linkOrSignInWithEmail` (sign-up + sign-in branches), `signInWithCredentialReplacingAnonymous`, `signOut`. Apple nonce SHA-256 + `OAuthProvider("apple.com")`. Google: native `authenticate()` on mobile, `signInWithPopup` on web. Web Apple → `AuthFailure('apple_web_unsupported')`.
- `lib/core/services/onboarding_state_service.dart` — `brainjamin.auth.onboarding_completed` key + persist/clear/read
- `lib/core/services/onboarding_flow_controller.dart` — `isAuthCompleted` flag, `markAuthCompleted`, `reloadAuthDismissalFromPersistence`
- `lib/core/bootstrap/app_bootstrap.dart` — loads `authCompleted` into `BootstrapResult`
- `lib/main.dart` — passes `initialAuthCompleted` to `OnboardingFlowController`
- `lib/router/app_router.dart` — `TODO(sprint-5)` on auth flag vs routing (Profile tab will read `isAuthCompleted`)
- `lib/features/onboarding/sign_in_screen.dart` — real OAuth/email handlers with loading state, `AlertDialog` for credential-already-in-use (“Switch accounts” path), Brainjamin-voice error mapping
- `lib/l10n/app_en.arb` — 21 new keys for Sprint 1.5 (account-conflict dialog, error messages, email sheet UI). NOTE: file was rebuilt mid-sprint after an accidental git checkout reverted it; Sprint 1.4.5 ARB entries were re-authored from memory at this point — Sprint 6 EN copywriter pass will polish all copy regardless.
- `ios/Runner.xcodeproj/project.pbxproj` — `CODE_SIGN_ENTITLEMENTS` for Debug/Release/Profile, file ref for `Runner.entitlements`
- `test/widget_test.dart` — `TODO(sprint-7)` for future auth integration tests

Quality gates: `flutter analyze` → No issues. `flutter test` → 2/2 passed. All grep gates 0 hits (FF9F04, DateTime.now, _showComingSoon, MainShellPlaceholder, SelfTestTab|ArenaTab|DuelTab).

Implicit decisions:

- Email disambiguation: `fetchSignInMethodsForEmail` (deprecated; ignore deprecation locally) when API returns; fallback to always-visible Sign up/Sign in segments. Anonymous path always uses `linkWithCredential`.
- Apple on web: explicit `AuthFailure('apple_web_unsupported')` → `authAppleUnavailableWeb` localized message.
- Google on web (anonymous): `User.linkWithPopup(GoogleAuthProvider)` preserves anonymous UID.
- Apple on Android: `SignInWithApple.isAvailable()` check; falls back to `apple_unavailable_platform` message if native flow not supported.
- Conflict dialog: red “Switch accounts” CTA (`BrainjaminColors.error`) for destructive emphasis.
- `signOut`: clears `brainjamin.auth.onboarding_completed`; optional OnboardingFlowController re-sync hook for Sprint 5 Profile tab.

Smoke test deferred to next session — 8 scenarios planned (Chrome 1–6, Samsung 7–8).

### 2026-04-30 (akşam) — Apple Developer Program + App Store Connect + Firebase Auth providers setup

Mert manual work, not Cursor.

Apple Developer (Stratech Dynamic FZCO, Team ID `J863Y2PK9U`, shared with Flit):

- App ID `com.stratech.brainjamin` registered with Sign In with Apple + Push Notifications capabilities
- Service ID `com.stratech.brainjamin.signin` registered, configured: Primary App ID `com.stratech.brainjamin`, domain `brainjamin-prod-app.firebaseapp.com`, return URL `https://brainjamin-prod-app.firebaseapp.com/__/auth/handler`
- Sign in with Apple Key registered (Key ID `L2K726P8TK`), `.p8` file stored locally at `C:\flutter_projects\secrets\brainjamin\AuthKey_L2K726P8TK.p8` (outside repo, never committed)
- App Store Connect record created: Brainjamin / iOS / 1.0 Prepare for Submission, App Store Connect App ID `6765467964`
- Listing content (screenshots, description, etc.) deferred to Sprint 6

Firebase Console (`brainjamin-prod-app`):

- Apple sign-in provider enabled with Service ID `com.stratech.brainjamin.signin` (Apple-side already trusts the Firebase callback URL via Service ID configuration)
- Google sign-in provider enabled (project support email = `info@stratechdynamic.net`)
- Email/Password sign-in provider enabled (Email link passwordless: kapalı per CONTEXT § Auth and Karar 2 from session)

Apple `.p8` → Cloud Secret Manager NOT done — deferred per session decision (only needed for future server-side Apple identity verification, e.g. `revokeUserAccount`; not Sprint 1.5 scope).

### 2026-04-30 (akşam) — Sprint 1.4.5 closed (4-tab refactor + Home cards)

Demoted Self-Test, Arena, Duel from tabs to standalone routes (`/self-test`, `/arena`, `/duel`). Added Tournaments + Leaderboard tabs. Home rebuilt as 5-card surface.

Files created:

- `lib/core/widgets/mascot_empty_state.dart` — shared empty-state widget (CircleAvatar + brand orange + `Icons.psychology` placeholder, `TODO(mascot)` preserved)
- `lib/features/self_test/self_test_screen.dart`, `lib/features/arena/arena_screen.dart`, `lib/features/duel/duel_screen.dart` — standalone screens, each using `MascotEmptyState`
- `lib/features/main_shell/tabs/tournaments_tab.dart`, `lib/features/main_shell/tabs/leaderboard_tab.dart`
- `lib/features/home/widgets/{daily_question_card, self_test_entry_card, quick_duel_card, active_arenas_card, next_live_countdown_card}.dart` — 5 placeholder Home cards with Material Card + brand-tinted accent + chevron + InkWell

Files deleted: `lib/features/main_shell/tabs/{self_test_tab, arena_tab, duel_tab}.dart`

Files modified:

- `lib/features/main_shell/main_shell.dart` — 4-page IndexedStack (Home, Tournaments, Leaderboard, Profile), exposes `onNavigateToTab` callback to `HomeTab`
- `lib/features/main_shell/tabs/home_tab.dart` — 5-card layout, no longer uses `MascotEmptyState`
- `lib/features/main_shell/tabs/profile_tab.dart` — uses `MascotEmptyState`
- `lib/router/app_router.dart` — 3 new top-level routes (`/self-test`, `/arena`, `/duel`); redirect tightened: any non-`/onboarding` path requires onboarding completion
- `lib/l10n/app_en.arb` — 5 keys removed (`mainTabSelfTest`, `mainTabArena`, `mainTabDuel`, `homeEmptyTitle`, `homeEmptyBody`), 19 keys added (`mainTabTournaments`, `mainTabLeaderboard`, `*EmptyTitle/Body` for Tournaments + Leaderboard, screen titles, 10 Home card keys), 6 updated copy for screen-context (`selfTestEmpty*`, `arenaEmpty*`, `duelEmpty*`)
- `test/widget_test.dart` unchanged (2 tests still pass)

Implicit decisions:

- Tab icons: Tournaments `Icons.emoji_events`, Leaderboard `Icons.leaderboard`
- Card visual system: brand orange tint (alpha 0.06) + matching border (alpha 0.35), leading mode icon + trailing chevron, full-card InkWell
- “Next Live Tournament” card: switches MainShell tab to Tournaments via `onNavigateToTab(1)`, not router push (preserves MainShell state)
- Daily Question card: no-op tap with `TODO(sprint-2)` marker

Quality gates: `flutter analyze` → No issues. `flutter test` → 2/2 passed. All grep gates 0 hits.

Smoke-tested in Chrome (7 scenarios all passed): Welcome → Age Gate <13 block → ≥13 advance → Sign In + 3 placeholder buttons + anonymous CTA → MainShell entry on Home → 5-card Home + 4-tab nav across all tabs → reload persists → tab switch from Next Live card works. Step 12 (deep-link redirect from `/self-test` to `/onboarding/welcome` when storage cleared) was attempted but failed due to literal “PORT” placeholder in Mert's manual URL test; redirect logic itself is correct and will be naturally exercised in Sprint 1.5 smoke tests.

### 2026-04-30 (afternoon) — Sprint 1.4 closed

Sprint 1.4 shipped go_router migration + 5-tab MainShell with
mascot-voice empty states.

Files created:
- lib/core/services/onboarding_flow_controller.dart — ChangeNotifier
  wrapping OnboardingStateService, in-memory flag mirror so
  go_router redirect (sync) can read without async lookup
- lib/core/services/onboarding_flow_provider.dart — InheritedNotifier,
  no `provider` package
- lib/router/app_router.dart — single GoRouter factory; redirect logic
  uses controller flags to gate `/` and `/onboarding/*` access
- lib/features/main_shell/main_shell.dart — NavigationBar (M3) +
  IndexedStack for tab state preservation
- lib/features/main_shell/tabs/{home,self_test,arena,duel,profile}_tab.dart
  — 5 placeholder tabs, mascot CircleAvatar + Brainjamin-voice empty
  state copy
- lib/features/onboarding/age_blocked_screen.dart — extracted from
  age_gate_screen.dart for separate go_router route registration

Files deleted:
- lib/features/onboarding/onboarding_gate.dart (logic moved to
  go_router redirect)
- lib/features/onboarding/onboarding_routes.dart (route names now in
  AppRouter)

Files modified:
- pubspec.yaml — go_router ^14.6.2 added (resolved to 14.8.1 in lock)
- lib/main.dart — MaterialApp.router + StatefulWidget owning controller
  and GoRouter for app lifetime
- lib/core/bootstrap/app_bootstrap.dart — returns BootstrapResult with
  preloaded SharedPreferences flags
- lib/features/onboarding/{welcome,age_gate,sign_in}_screen.dart —
  migrated to context.goNamed; sign_in's anonymous CTA now relies on
  controller notifyListeners triggering go_router redirect
- lib/l10n/app_en.arb — tab titles + 5 empty state title/body pairs
  (mascot voice draft, marked TODO(copy) for EN copywriter polish)
- lib/core/constants/app_colors.dart — PR-1 comment rephrased so
  banned hex string does not appear in lib/ (grep gate compliance)
- test/widget_test.dart — both tests updated to pump
  BrainjaminApp(bootstrap: BootstrapResult(...)) directly, isolated
  from Firebase

Quality gates:
- flutter analyze: No issues found
- flutter test: 2/2 passed
- git grep "FF9F04" lib/ test/ → 0 hits
- git grep "DateTime.now()" lib/features/ → 0 hits
- git grep "MainShellPlaceholder" → 0 hits
- git grep "Navigator.of(context).push" lib/ → 0 hits

Smoke test (Chrome, 7 scenarios all passed): Welcome render → Age Gate
<13 block + Go back → Age Gate ≥13 advance → Sign In screen + 3
placeholder buttons + anonymous CTA → MainShell entry on Home tab →
5-tab navigation across all tabs (mascot empty states render correctly)
→ reload (Ctrl+R) skips onboarding and lands on MainShell directly.

Architectural notes:
- go_router 14.8.1 resolved (asked for 14.6.2; lock pinned newer minor
  within caret range — acceptable)
- One ignore comment retained: `// ignore:
  prefer_const_constructors_in_immutables` on OnboardingFlowProvider
  constructor — InheritedNotifier's notifier param is mutable
  ChangeNotifier so genuine const is impossible; suppression is
  correct, no real bug risk
- Tab structure (Home / Self-Test / Arena / Duel / Profile) is interim
  — Sprint 1.4.5 refactors to final 4-tab layout per Brainjamin's
  game mode taxonomy

### 2026-04-30 (afternoon) — Sprint 1.1, 1.2, 1.3 implementation

Three sub-sprints implemented in one Cursor session, all passing
`flutter analyze` and `flutter test`. Sprint 1.3 code-complete but
pending manual smoke test in Chrome (carries over to next session — see
NEXT UP).

**Sprint 1.1 — Bootstrap** (commit `89496a7`)
- `flutter create brainjamin --org com.stratech --platforms=ios,android,web`
- 8 pubspec deps: firebase_core 3.15.2, firebase_auth 5.7.0, cloud_firestore 5.6.12, firebase_storage 12.4.10, firebase_database 11.3.10, firebase_crashlytics 4.3.10, firebase_analytics 11.6.0, intl
- `flutterfire configure --project=brainjamin-prod-app --platforms=ios,android,web` — 3 Firebase apps registered (Android `1:1047648611720:android:...`, iOS `1:1047648611720:ios:...`, Web `1:1047648611720:web:...`); `lib/firebase_options.dart` generated
- `lib/core/bootstrap/app_bootstrap.dart` — Firebase.initializeApp + Crashlytics handlers (FlutterError.onError + PlatformDispatcher.instance.onError)
- `lib/main.dart` — `BrainjaminApp` + `_SmokeTestScreen` ("Brainjamin / Firebase ready" hardcoded)
- Smoke test verified in Chrome: bold title + subtitle visible, console clean ✅
- Note: `flutterfire` not on PATH on Mert's MINGW64 by default; resolved via `~/.bashrc` alias `alias flutterfire='flutterfire.bat'`. Cursor uses `dart pub global run flutterfire_cli:flutterfire ...` form which works regardless. Either pattern is fine.

**Sprint 1.2 — Theme + i18n + ServerTimeService**
- `lib/core/constants/app_colors.dart` — `BrainjaminColors` token set (brandOrange `0xFFF97316`, brandOrangeLight, brandOrangeDark, surface, surfaceVariant, onSurface, onSurfaceMuted, success, warning, error, info). PR-1 BANNED `0xFFFF9F04` warning comment at top.
- `lib/core/theme/app_theme.dart` — `BrainjaminTheme.light` Material 3 with `ColorScheme.fromSeed` + token overrides for primary, surface, surfaceContainerHighest, onSurface, error.
- `flutter_localizations` + `intl 0.19.0` (downgraded from `0.20.2` for `flutter_localizations` compatibility — Cursor's correct trivial pick)
- `l10n.yaml` + `lib/l10n/app_en.arb` (3 keys initially: appTitle, smokeTestTitle, smokeTestSubtitle — last two superseded in 1.3)
- `MaterialApp` wired with `localizationsDelegates`, `supportedLocales`, `onGenerateTitle`
- `lib/core/services/server_time_service.dart` — PR-10 implementation. Reads `FirebaseDatabase.instance.ref('.info/serverTimeOffset')` with 5s timeout; defensive fallback to 0ms. `static .now()` exposed. `kDebugMode` log on initialize.
- `app_bootstrap.dart` updated: `await ServerTimeService.initialize()` between Firebase init and Crashlytics handlers, in its own try/catch.
- Smoke test in Chrome: console showed `[ServerTimeService] offset=0ms` ✅
- `flutter_gen` synthetic-package deprecation warning surfaced (Flutter SDK notice, not actionable in V1; track for SDK upgrade in V2).

**Sprint 1.3 — Anonymous auth + onboarding flow (UI only)**
- `shared_preferences 2.5.3` added (only new dependency).
- `lib/core/services/auth_service.dart` — `BrainjaminAuthService` with silent anonymous sign-in (`ensureSignedIn`, 10s timeout, defensive Crashlytics logging, no rethrow). Wired into bootstrap after ServerTimeService.
- `lib/core/services/onboarding_state_service.dart` — SharedPreferences wrapper for `brainjamin.onboarding.completed` and `brainjamin.age_gate.passed` flags. Birth date is intentionally NOT stored (PR-11 privacy minimization, COPPA-aligned).
- 4 onboarding screens + 1 routes file:
  - `welcome_screen.dart` — mascot placeholder (CircleAvatar + Icons.psychology + TODO marker), title, body, "Let's go" CTA in mascot voice
  - `age_gate_screen.dart` — neutral birth month + birth year dropdowns (NOT Yes/No per PR-11). Age computed via `ServerTimeService.now()`. Under-13 routes to private `_AgeBlockedScreen` with "Brainjamin is for ages 13 and up." (PR-11 exact text) + "Go back" button (no bypass).
  - `sign_in_screen.dart` — 3 OutlinedButtons (Apple/Google/Email) showing localized snackbar ("Brainjamin is sharpening this — coming in the next update."). Bottom prominent `FilledButton.tonal` "Continue without signing in" per PR-4 anonymous-first.
  - (Superseded in Sprint 1.4) `onboarding_gate.dart` was the top-level entry; replaced by `go_router` redirects + `OnboardingFlowController`.
- `lib/main.dart` — `MaterialApp.router` with `go_router`; entry routes resolve to onboarding or `MainShell`.
- `app_en.arb` — 16 new keys (welcomeTitle/Body/Cta, ageGate*, signIn*, mainPlaceholder*); old smoke keys removed.
- `test/widget_test.dart` — replaced single smoke test with two tests: "Welcome shows on first launch" (empty SharedPreferences) and "Skips welcome when completed" (mocked completed flag). Both pump OnboardingGate directly without bootstrapping Firebase (clean test isolation).
- Quality gates: `flutter analyze` → No issues. `flutter test` → 2/2 passed. `git grep "FF9F04"` → only docs and PR-1 BANNED comment. `git grep "DateTime.now()"` in `lib/features/` → zero hits (only `server_time_service.dart` uses it, expected).

**Git history note:** Sprint 1.2 and 1.3 commits both made at session end (Sprint 1.2 changes were uncommitted on disk when 1.3 began — Cursor's Step 1 discovery flagged this correctly per CB-8). After session-end commits, history is `89496a7 Sprint 1.1` → Sprint 1.2 → Sprint 1.3 → docs commit. Sprint 1.2's pre-1.3 intermediate state is not preserved as a separate snapshot, but that's acceptable given the sub-sprint discipline.

**Toolchain footnote:** A second Firebase CLI account `info@stratechdynamic.net` was added (`firebase login:add`) and set as global default (`firebase login:use`). Brainjamin's Firebase project is owned by this account; Flit's continues under `info@mfbteknoloji.com`. **If returning to Flit work, run `firebase login:use info@mfbteknoloji.com`** before any deploy from that workspace, otherwise the wrong account is active.

### 2026-04-30 (morning) — Sprint 1 prereqs closed + toolchain verified

- **Domain registered:** `brainjamin.com` purchased on GoDaddy (3-year,
  WHOIS privacy ON).
- **Firebase project created:** `brainjamin-prod-app` (`brainjamin-prod`
  taken), region `us-central1`, Blaze plan with $25/month budget alert.
  Services enabled in this order: Auth (Anonymous), Firestore (production
  rules), Storage (production rules, default bucket
  `gs://brainjamin-prod-app.firebasestorage.app`), Realtime Database
  (locked mode), Cloud Functions (Blaze-ready, no deploy yet), Hosting
  (default site `brainjamin-prod-app.web.app`, no second site yet),
  Crashlytics (passive, activates with Flutter plugin in Sprint 1.1).
  Apple/Google/Email auth providers deferred to Sprint 1.5.
  App Check deferred per Apple Developer enrollment (no change from Flit
  posture).
- **Toolchain verified on Mert's machine:** Flutter 3.29.3 (channel
  stable, same as Flit), Dart 3.7.2, Firebase CLI 15.13.0, FlutterFire
  CLI 1.3.2 (newly installed via `dart pub global activate`; PATH alias
  added to `~/.bashrc` so MINGW64 finds the `.bat` wrapper). Firebase
  identity already logged in as `info@mfbteknoloji.com`.
- **Sprint 1 split decided:** 5 sub-sprints (1.1 Bootstrap, 1.2 Theme +
  i18n + ServerTimeService, 1.3 Anonymous auth + onboarding, 1.4 5-tab
  shell, 1.5 Apple + Google + Email providers). See NEXT UP and CURSOR
  SPRINT SEQUENCE.

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

**Repo initialized 2026-04-30.** Sprint 1.1 + 1.2 + 1.3 + 1.4 + **1.4.5 +
1.5 + 1.5.5** implementation shipped in workspace. Confirm `origin` /
GitHub presence before relying on backup — see push step after commit.
Branch: `main`. Current concrete tree (only files Brainjamin owns —
Flutter-generated Android/iOS/web boilerplate omitted for clarity):

```
lib/
  core/
    bootstrap/
      app_bootstrap.dart
    constants/
      app_colors.dart
    services/
      auth_result.dart                         ← new (1.5)
      auth_service.dart                        ← expanded (1.5)
      onboarding_flow_controller.dart          ← expanded (1.5)
      onboarding_flow_provider.dart
      onboarding_state_service.dart            ← expanded (1.5)
      server_time_service.dart
    theme/
      app_theme.dart
    utils/
      auth_error_localizations.dart            ← new (1.5)
    widgets/
      mascot_empty_state.dart                  ← new (1.4.5)
  features/
    arena/
      arena_screen.dart                        ← new (1.4.5)
    duel/
      duel_screen.dart                         ← new (1.4.5)
    home/
      widgets/
        active_arenas_card.dart                ← new (1.4.5)
        daily_question_card.dart               ← new (1.4.5)
        next_live_countdown_card.dart          ← new (1.4.5)
        quick_duel_card.dart                   ← new (1.4.5)
        self_test_entry_card.dart              ← new (1.4.5)
    main_shell/
      main_shell.dart                          ← refactored to 4-tab (1.4.5)
      tabs/
        home_tab.dart                          ← rebuilt as 5-card (1.4.5)
        leaderboard_tab.dart                   ← new (1.4.5)
        profile_tab.dart
        tournaments_tab.dart                   ← new (1.4.5)
    onboarding/
      age_blocked_screen.dart
      age_gate_screen.dart
      email_sign_in_sheet.dart                 ← new (1.5)
      sign_in_screen.dart                      ← real handlers (1.5)
      welcome_screen.dart
    self_test/
      self_test_screen.dart                    ← new (1.4.5)
  l10n/
    app_en.arb                                 ← rebuilt (1.5)
  firebase_options.dart                        ← regenerated (1.5.5)
  main.dart
  router/
    app_router.dart                            ← 3 routes added + redirect tightened (1.4.5)

ios/
  Runner/
    GoogleService-Info.plist                   ← downloaded from Console (1.5.5)
    Info.plist                                 ← CFBundleURLTypes added (1.5.5)
    Runner.entitlements                        ← new, Sign In with Apple (1.5)
  Runner.xcodeproj/project.pbxproj             ← CODE_SIGN_ENTITLEMENTS wired (1.5)

android/
  app/
    google-services.json                       ← oauth_client populated (1.5.5)

test/
  widget_test.dart                             ← TODO(sprint-7) added (1.5)

l10n.yaml
pubspec.yaml                                   ← 3 new deps (1.5)
pubspec.lock
firebase.json
BRAINJAMIN_CONTEXT.md                          ← § provenance + Apple Sign In identifiers
BRAINJAMIN_RULES.md
BRAINJAMIN_TODO.md                             ← updated this session
.gitignore
analysis_options.yaml
.metadata
README.md
```

Files explicitly NOT carried over from Flit (do not port):
- `main_brand.dart`, `main_admin.dart`
- All `lib/features/brand/*`
- All `functions/src/brand*.ts`, `prediction*.ts`, `survey*.ts`,
  `phoneVerification*.ts`, `prize*.ts`, `discount*.ts`, `seedBrands.ts`
- All hosting target configurations except `brainjamin-prod-user` and
  `brainjamin-prod-landing` (latter not configured yet)

---

*End of BRAINJAMIN_TODO.md*