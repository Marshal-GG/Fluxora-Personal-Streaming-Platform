# Runbook: New repo init checklist

> **What:** First-day setup for a fresh repo. License, gitignore, README skeleton, conventional commits, branch protection, common config files.
> **Estimated time:** 30 minutes.

Use this as a literal checklist when starting any new project. Each item takes 1–5 minutes; skipping them now costs 5x later.

---

## Phase 1 — Create the repo

- [ ] **Name** — short, lowercase, hyphenated. Avoid version numbers, acronyms only your team understands.
- [ ] **Visibility** — private until you're ready to share. Going from private to public is easy; the reverse drags secret history out of git into search engines.
- [ ] **Default branch** — `main`. Don't use `master` (deprecated) or anything else (confuses tooling).
- [ ] **License** — pick at creation, not later (changing license post-launch is legally fraught):

  | License | Pick if |
  |---------|---------|
  | **MIT** | You want maximum permissive use. Most popular choice for libraries / tools |
  | **Apache 2.0** | MIT + explicit patent grant. Better for anything corporate-adjacent |
  | **AGPL-3.0** | You want SaaS-style copyleft. Anyone running the code as a service must publish their fork |
  | **Proprietary / All Rights Reserved** | Closed-source product. No license file = "all rights reserved" by default in most jurisdictions |
  | **None** (public repo) | Don't. "Public" without a license = no permission to use; people will avoid contributing |

- [ ] **`.gitignore`** — start from a language-aware template. GitHub generates these on repo creation if you pick a language. For a multi-language monorepo, combine multiple templates.

---

## Phase 2 — Essential files

### `.gitignore`

Start with the language template, then add these universal patterns:

```gitignore
# Secrets — defensive even if you store them outside the repo
.env
.env.*
!.env.example
*.pem
*.key
credentials.json
*service-account*.json

# OS
.DS_Store
Thumbs.db
desktop.ini

# Editor
.idea/
.vscode/*
!.vscode/launch.json
!.vscode/settings.json
!.vscode/extensions.json
*.iml
*.swp

# Build outputs (per language)
build/
dist/
out/
target/
*.pyc
__pycache__/
node_modules/
.dart_tool/

# Native build caches
.gradle/
**/android/.gradle/

# Local scratch
scratch/
tmp/
.tmp_*/
```

### `LICENSE`

Whatever you picked above. GitHub auto-generates this from the dropdown. If creating manually, use [choosealicense.com](https://choosealicense.com).

### `README.md` (skeleton)

```markdown
# <Project Name>

> One-line description.

## Status

What's working today. What's not.

## Getting started

```bash
git clone https://github.com/<owner>/<repo>.git
cd <repo>
# install + run commands
```

## Documentation

- [Architecture](docs/...)
- [License](LICENSE)
```

Keep the README **brief** — it's the front door, not the manual. Link to deeper docs.


If you'll have any contributors at all (including future-you on a fresh machine):

- Required tooling versions (Python, Node, Flutter, etc.)
- How to run things locally
- How to run tests + lint + format
- Code conventions (link to a style doc, don't repeat it inline)
- Branch model (link to [`04_branch_and_pr_workflow.md`](./04_branch_and_pr_workflow.md))
- Commit message format (next section)


---

## Phase 3 — Commit message convention

Pick **one** convention and stick with it. The rest of this section assumes [Conventional Commits](https://www.conventionalcommits.org/), which is the most widely supported pattern:

```
type(scope): summary in imperative mood

optional longer body explaining why, wrapped at 72 chars
```

| Type | When |
|------|------|
| `feat` | New user-visible behavior |
| `fix` | Bug fix |
| `chore` | Build, CI, deps, no behavior change |
| `docs` | Documentation only |
| `refactor` | Internal cleanup |
| `test` | Test-only changes |
| `build` | Dependency bumps, packaging |
| `ci` | CI/workflow changes |
| `perf` | Performance optimization |

Scope is `(server)`, `(mobile)`, `(api)`, etc. — or omit for repo-wide.

### Enforce with commitlint (optional)

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional
echo "module.exports = { extends: ['@commitlint/config-conventional'] };" > commitlint.config.js
```

Then in `.husky/commit-msg`:

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"
npx --no -- commitlint --edit "$1"
```

Now `git commit` rejects messages that don't match the convention.

For solo projects this is overkill. The discipline of typing the prefix is enough.

---

## Phase 4 — Branch protection

GitHub repo → **Settings → Branches → Add rule** for `main`.

Minimum settings (see [`04_branch_and_pr_workflow.md`](./04_branch_and_pr_workflow.md) for full setup):

- ✅ Require pull request before merging — Required approvals: 1
- ✅ Require status checks to pass before merging
- ✅ Restrict who can push to matching branches → admins only

---

## Phase 5 — CI baseline

Even before you write any code, set up:

- [ ] `lint_test_<language>.yml` workflow (see [`03_github_ci_cd.md`](./03_github_ci_cd.md))
- [ ] `secret_scan.yml` (gitleaks)
- [ ] `dependabot.yml`

Adding these later is annoying because you have to retroactively fix all the existing dependency / commit issues they catch. Do it now while the repo has nothing to find.

---

## Phase 6 — Optional but recommended

### `.editorconfig`

Standardizes whitespace across editors. Drop in repo root:

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
charset = utf-8
trim_trailing_whitespace = true

[*.{py,go}]
indent_size = 4

[Makefile]
indent_style = tab

[*.md]
trim_trailing_whitespace = false
```

Most editors honor this without plugins. PyCharm, VS Code, JetBrains, Sublime all support it natively.

### `CODEOWNERS`

If you have multiple contributors, this auto-assigns reviewers based on the files touched:

```
# .github/CODEOWNERS
/apps/server/      @<server-team-handle>
/apps/mobile/      @<mobile-team-handle>
/docs/             @<everyone>
*.yaml             @<infra-team-handle>
```

Solo projects skip this.

### `SECURITY.md`

If your project handles user data, secrets, or auth, document how to report vulnerabilities. Even one line:

```markdown
# Security Policy

To report a vulnerability, email security@<your-domain>.
```

This file gets surfaced by GitHub's UI under "Security" tab.

### `pre-commit` hooks

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-merge-conflict
      - id: check-added-large-files
        args: ['--maxkb=1024']
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

Then `pre-commit install`. Hooks run before each commit; stop typos and accidentally-committed secrets at the source.

---

## Phase 7 — Document the setup

When you've done all this, document it in the repo so future-you doesn't have to remember:

- [ ] `README.md` links to the runbooks you used (this directory)
- [ ] Add an entry to your project's design log / decisions doc explaining what you chose and why

---

## The complete checklist (single page)

- [ ] Repo created (private, `main` branch)
- [ ] LICENSE chosen
- [ ] `.gitignore` includes secrets, OS, editor, build outputs
- [ ] `README.md` skeleton written
- [ ] Commit convention chosen + documented
- [ ] Branch protection on `main` (PR required, 1 approval, status checks)
- [ ] CI: lint/test workflow
- [ ] CI: secret_scan.yml
- [ ] CI: dependabot.yml
- [ ] `.editorconfig` (optional)
- [ ] `CODEOWNERS` (if multi-contributor)
- [ ] `SECURITY.md` (if security-relevant)
- [ ] `pre-commit` hooks installed
- [ ] First commit pushed; CI runs green

---

## Cross-references

- **CI patterns:** [`03_github_ci_cd.md`](./03_github_ci_cd.md)
- **Branch / PR workflow detail:** [`04_branch_and_pr_workflow.md`](./04_branch_and_pr_workflow.md)
- **Secrets:** [`05_secrets_management.md`](./05_secrets_management.md)
