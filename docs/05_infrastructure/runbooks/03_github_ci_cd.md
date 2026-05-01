# Runbook: GitHub Actions CI/CD patterns

> **What:** The CI/CD patterns this project uses, written generically. Drop these into any new repo. Covers path-scoped workflows, concurrency, deploy gating, secret scanning, dependabot, and a public-mirror sync.
> **Estimated time:** 30 minutes to wire up the basics in a fresh repo.

---

## What you get out of this runbook

| Workflow | Triggers on | Does |
|----------|------------|------|
| `lint_test_<COMPONENT>.yml` | Push / PR touching `<COMPONENT>/**` | Lint + format check + tests |
| `web_landing_ci.yml` | Push / PR touching the static-site dir | Build → deploy to Firebase (preview / uat / live) |
| `secret_scan.yml` | Every push and PR | gitleaks scans full git history |
| `mirror-public.yml` | Push to `main` | Strips private files and mirrors to a public read-only repo |
| `dependabot.yml` | Weekly | Auto-PRs for pip/npm/pub/Actions version bumps |

---

## Common patterns we use everywhere

### 1. Path-scoped triggers

CI shouldn't run a Flutter build when only Python files changed:

```yaml
on:
  push:
    paths:
      - 'apps/server/**'
  pull_request:
    paths:
      - 'apps/server/**'
```

### 2. Concurrency groups (cancel old runs when you push twice)

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Special-case for **deploy workflows that touch production**: don't cancel `main` runs mid-flight, only cancel duplicates on other branches:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
```

For **mirror / sync workflows**: queue, don't cancel — interrupting a force-push mid-sync corrupts the mirror:

```yaml
concurrency:
  group: mirror-public
  cancel-in-progress: false
```

### 3. Pinned action versions

Use major-version tags (e.g. `@v5`) for first-party GitHub actions, exact tags for third-party:

```yaml
- uses: actions/checkout@v5             # first-party, major pin OK
- uses: subosito/flutter-action@v2      # third-party, major OK if maintained
- uses: gitleaks/gitleaks-action@v2     # third-party
```

Dependabot will bump these automatically (see "Dependabot" below).

### 4. Cache language toolchains

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.11'
    cache: 'pip'
    cache-dependency-path: <APP_DIR>/pyproject.toml
```

```yaml
- uses: subosito/flutter-action@v2
  with:
    channel: stable
    flutter-version: '3.32.0'    # pin if you use new-syntax features
    cache: true
```

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '22'
    cache: 'npm'
    cache-dependency-path: <APP_DIR>/package-lock.json
```

---

## Pattern A — lint/format/test workflow (Python example)

`.github/workflows/server_ci.yml`:

```yaml
name: Server CI

on:
  push:
    paths:
      - 'apps/server/**'
  pull_request:
    paths:
      - 'apps/server/**'

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/server

    steps:
      - uses: actions/checkout@v5

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'
          cache-dependency-path: apps/server/pyproject.toml

      - name: Install dependencies
        run: pip install -e ".[dev]"

      - name: Lint (ruff)
        run: python -m ruff check .

      - name: Format check (black)
        run: python -m black --check .

      - name: Tests (pytest)
        run: python -m pytest tests/ -v
```

---

## Pattern B — Flutter analyze + test

`.github/workflows/mobile_ci.yml`:

```yaml
name: Mobile CI

on:
  push:
    paths:
      - 'apps/mobile/**'
      - 'packages/**'
  pull_request:
    paths:
      - 'apps/mobile/**'
      - 'packages/**'

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: '3.32.0'
          cache: true
      - run: flutter pub get
        working-directory: packages/fluxora_core   # if you use a path: dependency
      - run: flutter pub get
        working-directory: apps/mobile
      - run: flutter analyze
        working-directory: apps/mobile
      - run: flutter test
        working-directory: apps/mobile
```

---

## Pattern C — build + deploy with environment gates (Firebase example)

This wires up the channel model from [`02_firebase_static_hosting.md`](./02_firebase_static_hosting.md) — preview channels for PRs, `uat` deploys, and gated `live` deploys.

`.github/workflows/web_landing_ci.yml`:

```yaml
name: Web Landing — Build & Deploy

on:
  push:
    branches: [main, uat]
    paths:
      - 'apps/web_landing/**'
  pull_request:
    paths:
      - 'apps/web_landing/**'

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}

jobs:
  # ── 1. Build ────────────────────────────────────────────────────────────────
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
          cache-dependency-path: apps/web_landing/package-lock.json
      - name: Install dependencies
        working-directory: apps/web_landing
        run: npm ci
      - name: Build static export
        working-directory: apps/web_landing
        run: npm run build
      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: landing-out
          path: apps/web_landing/out
          retention-days: 1

  # ── 2. Preview (PRs only — temporary Firebase channel) ─────────────────────
  deploy-preview:
    needs: build
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      checks: write

    steps:
      - uses: actions/checkout@v5
      - uses: actions/download-artifact@v4
        with:
          name: landing-out
          path: apps/web_landing/out
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_<PROJECT_ID> }}
          projectId: <project-id>
          # No channelId = auto-creates a preview channel for this PR
          # Firebase posts the preview URL as a PR comment automatically

  # ── 3. UAT (uat branch — auto-deploys, no approval needed) ─────────────────
  deploy-uat:
    needs: build
    if: github.ref == 'refs/heads/uat'
    runs-on: ubuntu-latest
    environment:
      name: uat
      url: https://<UAT_HOSTNAME>

    steps:
      - uses: actions/checkout@v5
      - uses: actions/download-artifact@v4
        with:
          name: landing-out
          path: apps/web_landing/out
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_<PROJECT_ID> }}
          channelId: uat
          expires: 30d
          projectId: <project-id>

  # ── 4. Production (main branch — requires reviewer approval) ────────────────
  deploy-production:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: production           # ← required-reviewers gate lives here
      url: https://<LIVE_HOSTNAME>

    steps:
      - uses: actions/checkout@v5
      - uses: actions/download-artifact@v4
        with:
          name: landing-out
          path: apps/web_landing/out
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_<PROJECT_ID> }}
          channelId: live
          projectId: <project-id>
```

The `environment:` keys are what make the GitHub UI show "Approve deployment" buttons and audit who deployed when.

---

## Pattern D — Secret scanning

`.github/workflows/secret_scan.yml`:

```yaml
name: Secret Scan

on:
  push:
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0       # full history so gitleaks can scan all commits

      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # Personal repos: leave GITLEAKS_LICENSE unset
          # Org-owned repos: set GITLEAKS_LICENSE secret
```

If a real secret was committed and is detected, **don't just delete the file in a follow-up commit** — the secret stays in git history. Rotate the secret AND scrub it from history with `git filter-repo` or BFG.

---

## Pattern E — Dependabot

`.github/dependabot.yml` (config, not a workflow):

```yaml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/<APP_DIR>"
    schedule: { interval: "weekly", day: "monday" }
    open-pull-requests-limit: 5
    commit-message: { prefix: "build(<scope>)", include: "scope" }
    groups:
      python-runtime:
        patterns: ["*"]
        update-types: ["minor", "patch"]

  - package-ecosystem: "pub"
    directory: "/<FLUTTER_DIR>"
    schedule: { interval: "weekly", day: "monday" }
    open-pull-requests-limit: 5
    commit-message: { prefix: "build(mobile)", include: "scope" }

  - package-ecosystem: "npm"
    directory: "/<NODE_DIR>"
    schedule: { interval: "weekly", day: "monday" }
    open-pull-requests-limit: 5
    commit-message: { prefix: "build(web)", include: "scope" }

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly", day: "monday" }
    open-pull-requests-limit: 5
    commit-message: { prefix: "ci", include: "scope" }
```

Group minor + patch updates per ecosystem to avoid one-PR-per-package noise. Major updates still arrive as individual PRs because they're more likely to need attention.

---

## Pattern F — Mirror to a public repo (private dev, public release)

If you keep your dev repo private but want a public mirror (for code transparency, attracting contributors, or shipping a public CHANGELOG), this is the pattern. The mirror strips internal-only files (logs, agent guides, internal CI) before pushing.

`.github/workflows/mirror-public.yml`:

```yaml
name: Mirror to Public Repo

on:
  push:
    branches: [main]

concurrency:
  group: mirror-public
  cancel-in-progress: false       # never interrupt a force-push mid-sync

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: Remove private files and references
        run: |
          rm -rf docs/logs docs/12_guidelines
          rm -rf .github/workflows/

          # Strip lines from markdown that reference now-deleted files
          find . -name "*.md" -type f -exec sed -i '/CLAUDE\.md/d' {} +
          find . -name "*.md" -type f -exec sed -i '/CONTRIBUTING\.md/d' {} +

          # Trim "For AI Agents" section out of README.md
          sed -i '/## For AI Agents/,$d' README.md 2>/dev/null || true

      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Build clean commit message
        id: msg
        run: |
          RAW=$(git log -1 --pretty=%B)
          CLEAN=$(echo "$RAW" | grep -iv "agent_log\|claude\.md\|agent log\|agent session" || echo "chore: update")
          echo "message<<EOF" >> $GITHUB_OUTPUT
          echo "$CLEAN" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Stage filtered files
        run: |
          git add -A

      - name: Commit clean state
        env:
          # Pass the message via env + stdin so the step doesn't break when the
          # commit body contains quotes, parens, or other shell metacharacters.
          # Direct ${{ }} substitution into `git commit -m "..."` will splice
          # inner quotes through and break the outer string.
          COMMIT_MSG: ${{ steps.msg.outputs.message }}
        run: |
          if ! git diff --cached --quiet; then
            printf '%s\n' "$COMMIT_MSG" | git commit -F -
          fi

      - name: Push to public repo
        run: |
          git remote add public https://<USERNAME>:${{ secrets.PUBLIC_REPO_TOKEN }}@github.com/<USERNAME>/<PUBLIC_REPO>.git
          git push public main --force
```

Required secret: `PUBLIC_REPO_TOKEN` — a fine-grained PAT scoped to the public repo with write access.

---

## Required GitHub secrets summary

| Secret | Used by | What it is |
|--------|---------|------------|
| `GITHUB_TOKEN` | All workflows | Auto-provided per run; no action needed |
| `FIREBASE_SERVICE_ACCOUNT_<NAME>` | `web_landing_ci.yml` | JSON key for the Firebase Hosting service account |
| `PUBLIC_REPO_TOKEN` | `mirror-public.yml` | PAT for the public mirror repo |
| `GITLEAKS_LICENSE` | `secret_scan.yml` | Only required for org-owned repos; leave unset on personal |

Add via repo Settings → Secrets and variables → Actions → New repository secret.

---

## Required GitHub environments (for deploy gates)

GitHub repo → Settings → **Environments** → New environment:

| Environment | Reviewers | URL | Used by |
|-------------|-----------|-----|---------|
| `production` | The humans who can approve live deploys | `https://<LIVE_HOSTNAME>` | `deploy-production` job |
| `uat` | None (auto-deploys) | `https://<UAT_HOSTNAME>` | `deploy-uat` job |

If the environment doesn't exist, the workflow's `environment:` reference is silently ignored — deploys go through without the gate. Always create the environment AND add reviewers explicitly.

---

## Cross-references

- **Cloudflare Tunnel:** [`01_cloudflare_tunnel.md`](./01_cloudflare_tunnel.md)
- **Firebase Hosting setup:** [`02_firebase_static_hosting.md`](./02_firebase_static_hosting.md)
- **Branch / PR flow that drives all this:** [`04_branch_and_pr_workflow.md`](./04_branch_and_pr_workflow.md)
- **Project-specific CI inventory:** [`../01_infrastructure.md`](../01_infrastructure.md)
