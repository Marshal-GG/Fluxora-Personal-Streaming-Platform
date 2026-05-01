# Runbook: Secrets management

> **What:** How to store, inject, and rotate every secret in a project. Where they live in dev, in CI, and in production. Patterns that scale from solo to small team without rework.
> **Estimated time:** 30 minutes to set up cleanly in a fresh repo.

---

## What counts as a secret

Anything that, if leaked, gives an attacker capability they shouldn't have:

| Category | Examples |
|----------|----------|
| **API keys to third-party services** | TMDB, Polar webhook secret, Cloudflare API token, Firebase service account |
| **Cryptographic secrets** | HMAC signing keys, license-issuance secrets, token encryption keys |
| **Database / service credentials** | DB passwords, Redis URIs with auth, S3 access keys |
| **Tunnel credentials** | Cloudflare Tunnel `.json`, `cert.pem` |
| **OAuth client secrets / refresh tokens** | Used to impersonate users or services |

**NOT secrets** (commit freely):
- Domain names, public hostnames
- Tier names, feature flags
- HTTP status codes, error message strings
- Public URLs (e.g. `https://api.fluxora.marshalx.dev`)
- Cloudflare tunnel UUIDs (they're shown in the public CNAME anyway)

When in doubt: ask "if a stranger had this, what could they do?" If "nothing harmful," it's not a secret.

---

## Where secrets live

Three layers, each independently managed:

```
[Local dev]                [CI]                       [Production]
~/.<app>/.env              GitHub Actions secrets     {data dir}/.env on the host
+ git-ignored                                          + chmod 600 / 0o400
```

Never share secret values across layers without rotation. Same secret in dev as in production = "compromise my laptop, compromise prod."

---

## Layer 1 — Local development

### `.env` file

Each app has its own. For Fluxora's server, secrets live in a platform data directory, NOT in the repo:

| Platform | Path |
|----------|------|
| Windows | `%APPDATA%\<APP>\.env` |
| macOS | `~/Library/Application Support/<APP>/.env` |
| Linux | `~/.<app>/.env` |

**Why outside the repo:** `.env` files inside repos get committed by accident. `.env` files in the platform data dir physically can't be committed because git can't see them.

If your framework needs the `.env` co-located with code (some frameworks do — Next.js for example):

- Name the file `.env.local` (auto-gitignored by Next.js)
- Add `.env`, `.env.local`, `.env.*.local` to `.gitignore` defensively
- Commit a `.env.example` with **placeholder values** showing structure

### Loading

For Pydantic-based Python (Fluxora's pattern):

```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    token_hmac_key: str = ""           # required at startup
    fluxora_license_secret: str = ""   # required for license validation
    polar_webhook_secret: str = ""     # required for webhook
    fluxora_tmdb_key: str = ""         # optional

    model_config = {
        "env_file": str(_data_dir() / ".env"),
        "extra": "ignore",
    }

settings = Settings()
```

For Node.js: `dotenv-flow` reads `.env`, `.env.local`, `.env.production` in priority order.

For Dart/Flutter: typically secrets are NOT in the client binary. Either inject at build time via `--dart-define`, or fetch from server at runtime.

### Generating secrets

Always use a CSPRNG, never type a password:

```bash
# Hex (for HMAC keys)
python -c "import secrets; print(secrets.token_hex(32))"

# URL-safe (for tokens, IDs)
python -c "import secrets; print(secrets.token_urlsafe(32))"

# OpenSSL alternative
openssl rand -hex 32
openssl rand -base64 32
```

---

## Layer 2 — CI / GitHub Actions

### Adding a secret

GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**.

Naming convention: `UPPER_SNAKE_CASE`, prefixed by category:

| Pattern | Example |
|---------|---------|
| `<SERVICE>_API_KEY` | `TMDB_API_KEY`, `POLAR_API_KEY` |
| `<SERVICE>_WEBHOOK_SECRET` | `POLAR_WEBHOOK_SECRET` |
| `<SERVICE>_SERVICE_ACCOUNT` | `FIREBASE_SERVICE_ACCOUNT_FLUXORA_STREAMING_PLATFORM` |
| `<SERVICE>_TOKEN` | `PUBLIC_REPO_TOKEN`, `GH_DEPLOY_TOKEN` |

### Using in workflows

```yaml
- name: Deploy
  env:
    POLAR_WEBHOOK_SECRET: ${{ secrets.POLAR_WEBHOOK_SECRET }}
    FIREBASE_SERVICE_ACCOUNT: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_<NAME> }}
  run: ./deploy.sh
```

GitHub auto-redacts secret values in logs (replaced with `***`). Don't fight this — it's protecting you. If you NEED to inspect a secret's value to debug, do it locally with the rotated value.

### Environment-scoped secrets (production-only secrets)

Some secrets should ONLY exist for production deploys:

GitHub repo → **Settings → Environments → `production` → Add secret**.

Now `secrets.PROD_DATABASE_URL` is only available to jobs that declare `environment: production`. Bonus: combined with required reviewers (see [`04_branch_and_pr_workflow.md`](./04_branch_and_pr_workflow.md)), you get "no production secrets without human approval."

---

## Layer 3 — Production / on-host secrets

### For self-hosted services on a single machine (Fluxora's model)

Same `.env` file pattern as local dev — just on the production host:

```
{platform data dir}/.env
```

File permissions: `chmod 600` on Linux/macOS so only the owner can read. On Windows, the platform data dir already restricts access to the user account by default.

### For cloud-hosted services

| Platform | Where secrets go |
|----------|-----------------|
| AWS | AWS Secrets Manager or SSM Parameter Store; instance role pulls them |
| GCP | Secret Manager; service account pulls them |
| Cloudflare Workers | `wrangler secret put` — encrypted at rest, injected as env var |
| Fly.io | `fly secrets set` |
| Heroku / Render | App-level config vars |

The pattern: **a service identity** (IAM role / service account) authenticates to a **secrets vault** to fetch live secrets at startup. No human-typed passwords on production hosts.

---

## Rotation

A secret is rotated when its **value changes**. Always rotate when:

- A teammate leaves the project
- A laptop is lost
- A secret was accidentally committed (rotate even if you delete the commit — git history is forever)
- Yearly, prophylactically, for any secret that signs entitlements (license keys, JWT signing keys)
- Whenever a vendor flags a possible compromise

### Rotation pattern

For ANY secret, the procedure is the same:

1. **Generate** the new value (CSPRNG, see "Generating secrets" above)
2. **Add** it as the new value in all three layers (local, CI, production) — but don't yet remove the old
3. **Verify** systems work with the new value
4. **Remove** the old value
5. **Audit** logs for use of the old value during the transition window
6. **Document** the rotation: who did it, when, why

For secrets that sign things (license keys, JWTs), rotation invalidates already-issued tokens. Plan a comms / re-issuance flow before rotating. See [`docs/06_security/02_license_key_operations.md`](../../06_security/02_license_key_operations.md) for Fluxora's example.

---

## What happens if a secret leaks

The damage from a leaked secret is constant in time — the moment it's published, attackers (automated bots scraping public repos in real time) know about it. Speed matters more than discretion.

### Order of operations

1. **Rotate immediately.** Don't wait until you understand how it leaked. Generate new value, push it to all consuming systems.
2. **Revoke the old value at the source.** API key in Cloudflare? Delete it via dashboard. JWT signing key? Generate new key, re-sign all live tokens.
3. **Scrub git history.** `git filter-repo` or BFG Repo-Cleaner. `git push --force` with team coordination if multi-contributor.
4. **Audit usage.** Check logs for any use of the leaked secret since the leak window opened.
5. **Document.** Write up what happened, what was rotated, what was checked. Don't blame; learn.

### Don't make things worse

- **Don't** just delete the file containing the secret. The secret stays in the git history.
- **Don't** push a new commit with "fix: remove secret" — Google's still indexing the leak window.
- **Don't** assume because the repo is private that it's safe. Repo can become public, get cloned, get screenshotted.
- **Don't** rotate without documenting — future-you needs the timeline.

---

## Tooling

### Pre-commit secret scanning (catch before commit)

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

```bash
pre-commit install
```

Now `git commit` runs gitleaks first. Refuses to commit if it finds something matching a secret pattern.

### CI secret scanning

[`03_github_ci_cd.md`](./03_github_ci_cd.md) covers this — `secret_scan.yml` runs gitleaks on every push and PR over full git history.

### Secret detection in production logs

Log output gets sent to many places (file, stdout, monitoring). Defense:

```python
# WRONG: logs the secret
logger.info("Validating with secret %s", secret)

# RIGHT: logs that validation happened
logger.info("Validated with HMAC key (last 4 chars: %s)", secret[-4:] if secret else "none")
```

For Fluxora specifically, the policy is in [`CLAUDE.md` Hard Prohibition #8](../../../CLAUDE.md#hard-prohibitions): "Never log tokens, passwords, or any PII."

---

## Repo hygiene checklist

Add to a fresh repo before writing any code:

- [ ] `.gitignore` includes `.env`, `.env.*`, `*.pem`, `*.key`, `secrets.*`, `credentials.json`, `service-account*.json`
- [ ] `.env.example` (committed) shows expected variable names with placeholder values like `<your-token-here>`
- [ ] `pre-commit` config installed with gitleaks hook
- [ ] CI runs `secret_scan.yml` (see runbook 03)
- [ ] No "real" `.env` is in git history — verify with `git log --all --full-history -- .env`
- [ ] CONTRIBUTING.md documents where secrets live and how to set them up locally

---

## Cross-references

- **CI secret-scan setup:** [`03_github_ci_cd.md`](./03_github_ci_cd.md)
- **License-key rotation specifics:** [`docs/06_security/02_license_key_operations.md`](../../06_security/02_license_key_operations.md)
- **Backup of secret material:** [`docs/05_infrastructure/05_backup_and_recovery.md`](../05_backup_and_recovery.md)
