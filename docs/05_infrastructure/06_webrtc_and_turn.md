# WebRTC & TURN Operations

> **Category:** Infrastructure
> **Status:** Active — STUN works out of the box; TURN is optional and currently unprovisioned
> **Last Updated:** 2026-05-01

Operational guide for the WebRTC stack: how it's wired today, how to set up a TURN server when symmetric NATs start dropping connections, and how to debug ICE failures from logs.

Read alongside [`docs/02_architecture/01_system_overview.md`](../02_architecture/01_system_overview.md) (architecture) and [`docs/04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) (`WS /api/v1/ws/signal`).

---

## What ships today

| Layer | Status | Notes |
|-------|--------|-------|
| Signaling channel | ✅ Implemented | `WS /api/v1/ws/signal` — SDP offer/answer + ICE candidate relay; auth required (token) |
| `aiortc` server-side peer connection | ✅ Implemented | `apps/server/services/webrtc_service.py` |
| `flutter_webrtc` client | ✅ Implemented | `apps/mobile/lib/features/player/data/services/webrtc_signaling_service.dart` |
| LAN smart-bypass | ✅ Implemented | `NetworkPathDetector` — /24 subnet check; LAN streams use HLS direct, no negotiation |
| 8-second WebRTC timeout → HLS fallback | ✅ Implemented | `PlayerCubit._handleSignalingDegradation` |
| ICE-failure mid-stream → HLS fallback | ✅ Implemented | Same handler watches `SignalingState.failed` |
| Transport badge UI | ✅ Implemented | `_TransportBadge` in `player_screen.dart` |
| **STUN servers** | ✅ Configured | Google public STUN (`stun.l.google.com:19302`, `stun1.l.google.com:19302`) |
| **TURN server** | 🔲 **Optional, not provisioned** | Env-var support exists in `webrtc_service.py`; no host running |

---

## When you need TURN

STUN gets a peer-to-peer WebRTC connection through ~80% of home routers. The remaining 20% — symmetric NATs, carrier-grade NAT (CGNAT) for some mobile networks, restrictive corporate firewalls — refuse direct P2P and require a relay. That's TURN.

**Signal you need TURN:**
- A meaningful percentage of WAN streams fall back to HLS at the 8-second timeout (currently impossible to detect server-side because we don't log it; first instrumentation TODO).
- Specific user reports: "WebRTC fails on cellular but works on Wi-Fi" — classic carrier NAT signature.
- A specific carrier (T-Mobile US, Jio, some EU carriers) keeps showing up in failure reports.

**Until then, the existing HLS fallback is the right answer.** Don't pre-provision TURN to solve a problem you don't have yet — TURN bandwidth is real money, since you relay every byte of every stream that uses it.

---

## When you DO need it: pick a host

| Option | Setup | Cost (1080p, 1 user, 4hr/day) | Notes |
|--------|-------|-------------------------------|-------|
| **Self-hosted coturn on a VPS** | 30 min, see below | ~$5/mo VPS + bandwidth (~$0.01/GB at most providers) | Full control. Use this. |
| **Twilio Network Traversal Service** | 5 min, API key | ~$0.40/GB | Hands-off. Expensive at scale. |
| **Metered.ca** | 5 min, API key | $0.40/GB free tier first 50GB | Cheaper than Twilio for low volume. |
| **Cloudflare TURN** | API token | Free up to 1TB/mo, $0.05/GB after | Only just GA'd; check current pricing. Likely the right answer in 2026+. |

For a personal-server home use case, **a $5/mo VPS running coturn** is the right balance.

---

## Self-hosting coturn

### 1. Provision

Pick any VPS provider (Hetzner, DigitalOcean, OVH). Spec: 1 vCPU, 1 GB RAM, **public IPv4 with no firewall blocking UDP**. Region close to your users — for a home setup that means "same continent as you and your phone".

DNS: add an A record `turn.fluxora.marshalx.dev` → VPS IP, **proxy OFF** (Cloudflare Tunnel does not support UDP and would break TURN even if proxy was on for TCP).

### 2. Install coturn

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install -y coturn
sudo systemctl enable coturn
```

### 3. Configure `/etc/turnserver.conf`

```conf
listening-port=3478
tls-listening-port=5349
fingerprint
lt-cred-mech
realm=turn.fluxora.marshalx.dev

# Use long-term credentials. Pick a random secret and password:
static-auth-secret=<32-char-hex-secret>
user=fluxora:<32-char-password>

# UDP relay range
min-port=49152
max-port=65535

# TLS via Let's Encrypt
cert=/etc/letsencrypt/live/turn.fluxora.marshalx.dev/fullchain.pem
pkey=/etc/letsencrypt/live/turn.fluxora.marshalx.dev/privkey.pem

# Drop loopback and private ranges from being relayed (no internal pivot)
no-loopback-peers
no-multicast-peers

# Quotas — total relay bandwidth ceiling
total-quota=200
bps-capacity=0
stale-nonce=600

# Logging
log-file=/var/log/turnserver/turnserver.log
verbose
```

Generate the credentials:

```bash
python -c "import secrets; print('SECRET:', secrets.token_hex(16)); print('USER:', secrets.token_urlsafe(24))"
```

Get a Let's Encrypt cert via `certbot --nginx` or `certbot certonly --standalone` (stop coturn briefly to free port 80).

### 4. Open firewall

```bash
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 5349/tcp
sudo ufw allow 49152:65535/udp
```

### 5. Start

```bash
sudo systemctl restart coturn
sudo systemctl status coturn        # confirm "active (running)"
```

### 6. Smoke test

From any machine:

```bash
sudo apt install -y stun-client coturn-utils
turnutils_uclient -u fluxora -w '<password>' -p 3478 turn.fluxora.marshalx.dev
```

Expect `Total connect time: 0.0xx sec` and `0 errors`.

---

## Wire it into Fluxora

The server already supports TURN via env vars — no code change.

```bash
# Add to ~/.fluxora/.env
WEBRTC_TURN_URL=turn:turn.fluxora.marshalx.dev:3478
WEBRTC_TURN_USERNAME=fluxora
WEBRTC_TURN_CREDENTIAL=<the-password-from-step-3>
```

Restart the Fluxora server. The `RTCConfiguration` returned to clients now includes the TURN entry — ICE will try direct, then STUN, then TURN.

`webrtc_service.py:_ice_servers()` will log `TURN server configured: turn:turn.fluxora.marshalx.dev:3478` at startup.

---

## Verifying TURN actually fires

Two ways:

**1. Server-side log signature.** When a client's ICE negotiation falls back to relay, `aiortc` logs include `relay` candidate types. Grep:

```bash
tail -f ~/.fluxora/logs/server.log | grep -i 'relay\|ice'
```

**2. Client-side `iceConnectionState`.** Add temporary logging in `webrtc_signaling_service.dart`:

```dart
peerConnection.onIceConnectionState = (state) {
  log.d('ICE: $state');
  // Look for: ICEConnectionState.connected
  // and check stats for transport.localCandidateId.candidateType == 'relay'
};
```

If you see `relay` candidates and `connected`, TURN is doing its job. If you see only `host`/`srflx` candidates, P2P or STUN got through and TURN was unused — that's fine.

---

## Cost guardrails

A 1080p H.264 stream is roughly **4 Mbps**. A single 2-hour movie via TURN relay is ~3.6 GB up + 3.6 GB down = 7.2 GB total bandwidth.

| Per user, per month | Light (4 hr/wk) | Medium (1 hr/day) | Heavy (4 hr/day) |
|---------------------|-----------------|-------------------|------------------|
| Bandwidth via TURN | ~60 GB | ~220 GB | ~860 GB |
| Cost @ Hetzner ($1/TB) | ~$0.06 | ~$0.22 | ~$0.86 |
| Cost @ DigitalOcean (after free 1 TB) | $0 | $0 | $0 |
| Cost @ Twilio ($0.40/GB) | $24 | $88 | $344 |

For self-hosting, bandwidth on a $5 VPS comfortably covers a single household. For more than one heavy user, monitor monthly transfer and consider Cloudflare's TURN service if it's cheaper at your volume.

**Set a hard cap.** In `turnserver.conf`:

```conf
# Reject new sessions when this many concurrent relays are active
total-quota=20

# Per-session bps cap (bits/sec) — 0 = unlimited
bps-capacity=8000000
```

`total-quota=20` lets up to 20 concurrent relayed sessions; with WebRTC's ~4 Mbps per session that's ~80 Mbps aggregate, comfortable for a $5 VPS.

---

## Cloudflare Tunnel does NOT relay TURN

This trips people up: you cannot put TURN behind `fluxora-api.marshalx.dev` via Cloudflare Tunnel.

Reasons:
- TURN is primarily UDP. Cloudflare Tunnel is HTTPS/TCP only.
- Even TURN-over-TCP (port 5349) is fine on raw TCP but Cloudflare Tunnel terminates TLS at the edge and re-encrypts — TURN-over-TLS expects the cert to be the relay's, not Cloudflare's.

So `turn.fluxora.marshalx.dev` is a **separate A record pointing directly at the VPS**, with Cloudflare proxy **OFF** (DNS only). It's not on the same infrastructure as `fluxora-api.marshalx.dev`. This is documented in [`04_domains_and_subdomains.md`](./04_domains_and_subdomains.md).

---

## Debugging ICE failures

### `ICEConnectionState.failed` reported by the client

Walk down this list in order:

1. **STUN reachable?** From the client's network: `nslookup stun.l.google.com` should return a real IP. If not, the network is blocking outbound DNS or UDP.
2. **STUN binding succeeds?** Use a browser-based test like `https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/`. Enter `stun:stun.l.google.com:19302` and click "Gather candidates". Expect a `srflx` candidate within 3 seconds. If only `host` shows, STUN is being blocked.
3. **Symmetric NAT?** Run the test on both peers. If both show `srflx` candidates but pairing fails, you've got symmetric NAT — TURN required.
4. **TURN configured?** Check the server's `GET /api/v1/info` indirectly: if `WEBRTC_TURN_URL` is set, server logs at startup will say so.
5. **TURN reachable from the failing peer?** From the client's network, check that UDP 3478 to the TURN host is not blocked. Some corporate networks drop all outbound UDP except 53/443.
6. **TURN credentials valid?** Test from a third machine with `turnutils_uclient` (step 6 above). If it fails there too, the credentials in `.env` are wrong.

### `signalingState: stable` but no media

The data channel is up but no frames are flowing. Usually:
- Codec mismatch — check the SDP offer/answer for the `m=video` line; must include H.264 (`a=rtpmap:96 H264/90000`).
- Server-side `aiortc` couldn't open the source file — check `ffmpeg_service` logs.
- `MediaRelay` not wired — `webrtc_service` should add the track to the peer connection. If a recent refactor broke this, the SDP includes a video track but `track.onframe` never fires.

### Logs to grep

```bash
# Server-side ICE events
grep -E 'ICE|peer|webrtc' ~/.fluxora/logs/server.log | tail -50

# coturn relay events
sudo tail -f /var/log/turnserver/turnserver.log

# Cloudflare-side WS upgrade success/failure (if signaling is going through CF Tunnel)
cloudflared tunnel logs <tunnel-id> | grep -E 'ws|upgrade|signal'
```

---

## What's NOT covered (yet)

- **Telemetry on WebRTC outcomes** — we don't log "session X used relay vs P2P, lasted N seconds, transferred N bytes". Add when TURN cost monitoring becomes important.
- **Automated TURN failover** to a secondary host if the primary is down — would require client-side support; not yet wired.
- **DTLS/SRTP cert pinning** — currently rely on the platform's TLS store. Acceptable for v1.
