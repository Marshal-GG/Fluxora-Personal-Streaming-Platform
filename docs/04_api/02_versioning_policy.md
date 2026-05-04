# API Versioning & Deprecation Policy

> **Category:** API
> **Status:** Active
> **Last Updated:** 2026-05-01

How Fluxora's REST + WebSocket API evolves over time without breaking shipped clients.

---

## Current version

**`/api/v1/`** — all endpoints are under this prefix. WebSocket paths follow the same convention (`/api/v1/ws/status`, `/api/v1/ws/signal`).

Defined in `apps/server/main.py` via FastAPI router prefixes. The version is part of the URL, never a header or query string.

---

## What's allowed in v1 (additive only)

After a path is published in v1 and at least one client has shipped against it, the following changes are **allowed** without bumping the version:

| Change | Allowed? | Notes |
|--------|----------|-------|
| Adding a new endpoint | ✅ | Most common. New router, new path. |
| Adding a new field to a response | ✅ | Clients ignore unknown fields. |
| Adding a new optional field to a request | ✅ | Defaults must be backwards-compatible. |
| Adding a new optional query parameter | ✅ | Server uses default when absent. |
| Adding a new error code (4xx/5xx) for new failure conditions | ✅ | Don't repurpose existing codes. |
| Loosening validation (accepting more inputs than before) | ✅ | Cautiously — make sure the new accepted input doesn't change the meaning of unchanged inputs. |

## What's NOT allowed in v1 (breaking — would require v2)

| Change | Why it breaks | Workaround |
|--------|---------------|------------|
| Removing a field from a response | Clients may parse it as required | Mark as deprecated; document in this file with a removal date; remove only in v2 |
| Renaming a field | Same as removing + adding | Add the new name alongside; deprecate the old |
| Changing a field's type (e.g. `int` → `string`) | Clients fail JSON parsing | Add a new field with a new name; deprecate the old |
| Removing an endpoint | Clients get 404 | Mark deprecated; keep returning until v2 |
| Tightening validation (rejecting previously-accepted inputs) | Working clients suddenly fail | Add a new endpoint or new field for the stricter behavior |
| Changing an existing error code (e.g. 400 → 422) | Client error-handling logic breaks | Don't. Add a new error condition with a new code. |
| Changing default values for optional fields | Behavior shifts under callers who never sent the field | Don't. The default in the doc is part of the contract. |
| Changing auth model on an existing endpoint (e.g. removing `validate_token_or_local`) | Working clients lose access | Add a new endpoint with the stricter auth; migrate over time |

If you find yourself needing one of the "not allowed" changes, it triggers v2 — see [When v2 happens](#when-v2-happens).

---

## Field deprecation flow

When a field needs to be removed or renamed (always in a future v2, never in v1):

1. **Announce** by adding a row to the [Deprecated fields](#deprecated-fields) table below with:
   - Endpoint + field name
   - Date deprecated
   - Replacement field (if any)
   - Earliest removal version (always v2 — fields are never removed within a version)
2. **Mark in code**: add a comment on the model field — `# DEPRECATED: removed in v2; use new_field`.
3. **Server keeps populating it** until v2 ships.
4. **Client stops reading it** as soon as the replacement is consumed.

Currently nothing is deprecated. The table exists for the future.

### Deprecated fields

| Endpoint | Field | Deprecated on | Replacement | Removed in |
|----------|-------|---------------|-------------|------------|
| *(none yet)* | | | | |

---

## When v2 happens

A v2 is justified only when an aggregate of breaking changes is large enough to outweigh the cost of running two API surfaces in parallel.

### Triggers

- A redesign of the auth model (e.g. moving from bearer tokens to OAuth)
- A schema overhaul where a majority of v1 endpoints would be deprecated
- A protocol change (e.g. replacing REST with gRPC, or switching media playlists from HLS to DASH at the API level)

Cosmetic field renames or single-endpoint redesigns do not justify a v2.

### Operating during a v2 transition

- **Both versions run in parallel** under their own prefixes (`/api/v1/...` and `/api/v2/...`). Same FastAPI app, same database; routers are separate Python modules.
- **v1 stays supported for at least 6 months** after v2 ships. During this window, every v1 endpoint must keep its behaviour exactly as documented before v2.
- **Clients are migrated tier-by-tier**: desktop control panel first (we ship updates fastest), then mobile, then any third-party integrations.

### What v2 changes do NOT do

- They don't reset behaviour rules — v2 itself follows the same additive-only rules within its own lifetime.
- They don't break paired-client bearer tokens (auth artifacts persist across API versions unless v2 redefines auth, in which case there's a separate migration plan).
- They don't break license keys — those are server-internal and orthogonal to API surface.

---

## Endpoint inventory at v1

The full list lives in [`01_api_contracts.md`](./01_api_contracts.md). Every endpoint there is part of the v1 contract.

### Public surface (subject to v1 stability rules)

- `GET /api/v1/info`
- `GET /api/v1/info/stats`
- `POST /api/v1/auth/request-pair`
- `GET /api/v1/auth/status/{client_id}`
- `POST /api/v1/auth/approve/{client_id}` *(localhost-only)*
- `POST /api/v1/auth/reject/{client_id}` *(localhost-only)*
- `DELETE /api/v1/auth/revoke/{client_id}`
- `GET /api/v1/auth/clients` *(localhost-only)*
- `GET /api/v1/files`, `GET /api/v1/files/{id}`, `POST /api/v1/files/upload`, `DELETE /api/v1/files/{id}`
- `GET /api/v1/library`, `POST /api/v1/library`, `GET/DELETE /api/v1/library/{id}`, `POST /api/v1/library/{id}/scan`
- `GET /api/v1/stream/sessions` *(localhost-only)*, `POST /api/v1/stream/start/{file_id}`, `PATCH /api/v1/stream/{session_id}/progress`, `GET /api/v1/stream/{session_id}`, `DELETE /api/v1/stream/{session_id}`
- `GET /api/v1/hls/{session_id}/playlist.m3u8`, `GET /api/v1/hls/{session_id}/{segment}.ts`
- `GET /api/v1/settings`, `PATCH /api/v1/settings` *(localhost-only)*
- `GET /api/v1/orders` *(localhost-only)*
- `POST /api/v1/webhook/polar`
- `WS /api/v1/ws/status`, `WS /api/v1/ws/signal`

### Internal surface (not under v1 stability rules)

These exist but are not part of the public contract — Fluxora may change them freely between releases.

- `/healthz` (planned, see [`docs/05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md)) — used by Cloudflare for tunnel uptime checks. Format may evolve.

---

## How a new endpoint goes from "added" to "v1 contract"

1. Implement and merge to `main` — endpoint is reachable but not yet documented in `01_api_contracts.md`.
2. Update [`01_api_contracts.md`](./01_api_contracts.md) with the path, request/response schema, error codes, auth mode.
3. Mark the row's "Status" as ✅ Implemented.
4. **From this point on, the additive-only rules apply.** The endpoint is part of v1.

The doc is the contract. If a request/response shape isn't documented, callers should not depend on it.

---

## Backwards compatibility for response schema additions

When you add a new field to an existing response, structure it so old clients keep working without rebuild:

```python
# apps/server/models/file.py — adding a field
class MediaFileResponse(BaseModel):
    id: str
    name: str
    # ... existing fields ...
    duration_sec: float | None = None
    size_bytes: int
    # NEW in v1.4 — optional, defaults to None for backwards compat
    streaming_protocol: str | None = None
```

Server populates it; old clients ignore it. New clients that read it must handle the `None` case for any record indexed before the field existed (in case a re-scan hasn't been run).

This is the entire reason field changes need to be additive — the moment a field becomes mandatory or strictly typed, an old client breaks.

---

## What if I made a breaking change by accident?

Revert it before merging. If it's already merged but not yet in a release, revert and write a follow-up that achieves the same goal additively. If it's already in a release that clients have shipped against, treat it as the trigger for either a hotfix to restore v1 behaviour or — if the bad change is too entangled — accelerated v2 work.

Don't fix breaking changes by "everyone has to upgrade". That's the failure mode this whole doc exists to prevent.

---

## Cross-references

- [`01_api_contracts.md`](./01_api_contracts.md) — full endpoint reference (the v1 contract)
- [`docs/12_guidelines/01_development_guidelines.md`](../12_guidelines/01_development_guidelines.md) — code conventions
- `apps/server/main.py` — where v1 router prefixes are wired
