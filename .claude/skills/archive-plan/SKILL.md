---
name: archive-plan
description: Move a fully-shipped Fluxora plan from docs/10_planning/<N>_<slug>.md into docs/10_planning/archive/<N>_<slug>.md and update every doc that links to it (roadmap.md, CLAUDE.md, current_status.md, and any cross-references). Use when the user says "archive plan <N>", "plan <N> is done", or after the doc-sweep that follows a milestone close-out. Skill handles the move, the link updates, and a grep sweep for stale references — fewer round-trips than doing each step inline.
---

# Archive a completed plan

## Step 0 — Sanity check

The plan should ONLY be archived when:
- Every milestone (M1, M2, …) is shipped + tested
- `current_status.md` has a lead paragraph announcing the plan as shipped
- `AGENT_LOG.md` has the shipping entry (with test counts re-baselined)
- All code commits for the plan have landed

If any of those are missing, refuse to archive and tell the user which step is incomplete. The archive is a close-out signal — moving an in-progress plan to `archive/` makes future agents think it's done.

## Step 1 — Locate the plan + confirm with user

```
ls docs/10_planning/<N>_*.md
```

If multiple match (shouldn't happen but defensive), ask. If exactly one match, use that.

## Step 2 — Move to archive

```bash
git mv "docs/10_planning/<N>_<slug>.md" "docs/10_planning/archive/<N>_<slug>.md"
```

Prefer `git mv` over plain `mv` so git tracks the rename (cleaner blame trail). The user owns commits — don't `git commit` after the move; let it sit in the working tree for them.

## Step 3 — Edit the plan's status banner

Open the just-archived file and update the status line near the top:

```diff
- > **Status:** 🚧 Drafted <YYYY-MM-DD> — awaiting M1 sign-off
+ > **Status:** ✅ shipped — <YYYY-MM-DD> (archived <YYYY-MM-DD>)
```

Or `> **Status:** ✅ shipped <YYYY-MM-DD>` if the plan already had a shipped date and only the archived date needs adding.

## Step 4 — Update roadmap.md

In `docs/10_planning/01_roadmap.md`, find the row whose link points at `./<N>_<slug>.md` and update both the status and link:

```diff
- | <Plan title> (plan <N>) | Must | 🚧 Drafted ... | Plan: [`docs/10_planning/<N>_<slug>.md`](./<N>_<slug>.md).  <summary>. |
+ | <Plan title> (plan <N>) | Must | ✅ Done <YYYY-MM-DD> — <one-line outcome summary>. Plan archived <YYYY-MM-DD>: [`docs/10_planning/archive/<N>_<slug>.md`](./archive/<N>_<slug>.md). |
```

Outcome summary should match the test-count + behavior-key-points in `current_status.md`'s lead paragraph for the plan.

## Step 5 — Update CLAUDE.md

In the "Where the detail lives" table, find the row pointing at `docs/10_planning/<N>_<slug>.md` and update the path to `docs/10_planning/archive/<N>_<slug>.md`:

```diff
- | <plan summary> | `docs/10_planning/<N>_<slug>.md` |
+ | <plan summary> (archived <YYYY-MM-DD>) | `docs/10_planning/archive/<N>_<slug>.md` |
```

## Step 6 — Grep for stale references

Run a multi-directory grep for the old path:

```
Grep pattern="10_planning/<N>_<slug>" output_mode=files_with_matches
```

For each file the grep returns (skip the just-moved plan file, skip already-updated roadmap.md and CLAUDE.md):

- If it's another doc → update the path to point at `archive/`
- If it's source code → very unlikely; if it happens, the code shouldn't be referencing a planning doc by path. Flag to the user.

Also grep for the OLD path with backslashes / forward-slash variants if the project mixes (Windows working tree).

## Step 7 — Append AGENT_LOG entry

Follow `docs/12_guidelines/04_agent_log_format.md` to append a `[docs]` entry titled "Archive plan <N> — <plan name>". Files Created/Modified should list:

- The renamed file (Action: `Renamed`, Path: `docs/10_planning/<N>_<slug>.md → docs/10_planning/archive/<N>_<slug>.md`, Why: "Plan complete; move to archive folder per project convention")
- `docs/10_planning/01_roadmap.md` (link + status update)
- `CLAUDE.md` (path update in "Where the detail lives")
- Any other docs the grep sweep caught

Working-Tree Status: note that the archive move is uncommitted; operator owns the commit.

Next Agent Should: usually "Wait for operator's commit decision" + any follow-up plans surfaced by this work.

## Step 8 — Report

Tell the user:
- The plan was moved (with the old + new paths)
- Which docs were updated (count + bullet list)
- Whether the grep sweep found additional references (zero is the happy path)
- That the move is uncommitted, ready for them to bundle into the next commit

## Anti-patterns to avoid

- **Don't `git commit`** after the move. Operator owns commits per CLAUDE.md hard prohibition #1.
- **Don't delete the original** if the `git mv` failed and you fell back to a Write + Delete pair. Verify the archive file exists before removing the source.
- **Don't archive a plan that has open milestones** — see Step 0. The archive is a close-out signal, not a "we got bored" signal.
- **Don't forget the grep sweep.** A stale link in `current_status.md` or `gotchas.md` will silently rot.
- **Don't change the plan's contents** beyond the status banner. The archived doc should be a faithful historical record of what shipped.
