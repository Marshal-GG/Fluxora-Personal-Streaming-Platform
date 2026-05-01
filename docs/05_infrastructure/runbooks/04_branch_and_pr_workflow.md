# Runbook: Branch model + PR workflow + preview channels

> **What:** The branching strategy and PR flow this project uses. Glues together the patterns in `02_firebase_static_hosting.md` and `03_github_ci_cd.md`.
> **Estimated time:** 15 minutes to set up branch protection rules in a fresh repo.

---

## Branch model

Three roles. No more.

| Branch | Role | Who pushes | Auto-deploys to |
|--------|------|-----------|-----------------|
| `main` | Production | Approved PRs only | Live URL (after manual approval gate) |
| `uat` | Staging / pre-prod | Direct push or merged PR | UAT URL (auto, every push) |
| `feature/<short-name>` (or `fix/<>`, `chore/<>`) | Topic branches | Anyone working on a change | PR preview URL (auto, when PR opens) |

You don't need a `develop` branch, you don't need release branches, and you don't need a Gitflow diagram. `feature` → `uat` → `main` is enough for any solo or small-team project.

---

## The flow visually

```
                                          ┌── auto: PR closes → preview channel deleted
                                          │
feature/foo ──[push]──▶ open PR ──[CI]──▶ deploy-preview ──[reviewer comments]──▶ merge to uat
                                                                                       │
                                                                                       ▼
                                                                                deploy-uat (auto)
                                                                                       │
                                                                                  uat.<APEX>
                                                                                       │
                                                          ───────[satisfied]────[merge to main]
                                                                                       │
                                                                                       ▼
                                                                          deploy-production
                                                                          (BLOCKED on reviewer
                                                                           approval — required
                                                                           reviewers in the
                                                                           `production` env)
                                                                                       │
                                                                                       ▼
                                                                                   live URL
```

---

## Step 1 — Branch protection rules

GitHub repo → Settings → **Branches** → Add branch protection rule.

### Rule for `main`

- **Branch name pattern:** `main`
- **✅ Require a pull request before merging**
  - **Required approvals:** `1` (or higher if multi-contributor)
  - **Dismiss stale approvals when new commits are pushed:** on
- **✅ Require status checks to pass before merging**
  - Pick the CI workflows that must be green: typically `<COMPONENT> CI / test`, `Secret Scan / gitleaks`, etc.
  - **Require branches to be up to date before merging:** on (catches integration breaks)
- **✅ Require conversation resolution before merging**
- **✅ Do not allow bypassing the above settings** (or allow only repo admins)
- **✅ Restrict who can push to matching branches** → only allow administrators (forces all changes through PRs)

### Rule for `uat`

Looser — `uat` is for breaking things and testing.

- **Branch name pattern:** `uat`
- **✅ Require status checks to pass before merging** (same checks as `main`)
- (No required approvals — push directly is fine for solo dev)

### Solo workflow alternative

If you're the only developer and find PR-to-self too much friction:

- Skip the `main` PR requirement; rely on `uat → main` as your gate
- "I'll merge to `main` only when I've seen it work on `uat`"
- Re-add the PR requirement the moment a second contributor joins

---

## Step 2 — Wire the GitHub `production` environment

Settings → **Environments** → New environment → name **`production`** (lowercase, exact).

- **Required reviewers:** add the GitHub usernames of people who can approve production deploys (yourself if solo + sane, plus any teammates)
- **Wait timer:** optional, e.g. "wait 5 minutes before deploying" gives you a chance to abort
- **Deployment branches:** restrict to `main` so the environment can't be deployed to from any other branch by accident

This is what makes the `deploy-production` CI job pause and email you for approval before deploying. See [`03_github_ci_cd.md`](./03_github_ci_cd.md) for the workflow that uses it.

> **Free-plan caveat:** required reviewers on environments are gated to **public repos** on GitHub Free, OR any repo on Team / Pro / Enterprise. If you're solo on Free + private, the branch-protection rule on `main` (PR + approvals) is your gate instead.

---

## Step 3 — Set up the `uat` environment (optional, for parity)

Same path: Settings → Environments → **`uat`**.

- **Required reviewers:** none (UAT is meant to deploy automatically)
- **Deployment branches:** restrict to `uat`

This is mostly for the URL display in the GitHub UI — you'll see `uat.<APEX>` linked from any deploy log.

---

## Step 4 — How a feature change actually flows

```bash
# 1. Branch from latest uat (or main — same thing if uat is current)
git checkout uat
git pull --rebase origin uat
git checkout -b feature/add-search

# 2. Make changes, commit
# ...edit, edit...
git add -A
git commit -m "feat: add search box to library screen"

# 3. Push and open a PR
git push -u origin feature/add-search
gh pr create --base uat --title "feat: add search to library" --body "..."
```

What CI does at this point:

1. **`<component> CI`** runs lint + tests
2. **`secret_scan`** scans the diff
3. **`web_landing_ci`** (if your change touches the static site) builds and runs `deploy-preview` → comments the preview URL on the PR
4. Reviewer (yourself or someone else) loads the preview URL, leaves comments, approves

```bash
# 4. Merge to uat (squash for cleaner history)
gh pr merge --squash --delete-branch
```

What happens automatically after merge:

5. `deploy-preview` cleans up the preview channel (Firebase deletes it when the PR closes)
6. `deploy-uat` runs, deploys to `uat.<APEX>`
7. You sanity-test against `uat.<APEX>`

When ready for production:

```bash
# 5. Promote uat to main via PR
gh pr create --base main --head uat --title "release: <description>" --body "..."
gh pr merge   # may require approval depending on your branch protection
```

What happens after the merge to `main`:

8. `deploy-production` job is created BUT pauses
9. GitHub emails the required reviewer(s)
10. Reviewer goes to **Actions → the workflow run → Review deployments → Approve and deploy**
11. Job continues, deploys to `live.<APEX>`

---

## Step 5 — How preview channels behave

| Event | Effect |
|-------|--------|
| Open a PR | Firebase auto-creates a unique channel like `pr-42-xxxxx`, deploys, posts URL to PR |
| Push more commits to the PR branch | Same channel updates, new deploy, URL stays the same |
| Close or merge the PR | Channel auto-deletes within minutes |

You can see all active channels:

```bash
firebase hosting:channel:list --project <PROJECT_ID>
```

---

## Step 6 — Versioning and changelog notes

This is project-specific — pick what fits:

| Pattern | When |
|---------|------|
| **Conventional commits + auto changelog** (`changesets`, `semantic-release`) | Public package, multiple contributors, releases mean something to users |
| **Manual `CHANGELOG.md`** | Single product, releases are mostly internal, you write release notes manually |
| **No changelog at all** | Solo dev, "the git log IS the changelog", releases are continuous |

Fluxora uses the third — git log + commit messages following the conventional-commits prefix style (`feat:`, `fix:`, `chore:`, `ci:`, `build:`, `docs:`, etc.) but no automated changelog.

---

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `deploy-production` runs through without waiting for approval | The `production` environment doesn't exist OR has no required reviewers | Settings → Environments → ensure `production` exists with reviewers configured |
| PR preview URL not posted to PR | `pull-requests: write` permission missing on the `deploy-preview` job | Add `permissions: pull-requests: write` to the job |
| `deploy-uat` runs on every PR (not just `uat` branch) | The `if: github.ref == 'refs/heads/uat'` guard is missing | Add the `if:` clause |
| Preview channel still exists after PR close | Firebase action's auto-cleanup didn't fire (rare) | `firebase hosting:channel:delete pr-<NUMBER>-<HASH> --project <PROJECT_ID>` |
| `gh pr merge` fails with "branch is not up to date" | Branch protection requires up-to-date branches and you have unmerged commits from base | `git pull --rebase origin uat && git push --force-with-lease` then retry merge |

---

## When to break this model

- **Hotfix to production** that can't wait for `uat`: branch off `main`, PR straight to `main`. Skip UAT explicitly. Note in the PR description that this is a hotfix and document what couldn't wait.
- **Long-running refactor / experiment**: long-lived `experiment/<name>` branch that periodically rebases on `uat`. PR only when ready to integrate.
- **Multiple production environments** (e.g. EU + US): introduce `production-eu` and `production-us` GitHub environments, each gated separately. The branch model stays the same.

---

## Cross-references

- **Cloudflare Tunnel:** [`01_cloudflare_tunnel.md`](./01_cloudflare_tunnel.md)
- **Firebase Hosting setup:** [`02_firebase_static_hosting.md`](./02_firebase_static_hosting.md)
- **CI/CD workflow patterns:** [`03_github_ci_cd.md`](./03_github_ci_cd.md)
