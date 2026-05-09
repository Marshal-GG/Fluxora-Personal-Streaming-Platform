# Fluxora — Project Structure

## Top-Level Layout

```
Fluxora/
├── apps/           # All runnable applications
│   ├── server/     # Python FastAPI backend
│   ├── mobile/     # Flutter iOS + Android
│   ├── desktop/    # Flutter Windows/macOS/Linux control panel
│   └── web_landing/# Next.js marketing site (static export → CF Pages)
│
├── packages/       # Shared Dart code (imported by mobile + desktop)
│   └── fluxora_core/
│
├── assets/         # Brand & marketing asset masters (canonical)
│   ├── brand/      # Logo, wordmark, identity-sheet masters
│   ├── banners/    # README hero, dividers, GitHub social
│   ├── icons/      # Animated section icons used in README.md
│   └── screenshots/# Marketing screenshots (post-Desktop M3)
│
├── docs/           # Architecture, planning, design docs
├── scripts/        # Build, release, CI scripts
├── functions/      # Cloud Functions (Phase 3+ Firebase signaling — degrades gracefully if absent)
├── installer/      # Windows installer build artefacts
├── build/          # Local build outputs (gitignored)
│
├── AGENT_LOG.md    # Append-only agent activity log (rotation policy: archive when >1000 lines)
├── CLAUDE.md
├── DESIGN.md
├── README.md
├── LICENSE / NOTICE / PRIVACY.md / TERMS.md / SECURITY.md / CODE_OF_CONDUCT.md / CONTRIBUTING.md
├── firebase.json   # Firebase project config (Phase 3+ only)
└── .github/        # GitHub Actions CI/CD
```

> `assets/` is the canonical source of truth for brand. Runtime copies live at `packages/fluxora_core/assets/brand/` (Flutter), `apps/web_landing/public/brand/` (Next.js), and `apps/desktop/windows/runner/resources/app_icon.ico` (Windows runner) — all sized + alpha-processed derivatives, kept in sync manually. See [`assets/README.md`](../../assets/README.md) for the sync flow.

---

## `apps/server/` — Python FastAPI Backend

```
apps/server/
├── main.py
├── config.py
├── pyproject.toml
├── fluxora_server.spec         # PyInstaller
├── Dockerfile
├── README.md
├── database/
│   ├── db.py
│   └── migrations/
│       ├── 001_initial.sql     # media_files, libraries, clients, tmdb_id
│       ├── 002_sessions.sql    # stream_sessions
│       ├── 003_usage.sql       # usage_events
│       ├── 004_tmdb_metadata.sql  # title, overview, poster_url
│       ├── 005_progress.sql    # last_progress_sec
│       ├── 011_groups.sql      # groups, group_members, group_restrictions
│       ├── 012_profile_fields.sql  # display_name, email, avatar_path, profile_created_at, last_login_at on user_settings
│       ├── 013_notifications.sql   # notifications table + idx_notifications_unread
│       ├── 014_activity_events.sql # activity_events table + 2 indexes
│       ├── 015_extended_settings.sql # 18 new columns on user_settings (general/network/streaming/security/advanced)
│       ├── 016_media_quality_episodes_client_email.sql  # FFprobe quality + TV episode aggregation + clients.email/paired_at
│       ├── 017_hwaccel_device.sql  # transcoding_hwaccel_device on user_settings
│       ├── 018_sanitize_encoder.sql  # cleans legacy encoder values from user_settings.transcoding_encoder
│       ├── 019_sanitize_license_key.sql  # nullifies license_key rows that hold the old 4-segment shape
│       ├── 020_encoder_chain.sql   # transcoding_chain TEXT (JSON list) on user_settings
│       ├── 021_session_encoder.sql # encoder_used TEXT on stream_sessions
│       ├── 022_remove_corrupt_media_paths.sql  # one-shot deletion of `[\filename` rows + dependent stream_sessions
│       ├── 023_clients_last_ip.sql # clients.last_ip TEXT — written at pair + every authenticated request via validate_token heartbeat
│       ├── 024_benchmark_history.sql  # benchmark_runs table + idx_benchmark_runs_started_at
│       ├── 025_groups_v2_content_spaces.sql  # v2 redesign — is_public/icon/color/requires_pin/pin_hash/pin_mode/max_concurrent_streams on groups; time_window_override on group_members; group_pin_grants + group_pin_attempts; manufactures Public; backfills allowed_libraries; auto-adds approved clients to Public
│       ├── 026_groups_per_client_pins.sql  # M8 hybrid PIN model — pin_model on groups + group_member_pins enrollment ledger
│       └── 027_transcode_jobs.sql  # plan 18 — transcoded_path / size / at columns on media_files + transcode_jobs queue table
├── routers/                     # 18 routers
│   ├── activity.py             # GET /api/v1/activity; validate_token_or_local
│   ├── auth.py                 # pairing, /clients/me, /clients/me/stats, /clients/me/continue-watching, PATCH /clients/me (M2.5)
│   ├── deps.py                 # shared FastAPI dependencies
│   ├── files.py                # upload/delete/recent/search + GET /files/{id}/content (M11)
│   ├── groups.py
│   ├── info.py                 # /info, /healthz, /info/stats, /info/support-bundle, /info/restart, /info/stop
│   ├── library.py
│   ├── logs.py                 # GET /api/v1/logs; WS /api/v1/ws/logs; validate_token_or_local
│   ├── notifications.py        # GET, POST /{id}/read, POST /read-all, DELETE /{id}; WS /ws/notifications
│   ├── orders.py               # /orders + /orders/portal-url (Polar order list)
│   ├── profile.py
│   ├── settings.py             # /settings GET + PATCH (transcoding + 18 extended fields + chain)
│   ├── signal.py               # WS /ws/signal — WebRTC offer/answer
│   ├── stream.py               # POST /stream/start/{file_id}?seek_sec=&tonemap=, POST /stream/{sid}/seek, DELETE /stream/{sid}
│   ├── transcode.py            # plan 18 — /transcode/{candidates,queue,jobs,jobs/{id},jobs/{id}/retry}
│   ├── transcoding.py          # GET /transcoding/status + /advisor + /devices + /fallback-history + POST /benchmark
│   ├── webhook.py              # POST /webhook/polar (Standard Webhooks signature)
│   └── ws.py
├── services/                    # 25 services
│   ├── activity_service.py     # record() + list_events(limit, since, type_prefix)
│   ├── auth_service.py         # pending-token store, update_client_heartbeat, list_clients
│   ├── benchmark_history_service.py  # benchmark_runs persistence + 50-entry prune
│   ├── benchmark_service.py    # encoder benchmark runner
│   ├── discovery_service.py
│   ├── encoder_advisor.py      # better-encoder recommendations for /transcoding/advisor
│   ├── encoder_registry.py     # 10-encoder registry (sw / NVENC / QSV / VAAPI / VideoToolbox)
│   ├── ffmpeg_capabilities.py  # FFmpeg version probe + capability flags (§17 M2)
│   ├── ffmpeg_service.py       # HLS pipeline (stream-copy / transcode), cuvid hint, HDR tonemap, static VOD playlist
│   ├── group_service.py
│   ├── hardware_probe.py       # GPU probes (best-effort)
│   ├── library_service.py      # FFprobe-at-scan, _persist_probe, backfill_missing_durations
│   ├── license_service.py      # 5-part HMAC-SHA256 license keys (advisory mode if FLUXORA_LICENSE_SECRET unset)
│   ├── log_service.py          # parse JSON-line log; filter/paginate; pubsub for WS /ws/logs
│   ├── notification_service.py # CRUD + asyncio pub/sub fan-out
│   ├── profile_service.py
│   ├── session_router.py       # multi-encoder priority chain (Slice C); pick_encoder + release_session
│   ├── settings_service.py     # user_settings read/write + tier-to-stream-cap mapping
│   ├── support_bundle_service.py     # gzipped tar bundle for /info/support-bundle
│   ├── system_stats_service.py # CPU/RAM/network/uptime + cached internet probe
│   ├── tmdb_service.py
│   ├── transcode_service.py    # plan 18 — single-worker FIFO queue + FFmpeg invocation + crash-recovery on boot
│   ├── transcoding_service.py  # encoder discovery + GPU probe; backs GET /transcoding/status
│   ├── webhook_service.py      # Polar Standard Webhooks signature verification + idempotent processing
│   └── webrtc_service.py
├── models/                      # 13 Pydantic response/request models
│   ├── activity.py             # ActivityEventResponse
│   ├── client.py
│   ├── group.py
│   ├── library.py
│   ├── log_record.py           # LogRecord, LogListResponse
│   ├── media_file.py           # MediaFileResponse (resume_sec alias)
│   ├── notification.py         # NotificationResponse, NotificationCreate, type/category enums
│   ├── order.py                # OrderResponse, OrderListResponse
│   ├── profile.py              # ProfileResponse (avatar_letter computed), ProfileUpdate
│   ├── settings.py
│   ├── stream_session.py       # StreamStartResponse (applied_seek_sec field §16) + StreamSeekResponse
│   ├── transcode.py            # plan 18 — TranscodeCandidate, TranscodeQueueRequest/Response, TranscodeJobResponse, TranscodeRetryResponse
│   └── transcoding.py          # TranscodingStatusResponse, EncoderLoad, ActiveTranscodeSession
├── utils/
│   ├── file_utils.py
│   └── tmdb_client.py
└── tests/
    ├── conftest.py
    ├── test_auth.py
    ├── test_files.py
    ├── test_groups.py
    ├── test_library.py
    ├── test_activity.py        # 12 tests — service CRUD, payload roundtrip, since/type filters, REST endpoints, emitter integration, off-loopback 401
    ├── test_notifications.py   # 12 tests — REST CRUD + WS fan-out + unread filter + dismiss
    ├── test_profile.py         # 9 tests — GET/PATCH profile + avatar_letter computation
    ├── test_stream.py
    ├── test_tmdb.py
    ├── test_transcoding.py     # 6 tests — encoder discovery, GPU probe, status shape, localhost restriction
    ├── test_logs.py            # 15 tests — JSON-line parse, filters, pagination, WS fan-out, auth
    └── test_settings_extended.py # 16 tests — PATCH + GET for 18 new settings fields, constraint enforcement
```

---

## `apps/mobile/` — Flutter iOS + Android (post-M9 redesign cutover)

```
apps/mobile/
├── pubspec.yaml               # depends on packages/fluxora_core; mobile-only direct deps include google_fonts, lucide_icons_flutter, screen_brightness, cached_network_image (^3.4.1), audio_service, mobile_scanner, package_info_plus, just_audio, pdfx, photo_view, share_plus, path_provider, connectivity_plus
├── analysis_options.yaml
├── README.md
├── android/
├── ios/
├── test/                      # 78 tests as of 2026-05-09 (PlayerCubit + auth + connect + library bloc + groups cubit + storage round-trip + widget pump)
│   ├── features/              # cubit + bloc tests
│   └── storage/               # SecureStorage playback-prefs round-trip + PlaybackPrefsScreen widget pump (settings remediation M3)
└── lib/
    ├── main.dart
    ├── app.dart               # MaterialApp.router — AppTheme.dark + BackgroundGradient via builder
    ├── core/
    │   ├── di/
    │   │   └── injector.dart  # ApiClient, SecureStorage, all repos, PlayerCubit + NotificationsCubit + ProfileCubit + ProfileStatsCubit + MobileGroupsCubit lazy singletons
    │   └── router/
    │       └── app_router.dart  # StatefulShellRoute.indexedStack with 4 tab branches (Home / Library / Search / Profile; Downloads tab hidden in v1) + outside-shell deep links: /splash /connect /pairing /reconnect /scan-qr /detail/:id /episodes/:id /library-files/:id /player /player/resume /notifications /offline /xray /group-watch /doc-viewer /photo-viewer /music-player /upgrade /account /privacy /playback-prefs (initial location: /splash)
    ├── features/
    │   ├── onboarding/             # M12 (2026-05-08) — splash_screen.dart (104-px glow FluxoraMark + wordmark + tagline + 3-dot pagination + Connect-to-server / Scan-QR CTAs)
    │   ├── auth/                   # pairing flow (V2-polished M12 — BrandLoader replaces inline spinners)
    │   ├── connect/                # mDNS + manual IP entry (rebuilt M12 — FluxAppBar + BrandLoader + glass tiles + bottom CTAs as FluxButton + manual entry as FluxBottomSheet)
    │   ├── upgrade/                # tier comparison + activation guide; AppGradients.brand header.  Routes.upgrade registered as a real top-level route at settings remediation M1 (was MaterialPageRoute-only via player tier-limit)
    │   ├── home/                   # M3 Discover — Continue-watching hero rail + 4-up Browse strip + Recently-added; bell → /notifications
    │   ├── search/                 # M3 — empty/active/no-results states; Browse chip group routes via Routes.libraryWithFilter
    │   ├── library/                # M3 redesign + legacy LibraryBloc for /library-files/:id deep link; LibraryScreen accepts initialFilter via ?filter= query param
    │   ├── files (legacy path "library/...screens/files_screen.dart") # M11 rebuild — categorized horizontal-rail browser routing per kind to /player /photo-viewer /doc-viewer /music-player; "other" kinds open system share sheet
    │   ├── viewer/                 # M11 (2026-05-08) — doc_viewer_screen (pdfx PdfControllerPinch over temp-downloaded copy) + photo_viewer_screen (photo_view over NetworkImage with bearer header) + music_player_screen (just_audio AudioSource.uri with bearer header) + music_player_cubit
    │   ├── notifications/          # M3 stub → M8 real-data
    │   │   ├── domain/repositories/notifications_repository.dart
    │   │   ├── data/repositories/notifications_repository_impl.dart   # REST polling /api/v1/notifications every 5 s; _pollLimit = 20 + _seenCap = 500 FIFO eviction (mobile redesign audit §17.3 #8, 2026-05-08, mirrors desktop); TODO(WS) for future migration
    │   │   └── presentation/{cubit,screens}/                          # Today/Week/Earlier buckets; category→icon+color; tap-to-markRead
    │   ├── detail/                 # M4 — hero + Play/Episodes + cast/crew/similar rails; emit guarded against post-close
    │   ├── episodes/               # M4 — season chips + episode rows
    │   ├── downloads/              # M8 — storage indicator + Downloading cards + Offline rows + FluxBottomSheet actions; tab hidden in v1 per real-data backfill plan §5 row 4
    │   ├── offline/                # M10 first slice (2026-05-08) — OfflineScreen UI shell; Routes.offline; no live connectivity detector wired in v1 (connectivity_plus only used by player Wi-Fi-only check today)
    │   ├── xray/                   # M10 second slice (2026-05-08) — XRayScreen UI shell + static cast/trivia fixtures; Routes.xray; pushed from player top-bar science-flask chip
    │   ├── group_watch/            # M10 third slice (2026-05-08) — GroupWatchScreen UI shell + static room/invite-link fixtures; Routes.groupWatch; pushed from player overflow menu.  NOT the same as Client Groups / Groups v2
    │   ├── groups/                 # Groups v2 mobile UX (2026-05-07) — Profile-screen group surfaces + PIN modals; MobileGroupsCubit + MobileGroupRow state; PinEntrySheet + PinEnrollmentSheet
    │   ├── profile/                # M8 baseline + settings remediation M1–M5 (2026-05-08).  profile_screen.dart now wires 8 live rows + 2 v1.1 stubs.  account_screen.dart (M2 — read-only fields + editable display name FluxBottomSheet → AuthRepository.updateMe → PATCH /clients/me).  privacy_screen.dart (M4 — device info readout + Clear in-app image cache + Clear temp downloads + sessions note).  playback_prefs_screen.dart (M3 — bg playback / Wi-Fi only / max quality picker / autoplay-next / subs default).  _StubRow widget renders Notifications + Language & region as honestly-stubbed (Opacity 0.55 + violet "v1.1" pill).  Sign-out target /splash (post-M12)
    │   └── player/
    │       ├── domain/, data/      # repository + WebRTC signaling + LAN-vs-WAN smart-path
    │       └── presentation/
    │           ├── controllers/player_controls_controller.dart   # M5 ChangeNotifier
    │           ├── cubit/                                       # M7 singleton + restart-safe startStream + dismiss().  Settings remediation M3 (2026-05-08): new ConnectivityChecker typedef + ctor param + _shouldRefuseOverCellular() Wi-Fi-only gate (fails-open on probe failure; dual-stack proceeds; cellular-only refused with PlayerFailure)
    │           ├── widgets/flux_player_controls.dart            # M5 + M6 — top bar / center transport / progress / quick-actions / gestures
    │           ├── sheets/                                      # M6 — audio_subs / speed / sleep / quality / cast.  Sleep "Custom…" wired via showTimePicker 24-h mode (mobile redesign audit §17.3 #9, 2026-05-08).  End-of-episode still 🔲 (needs next-episode resolver)
    │           └── screens/player_screen.dart                   # M7 dual constructors + drag-down minimize handle
    └── shared/
        ├── data/
        │   └── mock_data.dart    # MockMediaItem/Cast/Season/Episode + MockDownload + fixture lists; MockData.findById; storage constants
        ├── widgets/
        │   ├── background_gradient.dart   # M0 — two-radial brand gradient over bgRoot
        │   ├── mobile_shell.dart           # M2 — Scaffold(body, bottomNavigationBar: Column(MiniPlayer + FluxBottomTabs))
        │   ├── flux_mini_player.dart       # M7 — 64 px persistent bar
        │   ├── media_card.dart             # legacy (V2 tokens post-M9)
        │   ├── status_badge.dart           # legacy (V2 tokens post-M9)
        │   └── loading_overlay.dart        # legacy (V2 tokens post-M9)
        └── theme/
            └── app_theme.dart             # V2-pure post-M9; opaque Color(0xFF0F0C24) for InputDecorationTheme.fillColor
```

---

## `apps/desktop/` — Flutter Control Panel (Windows/macOS/Linux)

```
apps/desktop/
├── pubspec.yaml          # window_manager 0.5.1, flutter_bloc, go_router 17, get_it 9, intl, file_picker, dio
├── analysis_options.yaml
├── README.md
├── windows/runner/       # C++ runner — frameless via TitleBarStyle.hidden + WNDCLASSEX (hIcon + hIconSm) + AppUserModelID
│   ├── main.cpp          # SetCurrentProcessExplicitAppUserModelID(L"Fluxora.Desktop") for Aero Peek
│   ├── win32_window.cpp  # WM_GETMINMAXINFO floor 1332×720; UpdateTheme; WNDCLASSEX with both icon variants
│   ├── Runner.rc         # ProductName/CompanyName/FileDescription = Fluxora; pulls version from pubspec
│   ├── CMakeLists.txt    # links dwmapi.lib + shell32.lib (AUMID)
│   └── resources/app_icon.ico  # ← runtime copy of assets/brand/app_icon.ico
├── macos/                # Not yet generated
├── linux/                # Not yet generated
├── test/
│   ├── features/         # Unit + bloc tests (104 passing as of 2026-05-09)
│   └── goldens/          # M3 Dashboard golden — opt-in via --tags=golden, GetIt-mock recipe in _README.md
└── lib/
    ├── main.dart         # windowManager.ensureInitialized() + WindowOptions(titleBarStyle: hidden)
    ├── app.dart          # MaterialApp.router; title 'Fluxora'
    ├── core/
    │   ├── di/injector.dart  # GetIt registrations for every repo + cubit
    │   └── router/app_router.dart  # ShellRoute(builder: FluxShell) wraps every redesigned screen
    ├── features/         # 17 features: dashboard, library, clients, groups, activity, transcoding,
    │                     #   logs, settings, subscription, profile, notifications, help, storage,
    │                     #   recent_activity, system_stats, command_palette, orders
    └── shared/
        ├── widgets/      # V2 widgets only (legacy stat_card / status_badge / data_table deleted in M9)
        │   ├── flux_shell.dart      # Root layout — FluxTitlebar + sidebar + content + status bar
        │   ├── flux_titlebar.dart   # M10 — 36 px custom titlebar (drag region, help/bell, native Win 11 caption buttons)
        │   ├── flux_sidebar.dart    # 232 px nav rail (no logo header — moved to titlebar in M10)
        │   ├── flux_status_bar.dart # 28 px metric strip (CPU/RAM/NET/UP)
        │   ├── flux_button.dart     # M1 primitive — primary/secondary/ghost/danger × sm/md/lg
        │   ├── flux_card.dart       # M1 — glassmorphic surface
        │   ├── flux_progress.dart   # M1 — linear progress bar
        │   ├── flux_tab_bar.dart    # M4 — tab bar primitive
        │   ├── flux_text_field.dart # M6 form primitive
        │   ├── flux_select.dart     # M6 form primitive
        │   ├── flux_switch.dart     # M6 form primitive
        │   ├── flux_slider.dart     # M6 form primitive
        │   ├── page_header.dart     # M1 — title + subtitle + actions
        │   ├── pill.dart            # M1 — 7-color pill semantics
        │   ├── section_label.dart   # M1 — eyebrow caption
        │   ├── sparkline.dart       # M1 — micro line chart
        │   ├── stat_tile.dart       # M1 — icon + label + value tile
        │   ├── status_dot.dart      # M1 — colored status indicator
        │   └── storage_donut.dart   # M1 — donut breakdown chart
        ├── showcase/                # /showcase route — every primitive rendered (dev/QA tool)
        └── theme/app_theme.dart     # V2-pure (post-M9.5 cutover)
```

---

## `packages/fluxora_core/` — Shared Dart Code

> Imported by both `mobile/` and `desktop/` via local path dependency.  
> Contains ONLY code that is 100% shared — no platform-specific Flutter widgets.

```
packages/fluxora_core/
├── pubspec.yaml
├── README.md
└── lib/
    ├── fluxora_core.dart       # Barrel export
    ├── entities/
    │   ├── activity_event.dart         # M3: ActivityEvent (id, type, summary, createdAt …)
    │   ├── client.dart
    │   ├── client_list_item.dart
    │   ├── enums.dart
    │   ├── library.dart
    │   ├── library_storage_breakdown.dart  # M3: LibraryStorageBreakdown + StorageByType
    │   ├── media_file.dart
    │   ├── server_info.dart
    │   ├── stream_session.dart
    │   └── system_stats.dart
    ├── network/
    │   ├── api_client.dart     # Dio singleton + interceptors
    │   ├── endpoints.dart      # All API URL constants
    │   └── api_exception.dart
    ├── storage/
    │   └── secure_storage.dart # flutter_secure_storage wrapper
    └── constants/
        ├── app_colors.dart     # V2-only — V1 indigo/slate palette + brandGradient deleted at mobile M9 cutover (2026-05-03)
        ├── app_typography.dart # V2-only — displayLg/headingLg/bodyMd/caption/label/mono deleted at mobile M9
        ├── app_gradients.dart  # brand / progress / upgradeCallout / bg radials
        ├── app_radii.dart      # xs/sm/md/lg/pill
        ├── app_shadows.dart    # cardGlow / buttonGlow / dotGlow(color)
        ├── app_spacing.dart    # locked s2 … s32 scale
        └── app_sizes.dart      # legacy mobile sizes (still consumed by connect/upgrade screens)
```

---

## `scripts/` — Build & Release

```
scripts/
├── build_server.ps1            # Windows: PyInstaller .exe
├── build_server.sh             # Linux/macOS: PyInstaller binary
├── build_mobile.sh             # Flutter: APK + IPA
├── build_desktop.sh            # Flutter: Win/macOS/Linux
└── release.sh                  # Tag version + GitHub Release
```

---

## `.github/` — CI/CD (Path-Scoped)

```
.github/
└── workflows/
    ├── server_ci.yml           # Triggers on: apps/server/** changes only
    ├── mobile_ci.yml           # Triggers on: apps/mobile/** changes only
    └── desktop_ci.yml          # Triggers on: apps/desktop/** changes only
```

---

## Scalability Rules

| Rule | Why |
|------|-----|
| Features are **feature-first** inside each app | Adding a screen never touches other features |
| All shared Dart code in `packages/fluxora_core/` | Single source of truth for entities, API client, tokens |
| `apps/server/` is pure Python | Can move to its own repo later with zero refactoring |
| Each app has independent `pubspec.yaml` / `pyproject.toml` | Dependency upgrades are isolated |
| CI workflows are path-filtered | A `server/` change never triggers Flutter CI |
| `shared/` inside each app = that app's local reusables | Not promoted to `fluxora_core/` unless needed by both apps |
