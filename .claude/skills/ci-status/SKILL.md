---
name: ci-status
description: Check the current CI health of `main` in the Fluxora private repo via `gh` CLI, and if any recent run is `failure` auto-pull the failing log lines. Use at session start (per CLAUDE.md mandatory rule), after the operator confirms a push, or any time the user says "check CI", "is CI passing", "did my push break anything", or "ci status". Skill consolidates the run-list + log-grep pattern so the agent doesn't have to remember the flags or the grep regex.
---

# Check CI health

## Step 1 — Inventory recent runs on main

```bash
PATH="/c/Program Files/GitHub CLI:$PATH" gh run list --limit 5 --branch=main 2>&1
```

(The PATH prefix is for the Bash tool on Windows where `gh.exe` isn't on the inherited PATH; PowerShell sessions can drop it.)

Output is tab-separated columns: `status`, `conclusion`, `commit_msg`, `workflow_name`, `branch`, `event`, `run_id`, `duration`, `timestamp`. The `conclusion` column is what matters:
- `success` — green
- `failure` — broken
- `cancelled` — usually a re-push that cancelled the prior run, fine
- `in_progress` / `queued` — still running, check back in 30-60s
- `skipped` — workflow's `paths:` filter excluded the change, fine

## Step 2 — If any `failure` row appears, pull the cause

For each failing run id:

```bash
PATH="/c/Program Files/GitHub CLI:$PATH" gh run view <run_id> --log-failed 2>&1 | grep -iE "(error|fail|fatal|assertionerror|exception)" | head -40
```

Common failure shapes to recognise:

| Pattern in the output | Likely root cause |
|---|---|
| `would reformat /home/runner/.../foo.py` | `black --check` drift — run `python -m black .` from `apps/server/` |
| `FileNotFoundError: FFmpeg not found` | CI runner missing FFmpeg — install in the workflow or mock subprocess in the test |
| `AssertionError: assert False is True` on `C:\\…` paths | Platform-specific test running on Linux CI — needs `@pytest.mark.skipif(platform.system() != "Windows", …)` |
| `ModuleNotFoundError` | Missing dep in `pyproject.toml`'s `[dev]` extras, or workflow's `pip install -e ".[dev]"` step skipped |
| Ruff `E501` / `F401` | Line length or unused import — `python -m ruff check . --fix` from `apps/server/` |
| `flutter analyze` failed | Run `flutter analyze` locally in the affected app dir |
| Test suite has FAILED at exit | A non-format / non-lint test broke — get the test name + assertion delta from the log |

## Step 3 — Report concisely

When CI is green: one-line confirmation.

When CI has a failure: lead with workflow name + commit + reason in one sentence. Then offer a fix or ask. Example:

> Server CI failed on `bee0bfb` — `black --check` drift across 47 files. Pre-existing; not from this commit. Want me to run `python -m black .` from `apps/server/` and ship a chore commit?

Don't dump the raw log unless the user asks for it. The grep result is the signal.

## Step 4 — Special cases

### Just-pushed run still running

If the most recent run on main is `in_progress` and the push happened <2 min ago, tell the user "still running, check back in ~Ns based on this workflow's typical duration." Don't poll — let the user prompt the next check, or schedule one explicitly with `ScheduleWakeup`.

### Cancelled runs in the list

A recent `cancelled` row usually means a re-push superseded an older run (the workflow's `concurrency: cancel-in-progress: true` setting). Look at the NEXT row down; if that's `success` you're fine. If the cancellation pattern is unusual (e.g. 5 cancellations in a row), the operator may be force-pushing rapidly — surface that.

### Path-filtered workflows

Server CI / Mobile CI / Desktop CI have `paths:` filters. A docs-only commit will show zero rows for those workflows — that's correct, not a bug.

### Auth failure / token expired

If `gh` returns `HTTP 401` or `auth required`, the token's expired. Tell the user to run `gh auth login` or `gh auth refresh`; the keyring entry may have aged out. Don't try to work around it.

## When not to use this skill

- The user is asking about local test results, not CI — use `python -m pytest` / `flutter test` directly.
- The user is asking about deploy status on Firebase / production — that's a separate concern; check the Firebase Console or `gh run list --workflow=web_landing_ci.yml`.
- The user is asking about a specific PR's checks (not main) — use `gh pr checks <number>` directly.
