# BRAINJAMIN — SESSION FLOW

Two prompts. SESSION START at the beginning of every session, SESSION END before closing.

---

## SESSION START

Mert gives ducuments bellow to claude as drag and drop.

1. BRAINJAMIN_RULES.md
2. BRAINJAMIN_CONTEXT.md
3. BRAINJAMIN_TODO.md
4. BRAINJAMIN_SESSION_FLOW
---

## SESSION END

Update BRAINJAMIN_TODO.md based on this session, then commit + push.
Get today's date from the system in YYYY-MM-DD format. Use it for all date headers.

═══════════════════════════════════════════════════════════════
PART 1 — Update BRAINJAMIN_TODO.md
═══════════════════════════════════════════════════════════════

1. Set the "Last updated:" line to today's date.
2. Update "## NEXT UP — Active Thread":
    - If this session ended mid-work and the next session needs handoff context, write a short Turkish note (what was being done, where stopped, next move).
    - If this session ended cleanly, set the section body to: "*(Empty — clean handoff.)*"
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

Read lib/core/constants/app_routes.dart and lib/core/routing/app_router.dart. Single-table format (Brainjamin has one router only). Update only if route patterns or screens have changed.

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

Files untouched: BRAINJAMIN_RULES.md, BRAINJAMIN_CONTEXT.md.

═══════════════════════════════════════════════════════════════
PART 4 — Commit + push
═══════════════════════════════════════════════════════════════

Run, in order:
git add BRAINJAMIN_TODO.md
git status
git commit -m "session-end YYYY-MM-DD: <short summary, e.g. '3 tasks done, 2 new'>"
git push origin main

If git status shows uncommitted changes to files OTHER than BRAINJAMIN_TODO.md, list them and ask Mert before staging anything else. Do NOT auto-stage code files.

If push fails, print the error and stop. Do not retry automatically.

═══════════════════════════════════════════════════════════════
ABSOLUTE PROHIBITIONS
═══════════════════════════════════════════════════════════════

DO NOT modify BRAINJAMIN_RULES.md.
DO NOT modify BRAINJAMIN_CONTEXT.md (only Mert edits this manually when architecture changes).
DO NOT touch any code file.
DO NOT auto-stage files outside BRAINJAMIN_TODO.md.
If a CODEBASE SNAPSHOT subsection has zero matches, write "*(none)*". Do not fabricate.
