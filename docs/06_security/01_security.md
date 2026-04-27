# Security Architecture

> **Category:** Security  
> **Status:** ✅ Complete  
> **Last Updated:** 2026-04-27

---

## Overview

Fluxora uses a **local-first trust model**. The server runs on the user's own hardware;
there is no central authentication service, no user accounts in the cloud, and no third-party
identity provider. Every client device must be explicitly approved by the server owner before
it can access any protected API endpoint.

---

## Authentication & Authorization

| Mechanism | Technology | Notes |
|-----------|-----------|-------|
| Client identity | UUID (`client_id`) generated at first run | Stored in `flutter_secure_storage` |
| Auth token | Opaque UUID token (Phase 1) → JWT (Phase 2+) | Issued after pairing approval |
| Token storage (client) | `flutter_secure_storage` | OS Keychain / Android Keystore |
| Token transmission | `Authorization: Bearer {token}` header | All protected routes |
| Token revocation | Server deletes row from `clients` table | Takes effect immediately |
| Pairing approval | Manual tap in Control Panel | Human-in-the-loop; no auto-trust |

---

## Pairing Flow

```
New Device:
  1.  Client generates UUID client_id (stored in secure storage)
  2.  Client → POST /auth/request-pair
            { client_id, device_name, platform, app_version }
  3.  Server → Creates client record  (is_trusted = false)
  4.  Control Panel → Shows "New pair request: {device_name} [{platform}]"
  5.  Owner → Approves or Rejects in Control Panel UI
      If Approved:
  6.  Server → Sets is_trusted = true, generates auth_token, stores hash
  7.  Client → Polls GET /auth/status/{client_id}
  8.  Server → Returns { status: "approved", auth_token: "..." }
  9.  Client → Stores token in flutter_secure_storage
  10. Client → All subsequent requests: Authorization: Bearer {token}

  If Rejected:
  6.  Server → Sets is_trusted = false, records rejection
  7.  Client → Polls GET /auth/status/{client_id}
  8.  Server → Returns { status: "rejected" }
  9.  Client → Shows "Access denied" screen
```

---

## Route Authorization Matrix

| Route Pattern | Auth Required | Notes |
|--------------|--------------|-------|
| `GET /api/v1/info` | ❌ Public | Server identity only — no sensitive data |
| `POST /api/v1/auth/request-pair` | ❌ Public | Pairing initiation |
| `GET /api/v1/auth/status/{id}` | ❌ Public | Polling endpoint — token returned once on first approved poll |
| `POST /api/v1/auth/approve/{id}` | 🔒 Localhost only | `require_local_caller` dep — 403 if `request.client.host` not in `{127.0.0.1, ::1, localhost}` |
| `POST /api/v1/auth/reject/{id}` | 🔒 Localhost only | Same `require_local_caller` restriction |
| `DELETE /api/v1/auth/revoke/{id}` | ✅ Bearer token | Revoke a client's access |
| `GET /api/v1/files` | ✅ Bearer token | List indexed media files |
| `GET /api/v1/files/{id}` | ✅ Bearer token | Single file lookup |
| `GET /api/v1/library` | ✅ Bearer token | List libraries |
| `POST /api/v1/library` | ✅ Bearer token | Create library |
| `GET /api/v1/library/{id}` | ✅ Bearer token | Single library lookup |
| `DELETE /api/v1/library/{id}` | ✅ Bearer token | Delete library |
| `POST /api/v1/library/{id}/scan` | ✅ Bearer token | Trigger directory scan |
| `POST /api/v1/stream/start/{id}` | ✅ Bearer token | Start FFmpeg transcode session |
| `GET /api/v1/stream/{id}` | ✅ Bearer token | Session details |
| `DELETE /api/v1/stream/{id}` | ✅ Bearer token | Stop session (owner only) |
| `GET /api/v1/hls/{session}/{file}` | ✅ Bearer token | Serve HLS playlist or segment |
| `WS /api/v1/ws/status` | ✅ First-message token | Token sent as `{"type":"auth","token":"..."}` — not in header |
| `WS /api/v1/ws/signal` | ✅ Bearer token | WebRTC signaling (Phase 3) |
| All Control Panel routes | ✅ Localhost only | Not exposed externally |

---

## Threat Model

| Threat | Risk | Mitigation |
|--------|------|-----------|
| Unauthorized client access | 🔴 High | Pairing approval + bearer token on all protected routes |
| Token theft (client device) | 🟡 Medium | `flutter_secure_storage` (Keychain/Keystore); tokens revocable |
| Token theft (network) | 🟡 Medium | Phase 5: HTTPS with self-signed cert for LAN |
| MITM on LAN | 🟢 Low | Phase 1–4: acceptable on trusted home network; Phase 5: TLS |
| MITM on Internet | 🟡 Medium | WebRTC DTLS encryption (mandatory in spec) covers media payload |
| File system traversal | 🔴 High | Path resolution locked to `FLUXORA_LIBRARY_ROOTS`; `../` blocked |
| Accidental port exposure | 🟡 Medium | Default bind: `0.0.0.0`; users can restrict to `127.0.0.1` |
| TURN relay eavesdropping | 🟢 Low | WebRTC DTLS/SRTP encrypts all media; relay sees only ciphertext |
| Auth endpoint brute-force | 🟡 Medium | Rate limiting on `/auth/*` (Phase 2) |
| Malicious file path in request | 🔴 High | Server validates and sanitizes all file path params |

---

## Data Security

### Encryption at Rest

| Phase | Status |
|-------|--------|
| Phase 1–4 | No encryption at rest — files stay in user's local filesystem |
| Phase 5 | Optional: encrypted library vault for sensitive content |

### Encryption in Transit

| Connection | Phase 1–4 | Phase 5 |
|-----------|-----------|---------|
| LAN HTTP | Plain HTTP | HTTPS (self-signed cert, user-trusted) |
| Internet (WebRTC) | DTLS/SRTP (mandatory, built into WebRTC spec) | Same |
| Control Panel → Server | Localhost only (no network exposure) | Same |

### Sensitive Data Handling

| Data | Storage | Notes |
|------|---------|-------|
| Auth tokens | Server: SHA-256 hash in DB only | Plain token never persisted on server |
| Auth tokens | Client: `flutter_secure_storage` | OS-backed secure enclave |
| Device names | SQLite `clients` table | Plain text — not sensitive |
| Media file paths | SQLite `files` table | Paths within library roots only |
| TURN credentials | `~/.fluxora/config.json` | Read-only file; not exposed via API |

---

## File Access Security

The server enforces that **all file operations stay within configured library roots**:

```python
# Pseudocode — apps/server/utils/path_security.py
def resolve_safe_path(requested: str, library_roots: list[str]) -> Path:
    resolved = Path(requested).resolve()
    for root in library_roots:
        if resolved.is_relative_to(Path(root).resolve()):
            return resolved
    raise PermissionError("Path outside library roots")
```

Rules:
- No `../` path traversal
- No symlink following outside library roots
- No absolute paths injected by client
- All file params validated before filesystem access

---

## Security Policies

- All `/files`, `/stream`, `/library`, `/ws` routes require a valid, trusted auth token
- `GET /info` is intentionally public (server name, version — no file paths or user data)
- `/auth/request-pair` and `/auth/status/{id}` are public but rate-limited (5/minute per IP)
- `POST /auth/approve` and `POST /auth/reject` are restricted to `localhost` by `require_local_caller`
- `TOKEN_HMAC_KEY` must be set — server refuses to start with an empty key
- File path resolution must always be within configured library roots
- Control Panel binds to `localhost` only and is never exposed on the network
- Token hashes stored in DB with a constant-time comparison to prevent timing attacks

---

## Phase 2 Security Additions

| Addition | Notes |
|----------|-------|
| JWT tokens | Replace opaque UUID tokens with short-lived JWTs (15-min access, 30-day refresh) |
| Token refresh flow | `POST /auth/refresh` using refresh token |
| Audit log | Log all auth events (pair, approve, reject, revoke) to DB |

> **Already implemented in Phase 1:** Rate limiting (`slowapi`, 5/minute on `/auth/request-pair`; 10/minute on stream start); localhost restriction on `approve`/`reject`; startup key validation.

---

## Phase 5 Security Additions

| Addition | Notes |
|----------|-------|
| HTTPS on LAN | Self-signed cert generated at first run; user trusts via Control Panel |
| E2E encryption | Explicit encryption layer wrapping HLS stream content |
| Certificate pinning | Mobile client pins the server's self-signed cert after first trust |

---

## Compliance

| Area | Status |
|------|--------|
| Personal data collected | Device name only — no emails, no passwords, no cloud accounts |
| Cloud data storage | None — fully self-hosted |
| GDPR | N/A — no cloud storage; user controls all data on own hardware |
| COPPA | N/A — no child-specific features or data collection |
