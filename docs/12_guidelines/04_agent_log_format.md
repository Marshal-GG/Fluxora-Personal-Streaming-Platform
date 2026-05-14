# AGENT_LOG.md entry format

> Canonical structure for `AGENT_LOG.md` entries (and the per-entry shape preserved in `docs/logs/AGENT_LOG_archive_NN.md`).
> Established 2026-05-08 after a format audit comparing archives 01–08 (canonical) against archive 09 (drifted).
> Keep this short — if the structure isn't enforceable from this single page, it's too elaborate.

---

## Header

```
## [YYYY-MM-DD] [tag1] [tag2] [tag3] — Topic A · Topic B · Topic C
**Phase:** Phase N — short context line
**Status:** Complete | In progress | Blocked
**Commits:** abc1234, def5678   ← or "uncommitted" while in flight
```

### Tags (small fixed vocabulary)

Pick one or more — comma-grep-friendly, line up after the date.

| Tag | When to use |
|---|---|
| `[mN]` | Mobile redesign milestone work (e.g. `[m11]`, `[m14]`) |
| `[fix]` | Bug fix |
| `[feat]` | New feature / capability |
| `[refactor]` | Code reshape with no behaviour change |
| `[docs]` | Documentation updates only or doc-heavy session |
| `[tests]` | New tests or test-infra work |
| `[audit]` | Audit / cross-check session that surfaces gaps |
| `[infra]` | Build, CI, distribution, packaging |
| `[server]` | Server-side work (FastAPI / migrations / services) |
| `[mobile]` | Mobile-side work (Flutter `apps/mobile`) |
| `[desktop]` | Desktop-side work (Flutter `apps/desktop`) |
| `[core]` | `packages/fluxora_core` work |

Tags are a hint for grep, not a contract — `grep -E '^## .* \[m11\]'` to surface every M11 entry across archives.

---

## Body sections (in order, omit when empty)

```
### What Was Done                  ← always present
### Files Created / Modified       ← always present (3-column table)
### Docs Updated                   ← list every docs/ file touched
### Decisions Made                 ← only when there's a real judgement call
### Issues / Sharp Edges Discovered ← things the next agent should know
### Test Counts (re-baselined)     ← whenever tests changed
### Working-Tree Status            ← when uncommitted state matters for the next agent
### Next Agent Should              ← always present
```

### `### What Was Done`

Numbered subsections (`#### 1. Topic`) when the session has multiple threads. Inline prose when the work is one cohesive thread.

### `### Files Created / Modified` — 3-column table

```
| Action | Path | Why |
|---|---|---|
| Created | apps/server/services/foo.py | Implements the new bar pipeline (§4.5) |
| Modified | apps/mobile/lib/.../baz.dart | _quux resource leak fix |
```

Action is one of `Created` / `Modified` / `Deleted` / `Renamed`. Path is bare (no parenthetical text). Why is one short line — never paragraphs. The 3-column shape lets you grep `Why` independently of `Path`.

**Derive the file list from git, not from memory.** Before writing this table:

```bash
# For an uncommitted session:
git status --short
# For a session whose commits already landed (e.g. <HEAD~N>..<HEAD>):
git diff --name-status <base>..<HEAD>
```

Every row in the table must correspond to a real path in that output. Inventing plausible-sounding paths (e.g. recalling `player_progress_bar.dart` when the actual file is `flux_player_controls.dart`) corrupts the log permanently — future agents will grep the log to locate work and won't find what they expect. If you wrote the work yourself in this session, you still must verify from git because long sessions drift; if a prior agent claims to have done the work, treat their report as a hint, not a source of truth, and confirm against `git diff`.

### `### Decisions Made` — only when useful

Skip the section entirely if there were no real judgement calls. When you do include it, lead with the decision, then the reason. Don't include obvious-in-hindsight calls.

### `### Hard Rules Checklist` — DROPPED from canonical format

The performative `[x] No print()...` checklist that appeared in archives 01–08 has been dropped — every agent has already read CLAUDE.md before writing the log; reciting the checklist back is ritual, not signal.

If a rule was *context-relevant* (e.g. "did NOT add `package:http` despite needing it — used `dart:io.HttpClient` to honor rule #6"), call that out in 1–2 lines under `### Decisions Made`. Otherwise omit.

### `### Test Counts (re-baselined)`

```
- **Server: 661 passing** (+5 from /content tests; 656 → 661)
- **Mobile: 64 passing** (unchanged)
- **Desktop: 90 passing** (untouched)
- **Core: 8 passing** (untouched)
```

### `### Next Agent Should` — numbered list, concrete

Each item names a specific file / endpoint / milestone. No "consider exploring …".

---

## Worked example

See the most recent entry at the bottom of [`AGENT_LOG.md`](../../AGENT_LOG.md) for a full example following this format.

---

## What changed vs archive 09 drift

Archive 09 introduced lowercase headers + `#### Code` / `#### Docs` subsections + extra `### Verification` block + the always-empty `### Hard Rules Checklist`. The canonical format above:

- Restores **Title Case headers** (matches archives 01–08).
- Keeps the **single combined Files table** (no Code/Docs split — but adds a `Why` column for scannability).
- Drops `### Verification` — fold the verification line into `### What Was Done` prose ("`flutter analyze` clean × …"); the `### Test Counts` block carries the numeric deltas.
- Drops `### Hard Rules Checklist` (see above).
- Adds **`**Commits:**` line** to the header block so log↔git mapping is reliable.
- Adds **`[tag]` suffix** to the date for grep-filtering.

---

## Log rotation — archive verbatim, summarise into the fresh log

CLAUDE.md's rotation rule fires when `AGENT_LOG.md` crosses ~1000 lines. **Read this carefully — it's been done wrong before, losing the verbatim history.**

Correct flow:

1. **`docs/logs/AGENT_LOG_archive_NN.md` receives the verbatim contents** of the current `AGENT_LOG.md` (header included). Pick the next free `NN` by listing existing archives. The mechanical move is:

   ```bash
   git mv AGENT_LOG.md docs/logs/AGENT_LOG_archive_NN.md
   ```

   or, if you've already started a fresh `AGENT_LOG.md` in your editor:

   ```bash
   git show HEAD:AGENT_LOG.md > docs/logs/AGENT_LOG_archive_NN.md
   ```

   The archive must be the full body — every entry, every Files table, every Sharp Edges section — exactly as it was. Future agents `grep` archives to trace the history of a file or decision; a summary-only archive breaks that capability.

2. **`AGENT_LOG.md` is restarted** with:
   - The standard rotation header (the four `>` lines from the top of the previous log).
   - A `## Current State Summary (From Archive NN)` section listing each milestone / plan / large change in 1–2 lines with end-of-period test counts. Look at `docs/logs/AGENT_LOG_archive_11.md` lines 1-40 for the canonical shape.
   - A `---` separator.
   - Your new session entry.

3. **Do not put a summary into the archive file.** The archive is the verbatim record; the summary lives in the fresh log so future agents see the recent-state digest on every read.

The 2026-05-14 rotation got this backwards once (summary in archive_12.md, verbatim entries lost from the file system, only recoverable from git history). Don't repeat that.

---

## Don't

- Don't edit past entries. AGENT_LOG.md is append-only.
- Don't include `Co-Authored-By: Claude` or any AI branding (CLAUDE.md hard prohibition #2).
- Don't reference the AGENT_LOG from commit messages — commit messages describe code, not the log entry that documents the work.
- Don't paste full diffs into the log. The Files table + a one-line Why is enough; readers can `git show` for the actual change.
- Don't write decision-paragraphs. Decisions are 1–2 sentences; if it takes more, it belongs in a planning doc.
- Don't fabricate file paths in the Files Created / Modified table. Always derive from `git status --short` or `git diff --name-status`.
- Don't summarise into the archive. The archive is verbatim; the summary lives in the fresh log.
