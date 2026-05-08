# Mobile Settings — Audit & Remediation Plan

> **Category:** Planning
> **Status:** Drafted 2026-05-08; M1 + M2 + M2.5 + M3 (screen + storage + tests + owner-side wiring + Wi-Fi-only enforcement) + M4 + M5 ✅ all landed 2026-05-08; autoplay-next enforcement still deferred (folds into mobile_redesign_plan §17.3 #9); M6 (goldens + a11y) deferred to mobile redesign §M14.
> **Scope:** `apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart` — the Profile tab is *de facto* the mobile settings surface. 11 interactive entry points; 8 are currently dead-tap.
> **Triggered by:** user report 2026-05-08 — *"settings page lot of buttons and logics not working there"*. Confirmed by code audit.

---

## 1 · Executive Summary

Mobile shipped its Profile-as-settings surface at M8 (2026-05-03) as a `ListView` of 9 `FluxRow`s plus a header gear icon, an avatar block, a stats row, and a Sign-out button. The `ListView` matches the prototype `ProfileScreen` shape — but every row was wired with `onTap: onTap ?? () {}` so the rows render but do nothing on tap.

**Working today (3 of 11):**

| Surface | Behaviour |
|---|---|
| `_BackgroundPlaybackToggleRow` | Real toggle, persists to `SecureStorage.setBackgroundPlaybackEnabled`. |
| `_SettingsRow` "Reconnect to server" | Routes to `/reconnect`. |
| `_SignOutButton` | `revokeMe()` → `playerCubit.dismiss` → `apiClient.clearBearerToken` → `secureStorage.deleteAll` → `context.go('/connect')`. |

**Dead-tap today (8 of 11):**

Header gear, Account, Subscription, Downloads, Language & region, Notifications, Privacy & security, Help & support, About Fluxora.

**Headline failures (in user-impact order):**

1. **Subscription is dead** even though `/upgrade` already exists — there is no path from Profile to the upgrade screen.
2. **Account is dead** — users have no way to see device id, paired-at timestamp, or app version (the only place these can surface).
3. **The header gear icon implies a deeper settings page that doesn't exist** — visual debt that signals more than the surface delivers.
4. **Help & support / About are decorative** — these are zero-cost sheets but ship as dead taps.
5. **Three rows (Downloads, Language & region, Privacy & security) advertise capabilities that don't exist in v1.** Either build them, hide them, or stub-disable them with an explicit "v1.1" pill — the worst option is the current "looks live, does nothing".
6. **Sign-out routes to `/connect`** instead of `/splash` (the post-M12 entry point). Cosmetic but inconsistent.

---

## 2 · Current Architecture (one-page summary)

### 2.1 File layout

| Path | Role |
|---|---|
| [`apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart`](../../apps/mobile/lib/features/profile/presentation/screens/profile_screen.dart) | The whole 779-line surface — header, avatar block, stats row, settings list, groups section, sign-out. |
| [`apps/mobile/lib/features/profile/presentation/cubit/profile_cubit.dart`](../../apps/mobile/lib/features/profile/presentation/cubit/profile_cubit.dart) | `ClientProfile` fetch via `GET /auth/clients/me`. |
| [`apps/mobile/lib/features/profile/presentation/cubit/profile_stats_cubit.dart`](../../apps/mobile/lib/features/profile/presentation/cubit/profile_stats_cubit.dart) | Stats fetch via `GET /auth/clients/me/stats`. |
| [`packages/fluxora_core/lib/storage/secure_storage.dart`](../../packages/fluxora_core/lib/storage/secure_storage.dart) | Already persists `bg_playback_enabled` + `bg_playback_prompt_shown`. Will grow with this plan. |
| [`apps/mobile/lib/features/upgrade/presentation/screens/upgrade_screen.dart`](../../apps/mobile/lib/features/upgrade/presentation/screens/upgrade_screen.dart) | Existing Subscription target — needs no new code, just a route from Profile. |

### 2.2 Server endpoints relevant to settings

| Endpoint | Status | Used by this plan |
|---|---|---|
| `GET /api/v1/auth/clients/me` | ✅ exists | M2 Account detail (read-only fields). |
| `GET /api/v1/auth/clients/me/stats` | ✅ exists | Already consumed by `_StatsRow`. |
| `GET /api/v1/auth/clients/me/visible-libraries` | ✅ exists | Already consumed by `MobileGroupsCubit`. |
| `DELETE /api/v1/auth/clients/me` | ✅ exists (audit §17.3 #3, 2026-05-08) | Already consumed by Sign-out. |
| **`PATCH /api/v1/auth/clients/me`** | 🔲 **does not exist** | **M2 needs a server-side decision** — either add it (display-name edit) or scope Account to read-only. |

---

## 3 · Per-Entry-Point Audit + Triage

| # | Entry point | Current behaviour | Fix category | Milestone |
|---|---|---|---|---|
| 1 | Header gear icon (line 228-246) | Dead `onTap: () {}` over a 38-px decorative button. The Profile tab IS the settings surface — the gear implies a deeper page that doesn't exist. | **Remove** the icon; profile-IS-settings, no need for nesting. | M1 |
| 2 | `_SettingsRow` Account | Dead. | **Build** read-only Account detail screen (M2) — display name, email, tier, paired-at, last-seen, platform, app version, device id. Editable display-name is a stretch goal that depends on a new `PATCH /auth/clients/me` endpoint. | M2 |
| 3 | `_SettingsRow` Subscription (+ `_PlanPill`) | Dead. `_PlanPill` is purely visual. | **Wire** to existing `Routes.upgrade`. The pill becomes a tap target; the row's chevron-right also routes there. | M1 |
| 4 | `_SettingsRow` Downloads | Dead. Sub-text "Quality · auto-delete" advertises a feature that doesn't exist (Downloads tab is hidden in v1 per real-data backfill plan §5 row 4). | **Hide** the row in v1; restore alongside Downloads tab in v1.1. | M5 |
| 5 | `_BackgroundPlaybackToggleRow` (Playback) | ✅ working — single toggle. Prototype called this row "Playback" with sub "Wi-Fi only · streaming quality" — implies a multi-pref screen. | **Promote** to a Playback prefs screen (M3) holding bg-playback toggle + Wi-Fi-only toggle + max-quality picker + autoplay-next toggle. Each new pref gets a new `SecureStorage` key. | M3 |
| 6 | `_SettingsRow` Language & region | Dead. Fluxora has no i18n yet — every string is en-US. | **Stub-disable** with a "v1.1" pill (greyed text, no chevron, no tap). | M5 |
| 7 | `_SettingsRow` Notifications | Dead. The notifications **panel** exists at `/notifications` (REST polling); this row is about **preferences**, which are separate. | **Defer** to v1.1 — push opt-in (FCM) isn't wired and per-category prefs depend on FCM categories. **Stub-disable** with a "v1.1" pill for now. Re-evaluate when push lands. | M5 |
| 8 | `_SettingsRow` Privacy & security | Dead. Could surface: clear cache, show device id, show server URL, show last-seen IP. | **Build** a small Privacy & security screen (M4) — read-only "What we know about this device" panel + Clear cache button (clears `cached_network_image` + `getTemporaryDirectory`'s pdf/photo downloads). | M4 |
| 9 | `_SettingsRow` Help & support | Dead. | **Build** as a `FluxBottomSheet` (no need for a full screen) — GitHub repo URL, issue tracker URL, app + server version, link to `docs/` site if it exists. Sheet, not a screen, because the content is static and short. | M1 |
| 10 | `_SettingsRow` Reconnect to server | ✅ working. | Leave alone. | — |
| 11 | `_SettingsRow` About Fluxora | Dead. Sub-text "v1.0.0 · build 482" is **hardcoded** — needs to read `package_info_plus` for real version + build numbers. | **Build** as a `FluxBottomSheet` — version (from `package_info_plus`), build number, license summary, repo URL, "Made by Marshal" credit. Static otherwise. | M1 |

**Plus one cosmetic-but-real fix:** Sign-out's terminal `context.go('/connect')` should become `context.go('/splash')` post-M12 (the auth-gate would route there anyway, but the explicit jump is more honest).

---

## 4 · Remediation Plan — 6 milestones

Each milestone is one PR. Order is by user-visible impact ÷ implementation cost.

### M1 — Quick wins ✅ **landed 2026-05-08**

- ✅ Removed dead header gear icon — `_Header` is now a single `Text('Profile')`.
- ✅ Wired `_SettingsRow` Subscription → `context.push(Routes.upgrade)`. New `Routes.upgrade = '/upgrade'` constant + `GoRoute` registered in `app_router.dart` (the existing `UpgradeScreen` was previously only reachable via player tier-limit `MaterialPageRoute` — now it's a real top-level route).
- ✅ Wired Help & support → opens a `FluxBottomSheet` titled "Help & support" with intro copy ("Fluxora is self-hosted. For account questions, server outages, or feature requests, contact the operator who paired this device."), a "Diagnostic info" panel (`_DiagnosticRow` for App version + Server URL + Device ID — last two with copy-to-clipboard buttons), and a "Reconnect to server" `FluxButton` that closes the sheet and routes to `Routes.reconnect`. **No GitHub URLs baked in** — the user hasn't shared a public repo URL, and a placeholder URL would 404 silently.
- ✅ Wired About Fluxora → opens a `FluxBottomSheet` titled "About Fluxora" with centered glow `FluxoraMark(size: 56)` + "Fluxora Mobile" title + `package_info_plus`-driven `vX.Y.Z · build N` line + "Stream. Sync. Anywhere." tagline + body description + "Made by Marshal · 2026" credit.
- ✅ Added `package_info_plus: ^9.0.1` to `apps/mobile/pubspec.yaml` (justified under Hard Prohibition #6 — only way to read runtime version + build without hardcoding).
- ✅ Changed Sign-out's `context.go('/connect')` → `context.go('/splash')` so post-sign-out the user lands at the M12 splash.
- ✅ Removed the hardcoded "v1.0.0 · build 482" sub-text — the About row no longer carries a sub-text; the real version surfaces in the About sheet itself.
- **Bonus** (per Q4 stub-disable answer being scoped to M5): the Downloads / Language & region / Notifications / Privacy & security rows are **temporarily removed** from the settings list at M1. They reappear with v1.1 pills at M5 (Language & region / Notifications) and as a real screen at M4 (Privacy & security). Downloads stays gone — the Downloads tab itself is hidden in v1.

**Verification:** `flutter analyze` clean × `apps/mobile` (13.9 s); 64 mobile tests still pass (unchanged — wire-up changes, not logic). End-state: Subscription / Background-playback toggle / Help & support / Reconnect to server / About Fluxora / Sign out all live; profile-as-settings goes from 3 of 11 working to **6 of 6 working** in the trimmed list.

### M2 — Account detail screen ✅ **landed 2026-05-08**

- ✅ New [`apps/mobile/lib/features/profile/presentation/screens/account_screen.dart`](../../apps/mobile/lib/features/profile/presentation/screens/account_screen.dart) — 718 LoC.
- ✅ **Editable display name** — tap the "Display name" row → opens `FluxBottomSheet` ("Rename device") with `FluxTextField` + Save button → calls `AuthRepository.updateMe(displayName)` → on success refreshes `ProfileCubit` so the Profile-tab header reflects the new name + shows a "Renamed device to '…'" SnackBar. Inline validation: empty / >50 chars rejected client-side; server-side enforcement covers control chars + trim semantics.
- ✅ **8 read-only fields** rendered as 3 grouped `_AccountRowCard`s: **Profile** (Display name editable / Email / Subscription tier) · **Device** (Platform / Paired since / Last seen / App version) · **Diagnostic IDs** (Device ID + Server URL — both with copy-to-clipboard buttons + SnackBar feedback).
- ✅ `_IdentityCard` — gradient-bordered avatar block with violet→pink-radial 56-px initials avatar + display name + email, mirrors the prototype Profile shape.
- ✅ `BlocBuilder<ProfileCubit, ProfileState>` consumes the singleton cubit — Initial / Loading both render `BrandLoader`; Failure renders error + Retry; Loaded renders the body.
- ✅ New `Routes.account = '/account'` + `GoRoute` registered in `app_router.dart`. Outside the shell.
- ✅ **Server endpoint shipped** (M2.5 — Q1 yes): new `PATCH /api/v1/auth/clients/me` route in `apps/server/routers/auth.py:325` + `UpdateClientMeRequest` Pydantic model in `apps/server/models/client.py` (1–50 chars, trims whitespace, rejects blank-after-trim + control chars `\x00-\x1f`) + `auth_service.update_client_display_name()` (parameterized SQL UPDATE) + `client.profile_updated` activity event with `actor_kind='client'` + 8 new tests in `tests/test_auth.py` — happy path / whitespace trim / 401 without bearer / 422 on empty / whitespace-only / 51-char / control characters / activity event recorded. **Server suite: 661 → 668 passing**.
- ✅ New `AuthRepository.updateMe({required String displayName})` returns the fresh `ClientProfile` so `_IdentityCard` reflects the rename without a follow-up GET.
- ✅ New Account row in `_SettingsList` (re-introduced after M1 dropped it) — tap routes to `/account`.

**Verification:** `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass; `pytest tests/test_auth.py -v` 42/42 passing (the 8 new PATCH tests included).

### M3 — Playback prefs screen (~1.5 hr) — ✅ **screen + storage + tests landed 2026-05-08; player-cubit Wi-Fi-only + autoplay-next enforcement deferred to a follow-up**

- ✅ New `apps/mobile/lib/features/profile/presentation/screens/playback_prefs_screen.dart` (~370 LoC). `Scaffold(transparent + FluxAppBar)` with one `_PrefsGroup` card holding 5 rows: 4 boolean `_BoolRow`s (Background playback / Wi-Fi only streaming / Autoplay next episode / Subtitles on by default) + 1 `_QualityRow` that taps through to a `_QualityPickerSheet` (4 options: Auto / 1080p / 720p / 480p; tapped option pops with the picked enum value). No cubit — each row is a `Future` read on first build + a `Future` write on toggle, matching the existing `_BackgroundPlaybackToggleRow` pattern (rows are non-interactive while their initial read is in flight).
- ✅ `SecureStorage` extension at `packages/fluxora_core/lib/storage/secure_storage.dart` — 4 new keyed prefs + getters/setters: `wifiOnlyStreaming` (default `false`), `maxStreamingQuality` (default `'auto'`; allow-list defended both at write-time via `ArgumentError` and at read-time by falling back to the default for unknown values), `autoplayNext` (default `true`), `subtitlesDefaultOn` (default `false`). Mirrors the existing `getBackgroundPlaybackEnabled` / `setBackgroundPlaybackEnabled` shape. Each get / set logs failures via the project `Logger` — no silent swallows.
- ✅ `connectivity_plus: ^7.1.1` added to `apps/mobile/pubspec.yaml` (justified in `docs/11_design/mobile_redesign_plan.md` §6 — single dep, two consumers: M3 Wi-Fi-only enforcement + M10 Offline live-detector). Latest version verified against pub.dev rather than pinned to training-data values (Hard Prohibition #12).
- ✅ Tests at `apps/mobile/test/storage/secure_storage_playback_prefs_test.dart` — round-trip + default coverage for each of the 4 new prefs against a map-backed `_FakeFlutterSecureStorage` so the unit-under-test is the real `SecureStorage` class (not a mocked pair); `deleteAll` clears all four; out-of-range `maxStreamingQuality` writes throw `ArgumentError` and stale persisted values fall back to `auto`. Plus a widget pump test that mounts `PlaybackPrefsScreen` against a fresh `GetIt` registration, asserts all 5 row labels render after the initial `Future.wait` settles, then taps the Wi-Fi-only row and asserts the persisted value flips to `true`. **Test count: 64 → 71 (+7).** All pass; `flutter analyze` clean.
- ✅ **Wi-Fi-only enforcement landed 2026-05-08** in `PlayerCubit.startStream`. New `ConnectivityChecker` typedef = `Future<List<ConnectivityResult>> Function()`; cubit constructor gains an optional `connectivityChecker` param defaulting to `Connectivity().checkConnectivity` (overridable in tests so the cubit doesn't depend on a real network interface). New private `_shouldRefuseOverCellular()` reads the pref + runs the probe + returns `true` only when on cellular WITHOUT Wi-Fi (dual-stack devices proceed). On `true`, emits `PlayerFailure('Wi-Fi only mode is on. Connect to Wi-Fi to start streaming, or turn it off in Profile → Playback.')` and returns before the HTTP `startStream` fires. Connectivity-probe failures fail-open (return `false`) so a permission glitch doesn't trap the user with no playback. **+4 cubit tests** in `player_cubit_test.dart` — Wi-Fi-only on + cellular-only fails / Wi-Fi-only on + dual-stack proceeds / Wi-Fi-only off + cellular still proceeds / probe-throws fails-open. Test count: 71 → **75 mobile passing**.
- 🔲 **Still deferred:** the autoplay-next handoff in `PlayerCubit` end-of-stream (Sleep timer "End of episode" + Group Watch already plan against this hook in mobile_redesign_plan §17.3 #9). The pref is persisted; the player just doesn't fire the next item yet. Worth landing alongside §17.3 #9.
- ✅ **Owner-side wiring landed 2026-05-08:** `Routes.playbackPrefs = '/playback-prefs'` constant + `GoRoute` registered in `app_router.dart`. `_BackgroundPlaybackToggleRow` widget (~60 LoC of inline state) deleted from `profile_screen.dart` and replaced with a `_SettingsRow` "Playback" entry (sub: "Bg playback · Wi-Fi only · quality · autoplay · subtitles") that pushes `Routes.playbackPrefs`. The toggle now lives only inside the new screen.

### M4 — Privacy & security screen ✅ **landed 2026-05-08**

- ✅ New [`apps/mobile/lib/features/profile/presentation/screens/privacy_screen.dart`](../../apps/mobile/lib/features/profile/presentation/screens/privacy_screen.dart) — 426 LoC.
- ✅ "What this device knows about you" panel (`_DeviceInfoPanel`) — 4 read-only rows: Server URL · Remote URL · Device ID · App version. Server URL + Remote URL + Device ID all copyable with SnackBar feedback. Async-loads from `SecureStorage` + `package_info_plus` + the singleton `ProfileCubit` (preferred for Device ID over the storage copy since the cubit has the freshest `auth/clients/me` payload).
- ✅ "Maintenance" panel (`_MaintenancePanel`) — two `_ActionRow`s with per-action busy spinners: **Clear in-app image cache** (`PaintingBinding.instance.imageCache.clear()` + `clearLiveImages()`) and **Clear temp downloads** (walks `getTemporaryDirectory()`, deletes files individually with try/catch per-entry, reports `N files (XX MB)` to a SnackBar). The pdf/photo "Open in..." artefacts left by the M11 doc + photo viewers get cleared here.
- ✅ "Sessions" note panel (`_SessionsNote`) — explains in one short paragraph that Fluxora is one-device-per-token, so there are no other sessions to revoke (per Q2 dropped, the audit-listed "Sign out from all devices" button is intentionally absent — kept the explanation so the user understands the omission).
- ✅ New `Routes.privacy = '/privacy'` + `GoRoute` registered. Outside the shell.
- ✅ Privacy & security row re-introduced in `_SettingsList` (M1 had dropped it) — `onTap: () => context.push(Routes.privacy)`.
- ✅ Disk-level `cached_network_image` clear is **deferred to v1.1** — would require pulling `flutter_cache_manager` in as a direct dep; v1 ships in-memory clear only. Documented inline in `privacy_screen.dart`'s file-header comment so future agents know why.
- **Verification:** `flutter analyze` clean × `apps/mobile`; 64 mobile tests still pass.

### M5 — Stub-disabled v1.1 rows ✅ **landed 2026-05-08**

- ✅ New private widget `_StubRow` in `profile_screen.dart` — wraps `FluxRow` in `Opacity(0.55)` + replaces the chevron with a violet "v1.1" pill (8/3 pad, 999 radius, `violet@18%` fill, `violet@32%` border, `violetTint` text at 10.5/700/letterSpacing 0.4). `onTap: () {}` so taps are visually inert. Reusable for any future "ships at v1.1" row.
- ✅ Two stubbed rows added to `_SettingsList` between the bg-playback toggle and the Privacy & security row:
  - **Notifications** — sub: "Push opt-in + per-category preferences". Re-evaluate when push (FCM) lands.
  - **Language & region** — sub: "Localization not enabled in v1". Re-evaluate when i18n lands.
- ✅ Downloads row stays permanently dropped — Downloads tab itself is hidden in v1 (per real-data backfill plan §5 row 4); restoring the settings row would advertise a feature that doesn't exist.
- **Verification:** `flutter analyze` clean × `apps/mobile`.

End-state of the Profile-as-settings list after M1 + M2 + M3 + M4 + M5: **Account · Subscription · Background playback toggle · Notifications (v1.1) · Language & region (v1.1) · Privacy & security · Help & support · Reconnect to server · About Fluxora · Sign out** — 8 live + 2 honestly-stubbed.

### M5 — Hide / stub-disable v1.1 rows (~20 min)

- Drop Downloads row from the settings list entirely. Restore alongside the Downloads tab in v1.1 / Phase E (matches the existing pattern of hiding the Downloads tab itself).
- Replace Language & region row with a stubbed `_SettingsRow` rendered with reduced opacity + violet "v1.1" pill in the trailing slot + no `onTap`. Make the visual difference between live and stub rows obvious.
- Replace Notifications row with the same stub-disabled pattern.
- (Privacy & security graduates to live at M4, so does NOT get stubbed.)
- **Verification:** visual regression — open Profile, confirm 2 stubbed rows + Downloads gone + 7 live rows.

### M6 — Polish + golden tests (~1 hr) — defer to M14

- Golden test for the full Profile screen — paired user, Plus tier, all rows live.
- Golden test for the stubbed-row state — confirms greyed v1.1 pill + reduced opacity.
- Settings-row a11y labels (`Semantics`).
- **This milestone folds into the redesign-plan M14** (golden tests + a11y) rather than shipping standalone.

---

## 5 · Test Strategy

| Layer | Coverage |
|---|---|
| Unit | `SecureStorage` round-trip for the 4 new keys (M3). Widget pump for the new screens — render → verify all fields wired (M2 / M3 / M4). |
| Integration | `PlayerCubit.startStream` Wi-Fi-only branch (M3). |
| Golden | Full Profile screen + stubbed-row variant (M6 — folded into M14). |

Test counts after the full plan lands: ~64 → ~75 mobile passing.

---

## 6 · Open Questions — RESOLVED 2026-05-08

All five questions answered by the project owner; decisions locked in below.

1. **`PATCH /api/v1/auth/clients/me` for display-name edit?** ✅ **YES.** Ship M2 with editable display name (M2 absorbs what the original draft called M2.5). Endpoint added to the server in parallel with M1; mobile-side absorbs the edit sheet into the M2 Account screen scope.
2. **`DELETE /api/v1/auth/clients/me/sessions` for "Sign out everywhere"?** ✅ **DROPPED.** Fluxora is one-client-per-device; there is no `user → many devices` fan-out to sign out across. The button is removed from the M4 Privacy & security scope.
3. **`connectivity_plus` for Wi-Fi-only enforcement (M3) AND the M10 Offline detector?** ✅ **ADD.** Single dep, two real consumers, no alternative. Lands as part of M3.
4. **Hide vs. stub-disable for v1.1 rows.** ✅ **STUB-DISABLE.** Reduced opacity + violet "v1.1" pill in the trailing slot, no `onTap`. Matches the prototype Quality / Cast sheets.
5. **Header gear → Quick settings sheet?** ✅ **REMOVE.** Profile-IS-settings; a gear that opens another nesting is misleading. M1 deletes the icon.

---

## 7 · Dependencies on other plans

- **`docs/11_design/mobile_redesign_plan.md`** — this plan adds work to M12 + M14 of that plan (specifically: the M12 "signin / server picker" rebuild row's wording mentioned settings-touching surfaces; and M14 inherits M6 of this plan).
- **`docs/10_planning/08_real_data_backfill_plan.md`** — Phase A + B already wired the `ClientProfile` data this plan reads from. Phase C / D do not affect any row in §3.
- **`docs/10_planning/13_groups_v2_content_spaces.md`** — the existing `GroupsSection` between the avatar block and the settings list is already shipped + working. This plan does not modify it.
- **None of M1–M5 depend on each other.** Ship in any order; M1 first is recommended for the highest user-visible impact.

---

## 8 · Sequenced summary (TL;DR)

1. **M1 — quick wins.** Subscription→/upgrade, About sheet, Help sheet, drop dead header gear, fix Sign-out target. ~30 min, highest impact.
2. **M2 — Account detail screen.** Read-only for v1.
3. **M3 — Playback prefs screen.** 4 new prefs + Wi-Fi-only enforcement (adds `connectivity_plus` dep).
4. **M4 — Privacy & security screen.** Cache + temp clear + device info read-out.
5. **M5 — Hide Downloads; stub-disable Language & region + Notifications.** ~20 min.
6. **M6 — Goldens + a11y.** Folded into mobile redesign plan §M14.

After M1–M5 land, the Profile-as-settings surface goes from **3 of 11 working** to **9 of 11 working + 2 honestly-stubbed**.
