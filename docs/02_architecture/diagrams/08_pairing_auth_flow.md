# 08 — Pairing & Auth Flow

> How a fresh device discovers the server, gets paired, and stays authenticated. Mobile flow shown; desktop control panel is local-bypass on the same host.

---

## Full pairing happy path

```mermaid
sequenceDiagram
  autonumber
  actor U as User
  participant M as Mobile (Connect screen)
  participant DS as discovery_service (server)
  participant A as routers/auth.py
  participant DB as SQLite (clients)
  participant Op as Operator (desktop CP)

  Note over DS: app boot — Zeroconf registers service<br/>_fluxora._tcp.local.
  U->>M: Open app first time
  M->>M: launch Connect screen
  M->>DS: mDNS query _fluxora._tcp.local.
  DS-->>M: server name, IP, port
  M-->>U: list of discovered servers
  U->>M: pick a server (or manual IP)
  M->>A: POST /auth/pair {name, platform, raw_token}
  A->>A: HMAC-SHA256(raw_token) → hashed
  A->>DB: INSERT clients (status='pending', auth_token=hashed, last_ip)
  A-->>M: 202 Pending
  M-->>U: "Waiting for approval…" + BrandLoader

  Note over Op: meanwhile, operator…
  Op->>A: GET /api/v1/clients (Pending tab)
  A->>DB: SELECT WHERE status='pending'
  DB-->>A: pending rows
  A-->>Op: list
  Op->>A: POST /clients/{id}/approve
  A->>DB: UPDATE status='approved', paired_at=now
  DB-->>A: ok
  A-->>Op: 200

  loop poll every N seconds
    M->>A: GET /clients/me (Authorization: Bearer raw_token)
    A->>DB: SELECT client WHERE auth_token=HMAC(raw)
    alt approved
      A-->>M: 200 client
      M->>M: SecureStorage.setToken(raw_token)
      M->>M: navigate / (Home)
    else still pending
      A-->>M: 202 pending
    end
  end
```

---

## Token storage + transport

```mermaid
flowchart LR
  classDef secret fill:#ef4444,stroke:#000,color:#fff
  classDef hashed fill:#7c3aed,stroke:#fff,color:#fff
  classDef header fill:#a78bfa,stroke:#000,color:#000

  Raw["Raw token<br/>generated client-side<br/>UUID v4"]:::secret
  Raw -- "POST /auth/pair body" --> Hashed
  Raw -- "Authorization: Bearer ..." --> Header[Every authed request]:::header
  Hashed["HMAC-SHA256(raw, secret)<br/>stored in clients.auth_token"]:::hashed
  Header -- validate_token --> Hashed
  Raw -. "flutter_secure_storage<br/>(OS keychain / keystore)" .-> ClientStore[(SecureStorage)]

  Note["Raw token NEVER leaves the device<br/>beyond the initial pair body<br/>and Bearer header.<br/>DB only ever sees the HMAC hash."]
```

> **Hard prohibition #13:** Bearer tokens are stored as HMAC-SHA256 hashes. No plaintext, no reversible encryption. See [CLAUDE.md](../../../CLAUDE.md).

---

## Heartbeat — last_seen + last_ip

```mermaid
sequenceDiagram
  autonumber
  participant C as Client
  participant D as routers/deps.py validate_token
  participant DB as SQLite

  C->>D: Authenticated request
  D->>DB: SELECT WHERE auth_token=HMAC(raw)
  alt not found
    D-->>C: 401
  end
  D->>DB: UPDATE clients SET last_seen=now, last_ip=socket.peer
  D-->>C: proceed to handler
```

Every authenticated request bumps `last_seen` and `last_ip`. Pre-migration-023, these were frozen at pair time — the operator's Clients screen used to show "never seen" for active clients.

---

## Local-bypass (desktop control panel on same host)

```mermaid
flowchart TD
  Start([Request arrives]) --> Q1{socket.peer<br/>== 127.0.0.1?}
  Q1 -- yes --> Q2{Endpoint accepts<br/>validate_token_or_local?}
  Q2 -- yes --> Pass[Allow without bearer]
  Q2 -- no --> Bearer[Must have Bearer]
  Q1 -- no --> Bearer
  Bearer --> Validate[validate_token]
```

Some endpoints — `/info/*`, `/transcoding/*`, `/logs`, `/activity` — use `validate_token_or_local` so the operator's desktop control panel can hit them without pairing-as-itself. Remote callers still need a valid bearer.

---

## QR pairing (mobile-only convenience)

```mermaid
sequenceDiagram
  autonumber
  actor U as User
  participant D as Desktop CP
  participant M as Mobile (Scan QR)
  participant A as Server

  Note over D: operator shows pairing QR<br/>containing {server_url, name, hint_token}
  U->>M: tap Scan QR
  M->>M: open mobile_scanner
  U->>M: aim at desktop screen
  M->>M: decode QR → {server_url, name}
  M->>A: POST /auth/pair {pre-filled name, generated raw_token}
  A-->>M: 202 pending
  Note over M: rest of flow identical to manual pair
```

---

## Re-pair / reconnect

```mermaid
stateDiagram-v2
  [*] --> CheckToken : app cold start
  CheckToken --> ValidToken : SecureStorage has token AND GET /clients/me succeeds
  CheckToken --> NoToken : empty SecureStorage
  CheckToken --> StaleToken : 401 from /clients/me

  NoToken --> Connect : push /connect
  StaleToken --> Reconnect : push /reconnect<br/>(same server URL, fresh pair)

  ValidToken --> Home : push /

  Connect --> Pairing : pick server
  Pairing --> ValidToken : approved
  Pairing --> Connect : rejected / back
  Reconnect --> Pairing : new pair attempt
```

The Reconnect screen preserves the last server URL so the user doesn't have to rediscover.
