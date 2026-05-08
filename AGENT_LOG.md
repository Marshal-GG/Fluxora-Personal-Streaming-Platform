# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the canonical format spec at [`docs/12_guidelines/04_agent_log_format.md`](docs/12_guidelines/04_agent_log_format.md).
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_NN.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 10)
**Archived:** 2026-05-08
**Contents:** Mobile redesign **M11 close-out audit** + `files_screen` resource-leak fix + `/content` server tests + AGENT_LOG canonical format spec written → **M12 onboarding revamp** (splash + connect rebuild + pairing polish; signin scope cut as inapplicable to operator-approval pairing) → **mobile-settings remediation plan drafted** (`docs/10_planning/archive/15_mobile_settings_remediation_plan.md` — archived 2026-05-08 after closure, 6 milestones, 5 open questions resolved by user) → **M1–M5 of the settings plan shipped same day** (M1 quick wins + M2 Account screen + M2.5 server `PATCH /clients/me` + M3 Playback prefs + Wi-Fi-only enforcement + M4 Privacy & security screen + M5 stub-disabled v1.1 rows) → **audit §17.3 #8 + #9 cleanup** (Notifications FIFO cap parity + sleep-timer Custom).  Two opus subagents ran in parallel for M2.5 and M3 (subagents discontinued at user request after M3 completed).

* **M11 close-out audit (2026-05-08).** Verified every claim from the prior continuation against actual code; surfaced + fixed `files_screen.dart::_FileChip._openInExternal` HttpClient leak + silent-failure on the error path (mirrors the doc/photo viewer try/finally + ScaffoldMessenger pattern). +5 server tests for `GET /api/v1/files/{file_id}/content` (happy path / 404 not-in-DB / 404 not-on-disk / 404 group-deny / localhost-bypass). Server suite **656 → 661 passing**. AGENT_LOG canonical-format spec written at `docs/12_guidelines/04_agent_log_format.md` after format-drift audit; CLAUDE.md "Where the detail lives" + "Before ending your session" updated to reference it.

* **M12 — Onboarding revamp shipped (2026-05-08).** New `apps/mobile/lib/features/onboarding/presentation/screens/splash_screen.dart` matches the prototype `SplashScreen` (104-px glow `FluxoraMark` + wordmark + tagline + 3-dot pagination + 2 CTAs). Two CTAs (Connect / Scan QR) — the prototype's third "Sign in" + "Continue as guest" CTAs dropped because Fluxora has no credential auth or guest mode. New `Routes.splash = '/splash'` + `_guardRedirect` extended + `initialLocation` flipped to `/splash`. Server picker `connect_screen.dart` rebuilt (FluxAppBar + BrandLoader + glass tiles + bottom CTAs as `FluxButton` + manual entry as `FluxBottomSheet`). Pairing screen `pairing_screen.dart` polished (CircularProgressIndicator → `BrandLoader`). The original M12 plan-row's "email + password + 2FA TOTP + invite-code" scope was honestly cut.

* **Mobile settings remediation — plan drafted + M1–M5 + audit cleanup (2026-05-08).** `docs/10_planning/archive/15_mobile_settings_remediation_plan.md` (archived after closure); 5 open questions resolved (Q1 yes — ship `PATCH /clients/me` for display-name edit, Q2 ok — drop "Sign out everywhere", Q3 yes — add `connectivity_plus`, Q4 stub — stub-disable v1.1 rows, Q5 remove — drop the dead header gear). All five milestones landed same-day:
  - **M1 quick wins** — dropped header gear; wired Subscription → `Routes.upgrade` (existing screen now has a real top-level route); built About + Help & support `FluxBottomSheet`s driven by `package_info_plus ^9.0.1` (replaces hardcoded `v1.0.0 · build 482`); flipped Sign-out target `/connect` → `/splash`. New `Routes.upgrade` registered.
  - **M2 + M2.5** — full `Routes.account` Account screen (read-only Email / Tier / Platform / Paired since / Last seen / App version / Device ID + Server URL with Clipboard copy buttons; identity card with gradient avatar). Editable Display name → `FluxBottomSheet` calling new `AuthRepository.updateMe(displayName)` → `ProfileCubit.refresh` → SnackBar. **M2.5 server endpoint** shipped via opus subagent: `PATCH /api/v1/auth/clients/me` bearer-only `validate_token` + new `UpdateClientMeRequest` Pydantic model (1–50 chars, trims whitespace, rejects blank-after-trim + control chars `\x00-\x1f`) + `auth_service.update_client_display_name()` (parameterized SQL UPDATE) + `client.profile_updated` activity event with `actor_kind='client'` + 8 server tests. Server suite **661 → 669 passing**.
  - **M3 — Playback prefs screen + Wi-Fi-only enforcement** — opus subagent shipped `apps/mobile/lib/features/profile/presentation/screens/playback_prefs_screen.dart` (5 prefs: bg playback / Wi-Fi only / max quality picker / autoplay-next / subs default), 4 new `SecureStorage` keys + getters/setters (allow-list defended at write + read), `connectivity_plus ^7.1.1` added to pubspec, +7 mobile tests (5 round-trip + 2 widget pump). Owner-side wiring landed in main thread: `Routes.playbackPrefs` + lift the `_BackgroundPlaybackToggleRow` out of `profile_screen.dart` and replace with a `_SettingsRow` "Playback". **Wi-Fi-only enforcement** in `PlayerCubit.startStream`: new `ConnectivityChecker` typedef + ctor param + `_shouldRefuseOverCellular()` gate (fails-open on probe failure; dual-stack proceeds; cellular-only refused with `PlayerFailure`) + 4 cubit tests.
  - **M4 — Privacy & security screen** — `Routes.privacy` with `_DeviceInfoPanel` (Server URL / Remote URL / Device ID / App version, all copyable) + `_MaintenancePanel` (Clear in-app image cache via `PaintingBinding.imageCache.clear()` + Clear temp downloads via `getTemporaryDirectory()` walk reporting `N file(s) (XX MB)`) + `_SessionsNote` (one-device-per-token explanation; "Sign out from all devices" intentionally absent per Q2). Disk-level `cached_network_image` clear deferred to v1.1.
  - **M5 — Stub-disabled v1.1 rows** — new `_StubRow` widget (`Opacity(0.55)` + violet "v1.1" pill in trailing slot). Notifications + Language & region rendered as honestly-stubbed; Downloads stays permanently dropped (tab itself hidden in v1).
  - **Audit §17.3 #8** — mobile `notifications_repository_impl.dart::liveStream()` gained `_pollLimit = 20` + `_seenCap = 500` + FIFO eviction; mirrors desktop verbatim.
  - **Audit §17.3 #9 Custom** — `sleep_sheet.dart` "Custom…" wired via `showTimePicker` (24-h forced via `MediaQuery(alwaysUse24HourFormat: true)`, `0:00` cancels, label flips to `Custom (1h 30m)` when active).
  - **Bug fix:** M12 connect_screen rebuild had dropped a `?? 8000` literal that `tests/test_port_consistency.py` enforces — restored with comment pointing at the lockstep guard.

* **End-state Profile-as-settings list:** Account · Subscription · Playback · Notifications (v1.1 stub) · Language & region (v1.1 stub) · Privacy & security · Help & support · Reconnect to server · About Fluxora · Sign out — **8 live + 2 honestly-stubbed** (was 3-of-11-working at session start).

**Test counts at archive time (2026-05-08):**
- Server: **669 passing** (+8 since archive 09 baseline of 661 = M2.5 PATCH /clients/me adds 8 tests; the M12 connect_screen rebuild had transiently broken `test_mobile_connect_screen_uses_canonical_port` by dropping the `?? 8000` literal — restored mid-session with a comment pointing at the lockstep guard).
- Mobile: **75 passing** (+11 since archive 09 baseline of 64: M3 SecureStorage round-trip +5, M3 widget pump +2, Wi-Fi-only enforcement +4).
- Desktop: **90 passing** (untouched).
- Core: **8 passing** (untouched).

`flutter analyze` clean × all 3 packages.

**Migrations at archive time:** 001 → **026** (unchanged from archive 09; M2.5 used the existing `clients.name` column — no schema change).

**Mobile redesign progress at archive time:**
- ✅ M0–M9 (foundation through theme cutover, 2026-05-03)
- ✅ Post-M9 polish (Phase A + B backfill, QR-pairing scanner, player polish, seek-restart, Groups v2 mobile, trending rip-out, Groups M6 UX revision, DetailCubit emit-after-close)
- ✅ M10 (Offline + X-Ray + Group Watch — UI shells, 2026-05-08)
- ✅ M11 Beyond-video (files browser + PDF + photo + music viewers, 2026-05-08)
- ✅ M12 Onboarding revamp (splash + connect rebuild + pairing polish, 2026-05-08)
- 🔲 M13 Host-a-server shell (Phase 5+ runtime — gated)
- 🔲 M14 Polish + a11y + golden tests (last redesign milestone)

**Settings remediation plan status at archive time:** all 5 implementation milestones (M1–M5) + M2.5 server endpoint ✅ landed.  M6 (goldens) folds into mobile redesign §M14.  Two consumers of the persisted prefs still 🔲 (autoplay-next end-of-stream advance; sleep-timer "End of episode") — both blocked on a missing **next-episode resolver** (server endpoint or client-side library search; ~120 LoC + 5 tests when picked up).

**Audit §17.3 status at archive time:**
- ✅ #2 Profile real-data endpoint
- ✅ #3 Sign-out revokes server-side
- ✅ #4 Continue-watching empty state
- ✅ #5 `background_gradient.dart` `RepaintBoundary`
- ✅ #6 Dep version sweep
- ✅ #8 Notifications FIFO cap parity
- ✅ #9 Custom sleep-timer
- ✅ #10 Groups M6 self-hide gap
- ✅ #11 Cubit emit-after-close sweep
- 🔲 #1 iOS PIP (separate ticket; out of redesign cutover)
- 🔲 #7 Player-overlay goldens (folds into M14)
- 🔲 #9 End-of-episode (needs next-episode resolver)

**Streaming pipeline plan status at archive time:** No outstanding tactical work (unchanged from archive 09).

**New top-level direct deps locked at archive time** (mobile only): `package_info_plus ^9.0.1` (M1 — runtime version readout for About sheet), `connectivity_plus ^7.1.1` (M3 — Wi-Fi-only enforcement + future M10 Offline live-detector).

**Recent commit history at archive time:**
```
709cb21 feat(mobile,server): M11 beyond-video viewers + §17.3 audit cleanup
4d96fb0 docs: sync M10 closure + audit progress + rotate AGENT_LOG to archive_09
cfc859a feat(server,mobile): self-revoke for mobile sign-out (audit §17.3 #3)
d5ddc5a feat(mobile): close M10 milestone — Offline + X-Ray + Group Watch UI shells
9778e30 feat(server): finalise VOD playlist on FFmpeg natural exit (§4.5)
```

**Working-tree status at rotation:** Six stacked uncommitted batches on top of `4d96fb0`:
1. M12 onboarding revamp (4 mobile code + 3 doc files).
2. Settings remediation plan (`docs/10_planning/archive/15_*.md` + CLAUDE.md cross-ref).
3. M1 quick wins (pubspec + 2 mobile code files + plan §6/§4 M1).
4. M2 + M2.5 + M4 + M5 (2 new mobile screens + 5 modified mobile/server files).
5. M3 close-out + Wi-Fi-only enforcement (4 modified files + plan).
6. Audit §17.3 #8 + #9 cleanup (2 modified mobile files + plan).

**Recommended commit shape post-rotation:** four commits — `feat(mobile): M12 onboarding revamp` · `docs(planning): mobile settings remediation plan + M1 quick wins` · `feat(mobile,server): M2-M5 settings remediation + Wi-Fi-only enforcement` · `fix(mobile): audit §17.3 #8 + #9 — notifications FIFO cap + sleep-timer Custom`. Or condense.

**Next Immediate Steps (carried forward from archive 10):**
1. **Smoke-test M12 + M1–M5 + Wi-Fi-only on a real device.** Fresh install (no token) → splash → connect → pair → home. Then sign out → `/splash`. Then Profile → every row × 10 should reach a working surface (no dead taps, two stubbed rows render with v1.1 pill). Account edit-display-name → server rename → Profile header refreshes. Privacy clear-cache + clear-temp surface SnackBars. Toggle Wi-Fi-only on → cellular-only → tap a title → expect refusal SnackBar.
2. **Build the next-episode resolver** to unblock both autoplay-next + sleep-timer "End of episode". Suggested shape: new `GET /api/v1/files/{file_id}/next` returning the next file by `(tmdb_show_id, season_number, episode_number)` tuple comparison; null when no next exists; +3 server tests. Mobile-side: new `PlayerRepository.getNextEpisode(fileId)` + `player.stream.completed` listener in `PlayerCubit` consulting sleep-timer mode + `autoplayNext` pref to decide pause vs advance vs idle. ~120 LoC + 5 tests.
3. **M14 polish + a11y + golden tests** — the last redesign milestone with real value (M13 is gated on Phase 5+ phone-as-server runtime). Adds widget/golden tests for the 4 new screens (account / privacy / playback-prefs / splash) + the existing 8 player-overlay surfaces + the `_StubRow` v1.1-pill variant.
4. **Commit the 6-batch stack** in the recommended split (above).
5. **iOS PIP (§17.3 #1)** — its own ticket; `media_kit` MPV doesn't bridge to `AVPictureInPictureController`; either swap player backend to AVKit on iOS only, or build a custom `AVPlayerLayer` for iOS PIP and keep `media_kit` for Android + desktop.

---

<!-- New session entries go below this line. -->
