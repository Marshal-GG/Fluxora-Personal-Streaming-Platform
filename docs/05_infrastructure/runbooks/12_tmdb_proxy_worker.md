# Cloudflare Worker — TMDB Reverse Proxy

> **Why this exists:** some ISPs block TMDB at the network level.  End
> users can't fix this from their machine without a VPN, and asking
> every Fluxora user to switch system DNS isn't a ship-able
> requirement.  This runbook is the **operator's** path to running a
> single Cloudflare Worker that proxies TMDB for every Fluxora install
> at once.

---

## Full story — why this runbook exists

### The original problem (2026-05-06)

A field user (in India, on Reliance Jio) reported that TMDB
enrichment was silently failing on every library scan.  The desktop
showed posters as broken icons; the server log filled with hundreds
of `TMDB enrichment done: 0/N files updated` lines.

After improving the error log to include the exception class
(`repr(exc)` — see [`apps/server/services/tmdb_service.py`](../../../apps/server/services/tmdb_service.py)),
the real error surfaced:

```
WARNING services.tmdb_service: TMDB search failed for 'X':
  ConnectTimeout: ConnectTimeout('')
```

`Test-NetConnection` from PowerShell confirmed:

```
ComputerName    : api.themoviedb.org
RemoteAddress   : 49.44.79.236      ← Reliance Jio sinkhole IP
TcpTestSucceeded: False
```

`nslookup` against Cloudflare's `1.1.1.1` returned the real Amazon
CloudFront IP (`3.165.239.x`); the user's ISP-supplied resolver
returned `49.44.79.236`.  **Classic DNS-hijack pattern**: ISP
intercepts the lookup for a regionally-blocked domain and returns a
sinkhole address.

### Approach 1 — DoH bypass (didn't fully solve it)

We shipped [`apps/server/utils/dns_override.py`](../../../apps/server/utils/dns_override.py)
which monkey-patches `socket.getaddrinfo` and resolves blocked
hostnames via Cloudflare DoH (`https://1.1.1.1/dns-query` — connects
by IP, no recursive DNS needed).  On the first `ConnectTimeout`,
`TmdbService` registers a DoH override and retries.

**Result on the user's network: still failed.**  The retry's
`ConnectTimeout` showed Jio is doing more than DNS hijacking — they're
also IP-blocking TMDB's CDN ranges (or the DoH endpoint itself, but
the latter would have produced a different error class).  No
client-side resolution trick can defeat an IP-level block; packets
literally never reach TMDB.

The DoH workaround stays in the codebase as a **belt-and-suspenders
fallback** for users whose ISP only does DNS hijacking — that's a
real and more common case than full IP blocks, and the workaround
costs nothing when it isn't needed.

### Approach 2 — Cloudflare Worker reverse proxy (this runbook)

The fix that actually works: route TMDB traffic through a hostname
on a domain the operator controls (`fluxora-api.marshalx.dev` here).
Your domain is served from Cloudflare's global anycast — the user's
ISP can't IP-block your domain without breaking everything else
hosted on Cloudflare.  The Worker at the edge does the actual fetch
to TMDB, where the ISP's reach ends.

Confirmed working on Jio:

```
$ curl https://fluxora-tmdb-proxy.marshalgcom.workers.dev/tmdb/3/configuration?api_key=KEY
{"images":{"base_url":"http://image.tmdb.org/t/p/", ...}}
```

Both `*.workers.dev` and the operator's custom subdomain
(`fluxora-api.marshalx.dev`) work.  The custom subdomain hit a
local-DNS-cache stickiness issue on the user's machine that the
workers.dev URL didn't have, so the **workers.dev URL is currently
the recommended setting** for this user.  Either URL works — the
Worker is the same code, both go through Cloudflare anycast.

---

## What you ship

Two URL prefixes on your existing zone:

- `https://<your-domain>/tmdb/*` → proxies to `https://api.themoviedb.org/*`
- `https://<your-domain>/tmdb-img/*` → proxies to `https://image.tmdb.org/*`

The Fluxora server is then configured with two env vars that point at
those prefixes (see [Server configuration](#server-configuration)
below).

Cost: free tier (100 000 Worker requests/day; 10 ms CPU per request).
A typical Fluxora install uses well under 1000 TMDB requests/day, so
you can host the Worker for every Fluxora user out there for years
without paying.

---

## Worker code

Open the Cloudflare dashboard → **Workers & Pages** → **Create
application** → **Create Worker**.  Name it something like
`fluxora-tmdb-proxy`.  Replace the default code with:

```js
// fluxora-tmdb-proxy
//
// Reverse-proxies api.themoviedb.org + image.tmdb.org so end-user
// ISPs that DNS-hijack or IP-block TMDB can still reach it via the
// operator's own domain (which is on Cloudflare's anycast edge).

const TMDB_API = "api.themoviedb.org";
const TMDB_IMG = "image.tmdb.org";

// Cache TTLs.  TMDB metadata is essentially immutable once a title is
// released (the same `id` returns the same payload for years).
// Posters are cached forever in practice; we set a long TTL but allow
// Cloudflare to serve stale-while-revalidate.
const API_CACHE_TTL = 24 * 60 * 60;       // 1 day
const IMG_CACHE_TTL = 30 * 24 * 60 * 60;  // 30 days

export default {
  async fetch(request) {
    const url = new URL(request.url);

    let upstream;
    let cacheTtl;
    if (url.pathname.startsWith("/tmdb/")) {
      upstream = TMDB_API;
      url.pathname = url.pathname.slice("/tmdb".length);  // /3/search/multi
      cacheTtl = API_CACHE_TTL;
    } else if (url.pathname.startsWith("/tmdb-img/")) {
      upstream = TMDB_IMG;
      url.pathname = url.pathname.slice("/tmdb-img".length);  // /t/p/w342/...
      cacheTtl = IMG_CACHE_TTL;
    } else {
      return new Response("Not found", { status: 404 });
    }

    url.hostname = upstream;
    url.protocol = "https:";

    // Pass the request through with the original method, body, and
    // query string.  We do NOT forward the client's Authorization /
    // Cookie headers — TMDB only cares about the api_key query param,
    // and stripping client headers prevents accidental leaks.
    const upstreamReq = new Request(url.toString(), {
      method: request.method,
      headers: {
        "Accept": request.headers.get("Accept") || "application/json",
        "User-Agent": "Fluxora-TMDB-Proxy/1.0",
      },
      // GET-only in practice for TMDB search/poster, but we forward
      // body for forward-compat.
      body: request.method === "GET" || request.method === "HEAD"
        ? undefined
        : request.body,
      // Cloudflare-specific cache hint.  cacheEverything overrides
      // the Cache-Control header from the origin so even non-cacheable
      // responses get cached at the edge.
      cf: {
        cacheEverything: true,
        cacheTtl: cacheTtl,
      },
    });

    return fetch(upstreamReq);
  },
};
```

Click **Save and deploy**.  The Worker is now live at the auto-
generated `*.workers.dev` URL — but we want it on your domain.

---

## Route the Worker on your domain

In the Cloudflare dashboard, go to your zone (e.g. `marshalx.dev`)
→ **Workers Routes** → **Add route**:

| Field | Value |
|---|---|
| Route | `fluxora-api.marshalx.dev/tmdb/*` |
| Worker | `fluxora-tmdb-proxy` |
| Failure mode | `Fail closed` |

Add a **second route** for images:

| Field | Value |
|---|---|
| Route | `fluxora-api.marshalx.dev/tmdb-img/*` |
| Worker | `fluxora-tmdb-proxy` |
| Failure mode | `Fail closed` |

Save.  Cloudflare propagates within ~30 seconds.

---

## Verify

From any network (yours, your phone, a friend's blocked-by-Jio
network):

```bash
# Should return TMDB's configuration JSON.
curl "https://fluxora-api.marshalx.dev/tmdb/3/configuration?api_key=YOUR_KEY"

# Should return a poster image (binary).  Replace path with any
# poster_path you've seen in the API.
curl -I "https://fluxora-api.marshalx.dev/tmdb-img/t/p/w342/inception.jpg"
```

If both return 200 (or the second returns 200/304), the proxy is
working.

---

## Server configuration

Edit `~/.fluxora/.env` (or wherever your Fluxora server's `.env` lives):

```bash
FLUXORA_TMDB_BASE_URL=https://fluxora-api.marshalx.dev/tmdb/3
FLUXORA_TMDB_IMAGE_BASE_URL=https://fluxora-api.marshalx.dev/tmdb-img/t/p/w342
```

Restart the server.  All TMDB API calls + image URLs now flow
through your Worker.  Verify by triggering a TMDB rescan from the
desktop and checking the server log — you should see HTTP requests
go out to `fluxora-api.marshalx.dev` (visible to Cloudflare's
analytics) instead of `api.themoviedb.org`.

**Empty values fall back to the canonical TMDB URLs** — so users
who don't have an ISP problem (or don't want to host a Worker) can
just leave both env vars unset.

---

## Operational notes

### TMDB rate limiting

TMDB enforces ~50 requests/second per API key.  When users proxy
through your Worker their requests still carry their own
`?api_key=`, so each user uses their own quota — your Worker is just
the network path, not a shared rate-limit pool.  No risk of one
user's enrichment storm breaking another's.

### Worker quota

Free tier: 100 000 requests/day, 10 ms CPU/req.  This Worker does
zero CPU work beyond URL rewriting (the actual upstream fetch is
managed by Cloudflare's network layer), so the CPU budget is not a
practical concern.

If you anticipate >100 000 requests/day across all Fluxora installs
(unlikely until you have ~1000 active users), upgrade to the Workers
Paid plan ($5/month for 10M requests/day).

### Cache poisoning concerns

The Worker forwards `?api_key=` in the URL, which becomes part of
the cache key.  Two users hitting the same poster path share the
cache entry; two users searching the same query also share — even
across api keys, because the response body is the same JSON
regardless of which key was used to fetch it.  This is the desired
behaviour and reduces TMDB API consumption proportionally to your
user count.

If TMDB ever ships per-key personalised responses (they don't
today), revisit by including `api_key` in the cache key
(`cf.cacheKey`).

### What this does NOT solve — known follow-ups

#### 1. Existing `media_files.poster_url` rows still reference image.tmdb.org

When you set `FLUXORA_TMDB_IMAGE_BASE_URL`, *new* TMDB lookups will
write proxy-prefixed poster URLs to the database.  But every row
already enriched (before this change) keeps its original
`https://image.tmdb.org/t/p/w342/...` URL.  The mobile / desktop
client fetches those directly, hitting whatever TMDB block the user
is behind.

**Fix when shipping this:** one-shot SQL migration that rewrites
existing posters:

```sql
UPDATE media_files
   SET poster_url = REPLACE(
         poster_url,
         'https://image.tmdb.org/t/p/w342',
         'https://fluxora-tmdb-proxy.marshalgcom.workers.dev/tmdb-img/t/p/w342'
       )
 WHERE poster_url LIKE 'https://image.tmdb.org/%';
```

Tracked in [`docs/10_planning/04_manual_tasks.md`](../../10_planning/04_manual_tasks.md).
Until that lands, users can run the **Rescan TMDB** action on each
library — the rescan replaces `tmdb_id IS NULL` rows but does NOT
overwrite rows that already have metadata.  A migration is the right
fix; the rescan path won't help for already-enriched files.

#### 2. Custom domain DNS quirk on the user's local resolver

The user's local DNS cache (Windows DNS Client) held a stale
`NXDOMAIN` for `fluxora-api.marshalx.dev` even after `ipconfig
/flushdns`.  `nslookup` correctly returned Cloudflare anycast IPs
from `1.1.1.1` and `8.8.8.8`, but `getaddrinfo` (the path `curl` /
Python's `httpx` use) couldn't resolve.

Workarounds:
- **Restart Windows DNS Client service** (admin PowerShell):
  ```powershell
  Restart-Service Dnscache
  ```
- **Use the workers.dev URL instead** — Cloudflare's auto-generated
  subdomain `<worker-name>.<account>.workers.dev` is functionally
  identical to a custom domain Worker route.  No DNS issues observed.
- **Wait** — DNS-Client negative cache eventually expires.

If you ship to wider users on a fresh setup, prefer the workers.dev
URL: it's a known-good zero-config path.  Custom domain is for when
you want branded URLs in shared / public-facing surfaces.

#### 3. Other TMDB endpoints

Only `/3/*` (API) and `/t/p/*` (images) are routed.  The Worker's
`/tmdb/*` and `/tmdb-img/*` prefixes mean any new path under those
namespaces works automatically — if the server later starts hitting
`/3/discover` or `/t/p/original/...`, no Worker change needed.

If the server adds an entirely new TMDB host (e.g.
`api3.themoviedb.org` if TMDB ever rolls a v4), add a third route
prefix to the Worker.

#### 4. TMDB outages

The Worker is a passthrough.  When TMDB itself is down, the Worker
returns 5xx.  `TmdbService` swallows errors and continues (no
enrichment that round, retry next scan).  Cloudflare's edge cache
(via `cacheEverything: true`) means recently-fetched titles still
return their cached response during a TMDB outage — a pleasant side
effect of the cache that wasn't its primary purpose.

#### 5. TMDB API key handling (per user vs shared)

Today: the server's `?api_key=` is forwarded as-is by the Worker.
Each user uses their own TMDB key (free signup at
themoviedb.org); rate limiting is per-key, so users don't compete.

Possible refinement (not yet shipped): inject the API key at the
Worker level so users don't need to register a key themselves.  Risks:
- All Fluxora users share one rate-limit pool (your key gets the
  cumulative load)
- If your key gets revoked, every Fluxora install loses TMDB at once

Defer until / unless TMDB user-key registration becomes a friction
point in install feedback.

---

## Removal / disable

If you ever want to disable the proxy and go direct:

1. Delete the routes (Cloudflare dashboard → Workers Routes → delete
   both).
2. Unset the env vars in `.env` (`FLUXORA_TMDB_BASE_URL=` and
   `FLUXORA_TMDB_IMAGE_BASE_URL=`).
3. Restart the server.

Existing `poster_url` values stored in the DB still point at the
proxy prefix — either leave them (the now-deleted route 404s, posters
break), or run a one-shot SQL update to rewrite them back to
`image.tmdb.org`.

---

## Cross-references

- Server config: [`apps/server/config.py`](../../../apps/server/config.py)
  — `fluxora_tmdb_base_url` / `fluxora_tmdb_image_base_url` fields.
- Service that consumes the URLs:
  [`apps/server/services/tmdb_service.py`](../../../apps/server/services/tmdb_service.py)
  — `TmdbService.__init__` accepts `base_url` / `poster_base_url`.
- DoH workaround (separate, complementary):
  [`apps/server/utils/dns_override.py`](../../../apps/server/utils/dns_override.py)
  — handles the simpler "DNS hijack but IP not blocked" case.  The
  Worker proxy supersedes it for users with a deployed proxy; the
  DoH path stays as a default fallback for users without one.
