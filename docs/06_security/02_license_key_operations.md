# License Key Operations

> **Category:** Security
> **Status:** Active
> **Last Updated:** 2026-05-01

Operational runbook for the Fluxora license key system: how keys are minted, validated, rotated, revoked, and recovered after a leak. Read alongside [`01_security.md`](./01_security.md) (threat model) and [`docs/05_infrastructure/05_backup_and_recovery.md`](../05_infrastructure/05_backup_and_recovery.md) (DR).

---

## Key format

```
FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>
```

| Segment | Format | Notes |
|---------|--------|-------|
| Prefix | Literal `FLUXORA` | Brand discriminator |
| Tier | `FREE` · `PLUS` · `PRO` · `ULTI` | 4-letter codes |
| Expiry | `YYYYMMDD` (8 digits) | `99991231` = lifetime |
| Nonce | 4-char hex (`A0FE`) — or the full Polar order ID for webhook-issued keys | Prevents identical-payload collisions and rainbow-table attacks |
| Sig | 8 uppercase hex chars | First 8 chars of `HMAC-SHA256(secret, "TIER:EXPIRY:NONCE")` |

Example: `FLUXORA-PLUS-20270501-CAFE-A1B2C3D4`

Validated by `apps/server/services/license_service.py`. **Legacy 4-part keys are no longer accepted** — see `test_four_part_key_rejected` in `tests/test_license_service.py`.

---

## Required environment variable

| Var | Where | Description |
|-----|-------|-------------|
| `FLUXORA_LICENSE_SECRET` | `~/.fluxora/.env` | The HMAC secret. Must be present and stable for keys to validate. **Treat as a top-tier secret — losing it invalidates every issued key.** |

Generate once with:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

If absent at server startup, `license_service.validate_key()` returns `LicenseResult(valid=False, reason="no_secret")` for every key — i.e. advisory mode. The server keeps running and reports `license_status: "no_secret"` in `GET /api/v1/settings`, so you can detect the misconfiguration.

---

## Issuing keys

### Path 1 — Polar webhook (automatic, the production path)

When a customer pays via Polar, `POST /api/v1/webhook/polar` (`order.paid`):

1. Verifies the Standard Webhooks signature against `POLAR_WEBHOOK_SECRET`
2. Reads the tier from `event_data.product.metadata.tier`
3. Generates a key with `nonce = order_id` (deterministic — re-delivery is idempotent)
4. Stores it in `polar_orders` (`order_id`, `customer_email`, `tier`, `license_key`, `processed_at`)
5. Owner retrieves it from the desktop **Licenses** screen and emails the customer

The `polar_orders` table is the audit log — every issued production key is in there.

### Path 2 — Manual CLI (for testing, comp keys, friends-and-family)

```bash
cd apps/server
python -m services.license_service --tier plus --days 365
# → FLUXORA-PLUS-20270501-A0FE-83B12FCD

python -m services.license_service --tier ultimate
# → FLUXORA-ULTI-99991231-7B14-1F2E3D4C  (lifetime)
```

CLI keys are **not recorded** anywhere — there's no equivalent of `polar_orders` for them. If you give one out, write it down somewhere yourself.

---

## Validating a key

```python
from services.license_service import validate_key
result = validate_key("FLUXORA-PLUS-20270501-A0FE-83B12FCD")

result.valid           # True/False
result.tier            # "plus" / "pro" / etc — even on failure if structure parsed
result.expires         # "20270501" / "99991231"
result.reason          # "" on success; "expired" / "invalid_signature" / "malformed" / etc on failure
```

The result is exposed via the API at `GET /api/v1/settings`:

```json
{
  "license_key": "FLUXORA-PLUS-20270501-A0FE-83B12FCD",
  "license_status": "valid",   // or "expired" / "invalid_signature" / "no_secret" / "missing"
  "license_tier": "plus"
}
```

The desktop Settings screen surfaces this directly.

---

## Rotation — `FLUXORA_LICENSE_SECRET` change

**This invalidates every previously-issued key.** Only rotate when there's a concrete reason.

### Reasons to rotate

1. The secret was committed to a public repo or pasted into a screenshot
2. A backup containing the secret was stolen
3. A trusted operator with secret access has left the project
4. You suspect a side-channel leak (no one ever does — but document the assumption)

### Rotation procedure

1. **Pause new key issuance.** Stop the server, or set `POLAR_WEBHOOK_SECRET=""` so the webhook returns 501.
2. **Pull the audit list** of currently-active keys:
   ```sql
   sqlite3 ~/.fluxora/fluxora.db \
     "SELECT order_id, customer_email, tier FROM polar_orders ORDER BY processed_at;"
   ```
   Save this output — you need to email each customer.
3. **Generate the new secret.** `python -c "import secrets; print(secrets.token_hex(32))"`. Write to `.env`. Do NOT commit.
4. **Re-issue every key.** For each row from step 2:
   ```bash
   python -m services.license_service --tier plus --days 365
   # capture output, update polar_orders.license_key for that order_id
   ```
   Idempotency: use the same `order_id` as the nonce so the new key is deterministic for that order. (The CLI doesn't currently accept a custom nonce — TODO.)
5. **Restart the server** with the new secret. Verify `GET /api/v1/settings` shows `license_status: "valid"` for your own server's stored key.
6. **Email customers.** Template:
   > Hi <name>,
   >
   > As part of a routine security rotation, your Fluxora license key has been re-issued. Please replace your previous key with: `FLUXORA-PLUS-...`. The old key will stop working in 7 days. Apologies for the inconvenience.
7. **Log the rotation event** in `~/.fluxora/logs/security.log` with the rotation reason, the date, and the customer count notified. (Currently this log file does not exist — add it as a TODO under operational improvements.)

### Customer comms cadence

- Day 0: rotation done; emails sent. New keys work, old keys still work.
- Day 7: server restarted with **only** the new secret in `.env`. Old keys break for any customer who didn't update.
- Day 14: support tickets from stragglers handled individually.

You **cannot skip the 7-day grace window** unless the leak is actively being exploited. If exploited, rotate immediately and bear the customer-support cost.

---

## Revocation — single key

**Not currently implemented.** There is no revocation list.

If you need to invalidate a single key (refund, abuse, lost device), the only options today are:

1. **Soft revoke** — open the customer's row in `polar_orders` and `UPDATE polar_orders SET license_key = '' WHERE order_id = '...';`. Their server's stored key still validates (the secret is unchanged), so this only stops the owner-side audit trail. Not security-meaningful for the customer's actual server.
2. **Hard revoke (nuclear option)** — full secret rotation per above. Wipes every key, not just the targeted one.

### Why no real revocation?

The license check is **fully offline** (CLAUDE.md "local-first, zero cloud dependency" constraint). A revocation list would require either:
- A public CRL the home server fetches (adds a cloud dependency)
- An expiry-based scheme (already exists — keys default to 1 year)

For Phase 4 the answer is: **keys expire; that's the revocation mechanism.** Issue 1-year keys for paid tiers, lifetime only for Ultimate. Customers who refund stop renewing; their key expires within ≤ 1 year.

If revocation becomes important (e.g. piracy at scale), a v2 feature could be a server-id-bound key that calls home to a revocation Worker once a day — see [`docs/05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md#v2--multi-tenant-rollout) for the control-plane that would host it.

---

## Leak response — checklist

| Step | Owner | Done |
|------|-------|------|
| Identify scope (was it just `FLUXORA_LICENSE_SECRET` or also `TOKEN_HMAC_KEY` / `POLAR_WEBHOOK_SECRET`?) | Operator | ☐ |
| Pull `polar_orders` audit list to disk | Operator | ☐ |
| Generate new secret | Operator | ☐ |
| Stop the running server | Operator | ☐ |
| Update `.env` with new secret | Operator | ☐ |
| Re-issue every key, update `polar_orders.license_key` | Operator | ☐ |
| Restart server, validate own key | Operator | ☐ |
| Email all affected customers | Operator | ☐ |
| Document the incident in `AGENT_LOG.md` (date, scope, root cause, time-to-resolve) | Operator | ☐ |
| If `TOKEN_HMAC_KEY` was leaked too: every paired client must re-pair | Operator | ☐ |
| If `POLAR_WEBHOOK_SECRET` was leaked: rotate in Polar dashboard, replay any in-flight orders | Operator | ☐ |
| Schedule a post-mortem within 7 days | Operator | ☐ |

---

## Audit queries

Useful one-liners for routine ops:

```bash
# Total keys issued, by tier
sqlite3 ~/.fluxora/fluxora.db \
  "SELECT tier, COUNT(*) FROM polar_orders GROUP BY tier;"

# Keys issued this month
sqlite3 ~/.fluxora/fluxora.db \
  "SELECT count(*) FROM polar_orders WHERE processed_at LIKE '2026-05-%';"

# Find the order that issued a specific key
sqlite3 ~/.fluxora/fluxora.db \
  "SELECT * FROM polar_orders WHERE license_key = 'FLUXORA-PLUS-20270501-A0FE-83B12FCD';"

# Customer email lookup (for re-issuance after rotation)
sqlite3 ~/.fluxora/fluxora.db \
  "SELECT order_id, customer_email FROM polar_orders WHERE customer_email IS NOT NULL ORDER BY processed_at DESC;"
```

---

## What's NOT covered by this runbook (yet)

- **Server-side audit log of every `validate_key` call** — currently only the result is exposed via `/api/v1/settings`; we don't log "client X attempted to install key Y at time Z." Add when there's a need.
- **Self-service customer key recovery** — no UI for "I lost my key, please email me a new one". Currently a manual support ticket. Add when ticket volume justifies.
- **Hardware binding** — keys today are not bound to a specific server's hardware fingerprint. Listed as Phase 5 future work in [`01_security.md`](./01_security.md#license-key-security--enforcement).
