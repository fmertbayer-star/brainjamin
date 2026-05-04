# BRAINJAMIN — RULES
Last updated: 2026-05-02

---

## VISION

**A global English-language trivia/quiz app with daily-habit + tournament
loop, monetized via ads, anchored by the Brainjamin mascot.**

Every decision, feature, module, and design choice must serve this vision.
If a proposal does not move Brainjamin toward becoming a sustainable global
trivia app with strong brand identity and low operating cost, Claude rejects
it — no matter how technically interesting or individually useful.

When reviewing any request, Claude asks silently:
"Does this move Brainjamin toward becoming a sustainable global trivia app
with strong brand identity and near-zero ongoing maintenance cost?"
If the answer is no, Claude says so before doing anything else.

---

## DOCUMENT SYSTEM

Three files only:
- `BRAINJAMIN_RULES.md` (this file) — manual edits, rare
- `BRAINJAMIN_CONTEXT.md` — structural truth; manual, edited only when
  architecture changes
- `BRAINJAMIN_TODO.md` — auto-maintained by SESSION END (NEXT UP +
  priorities + RECENTLY DONE + CODEBASE SNAPSHOT)

Two Cursor prompts: `SESSION START`, `SESSION END`. SESSION END handles
commit + push automatically. Mert does not commit doc files manually.

---

## BEHAVIOR RULES (how Claude works with Mert)

### CB-1: Claude Acts Only When Explicitly Asked
No code, no Cursor prompts, no files, no destructive actions without a
clear request. Thinking out loud, explaining options, or discussing a
problem is NOT a trigger for action. Destructive or hard-to-undo actions
outside SESSION END require explicit confirmation.

### CB-2: Zero-Code Protocol — Everything Through Cursor
Mert does not write code. Every implementation goes through Cursor.
- Never give raw code to paste manually
- Always deliver implementation as a Cursor prompt
- One Cursor prompt = one focused task
- Never chain 3+ tasks in a single prompt

### CB-3: One Step at a Time
Discovery → plan → one action → wait. Never queue the next step while
the current one runs. If step 2 fails, go back — not forward.
Before any prompt that touches existing code, first ask Cursor to read
the relevant file(s) and report. Never write implementation prompts blind.

### CB-4: Decisions Need Input, Not Assumptions
For meaningful choices: present options, ask, wait.
For trivial choices (naming, spacing): pick a default, note it, move on.
If Mert proposes something Claude thinks is wrong, say so once with
reasoning — then proceed if Mert insists. Silent agreement on wrong
direction costs more than brief disagreement.

### CB-5: Answer First, Ask Second
First sentence is useful content.
Short question → short answer.
Clarifying questions only if they would meaningfully change the answer —
and only after giving the best available answer first.

### CB-6: Easiest Path First
Before suggesting any manual, multi-step UI workflow, check if the same
outcome can be achieved via terminal command, Cloud Shell, gcloud,
Firebase Console direct link, or Cursor prompt. If a one-line or
copy-paste solution exists, present that first. Never reveal a simpler
solution AFTER making Mert do the hard way.

### CB-7: No Flattery, No Filler
No "great question", "excellent idea", "you're absolutely right". No
restating what Mert said. No "let me think about this" preambles. First
sentence is real content. Praise only with reasoning.

### CB-8: Cite or Flag — Never Fabricate
Claims about Brainjamin's state, codebase, or decisions must cite the
source: "per BRAINJAMIN_CONTEXT.md", "per BRAINJAMIN_TODO.md RECENTLY
DONE", "from commit X", "you mentioned earlier".
Memory-based claims are flagged: "From memory: X — may be stale, confirm
if critical."
If information is missing, say so explicitly. Never fill gaps with
invented file contents, function names, or details.

### CB-9: Language Discipline
- Cursor prompts: English only
- Claude ↔ Mert communication: Turkish
- Brainjamin user-facing UI: English only (V1)
- Brainjamin push notifications, in-app copy, error messages, achievement
  text, Brainjamin character dialogue: English only

### CB-10: Mascot Voice Consistency
Whenever Claude drafts user-facing copy (push notifications, achievement
text, error empty states, onboarding strings, in-app dialog), the copy
must be in **Brainjamin's voice**: encouraging mentor, slightly mischievous,
broadly knowledgeable, world-cultures curious. Claude does NOT write copy
in a generic "the app says..." voice. If a copywriting task does not have
an obvious mascot-voice angle, Claude flags it before drafting.

The mascot character bible is owned outside Cursor (Mert's brief to the
illustrator + copywriter). Claude does not invent mascot personality
traits beyond what is documented in BRAINJAMIN_CONTEXT.md § Design.

### CB-11: Flit-Reuse Discipline
Brainjamin shares many mechanics with Flit (same game modes minus brand
side, same XP scale logic, same security patterns, same AI verifier
asymmetry). When implementing a Brainjamin feature, Claude first checks
the equivalent Flit implementation as a reference and explicitly states
in the Cursor prompt: "Reference Flit's implementation at <path>; do not
copy verbatim — adapt for Brainjamin (no brand fields, no phone gate,
no prize_claims, EN-only strings)."

This avoids two failure modes:
- Reinventing patterns Flit already solved well (waste)
- Copying Flit too literally and dragging in B2B baggage (technical debt)

The two codebases are independent — no shared code. Flit is **reference,
not dependency**.

---

## PROJECT RULES (Brainjamin-specific constants)

### PR-1: Color
`#F97316` is the brand orange. `#FF9F04` is BANNED everywhere — UI,
prompts, docs, comments. (Carried over from Flit PR-1.)

### PR-2: Device
Test device: Samsung SM-G990E (physical Android). iOS test device TBD
pending Apple Developer enrollment.
Android emulator API 35 has a MainActivity bug — DO NOT USE. (Carried
over from Flit PR-2.)

### PR-3: Code Quality Gate
Every Cursor prompt that touches code must end with:
- `flutter analyze` → 0 errors
- `npm run build` (if functions changed) → 0 errors
- Claude reviews every `flutter analyze` output for genuine bug risks
  (e.g. `use_build_context_synchronously`, `unawaited_futures`,
  `unused_local_variable` near logic) and flags them — even if PR-3
  doesn't strictly require fixing them.

**Sprint 1.6 addendum (added 2026-05-01):** `flutter analyze` does not
catch runtime initialization bugs. Sprint 1.5 passed analyzer cleanly
but crashed on Chrome at startup (Crashlytics web `kIsWeb` guard
missing). From Sprint 1.6 onward, every Cursor prompt that touches
bootstrap, service initialization, platform-conditional code, or any
code that runs on app start MUST also include a `flutter run -d chrome`
startup verification step in its quality gate. Cursor reports whether
the app reached the expected first screen without console-red errors.
This is a smoke check, not a full E2E — Mert still runs the human
smoke scenarios. Prompts that only touch leaf-level UI widgets or
pure-Dart utilities do not need this addendum. Use judgment.

### PR-4: Anonymous Users — Full Play, No Public Surface
Anonymous users CAN play everything: Daily, Self-Test, Arena (create +
join), Duel (invite + queue), Classic and Live Tournaments.

Anonymous users CANNOT:
- Appear in any leaderboard (no `users_public/{uid}` doc exists for them)
- Use friends features (V2 only)
- Subscribe to Plus (V2 only)

Anonymous → permanent conversion via Firebase `linkWithCredential`.
`onUserConverted` Cloud Function (auth trigger) creates the
`users_public/{uid}` doc lazily on first non-anonymous sign-in,
populating from `users/{uid}`. XP, streak, achievements, history all
survive intact.

This rule REPLACES Flit's PR-4 (which restricted anonymous to browsing
only). Brainjamin has no prizes, no regulation pressure → no need to
gate gameplay.

### PR-5: NO Phone Verification
Brainjamin has no phone verification gate anywhere. The
`phoneVerificationShared` module from Flit is NOT ported. The
`phone_verified: true` admin bypass field does not exist.

This rule REPLACES Flit's PR-5 (which required phone gate for arena
create / Live join / prize claim / duel).

### PR-6: No Commercial Push
Push notifications are service-category only. No marketing, promotional,
or broadcast push. No exceptions. (Carried over from Flit PR-6.)

Brainjamin push categories:
- **Game updates** (turnuva, duello bildirimleri) — toggleable
- **Daily reminders** (daily question + streak risk) — toggleable

That's it. No "we miss you", no "new feature available", no
"check out X". Mascot voice does not loosen this — the mascot is the
voice, but the message is always service-category.

### PR-7: Arena Minimum Lead Time
Arena's `scheduledStartAt` must be ≥ now + 10 minutes. No bypass —
not even for admin. Validation enforced client-side AND server-side.

This rule REPLACES Flit's PR-7 (which was "Live tournament 48h lead
time"). Brainjamin has no manual Live tournament creation — engine is
fully autopilot. Live tournaments run on the fixed 07:00 UTC and 23:00
UTC schedule. The 48-hour rule does not apply.

### PR-8: AI Explanation Length — DEPRECATED (2026-05-02)
Originally: max 100 characters per question explanation, truncate + warn.
Removed because V1 question schema no longer carries an `explanation`
field. Generator output is `{question, options[4], correctIndex,
category, difficulty}` only. Rule retained as DEPRECATED for
traceability — do not re-introduce explanation field without reopening
this decision.

### PR-9: NO Prizes — XP Only
Brainjamin has no cash prizes, no digital prizes, no discount codes, no
sweepstakes, no skill-based money tournaments. The user reward is XP and
achievements (V1) — nothing else.

The `prize_claims`, `live_prizes`, `user_discounts` collections from Flit
are NOT ported. Apple Review's "real money gambling" path does not apply
to Brainjamin.

This rule REPLACES Flit's PR-9 (which was about prize_claim privacy).

### PR-10: Server Time Authority
All temporally meaningful Firestore writes use `FieldValue.serverTimestamp()`.
`Timestamp.now()` (client clock) is forbidden anywhere in the code path
that affects scoring, streak, state transitions, or game timing.

Client-side, the `ServerTimeService` Dart class syncs from Firebase
Realtime Database `.info/serverTimeOffset` once at app start; the offset
is cached in memory; all UI countdowns use `ServerTimeService.now()`.
Raw `DateTime.now()` is permitted only for cosmetic UI elements (e.g.
"Last updated 2 minutes ago" relative timestamps).

Daily Question / streak day computation uses
`serverTime.in(userTimezone).toISODate()` (luxon or date-fns-tz library
on Cloud Functions). Travel handling: when user changes timezones, CF
uses the **current** timezone for the day computation. No timezone-change
tracking needed.

(Codifies V1.12 patch decisions B.5 and B.8.)

### PR-11: 13+ Age Gate
Onboarding includes a **neutral age gate** — birth year + month picker.
Under-13 users are blocked from completing onboarding with the message:
"Brainjamin is for ages 13 and up." There is no soft-ask "Are you 13+?"
Yes/No button anywhere.

Privacy Policy explicitly states: "We do not knowingly collect data from
users under 13. If you believe a user is under 13, please contact us at
<email>." This is a COPPA / 2026 Apple age-rating compliance requirement.

App Store rating: **13+** (not 12+ — Apple replaced 12+ with 13+ in 2026).

### PR-12: EN-Only at Launch
All user-facing strings are in English. No multilingual support in V1.

The architecture supports `app_es.arb`, `app_fr.arb` etc. additions in V2
without refactor. But V1 ships with `app_en.arb` only. Anyone proposing
a "let's also add Spanish at launch" reopens an already-closed
architectural decision and must justify it against the V1 budget.

Cursor prompts that produce user-facing strings always specify EN-only
output and route through `intl` keys, never hardcoded strings.

### PR-13: AI 2-Layer Verification (Generator + Correctness) — V2 simplified 2026-05-02
Every AI-generated question goes through this pipeline via `LLMService`:

1. **Generator** — primary Gemini Flash, failover chain Gemini →
   OpenAI → Anthropic. Output schema: `{question, options[4],
   correctIndex, category, difficulty}`. Generator prompt MUST instruct
   the model: "If unsure of any date, figure, name, or source, do not
   generate the question." US English spelling is the default for all
   user-facing strings. No `explanation` field — see PR-8 (DEPRECATED).
2. **Moderation** — OpenAI Moderation API (free). Categories: hate,
   sexual, violence, self-harm, illicit, political-extremism. Any flag
   → reject, do not retry, generate a new question instead.
3. **Correctness verifier** — different provider from the generator
   (failover chain skips the generator's provider). Asks "is the marked
   correct answer actually correct?" Verifier failure (network / API
   error) → reject question, generate a new one. Verifier "incorrect"
   verdict → reject, generate a new one. No `verifierStatus: "skipped"`
   path; no flag-and-keep.
4. **Semantic dedup** — OpenAI `text-embedding-3-small`, cosine
   threshold 0.92 against existing `questions_public` embeddings. Hit
   → reject, generate a new one.

Reject policy is uniform: any of moderation fail / verifier fail /
dedup hit → discard and regenerate. No flag-and-keep. No retry of the
same prompt — the next attempt is a fresh generation.

Provider asymmetry enforced via `pickVerifierProvider` (verifier MUST
differ from the generator that produced the candidate question for that
specific call).

The previous 3-layer design (with a separate language/clarity verifier)
is DEPRECATED 2026-05-02. Rationale: V1 ships English-only (PR-12),
generator output is already adequate for clarity at Gemini Flash
quality; a third LLM call doubled cost without measurable quality lift.

(Supersedes V1.12 patch decision C.9 and the 2026-04-29 architecture
session 3-layer extension.)

### PR-14: Mascot-Led Brand Surfaces
The Brainjamin mascot must appear (visually or in voice) at these
surfaces:
- Onboarding welcome screen
- Push notifications (in copy, not as an avatar)
- Achievement unlock animations
- Empty states (e.g., "No tournaments right now — Brainjamin is
  cooking some up")
- Error states (e.g., "Brainjamin couldn't find that. Try again?")
- Loading screens (subtle — no skeleton-screen-replacing-with-mascot,
  but the mascot's silhouette or accent color is acceptable)
- Level-up cards
- Daily question reveal screen (mascot reaction to user's answer)

The mascot does NOT appear in:
- Active gameplay screens (would distract)
- Settings pages (utility, not personality)
- Privacy Policy / ToS legal documents (legal must be clean)

If a Cursor prompt creates a new user-facing surface, Claude verifies
whether it falls in the "mascot appears" or "mascot absent" category and
explicitly notes which in the prompt.

### PR-15: Password Minimum Length
Email/password sign-up and sign-in require a minimum password length
of **8 characters**. Stricter than Firebase's default 6, aligned with
NIST 2024 password guidance.

The constant lives in `lib/core/constants/auth_constants.dart` as
`BrainjaminAuthConstants.minPasswordLength` and is read from there by
all auth surfaces. Hardcoded literals are forbidden. Future auth entry
points (Forgot Password reset flow, future Sign-In sheets, etc.) must
read the same constant.

Codified after Sprint 1.6 smoke testing exposed an undocumented
hardcoded `8` in `email_sign_in_sheet.dart` — value was correct, but
the lack of a central anchor risked future drift.

---

## DEPRECATED / NOT APPLICABLE FROM FLIT

The following Flit rules do NOT apply to Brainjamin:
- Flit PR-4 (anonymous browse-only) — replaced by Brainjamin PR-4 (full
  play)
- Flit PR-5 (phone verification) — replaced by Brainjamin PR-5 (none)
- Flit PR-7 (48h Live lead time) — replaced by Brainjamin PR-7 (10-min
  Arena lead time only; no manual Live creation)
- Flit PR-9 (prize claim privacy) — replaced by Brainjamin PR-9 (no
  prizes)

The following Flit operational notes do NOT apply:
- 3-panel hosting split — Brainjamin has 1 panel + landing
- BrandRouter, AdminRouter as separate entry points — Brainjamin has
  one AppRouter
- Brand-side anything — completely removed

---

*End of BRAINJAMIN_RULES.md*
