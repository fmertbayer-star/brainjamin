# BRAINJAMIN — SESSION FLOW

Two prompts. SESSION START at the beginning of every session, SESSION END before closing.

---

## SESSION START

Claude reach the bellow docs and leads the conversation.

1. BRAINJAMIN_RULES.md
2. BRAINJAMIN_CONTEXT.md
3. BRAINJAMIN_TODO.md
4. BRAINJAMIN_SESSION_FLOW
---

## SESSION END

Update BRAINJAMIN_TODO.md based on this session, then commit + push.

Get today's date from Claude's conversation context (the system
prompt's "current date" line, e.g. "Monday, May 04, 2026" →
"2026-05-04"). Do NOT call shell `date` or guess from file
timestamps — Claude's context date is authoritative for this
session. Use it for all date headers in this run.

═══════════════════════════════════════════════════════════════
PART 1 — Update BRAINJAMIN_TODO.md
═══════════════════════════════════════════════════════════════

1. Set the "Last updated:" line to today's date.
2. Update "## NEXT UP — Active Thread":
    - **Mid-work** = the session stopped in the middle of a defined
      multi-step task whose next step is unambiguous (e.g. "deploy
      pending after Cursor changes", "pilot run blocked on auth").
      Write a short Turkish handoff note: what was being done, where
      it stopped, what the literal next move is.
    - **Clean handoff** = no unfinished multi-step task; the next
      session is free to pick any priority. Set the section body to:
      "*(Empty — clean handoff.)*"
    - When in doubt between the two, default to clean handoff —
      over-explaining stale context costs more than re-deriving it.
3. For every task COMPLETED this session:
    - Remove it from its priority section (IMMEDIATE / P1 / P2 / P3 / P4 / PARTIALLY DONE).
    - It will be logged in RECENTLY DONE (Part 4). No duplication.
4. For every NEW task that emerged this session:
    - Add it to the appropriate priority section.
    - DEFAULT priority: P2.
    - Use IMMEDIATE or P1 only if Mert explicitly said so.
5. Update "## ✅ RECENTLY DONE":
    - Find the "### YYYY-MM-DD" subsection for today. If absent, create it at the TOP of RECENTLY DONE.
    - Append one bullet per concrete piece of work from this session:
    • Code commits → include short SHA, e.g. "(commit abc1234)"
    • File edits → include path + line range when relevant
    • Decisions → state decision + 1-line rationale
    • Deferrals → state what was deferred and why
    - Within RECENTLY DONE, find any "### YYYY-MM-DD" subsection where (today - date) > 14 days and DELETE the entire subsection (header + bullets). Git history is the long-term record.

═══════════════════════════════════════════════════════════════
PART 2 — Regenerate "## 🤖 CODEBASE SNAPSHOT"
═══════════════════════════════════════════════════════════════

REPLACE (not append) the entire contents under "## 🤖 CODEBASE SNAPSHOT" with freshly-generated content from the codebase.

### Cloud Functions

Read functions/src/index.ts. List every `export` (function name, alphabetical, comma-separated, single paragraph). If the file has fewer than 80 or more than 150 exports, flag it in the diff summary.

### Screen inventory

Glob lib/features/**/*_screen.dart. Also explicitly include lib/features/tournament/live_question_screen_v2.dart even though it doesn't end with _screen.dart (pattern exception).
Group by top-level folder. Format: "- **folder/** (N): file1, file2, ..." (without _screen.dart suffix).

### Firestore collections

From firestore.rules: extract every top-level `match /COLLECTION_NAME/{...}` (4-space indent root match blocks).
From functions/src: grep for db.collection("NAME"), db.collection('NAME'), admin.firestore().collection("NAME"), opts.db.collection("NAME") at chain root.
Print the union, alphabetical, deduplicated, comma-separated single paragraph.
Mark "[rules-only]" (in rules but no CF use) and "[code-only]" (in CF but no top-level match).

### Routes

Read lib/core/constants/app_routes.dart (if it exists; current
codebase has no such file — write "*(none — not present)*" in
that case) and lib/router/app_router.dart. The router lives at
lib/router/, NOT lib/core/routing/ — that earlier path was
superseded by the Sprint 1.4 go_router migration. Single-table
format (Brainjamin has one router only). Update only if route
patterns or screens have changed.

### Hosting targets

Read firebase.json hosting array + .firebaserc targets. Format: 2-row table (target / site / public path) — Brainjamin has one app + one landing.

### Repo structure

Print 2-level deep tree of: lib/, functions/src/, web/. Plain text inside a fenced code block.

═══════════════════════════════════════════════════════════════
PART 3 — Diff summary
═══════════════════════════════════════════════════════════════

Print plain text (no markdown auto-links):

BRAINJAMIN_TODO.md:

- Last updated: set to YYYY-MM-DD
- NEXT UP: [updated with handoff note | cleared to empty]
- Tasks completed (removed from priority sections): N
- Tasks added: N (priority breakdown: IMMEDIATE=a, P1=b, P2=c, P3=d, P4=e)
- RECENTLY DONE: today subsection [created | appended]; bullets added: N; old subsections pruned (>14d): N (dates: ...)
- CODEBASE SNAPSHOT: regenerated. CF exports: X, Screens: Y, Collections: Z.

Files untouched by this SESSION END run: BRAINJAMIN_RULES.md,
BRAINJAMIN_CONTEXT.md. (Note: Claude/SESSION END never modifies
these. Mert may have edited CONTEXT.md manually earlier in this
same session — that is independent of this claim.)

═══════════════════════════════════════════════════════════════
PART 4 — Commit + push
═══════════════════════════════════════════════════════════════

Run, in order:
git add BRAINJAMIN_TODO.md
git status
git commit -m "session-end YYYY-MM-DD: <short summary, e.g. '3 tasks done, 2 new'>"
git push origin main

If `git status` shows uncommitted changes to files OTHER than
BRAINJAMIN_TODO.md, do NOT auto-stage them. Instead, list each
file and ask Mert to classify it into one of these categories:

- **(a) Production code change** (any file under lib/,
  functions/src/, firestore.rules, firebase.json, pubspec.yaml,
  package.json, etc.) → Mert must commit these in a SEPARATE
  commit BEFORE SESSION END proceeds. SESSION END's commit is
  for TODO.md only. Production code commits are Mert's
  responsibility (typically right after the Cursor turn that
  produced them — flag if missing).
- **(b) Temporary diagnostic / one-shot script** (e.g.
  functions/scripts/dump*.mjs, diagnose*.mjs, wipe*.mjs created
  during a debug session) → Mert decides per file: commit (if
  reusable), delete (if disposable), or add to .gitignore (if
  pattern-shaped). Do not commit "for safety" — these accumulate.
- **(c) Unclear / unfamiliar file** → Stop. Ask Mert what it is
  before classifying.

Only after all non-TODO files are classified and handled may
SESSION END proceed to its TODO.md-only commit.

If push fails, print the error and stop. Do not retry automatically.

**Cursor commit hygiene check.** SESSION END does not commit
code changes Cursor produced earlier in the session. Before the
final TODO.md commit, verify that any code edits made by Cursor
during this session have already been committed by Mert. If
`git log --oneline -10` does not show a commit reflecting each
Cursor turn's output, flag the gap to Mert and let Mert commit
the production code in a separate commit FIRST. The TODO.md
"session-end YYYY-MM-DD" commit must come AFTER all production
code commits, never before.

═══════════════════════════════════════════════════════════════
ABSOLUTE PROHIBITIONS
═══════════════════════════════════════════════════════════════

DO NOT modify BRAINJAMIN_RULES.md.
DO NOT modify BRAINJAMIN_CONTEXT.md directly. CONTEXT.md is
updated only via dedicated Cursor prompts (Mert authorizes;
Cursor executes). SESSION END never touches CONTEXT.md. Same
for BRAINJAMIN_SESSION_FLOW.md — it is updated only via
dedicated Cursor prompts, never by SESSION END.
DO NOT touch any code file.
DO NOT auto-stage files outside BRAINJAMIN_TODO.md.
If a CODEBASE SNAPSHOT subsection has zero matches, write "*(none)*". Do not fabricate.
DO NOT modify BRAINJAMIN_SESSION_FLOW.md during a SESSION END
run. Updates to SESSION_FLOW are dedicated Cursor turns, like
the one that produced this very revision.
