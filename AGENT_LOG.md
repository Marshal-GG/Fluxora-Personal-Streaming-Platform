# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_10.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 09)
**Archived:** 2026-05-08
**Contents:** Tier 2 benchmark axis (resolution-tier matrix) · Groups remediation plan + M1 (restriction editing) · Groups M2-M5 + bulk member ops + activity feed · Groups v2 content-spaces redesign + M8 hybrid PIN (server + desktop) · Groups dedicated management page (M1-M5) · Groups M7 desktop polish + producer-side audit aggregation + bulk grants reset · Groups v2 mobile (M4 + M6 + M8) · Full doc audit pass · Mobile redesign audit + trending rip-out + streaming §4 leftovers + Groups M6 UX revision + DetailCubit emit-after-close · Streaming §4.5 finalise-on-exit + M10 closed (Offline + X-Ray + Group Watch) + Audit §17.3 #2 + #3.

* **Tier 2 benchmark axis (2026-05-07).** Resolution-tier matrix mode for the encoder benchmark — `BenchmarkRequest.resolutions: list[ResolutionTuple]` additive to legacy `width`/`height`; outer-loop-per-resolution × inner-loop-per-encoder; `_progress` schema extended with `total_resolutions` + `current_resolution_*` fields; history sidebar caption switches to "3 res · 30 fps · 18 enc". `EncoderBenchmarkResult` gains `width: int` + `height: int` so each row self-describes; `BenchmarkHistoryEntry.resolution_count` derived in-place from `results_json` parse (no migration). Desktop entity `Resolution` freezed; multi-select chip row replaces single-select. Server suite +N tests.
* **Groups remediation plan + M1 ship (2026-05-07).** `12_groups_remediation_plan.md` written from a 5-finding audit (decorative create/edit dialogs / raw-UUID add member / mobile 403 UX / etc.). M1 (restriction editing) shipped: desktop dialog gains rest-fields editing for time-window + max-concurrent-streams + library-blocklist; `PATCH /api/v1/groups/{id}` accepts the new fields; activity event recorded.
* **Groups M2-M5 (2026-05-07).** End-to-end Groups feature usable: M2 (delete safety + cascade tests), M3 (member-management with display names + bulk add/remove + status badges); M4 (Activity tab on group detail panel), M5 (mobile 403 → human-readable error). Plan 12 fully closed.
* **Groups v2 content-spaces redesign (2026-05-07).** Plan 13. Major semantic flip: M1 schema migrations 025 + 026 (additive UNION model — `allowed_libraries` flips from subtractive to additive without changing the wire format; pin_model='shared' vs 'per-client'); M2 service refactor (`get_visible_libraries` + `reason_to_deny_stream` replace v1 intersection logic); M3 mandatory Public group with auto-membership; M4 shared-PIN gating + grant flow + 5-fails-in-10-min activity aggregator; M8 hybrid per-client PIN enrollment with `group_member_pins` table + obvious-PIN blocklist + HMAC-SHA256 hashing. Master-override (localhost-only). Server suite **565 → 637 passing** through this work.
* **Groups dedicated management page (2026-05-07).** Plan 14. Replaced the M1 modal with a 6-tab full-page edit (`/groups/new` + `/groups/:id/edit`) — Overview / Members / Access / PIN / Activity / View As. Lifted shared form widgets to `widgets/group_form_widgets.dart`. M5 View-As tab consumes `GET /auth/clients/{id}/visible-libraries` (localhost-only).
* **Groups M7 desktop polish + bulk grants reset (2026-05-07).** Tier-2 operator quality of life: 12-icon picker + 6-color picker + `groups.max_concurrent_streams` field + `POST /grants/reset` (drops every active grant — backs Edit dialog "Reset all PINs" in shared-mode). Activity producer aggregation (`_maybe_emit_failed_burst` for 5-fails-in-10-min). 78 group-specific tests; suite reaches **637 passing**.
* **Groups v2 mobile (2026-05-07).** Plan 13 §M4 + §M6 + §M8 mobile. New `apps/mobile/lib/features/groups/` (repo + cubit + state + widgets) consumes `GET /auth/clients/me/visible-libraries` for a single-fetch payload of locked / unlocked / visible groups + libraries. Profile screen mounts `GroupsSection` with three cards — Locked (PIN-required, opens `PinEntrySheet`), Unlocked (live grants with expiry + Lock action), Visible Libraries (the additive UNION). `PinEnrollmentSheet` covers per-client mode; both sheets reuse `FluxBottomSheet` and the `_kObviousPins` blocklist. 16 cubit tests; mobile suite **48 → 64**.
* **Full doc audit pass (2026-05-07).** 14 docs touched in a comprehensive consistency sweep: current_status / data_models / data_flows / migration_guide / API contracts / API versioning policy / system_overview / tech_stack / component_architecture / frontend_architecture / backend_architecture / ship_readiness / desktop_redesign_plan / mobile_redesign_plan. Migration range refreshed (001-026), test counts re-baselined, v1→v2 stream-gate semantics propagated, "intersection" → "UNION" everywhere live (archives left frozen). Net: **637 server / 64 mobile / 90 desktop / 8 core passing**.
* **Mobile redesign audit + trending rip-out + streaming §4 leftovers + Groups M6 UX revision + DetailCubit emit-after-close (2026-05-08).** Five interleaved threads: (1) mobile_redesign_plan §17 audit added (4 subsections — plan-vs-reality table, trending removal strategy, 9 sharp edges, next-priority order); (2) trending rip-out — `MockData.trending` + `MockData.trendingSearches` deleted, `home_screen.dart` `_MockRail` → `_BrowseStrip` (4-up Movies/Shows/Music/Documents using LucideIcons), `search_screen.dart` "Trending searches" → "Browse" chip group, `Routes.libraryWithFilter(slug)` helper, `LibraryScreen.initialFilter` from `?filter=`; (3) streaming §4.3 + §4.10 — segment-wait 5s → 2s + new `POST /api/v1/files/{id}/reset-progress` "Start over" affordance + 4 server tests; (4) Groups M6 UX revision — Locked + Unlocked cards collapsed into single "My groups (N)" card with state badges, fix for the field-report "no way to see how many groups i am part of and where to enter pin?"; (5) `DetailCubit.emit` post-close guard — fixes navigate-back-mid-fetch crash from logs. Server suite **637 → 641 passing**. 4 commits landed (`3b25365` / `489a9cb` / `f8dcdc3` / `b869c3a`).
* **Streaming §4.5 finalise-on-exit + M10 closed (Offline + X-Ray + Group Watch) + Audit §17.3 #2 + #3 (2026-05-08, uncommitted at rotation).** Six threads stacked on top of the morning's commit batch: (1) §4.5 — `_finalize_vod_playlist` + watcher in `ffmpeg_service.py` replaces spawn-time over-promised playlist with FFmpeg's accurate one on natural exit + 11 tests; (2) M10 Offline screen — `OfflineScreen` widget + `Routes.offline` route, UI shell only (no `connectivity_plus`); (3) M10 X-Ray side panel — `XRayScreen` with static cast + trivia fixtures + `Icons.science_outlined` chip on player top bar; (4) M10 Group Watch modal — `GroupWatchScreen` with mock party-watch chrome + invite-link copy + ListTile in player overflow menu; (5) Audit §17.3 #2 closed as no-op (Phase A + B backfill had already wired Profile real-data — audit was stale); (6) §17.3 #3 self-revoke — new `DELETE /auth/clients/me` route + `AuthRepository.revokeMe()` + `_performSignOut` calls it before local teardown + 4 tests. Server suite **641 → 652 → 656 passing**. M10 milestone fully ✅.

**Test counts at archive time (2026-05-08):**
- Server: **656 passing** (+91 since archive 08 baseline of 565: Groups v2 +72, streaming §4.10 +4, §4.5 +11, audit §17.3 #3 +4)
- Mobile: **64 passing** (+19 since archive 08's 45: Groups v2 mobile +16, streaming Commit 3 already counted in 45)
- Desktop: **90 passing** (+6 since 84)
- Core: **8 passing** (unchanged)

`flutter analyze` clean × all 3 packages.

**Migrations at archive time:** 001 → **026** (`groups_per_client_pins.sql` is latest; 025 = Groups v2 content-spaces flip, 026 = M8 hybrid PIN ledger).

**Mobile redesign progress at archive time:**
- ✅ M0–M9 (foundation through theme cutover, 2026-05-03)
- ✅ Post-M9 polish (Phase A + B backfill, QR-pairing scanner, player polish, seek-restart, Groups v2 mobile, trending rip-out, Groups M6 UX revision, DetailCubit emit-after-close)
- ✅ M10 (Offline + X-Ray + Group Watch — all UI shells, 2026-05-08)
- 🔲 M11 Beyond-video (files browser + PDF + photo + music viewers) — next unstarted milestone
- 🔲 M12 Onboarding revamp (QR scanner partly done; splash + signin + server-picker rebuild owed)
- 🔲 M13 Host-a-server shell (Phase 5+ runtime)
- 🔲 M14 Polish + a11y + golden tests

**Audit progress (mobile_redesign_plan §17.3 sharp edges) at archive time:**
- ⏸ #1 iOS PIP — separate ticket (out of v1 scope)
- ✅ #2 Profile real-data endpoint — already shipped; audit was stale
- ✅ #3 Sign-out revokes server-side — shipped 2026-05-08
- 🔲 #4 Continue-watching empty state — open (small)
- 🔲 #5 `background_gradient.dart` `RepaintBoundary` — open (tiny)
- 🔲 #6 Dep version sweep — open (start of M11)
- 🔲 #7 Player-overlay goldens — open (M14 work)
- 🔲 #8 Notifications panel FIFO cap parity — open (small)
- 🔲 #9 Sleep-timer "Custom" + "End of episode" — open (small)
- ✅ #10 Groups M6 self-hide gap — shipped 2026-05-08
- ⏯ #11 DetailCubit emit-after-close (+ remaining cubit sweep) — partial; DetailCubit + MobileGroupsCubit have the override; ProfileCubit / ProfileStatsCubit / RecentCubit / ContinueWatchingCubit / NotificationsCubit / SearchCubit / LibraryBloc / PlayerCubit still need it (one line each)

**Streaming pipeline plan status at archive time:** **No outstanding tactical work.** All §3 user-reported regressions and §4 leftovers closed (4.3 / 4.5 / 4.8 / 4.10 ✅; 4.7 explicitly deferred as low priority). Future iterations would be field-report-driven (e.g. in-progress playback case still 404s on the over-promised tail because media_kit caches the VOD playlist on first load — would require either custom 410 + `Retry-After` handling or a WS-pushed playlist-refreshed signal).

**Recent commit history at archive time:**
```
b869c3a docs: sync mobile redesign audit + cross-cutting status updates
f8dcdc3 fix(mobile): consolidate "My groups" card + guard DetailCubit against emit-after-close
489a9cb feat(server,mobile): close streaming pipeline §4 leftovers — reset-progress + segment-wait
3b25365 feat(mobile): drop trending rail + chip group, replace with Browse navigation
dd480f9 docs: sync for groups v2 + dedicated page + mobile UX
456d9ea feat(mobile/groups): Profile-screen group surfaces + PIN modals
93e7948 feat(desktop/groups): dedicated /groups/:id/edit page + v2/M7/M8 UI
b237dab feat(core): extend Group entity with v2/M8 fields + endpoints
ba74742 feat(groups): v2 content-spaces redesign + M8 hybrid PIN + M7 polish
89af7fc docs(plans): add v2 groups content-spaces + dedicated page plans
```

**Working-tree status at rotation:** Single big uncommitted batch since `b869c3a` covering §4.5 + M10 Offline + M10 X-Ray + M10 Group Watch + §17.3 #2 doc-close + §17.3 #3 self-revoke + 11 doc files (full list in archive 09's last entry).

**Next Immediate Steps (carried forward from archive 09):**
1. **Commit the uncommitted batch** in logical chunks: (a) §4.5 finalise-on-exit (server + tests + plan / api / backend doc updates); (b) M10 milestone — three new mobile screens + router + player chrome + frontend-arch doc; (c) §17.3 #2 doc close-out + §17.3 #3 self-revoke (server + mobile + tests + 5 docs); (d) cross-cutting doc sync (current_status / roadmap / ship_readiness / data_flows / mobile_redesign_plan / AGENT_LOG rotation).
2. **Smoke-test M10 + self-revoke + §4.5 on the user's box.** Sign-out should now actually invalidate the bearer server-side (verify via curl with the cleared token returning 401). Open the player → top bar X-Ray chip → X-Ray panel renders. Open the player → 3-dot overflow → "Group Watch" → Group Watch screen renders + invite-link copy works. Play any stream-copy HEVC source through to natural completion → tail segments shouldn't 404 on a fresh load of the same playlist URL.
3. **Pick the next audit item or M11**: §17.3 #4 (Continue-watching empty state — small), #5 (`background_gradient.dart` `RepaintBoundary` — tiny), #11 finish (mechanical sweep across remaining cubits — ~10 min), or **M11 Beyond-video** (files browser + PDF / photo / music viewers — bigger, ~1–2 sessions; would commit `pdfx` + `photo_view` + `just_audio` + `audio_service` deps).
4. **§4.5 follow-up consideration:** the in-progress playback case still 404s on the over-promised tail because media_kit caches the VOD playlist on first load. If the user reports it, the next iteration would either (a) add a server-side hint on the segment-serve handler to flag "tail past the actual end" with a custom 410 / `Retry-After` header, or (b) push a "playlist refreshed" notification through the WS channel so media_kit re-fetches. Defer until a real complaint surfaces.
5. **iOS PIP** (audit §17.3 #1) remains the only audit-list priority that's neither shipped nor explicitly deferred. `media_kit`'s MPV doesn't bridge to `AVPictureInPictureController`; two paths — swap backend on iOS only (heavy) or build a custom AVPlayerLayer surface (medium). Separate ticket scope.

---

<!-- New session entries go below this line. -->
