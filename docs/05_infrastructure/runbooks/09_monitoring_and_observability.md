# Runbook: Monitoring & observability

> **What:** Minimum-viable monitoring for a self-hosted or cloud-deployed service. Detects "is the thing running and reachable" and "did it crash and why" for free or near-free, without an SRE team.
> **Estimated time:** 1 hour from zero to monitored.

---

## What "minimum viable" means

You can spend infinite money on monitoring. For a hobby / small project, cover four things:

| Tier | Question | Tool |
|------|----------|------|
| **Black-box uptime** | Is the service responding to requests? | UptimeRobot / Better Stack |
| **Error reporting** | When the service crashes or hits an exception, do I find out? | Sentry (free tier) |
| **Structured logs** | Can I grep recent logs to debug an incident? | Local log file with rotation; ship to a service later |
| **Performance baseline** | Is the service getting slower over time? | Defer until you have a complaint about speed |

Skip APM, distributed tracing, custom metrics dashboards, on-call rotations. These pay off above a threshold of users and revenue. Below that threshold, they're make-work.

---

## Tier 1 — Black-box uptime (10 minutes)

### Add a `/healthz` endpoint

Cheap, no DB hit, no auth, returns 200 OK. Fluxora's example:

```python
# apps/server/routers/info.py
@router.get("/healthz")
async def healthz() -> dict:
    return {"ok": True}
```

Don't check the DB or downstream services — the point of `/healthz` is "is this process alive and accepting requests." A check that talks to the DB will fail when the DB is being maintenance'd, even though the API process is fine. Keep it dumb.

### Wire to UptimeRobot

[UptimeRobot](https://uptimerobot.com) free tier: 50 monitors, 5-minute interval, email + webhook alerts. More than enough for a personal project.

1. Sign up
2. Add New Monitor → HTTP(S) → URL: `https://<your-hostname>/healthz`
3. Friendly Name: `<service-name> production`
4. Monitoring interval: 5 minutes
5. Alert contacts: your email (and optionally a Slack/Discord webhook)
6. Save

Five minutes after, UptimeRobot is checking your service. When it goes down for 2+ consecutive checks, you get an email.

### Public status page (optional)

Same dashboard → Status Pages → Add. Auto-builds a public status URL like `https://stats.uptimerobot.com/<id>`. Useful for telling users "it's not just you" during outages.

For a custom domain (`status.<APEX>`), CNAME to UptimeRobot's host on the paid plan, or roll your own with [Statping](https://statping.com) or [upptime](https://github.com/upptime/upptime) (GitHub-Actions-based, free).

---

## Tier 2 — Error reporting (15 minutes)

### Sentry — free tier

Free: 5,000 errors/month, 10,000 performance events, 1 user. Generous; you'll only outgrow this if you have actual production traffic.

Setup for a Python app:

```bash
pip install --upgrade sentry-sdk
```

```python
# apps/server/main.py — early in startup
import sentry_sdk

if settings.sentry_dsn:
    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.environment,         # "prod" / "uat" / "dev"
        release=settings.version,
        traces_sample_rate=0.0,                   # turn on if you want perf monitoring
        send_default_pii=False,
    )
```

`SENTRY_DSN` lives in your `.env` (see [`05_secrets_management.md`](./05_secrets_management.md)). Sentry's project page gives you the DSN.

### What you get

- **Unhandled exceptions** are auto-captured with full stack trace, request data (URL, method, query params), and a "release" tag (so you can see "this regression appeared in version 0.4.2").
- **Manual reporting** for error paths you handle gracefully but want to know about:
  ```python
  import sentry_sdk
  try:
      do_thing()
  except SomeError:
      sentry_sdk.capture_exception()
      return graceful_fallback()
  ```
- **Breadcrumbs**: Sentry captures the most recent log lines + HTTP requests leading up to a crash, so you can see what happened.

### Filter noise

Most projects start with a flood of "expected" errors (404s, 401s, validation errors). Add filters in `sentry_sdk.init`:

```python
def before_send(event, hint):
    exc = (hint.get("exc_info") or [None])[0]
    if exc and exc.__name__ in ("HTTPException", "RequestValidationError"):
        return None     # drop
    return event

sentry_sdk.init(
    dsn=...,
    before_send=before_send,
)
```

Tune over time. Goal: Sentry should only show you things that are unexpected and actionable.

### Flutter side

Sentry has a [`sentry_flutter`](https://pub.dev/packages/sentry_flutter) package. Same idea: init with a DSN, captures unhandled errors. Skip until you actually ship to users.

---

## Tier 3 — Structured logs (20 minutes)

### Log to file + stdout

Logs go to two places:

1. **stdout** — read by humans during dev (`uvicorn` shows them) and by CI in test runs
2. **`{data dir}/logs/server.log`** — rotated by size, retained for 5 backups

```python
# apps/server/utils/logging.py
import logging
from logging.handlers import RotatingFileHandler
from pythonjsonlogger import jsonlogger

def configure_logging(log_path: Path, level: str = "INFO") -> None:
    handler_file = RotatingFileHandler(
        log_path, maxBytes=10 * 1024 * 1024, backupCount=5
    )
    handler_file.setFormatter(
        jsonlogger.JsonFormatter("%(asctime)s %(levelname)s %(name)s %(message)s")
    )
    handler_console = logging.StreamHandler()
    handler_console.setFormatter(
        logging.Formatter("%(asctime)s %(levelname)s %(name)s — %(message)s")
    )

    root = logging.getLogger()
    root.setLevel(level)
    root.handlers = [handler_file, handler_console]
```

Why JSON for the file but not stdout? **Files get parsed by tools** (ship to Loki, Cloudwatch, etc. when you're ready). **Stdout gets read by humans** during dev — JSON is unreadable there.

### Log discipline

| Do | Don't |
|----|-------|
| `log.info("Stream started", extra={"session_id": sid, "client_id": cid})` | `log.info(f"Stream started for session {sid} client {cid}")` |
| Use structured fields for IDs, timestamps, durations | Concatenate into the message |
| Log errors with `exc_info=True` | Log `str(exc)` and lose the stack |
| Log at `INFO` for "things happened that are normal" | Log at `INFO` for every line of code |
| Log at `WARNING` for "this looks wrong but didn't fail" | Log at `WARNING` because you might want to debug later |
| Log at `ERROR` for "this failed in a way that needs investigation" | Log at `ERROR` for every 4xx response |

### Logs over the wire

When you have a real public deployment, ship logs off the host before they get rotated away. Two patterns:

- **Self-hosted Loki + Grafana** — free, your servers ship logs to your Loki instance, Grafana dashboards on top
- **Hosted: Better Stack, Datadog, Honeycomb** — start at $0–10/mo for low volumes

For Fluxora today, we just keep logs on the host. The `GET /api/v1/info/logs` endpoint streams the most recent 1000 lines to the desktop control panel. That's enough for a single-owner deployment.

---

## Tier 4 — Performance (defer)

Don't set up performance monitoring until either (a) someone complains, or (b) you have a baseline you want to defend.

When you do:

- Sentry's `traces_sample_rate=0.1` (10%) gives you per-request timing for free
- Browser-side: Lighthouse CI, Web Vitals
- Server-side custom metrics: Prometheus + Grafana, or just read your existing logs and grep for `duration_ms` patterns

---

## Alerting hygiene

Every alert you create has a cost — a notification you'll either act on or learn to ignore. Two rules:

1. **Every alert must be actionable.** "Service is down" → I restart it / check the tunnel. "Error rate is 0.5% higher than last hour" → I do nothing. The latter shouldn't be an alert.
2. **Every false alarm should produce a fix.** If UptimeRobot pages you when your home internet flickers, raise the threshold (3 consecutive failures) or move to a different probe location.

If you're getting more than ~1 alert per week and most are no-ops, your alerts are wrong.

---

## What to do when you get a real alert

```
1. Acknowledge the alert (silences noise)
2. Reproduce the symptom (curl the URL yourself)
3. Check the obvious: tunnel up? Service running? DB writable?
4. Check Sentry for the trigger error
5. Roll back if a recent deploy looks suspicious
```

Skip step 6 at your peril. Memory rots; an incident you don't document will repeat.

---

## Cross-references

- **`/healthz` endpoint pattern:** [`01_cloudflare_tunnel.md`](./01_cloudflare_tunnel.md) (the tunnel's smoke test uses one)
- **Where SENTRY_DSN lives:** [`05_secrets_management.md`](./05_secrets_management.md)
- **Existing Fluxora log endpoint:** `GET /api/v1/info/logs`
