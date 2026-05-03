# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_07.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 06)
**Archived:** 2026-05-04
**Contents:** Mobile redesign M8–M9 (Downloads + Profile + Notifications real-data, then breaking V2 theme cutover) · Documentation sync round (M8/M9 across 8 docs) · Mobile real-data backfill plan + Phase A scope freeze · Phase A delivered in three commits (server slice + mobile data wiring + pairing UX rebuild) · Desktop polish round in parallel (real glass on Library popups + dialogs, theme tweaks).

* **Mobile M8 — Downloads + Profile + Notifications real-data wiring + log rotation (2026-05-03):** New `features/notifications/` repo + cubit + state mirroring desktop's REST-polling pattern (singleton `NotificationsCubit`); Downloads + Profile screens rebuilt with mock fixtures (`MockDownload`, hardcoded profile fields); previous AGENT_LOG rotated to archive 05. `// TODO(WS):` markers left for future HMAC-bearer WS migration.
* **Mobile M9 — Theme cutover (2026-05-03, breaking PR):** 7 mobile call-sites + 1 desktop straggler migrated off V1 tokens; deleted 17 V1 colors + 11 V1 typography styles from `fluxora_core/constants/`; `apps/mobile/lib/shared/theme/app_theme.dart` body rewritten onto V2 tokens. M9.5 follow-up patched 4 polish issues (`InputDecorationTheme.fillColor` opacity, `surfaceRaised` contrast, Pro/Ultimate tier collapse, Grep matrix verification).
* **Doc sync round (2026-05-03):** Eight architecture / frontend / data / security / planning / gotchas docs rolled forward to reflect M8/M9. Set the precedent for the new "comprehensive Grep matrix before declaring a cutover complete" gotcha.
* **Real-data backfill plan + Phase A scope freeze (2026-05-04):** New `docs/10_planning/08_real_data_backfill_plan.md` — 10 sections covering goal / inventory / phases A-G / decisions / cutover ritual / NOT-doing list / pre-flight findings / frozen Phase A scope. Eight owner decisions locked. Pre-flight caught two server bugs (re-pair from same `client_id` returning 409; pending tokens in-memory only).
* **Phase A — Server slice (commit `ac5051f`, 2026-05-04):** Migration 016 adds FFprobe video metadata + TV episode aggregation + per-client `email`/`paired_at` to `media_files` and `clients`. New `probe_video()` in `ffmpeg_service.py` runs at scan time. `auth_service.create_pair_request` rewritten to reset same-`client_id` rows back to `pending` regardless of prior status (§8.5 bug 1 fix); in-memory pending-token store moved into the service so re-pair can invalidate it. New endpoints: `GET /files/recent?limit=N` (1..50, mobile Home rail) + `GET /auth/clients/me` (bearer-required per-client profile). `MediaFileResponse` extended with the seven new optional fields. Server suite 253 → 262 passing (+9 cases).
* **Phase A — Mobile data wiring (commit `bb9a94f`, 2026-05-04):** Three new cubits — `RecentCubit` (Home rail), `DetailCubit` (per-screen), `ProfileCubit`. New `ClientProfile` entity (freezed); `MediaFile` extended with the 7 Phase A fields plus a `qualityBadge` extension. Library tab consumes `LibraryBloc` (containers + 5-chip `LibraryType` filter). Detail screen consumes `DetailCubit` over `getFile(id)`. Profile header reads `display_name + email + tier` from `/auth/clients/me`; stats row em-dashed until Phase B. Episodes screen converted to a Phase D placeholder. `MockGradients` lifted to `apps/mobile/lib/shared/widgets/gradients.dart` as `AppGradientPlaceholders` with a `forKey(String)` deterministic helper. `mock_data.dart` shrunk ~360 lines (`MockGradients`, `recentlyAdded`, `findById`, `_details`, `MockCastMember/Season/Episode` all deleted). Mobile tests still 27 passing.
* **Phase A — Pairing UX rebuild (commit `556fe48`, 2026-05-04):** `PairCubit` rewritten with two-step entry (`prepare(server)` → `submitEmail({server, email})`) plus a `reconnect()` entry that uses saved `client_id` + `server_url`. New `PairCollectEmail(server)` state for the optional-email pre-request UI. Pairing screen rebuilt V2-styled per state. New `/reconnect` route + `ReconnectScreen` for lost-token recovery. `ApiClient.unauthorizedStream` (broadcast) emits on 401-with-bearer; `setupRouterUnauthorizedBridge()` in `main.dart` redirects to `/reconnect` (unless already on a pairing surface). Auth-guard updated: `/reconnect` is public; the "authenticated → /home" reflection is scoped to `/connect` and `/pairing` only. Profile gains a "Reconnect to server" sub-row. `pair_cubit_test` rewritten — 5 → 9 cases. Mobile 27 → 31 passing; core 8 still passing.
* **Desktop polish — real glass on Library popups + dialogs (parallel 2026-05-04):** New `FluxGlassDialog` + `FluxGlassMenu` widgets using `BackdropFilter` for proper translucent surfaces over the gradient backdrop. Library Sort menu / Filters dialog / Delete confirm migrated. Several theme tweaks (Card default fill `Color(0xFF0F0C24)` for opaque mid-tier, etc.).

**Phase A is shipped end-to-end (server + mobile + pairing).** Mobile Library / Detail / Home-Recent rail / Profile are all real-data-backed; pairing UX is state-machine-driven with the optional email field; lost-token recovery flows through `/reconnect` with auto-redirect on 401.

**Next Immediate Steps:**
1. **Phase B — Continue-watching + Search + Profile stats.** Three new server endpoints (`/clients/me/continue-watching`, `/files/search`, `/clients/me/stats`) plus three mobile cubit / screen rewires. Each is the smallest fully-real surface left in the mobile app. Plan §3 row 1–3 in `docs/10_planning/08_real_data_backfill_plan.md`.
2. **Hide Downloads tab in v1** (decision §5 row 4). Standalone tiny commit: remove from `FluxBottomTabs` registry + `Routes.downloads` + the `StatefulShellBranch`. Could land before or after Phase B.
3. **Visual QA pass on Phase A.** Walk a paired Android / iOS device through the new pairing UX (server tile → email step → pending → approval → /home) and the reconnect flow (revoke token from desktop → 401 fires → redirect → re-approval → /home). All flutter analyze + tests are green; the actual UI hasn't been exercised.
4. **Mobile redesign M10** — X-Ray panel + Group Watch shell + Offline state, UI shells only per plan §1 row 4. Lower priority than Phase B since these surfaces are largely cosmetic.

---

## Entry Template

```
---
## [YYYY-MM-DD] — Brief title
**Phase:** Phase N (description)
**Status:** Complete | Partial | Blocked

### What Was Done
- bullet list

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | path |
| Modified | path |

### Docs Updated
- list

### Decisions Made
- list

### Blockers / Open Issues
- list

### Issues / Sharp Edges Discovered
- list

### Suggested Next Steps
- list

### Hard Rules Checklist
- [ ] item
```

---
