# GitHub CLI (`gh`) — Setup & Usage

> Operational doc for interacting with the **private** `Marshal-GG/Fluxora-Private` repo's CI runs, issues, and PRs from the local shell.
> Set up 2026-05-12. Lives in `docs/12_guidelines/` because the mirror-public workflow strips this folder — repo-internal tooling doesn't ship to the public mirror.

---

## Why it exists

The repo is private. GitHub Actions logs, PR check details, and issue threads are all behind auth — the anonymous GitHub API + `WebFetch` can't reach them. `gh` CLI gives auth'd CLI access so an agent (or you) can:

- See whether the latest push broke CI
- Pull the failing log lines without scrolling through 1,000 lines of runner setup output
- List open PRs / issues / dependabot grouped updates
- Watch an in-progress run finish

Saves the "screenshot a failing CI log and paste it into chat" round-trip.

## Install (one-time, already done on this machine)

```powershell
winget install --id GitHub.cli --silent --accept-package-agreements --accept-source-agreements
```

Installed to `C:\Program Files\GitHub CLI\gh.exe`. Version 2.92.0 at install time. Winget keeps it on PATH after the next shell restart; for an in-flight bash session add `PATH="/c/Program Files/GitHub CLI:$PATH"` prefix.

## Auth (one-time, already done)

```powershell
gh auth login
```

Interactive flow — pick GitHub.com → HTTPS → Yes (auth Git too) → "Login with a web browser" → copy code → browser → approve.

Token scopes granted: `gist`, `read:org`, `repo`, `workflow`. Stored in Windows credential keyring; persists across PC reboots. Verify with:

```powershell
gh auth status
```

Expected output: `✓ Logged in to github.com account Marshal-GG (keyring)`.

## Common commands — by task

### Inventory recent CI runs

```bash
gh run list --limit 15
```

Columns: status, conclusion, commit msg, workflow name, branch, event, run id, duration, timestamp. Failed runs show `failure` in column 2.

Filter by workflow:

```bash
gh run list --workflow="Server CI" --limit 5
gh run list --workflow=server_ci.yml --limit 5
```

Filter by branch:

```bash
gh run list --branch=main --limit 10
```

Filter by status — useful when you only care about reds:

```bash
gh run list --status=failure --limit 10
```

### Investigate a failed run

```bash
gh run view <run_id>                  # summary + per-job status
gh run view <run_id> --log            # full log (long — pipe to less or grep)
gh run view <run_id> --log-failed     # only the failing steps' logs (preferred)
```

Best pattern when triaging a CI failure (used 2026-05-12 to find plan-20's `black --check` failure in 1 grep):

```bash
gh run view <run_id> --log-failed | grep -iE "(error|fail|fatal|assertionerror|exception)" | head -40
```

### Watch an in-progress run

```bash
gh run watch <run_id>
```

Refreshes every few seconds; exits when the run finishes. Useful for "I pushed a fix, did it stick?" without F5'ing the GitHub UI tab.

### Re-run a failed workflow

```bash
gh run rerun <run_id>                 # re-run all failed jobs
gh run rerun <run_id> --failed        # only re-run the jobs that failed (faster)
gh run rerun <run_id> --debug         # re-run with step-debug logging enabled
```

Useful when a CI failure was flaky (network blip, transient timeout) rather than a real code issue.

### PR checks

```bash
gh pr list                                # open PRs
gh pr view <pr_number>                    # PR summary + checks status
gh pr checks <pr_number>                  # just the checks table
gh pr view <pr_number> --json statusCheckRollup --jq '.statusCheckRollup'
```

### Issues

```bash
gh issue list                             # open issues
gh issue view <issue_number>              # full thread
gh issue list --label=bug --state=open
```

### Repo-level info

```bash
gh repo view                              # summary of the current repo
gh api /repos/Marshal-GG/Fluxora-Private/actions/runs --paginate | jq ...
                                          # raw GitHub API for anything `gh` doesn't wrap
```

## Permission allowlist (project-scoped, persisted)

To skip the "Allow Bash(gh …)?" prompt on every call, the following live in `.claude/settings.json` (project scope, committed to private repo):

```json
{
  "permissions": {
    "allow": [
      "Bash(gh run *)",
      "Bash(gh pr *)",
      "Bash(gh issue *)",
      "Bash(gh repo *)",
      "Bash(gh auth status*)",
      "Bash(gh api *)"
    ]
  }
}
```

Write-y operations (`gh pr create`, `gh issue create`, `gh pr close`, `gh pr merge`, `gh repo create`) are **deliberately not allowlisted** — they're externally visible, so the agent must request explicit approval per call. Mirrors CLAUDE.md hard prohibition #1's "operator owns version control writes" intent.

## What `gh` will NOT do for you

- **Push commits / create branches** — the existing CLAUDE.md hard prohibition #1 still applies. `gh` doesn't help here; that's git, which the agent never writes to.
- **Approve workflow runs** — protected-environment approval gates (e.g. production deploys) need a real human-in-the-loop UI session, not a CLI flag.
- **Reach the public mirror** — `gh` is auth'd against `Marshal-GG/Fluxora-Private`; to inspect the public mirror replay, switch hosts or use `gh repo view Marshal-GG/Fluxora-Personal-Streaming-Platform`.

## Common gotchas

1. **PowerShell mangles jq expressions** with `//` operators. The `//` is parsed as a PowerShell line-continuation. Workaround: use the Bash tool, or wrap the jq expression in single quotes: `gh run list --json conclusion --jq '.[] | "\(.conclusion // "in_progress")"'` (but even single-quoted, PowerShell can fail). Easiest path is just run it through `bash` invocation when the jq is non-trivial.

2. **Path scoping** — Server CI / Mobile CI / Desktop CI have `paths:` filters (`apps/server/**` etc.). A commit that only touches `docs/` triggers zero language CI runs — `gh run list` will be silent for that push and that's correct, not a bug.

3. **`--log` output is huge** — a single CI run can produce ~5 MB of log. Always pipe to `head`, `grep`, or `--log-failed` before reading. The agent's context window will fill fast otherwise.

4. **Token scope creep** — if a future command fails with `gh: HTTP 403`, the token's scopes may be insufficient. Re-run `gh auth refresh -s <scope>` (e.g. `gh auth refresh -s admin:repo_hook` for webhook ops). Don't dump tokens to chat or log files.

5. **Authentication is per-user, per-machine** — fresh checkout on a new dev machine requires re-running `gh auth login`. The skill doc `/log-entry` doesn't capture this in the AGENT_LOG entry because it's not project state.

## When to use `gh` vs other tools

| Task | Use |
|------|-----|
| "Did CI pass on my last push?" | `gh run list --limit 5` |
| "What broke in Server CI?" | `gh run view <id> --log-failed \| grep -iE 'error\|fail' \| head -20` |
| "Show me the diff for a PR" | `gh pr diff <number>` — beats opening the UI |
| "Re-run that flaky test job" | `gh run rerun <id> --failed` |
| "Open an issue / PR" | **Operator does this in the GitHub UI** — agent must not create externally-visible artifacts without explicit approval |
| "Edit / commit code" | Regular `git` + the agent's `Edit` tool — `gh` doesn't touch the working tree |
| "Check what's deployed where" | `gh run list --workflow=web_landing_ci.yml` for deploy history; live Firebase channel state needs the Firebase Console |

## See also

- `.github/workflows/` — every workflow file the queries above target
- `docs/05_infrastructure/01_infrastructure.md` § "CI/CD Pipeline" — what each workflow does
- CLAUDE.md hard prohibition #1 — git write rules (apply to `gh` write commands too)
