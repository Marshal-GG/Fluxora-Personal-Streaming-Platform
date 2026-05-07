# Client Groups — Issue Audit & Remediation Plan

> **Category:** Planning
> **Status:** ✅ Complete — M1–M5 all shipped 2026-05-07
> **Succeeded by:** [`13_groups_v2_content_spaces.md`](./13_groups_v2_content_spaces.md) — v2 content-spaces redesign (additive semantic + Public group + PIN-gated groups + hybrid PIN model). The v1 model this plan completed was kept intact through v2 M1; the semantic flip (subtractive → additive) landed via migration 025 on the same day this plan finished.  ADR-015 (intersection rule) → superseded by ADR-018 (union content-spaces); ADR-014 (stream-gate location) still valid.
> **Scope:** Identifies why the Client Groups feature is unusable in practice despite a working backend, and lays out a sequenced remediation plan with concrete code targets, milestone boundaries, and test strategy.
> **Triggered by:** user report ("groups are unusable currently") on 2026-05-07 — confirmed by code audit: every defect is on the desktop UI side; the server enforcement plumbing works.

---

## 1 · Executive Summary

Client Groups shipped at M0 §7.1 (migration `011_groups.sql` + `routers/groups.py` + `services/group_service.py` + 8 endpoints). The backend supports four restriction kinds and the stream-gate ([`stream.py:100-107`](../../apps/server/routers/stream.py#L100)) actually invokes `get_effective_restrictions` + `reason_to_deny` on every stream-start. **The plumbing works.**

The problem is that **the desktop UI is decorative** — every group ships with empty restrictions because no UI ever populates them, the Add Member dialog asks for raw client UUIDs that nobody knows offhand, and the Clients screen has no idea that group membership is a thing. So the feature is technically present but practically dead.

**Headline failures (in operator-impact order):**

1. **Create + Edit dialogs only collect name + description.** No fields for `allowed_libraries` / `time_window` / `bandwidth_cap_mbps` / `max_rating`. Every group is created with `restrictions = null`. The stream gate has nothing to deny against.
2. **Add Member asks for raw client UUID.** Operator must paste a UUID by hand. There's no client picker. Realistically nobody uses this.
3. **Clients screen has zero awareness of group membership.** No "Groups" column, no badge, no per-client "Add to group" action. Only entry to add a member is Groups → Detail panel → Add Member dialog.
4. **Two of the four restriction fields are server-side advisory.** [`group_service.py:1-9`](../../apps/server/services/group_service.py#L1) docstring is explicit: `bandwidth_cap_mbps` and `max_rating` are recorded but never enforced. `media_files` doesn't even have a `rating` column.
5. **Mobile shows generic "Stream failed: 403" on a denied stream.** Server returns a meaningful reason in the error body but the mobile player doesn't surface it.

**Cross-cutting symptom:** the Groups screen reads as a fully-built feature (stat tiles, table, detail panel, dialogs), so it's not obvious from a quick walkthrough that the gates don't actually work. The bug is silent.

**Sequenced remediation:** five milestones, ~18 hr end-to-end. M1 (restriction editing) is the headline fix and is independently shippable — that alone flips Groups from "decorative" to "gates streams in production." Detail in [§5](#5--remediation-plan).

---

## 2 · Current Architecture (one-page summary)

### 2.1 Server data model

```sql
groups (id, name, description, status, created_at, updated_at)
group_members (group_id, client_id, added_at)            -- M:N
group_restrictions (group_id, allowed_libraries,
                    bandwidth_cap_mbps, time_window,
                    max_rating)                          -- 1:1
```

A client belongs to **0..N** groups. The effective restriction at stream time is the *intersection* (most restrictive) of every active group the client is in:

- `allowed_libraries` — set intersection across groups
- `time_window` — stream must satisfy *every* group's window (AND)
- `bandwidth_cap_mbps` — minimum across groups
- `max_rating` — most recent non-null (advisory only)

### 2.2 Stream-gate flow

```
  POST /stream/start/{file_id}
        │
        ▼
  stream.py — resolve file_row
        │
        ▼  group_service.get_effective_restrictions(db, client_id)
        │   → walks group_members JOIN group_restrictions
        │   → returns EffectiveRestrictions (frozen dataclass)
        │
        ▼  group_service.reason_to_deny(restrictions, library_id, now)
        │   → checks allowed_libraries set + time_windows AND
        │   → returns None ✅ or "human-readable reason" ❌
        │
        ▼ if reason ≠ None: HTTPException(403, detail=reason)
```

### 2.3 Key files

| Concern | Path |
|---|---|
| Schema | [`apps/server/database/migrations/011_groups.sql`](../../apps/server/database/migrations/011_groups.sql) |
| CRUD service | [`apps/server/services/group_service.py`](../../apps/server/services/group_service.py) |
| REST router (8 endpoints) | [`apps/server/routers/groups.py`](../../apps/server/routers/groups.py) |
| Pydantic models | [`apps/server/models/group.py`](../../apps/server/models/group.py) |
| Stream-gate hook | [`apps/server/routers/stream.py:100-107`](../../apps/server/routers/stream.py#L100) |
| Server tests | [`apps/server/tests/test_groups.py`](../../apps/server/tests/test_groups.py) |
| Desktop screen | [`apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart) |
| Desktop cubit + state | [`apps/desktop/lib/features/groups/presentation/cubit/`](../../apps/desktop/lib/features/groups/presentation/cubit/) |
| Desktop repo | [`apps/desktop/lib/features/groups/data/repositories/groups_repository_impl.dart`](../../apps/desktop/lib/features/groups/data/repositories/groups_repository_impl.dart) |
| Core entity | [`packages/fluxora_core/lib/entities/group.dart`](../../packages/fluxora_core/lib/entities/group.dart) |

### 2.4 Restriction enforcement status

| Field | Storage | Server enforcement | Why |
|---|---|---|---|
| `allowed_libraries` | `group_restrictions.allowed_libraries` JSON list | ✅ Live — `reason_to_deny` checks against `media_files.library_id` | Library id is on every file row; trivial to compare. |
| `time_window` | `group_restrictions.time_window` JSON `{start_h, end_h, days}` | ✅ Live — `_in_window` walks the day list + hour range, supports midnight wrap | Server local time only; no timezone awareness. |
| `bandwidth_cap_mbps` | `group_restrictions.bandwidth_cap_mbps` INTEGER | ❌ Advisory only — recorded, never read by FFmpeg or HLS router | Would require FFmpeg `-maxrate`/`-bufsize` injection per session, or HTTP rate limiting at the HLS route. Multi-day project on its own. |
| `max_rating` | `group_restrictions.max_rating` TEXT | ❌ Advisory only — `reason_to_deny` doesn't check it | `media_files` has no `rating` column. Needs a TMDB-side or operator-tagged source + a comparison ladder (G < PG < PG-13 < R). |

---

## 3 · Defects — Desktop UI gaps that make Groups unusable

These were found by reading the code. Severity is "operator can't ship a working group" → critical.

### 3.1 Create dialog ignores restrictions entirely · 🛑 critical

**Symptom:** Operator clicks Create Group → only fields are Name + Description. Group lands in DB with `restrictions = null`. Stream gate has nothing to deny.

**Code:** [`_CreateGroupDialog`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart#L986) lines 1006-1054. The dialog's `Column` has two `TextField`s and that's it. The cubit's `createGroup` *does* accept a `restrictions: GroupRestrictions?` parameter but the dialog never populates one — `onConfirm` only forwards `name` and `description`.

**Fix:** see [§5.1](#51-m1--restriction-editing-the-headline-fix-).

### 3.2 Edit dialog ignores restrictions + status · 🛑 critical

**Symptom:** Operator edits a group → only Name + Description editable. Can't add restrictions to an existing group. Can't toggle Active ↔ Inactive (and `status` is a real DB field that the gate honors — `WHERE g.status = 'active'`).

**Code:** [`_EditGroupDialog`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart#L1056) lines 1086-1133. Same shape as the create dialog — two `TextField`s and nothing else.

**Fix:** see [§5.1](#51-m1--restriction-editing-the-headline-fix-).

### 3.3 Add Member asks for raw client UUID · 🟠 high

**Symptom:** Operator clicks "Add" on the group detail panel → modal with a single "Client ID" `TextField`. Has to paste a UUID. There's no list of paired clients. No search.

**Code:** [`_showAddMemberDialog`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart#L783) lines 791-798. Prompts for raw `clientId` string.

**Fix:** see [§5.2](#52-m2--real-client-picker-for-add-member-).

### 3.4 Clients screen has no idea groups exist · 🟠 high

**Symptom:** Operator looking at the Clients screen wants to know "is this device gated?" or "add this device to the Kids group". Neither is possible. There's no Groups column on the table, no group chips on the detail panel, no per-client "Add to group" action.

**Code:** [`apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart`](../../apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart) — no references to any Groups types. `auth_service.list_clients` ([`auth_service.py:205-241`](../../apps/server/services/auth_service.py#L205)) returns `last_ip` + `active_session` per client but no `groups` field.

**Fix:** see [§5.3](#53-m3--cross-link-from-clients-screen-).

### 3.5 Filter button on Groups table is disabled · 🟢 low

**Symptom:** "Filter" button at top right of the table renders but `onPressed: null`.

**Code:** [`groups_screen.dart:205-206`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart#L205). Empty TODO since M5 shipped.

**Fix:** see [§5.4](#54-m4--filter-chip-on-groups-table-).

### 3.6 Mobile shows generic 403 on a denied stream · 🟠 high

**Symptom:** Operator's kid hits Play outside the time window. Server returns:

```http
HTTP/1.1 403 Forbidden
{"detail":"Outside the allowed streaming time window"}
```

Mobile player surfaces this as a generic `PlayerFailure("Stream failed")`. The actual reason is discarded.

**Code:** Mobile `PlayerCubit` swallows the API exception's detail field and emits a generic failure state. Compare with the desktop pattern that recently landed for tier-limit handling — [`PlayerTierLimit`](../../apps/mobile/lib/features/player/presentation/cubit/player_state.dart) state class exists for "free tier rejected this start"; we want the same idea for "group gate denied this start".

**Fix:** see [§5.5](#55-m5--mobile-403-ux-polish-).

---

## 4 · Defects — Server / Schema gaps (out of scope for this plan)

These aren't blocking for "make Groups usable" but are honest limitations the doc should record so they're not rediscovered later.

### 4.1 `bandwidth_cap_mbps` is advisory only · 🔵 deferred

**Where:** [`group_service.py:1-9`](../../apps/server/services/group_service.py#L1) docstring is explicit.

**Impact:** Setting this field has no effect. UI should render it as a greyed-out input with a "v1 limitation" tooltip rather than pretending it works.

**Why deferred:** Real enforcement requires either:

- FFmpeg-level injection: `-maxrate {kbps}k -bufsize {2kbps}k` on the encode command line. Per-session, only works for transcoded streams (stream-copy can't be capped this way).
- HTTP-level: rate limiting at the HLS segment route. Works for both transcode + stream-copy. Adds latency unless tuned.

Either is its own multi-day project. v2 territory.

### 4.2 `max_rating` enforcement requires a `media_files.rating` column · 🔵 deferred

**Where:** Same docstring.

**Impact:** Setting this field has no effect.

**Why deferred:** Needs:

1. A `media_files.rating TEXT` column (migration ~025).
2. A source for the rating data — either parse it out of TMDB's response (TMDB returns content ratings per-region for movies + TV) or let the operator tag it manually in the Library screen.
3. A comparison ladder. ESRB / MPAA / TV-PG / international. Picking one is a UX decision.

Multi-week project. v2 territory.

### 4.3 `_in_window` uses naive `datetime.now()` · 🔵 deferred

**Where:** [`group_service.py:380`](../../apps/server/services/group_service.py#L380).

**Impact:** Time windows are evaluated in the server host's local time. Daylight saving changes shift the boundary by an hour twice a year. Remote clients across timezones see windows in the *server's* timezone, not theirs.

**Why deferred:** For a self-hosted-at-home v1 ("Plex without the cloud account"), the operator + the kid + the server are all in the same timezone. Fine for v1. Document as a known limitation in the dialog ("Time windows use the server's local time") and in [`docs/12_guidelines/03_gotchas.md`](../12_guidelines/03_gotchas.md).

### 4.4 Mid-stream gate violations don't kill in-flight sessions · 🔵 deferred

**Where:** No mechanism exists. Stream-gate runs at start, never re-checked.

**Impact:** Operator removes a client from a group at 22:01. An active stream past 22:00 keeps playing until the file ends or the operator manually kills it.

**Why deferred:** Would require either:

- A periodic sweep that walks `stream_sessions WHERE ended_at IS NULL` and re-runs `reason_to_deny` per session, killing matches.
- A push-based hook on group-membership-change that finds matching active sessions immediately.

Both add complexity for an edge case (operator changes the group mid-evening). Defer to v2; document.

---

## 5 · Remediation Plan

### Sequencing

```
M1 — Restriction editing       ✅ shipped 2026-05-07
M2 — Real client picker        ✅ shipped 2026-05-07
M3 — Clients-screen cross-link ✅ shipped 2026-05-07
M4 — Filter chip               ✅ shipped 2026-05-07
M5 — Mobile 403 UX             ✅ shipped 2026-05-07
─────────────────────────────  ──────
All five shipped 2026-05-07.
```

All five milestones shipped same-day after the audit landed.  Groups
went from "decorative" to "fully usable end-to-end" — operator can
configure restrictions, manage membership from either side (Groups
panel OR Clients detail), filter the table, and the mobile player
surfaces a soft "outside playback hours" card instead of a generic
"stream failed" error.

### 5.1 M1 — Restriction editing (the headline fix) ✅ shipped 2026-05-07

**Goal:** Create + Edit dialogs collect every restriction the server understands. Stream gate has something to deny against.

**Shipped (2026-05-07):**

- New shared `_GroupRestrictionsForm` widget owns the restriction state + emits `GroupRestrictions?` to the parent dialog. Both Create and Edit dialogs embed it.
- New `_TimeWindowPicker` — start/end hour `_HourField`s (chevron up/down, 0-23 wrap-aware) + 7-chip day-of-week multi-select. Live preview caption ("Mon-Fri 18:00-22:00" / "All week, 09:00-21:00" / "Weekends, 12:00-22:00") + midnight-wrap warning + timezone note.
- New `_LibraryAllowlistPicker` — multi-select chip row over `state.libraries` (cached on `GroupsCubit.load`). Pre-selects all libraries when toggled on so the gate doesn't immediately deny every stream. Empty libraries list renders an explanatory placeholder.
- `_AdvisoryFieldsSection` — bandwidth + max-rating placeholders, both disabled with tooltips citing §4.1 / §4.2 of this plan. Operator sees the surface exists; we don't pretend it works.
- Edit dialog gains a status `FluxSwitch` ("Active · restrictions enforced" ↔ "Inactive · restrictions not enforced"). Server gate filters `WHERE g.status = 'active'` so flipping inactive disables enforcement immediately for new streams.
- `GroupsCubit` now takes a `LibraryRepository`, fetches libraries best-effort once per cubit lifecycle (failure is non-blocking — empty list, picker shows placeholder), exposes them via `GroupsLoaded.libraries`.
- `_GroupDetailPanel` updated to (a) format the time window via the same `_formatTimeWindow` helper the picker uses (so "Mon-Fri 18:00-22:00" renders identically in the dialog preview and the panel summary) and (b) resolve `allowedLibraries` ids → names via the cached library catalog (chips read "Movies, TV" instead of two opaque UUIDs).
- Server tests: 2 new pytest cases — `test_create_then_get_round_trips_full_restrictions` (every restriction field round-trips byte-for-byte; pins the wire format the desktop sends) and `test_update_group_status_to_inactive` (status PATCH round-trip pins the active↔inactive flip).
- Server suite **573 → 575 passing**. Desktop `flutter analyze` clean.

Code targets that landed:
- `apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart` — `_GroupRestrictionsForm`, `_TimeWindowPicker`, `_LibraryAllowlistPicker`, `_AdvisoryFieldsSection`, `_SectionToggleHeader`, `_HourField`, `_ChevronButton`, plus rewritten `_CreateGroupDialog` / `_EditGroupDialog` and updated `_GroupDetailPanel`.
- `apps/desktop/lib/features/groups/presentation/cubit/groups_state.dart` — `GroupsLoaded.libraries: List<Library>`.
- `apps/desktop/lib/features/groups/presentation/cubit/groups_cubit.dart` — `LibraryRepository` injection, `_safeLoadLibraries()` helper, `Future.wait` parallel load.
- `apps/server/tests/test_groups.py` — +2 cases.

---

**Original M1 plan (preserved for reference):**

#### 5.1.1 Time Window picker (~2 hr)

Most-requested use case (parental control / kid bedtime). The server already supports midnight wrap (`end_h <= start_h`) so the picker just needs to surface that semantics.

- New `_TimeWindowPicker` widget in `groups_screen.dart`:
  - Toggle row "Restrict streaming time" (off → null window; on → expanded picker).
  - Two `_HourSelector` chip rows: start hour 0–23, end hour 0–23. JetBrains-Mono "00"–"23" labels matching the existing `_FpsSelector` style.
  - 7-chip day-of-week selector (Mon, Tue, Wed, Thu, Fri, Sat, Sun) — multi-select. Empty = all days; full = all days. UI defaults to all selected.
  - Helper text: "Streams allowed Mon-Fri 18:00-22:00" (live preview that mirrors the picker state).
- Dialog state: `TimeWindow?` nullable.
- Server `TimeWindow` model already exists ([`models/group.py:8`](../../apps/server/models/group.py#L8)) — `start_h: int`, `end_h: int`, `days: list[int]` (Python weekday: 0=Mon).
- Core entity `TimeWindow` already mirrors server shape.

#### 5.1.2 Library allowlist picker (~2 hr)

The next-most-useful gate.

- Pre-fetch `Library.list()` via the existing `LibraryRepository` on dialog open. Cache for the dialog's lifetime (libraries don't change often).
- New `_LibraryAllowlistPicker` widget:
  - Toggle row "Restrict to specific libraries" (off → null = all libraries; on → multi-select).
  - Multi-select chip row of library names (resolved from `LibraryRepository.list()`); selected ids flow into `restrictions.allowed_libraries`.
  - "All libraries" hint when null.
  - Loading + error states for the libraries fetch.
- Server-side: `allowed_libraries` is already a JSON `list[str]` of library ids; server enforcement is live ([`reason_to_deny:373-378`](../../apps/server/services/group_service.py#L373)).

#### 5.1.3 Status toggle in edit dialog (~30 min)

- Active ↔ Inactive `FluxSwitch` row in `_EditGroupDialog`.
- PATCH body sends `status: 'active' | 'inactive'`.
- Server gate already filters `WHERE g.status = 'active'` so flipping to inactive disables the group's restrictions immediately — no FFmpeg restart needed for the gate.

#### 5.1.4 Bandwidth cap + Max rating fields — disabled with tooltip (~30 min)

Render the surfaces, but mark them advisory.

- `_RestrictionField` for `bandwidth_cap_mbps`: disabled `TextField` with `Tooltip("Recorded but not yet enforced; see roadmap §4.1")`.
- `_RestrictionField` for `max_rating`: disabled `Dropdown` with placeholder values (G / PG / PG-13 / R / NC-17) + same tooltip pointing at §4.2.
- Operator sees the surface exists; we don't pretend they work.

#### 5.1.5 Restriction summary in detail panel (~30 min)

[`_GroupDetailPanel`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart#L520) lines 643-688 already partly renders restrictions. Tighten:

- Time window: render day list ("Mon-Fri 18:00-22:00") instead of just "18:00-22:00". Use the same picker's preview formatter for consistency.
- Allowed libraries: resolve library ids → names via the `LibraryRepository` cache so the chips read "Movies, TV" instead of two opaque UUIDs.
- Bandwidth + Max rating: prefix with "Advisory:" so the operator knows these are recorded but not enforced.

#### 5.1.6 Tests

- Cubit-level: `createGroup` / `updateGroup` with full restriction payloads round-trip through the existing repo.
- Widget smoke: `_TimeWindowPicker` toggle off → on → off again returns null; day toggles preserve order.
- Widget smoke: `_LibraryAllowlistPicker` resolves library names from a mock `LibraryRepository`.
- Server: extend `tests/test_groups.py` with one round-trip test that POSTs a full-restrictions group and asserts every field via `GET /{id}`.

#### 5.1.7 Code targets

| Path | Change |
|---|---|
| [`groups_screen.dart`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart) | Rewrite `_CreateGroupDialog` + `_EditGroupDialog` to embed the four pickers; tighten `_GroupDetailPanel` restriction summary. |
| [`groups_cubit.dart`](../../apps/desktop/lib/features/groups/presentation/cubit/groups_cubit.dart) | No signature change — `createGroup` / `updateGroup` already accept `restrictions: GroupRestrictions?`. The dialog finally populates it. |
| [`tests/test_groups.py`](../../apps/server/tests/test_groups.py) | One full-restrictions round-trip case. |
| New widget tests | `groups_screen_test.dart` covering the four pickers. |

---

### 5.2 M2 — Real client picker for Add Member ✅ shipped 2026-05-07

**Shipped:**

- New `_AddMemberDialog` widget in `groups_screen.dart` — fetches the operator's paired clients via `getIt<ClientsRepository>().getClients()` on dialog open, filters to `status == approved && isTrusted`, excludes any client already in the group (passed in via `existingMemberIds: Set<String>`), and renders a search box + scrollable list with platform icon + name + "last seen Nh ago" caption.  Same `MouseRegion` + hover-tinted-row + 14×14 selection box pattern as the F9 Profile Sessions tab.
- Multi-select via tap toggle; Confirm fires a single `cubit.addMembers(groupId, ids)` call.
- New `GroupsCubit.addMembers(groupId, List<clientIds>)` — sequential walk; per-call failures swallowed with a warn-level log so one bad insert doesn't abort the rest of the batch.  Final `loadMembers(groupId)` once at the end so the panel re-renders with the new chips.  Mirrors the F9 Sessions sequential-revoke pattern.
- Two distinct empty states: search-narrowed-to-zero ("No clients match…") vs nothing-to-pick-from ("Every paired device is already in this group." or "No paired devices.  Pair one from the Clients screen first.").
- Loading + error states with retry button.
- Old raw-UUID `TextField` is gone; nobody pastes UUIDs by hand anymore.

Code targets that landed:
- `apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart` — `_AddMemberDialog`, `_ClientPickRow`, plus the `_showAddMemberDialog` rewrite that replaced the old 18-line `TextField` modal.
- `apps/desktop/lib/features/groups/presentation/cubit/groups_cubit.dart` — new `addMembers` bulk method.

---

**Original M2 plan (preserved for reference):**

**Goal:** Stop asking for UUIDs. Surface the operator's actual paired clients.

- Replace [`_showAddMemberDialog`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart#L783) with a new `_AddMemberDialog` widget.
- Fetch `GET /api/v1/auth/clients` (already returns the full list with names + platforms + status) on dialog open via the existing `ClientsRepository` (singleton in DI). Filter to `is_trusted && status == approved` so pending / rejected rows don't pollute the picker.
- Filter out clients already in the group (cubit needs to expose `state.members[group.id]` to the dialog — already there via `state.members`).
- Render a search box + scrollable list of clients with platform icon + name + "Last seen Nh ago" caption. Same pattern as the F9 Profile Sessions tab landed 2026-05-07.
- Multi-select: tick multiple clients; single Confirm fires N parallel `addMember(groupId, clientId)` calls (cubit already supports it). Loop sequentially per the F9 sequential-revoke pattern to keep `processingIds` predictable.
- Cubit: extend `addMember` semantics is fine; alternatively add a server-side bulk endpoint `POST /groups/{id}/members:bulk` but skip until field reports demand it.

**Tests:** widget test for search + multi-select + filtered-out membership.

**Code targets:**

| Path | Change |
|---|---|
| [`groups_screen.dart`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart) | Replace `_showAddMemberDialog` body with `_AddMemberDialog` (new). |
| [`groups_cubit.dart`](../../apps/desktop/lib/features/groups/presentation/cubit/groups_cubit.dart) | New `addMembers(groupId, List<clientId>)` that sequentially calls `addMember`. |

---

### 5.3 M3 — Cross-link from Clients screen ✅ shipped 2026-05-07

**Shipped:**

- **Server**: `auth_service.list_clients` extended with a SQL LEFT-JOIN aggregating group memberships per client via SQLite's `json_group_array`.  New `groups_json` output column carries a JSON array of `{id, name, status}` objects, NULL when the client is in no groups.  Single query, no N+1.
- New `GroupSummary` Pydantic model in `models/client.py` (id, name, status — three fields, intentionally lighter than the full `GroupResponse`).  `ClientListItem.groups: list[GroupSummary] = []` — defaulted so any pre-M3 caller deserialising the response shape doesn't break.
- `routers/auth.list_clients` parses `groups_json` defensively (malformed JSON → empty list with a warn log; never 500s the entire list call).
- **Core**: new `GroupSummary` freezed entity in `entities/group.dart` mirroring the server shape.  `ClientListItem.groups: List<GroupSummary> = const []`.  Hand-rolled JSON parser updated to walk the new field.
- **Desktop**: new `_ClientGroupsSection` rendered in the Clients-screen detail panel (only for `approved + isTrusted` clients — pending pair requests can't legally be in a group).  Header row: "Groups" + a violet `+` button.  Empty state: "Not in any group.  Click + to add this device to one."  Populated state: `Wrap` of `_ClientGroupChip`s, each with a status dot + group name + hover-revealed × that opens a confirmation dialog before calling `GroupsRepository.removeMember`.
- New `_PickGroupDialog` — modal that fetches all groups via `GetIt<GroupsRepository>()`, filters to active only (inactive groups appear after the operator re-activates them on the Groups screen), excludes groups the client is already in, search + scroll list.  Returns a `GroupSummary` to the caller; the calling site fires `addMember` then `cubit.refreshSilent()` (with `cubit.load()` fallback if `refreshSilent` isn't available — the panel updates silently without flickering through the loading state).
- **Tests**: 2 new server cases — `test_list_clients_includes_group_memberships` (pins the wire format the desktop M3 cross-link consumes) and `test_list_clients_groups_empty_for_unaffiliated_client` (NULL `json_group_array` → `[]`, not `null`/missing, so the desktop reads it without a null check).

Code targets that landed:
- `apps/server/services/auth_service.py` — extended `list_clients` SQL with the `json_group_array` aggregation.
- `apps/server/models/client.py` — new `GroupSummary` + `ClientListItem.groups` field.
- `apps/server/routers/auth.py` — JSON parsing + `GroupSummary` construction per row.
- `packages/fluxora_core/lib/entities/group.dart` — new `GroupSummary` freezed entity.
- `packages/fluxora_core/lib/entities/client_list_item.dart` — `groups: List<GroupSummary>` field + JSON parser update.
- `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart` — `_ClientGroupsSection`, `_ClientGroupChip`, `_PickGroupDialog`, `_PickGroupRow`, plus the section integration in `_PopulatedDetailPanel`.
- `apps/server/tests/test_auth.py` — +2 cases.

---

**Original M3 plan (preserved for reference):**

**Goal:** Operators looking at a client should see what groups it's in + be able to add/remove without leaving the screen.

#### 5.3.1 Server side

- Extend [`auth_service.list_clients`](../../apps/server/services/auth_service.py#L205) to LEFT-JOIN `group_members` + `groups` and return `groups: list[GroupSummary]` per client (`{id, name, status}`). Same row-aggregation pattern as the existing `active_session` join (window function or `json_group_array`).
- Update `ClientListItem` Pydantic model + Dart freezed entity.

OR, lower-impact alternative:

- New endpoint `GET /api/v1/auth/clients/{client_id}/groups` returning the same shape on demand. Slower (extra round-trip per client detail panel open) but doesn't bloat the list response.

Recommendation: extend `list_clients` since the join is cheap and the data size is tiny (most clients in 0-2 groups).

#### 5.3.2 Desktop side

- Clients screen detail panel gains a **"Groups" section** below the existing info rows:
  - Chip per group with name + status dot. Same `FluxChip` pattern used elsewhere.
  - "+" button → opens `_PickGroupDialog` (mirrors M2's picker pattern but inverted — pick a group from the list of all groups; filter out groups the client is already in).
  - X on a chip → confirm dialog → `DELETE /groups/{id}/members/{client_id}` via existing repo.
- Update `clients_cubit` to refresh after add/remove.

**Tests:** server test for the extended `list_clients` shape; desktop widget test for the chip + dialog.

**Code targets:**

| Path | Change |
|---|---|
| [`auth_service.py`](../../apps/server/services/auth_service.py) | Extend `list_clients` query with the groups join. |
| [`models/auth.py`](../../apps/server/models/auth.py) | Add `groups: list[GroupSummary]` to `ClientListItem`. |
| [`packages/fluxora_core/lib/entities/client_list_item.dart`](../../packages/fluxora_core/lib/entities/client_list_item.dart) | Add `groups: List<GroupSummary>` (new freezed type or reuse existing `Group` summary). |
| [`clients_screen.dart`](../../apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart) | New "Groups" section in detail panel. |
| `tests/test_auth.py` | Round-trip test for `list_clients` returning groups. |

---

### 5.4 M4 — Filter chip on Groups table ✅ shipped 2026-05-07

**Shipped:**

- `_GroupsLoaded` widget converted from `StatelessWidget` to `StatefulWidget` (now `_GroupsLoadedState`) so it can hold filter state locally.  Filter is purely client-side — group lists are small enough (handful per household) that round-tripping through the cubit would be over-engineered.
- New `_GroupsSearchField` widget — compact dark-pill input with a search icon prefix.  Mirrors the Clients screen's `_SearchField` look so the two screens feel identical at the chrome level.  Matches both group `name` AND `description` so an operator who labelled the group via its description still finds it.
- New `_GroupsStatusFilter` widget — `PopupMenuButton` with All / Active / Inactive options, mirroring the Clients screen's `_FilterDropdown`.
- Three empty states for the table: (a) zero groups → onboarding "Create one to get started", (b) filter active and zero matches → "No groups match your filters" + a "Clear filters" ghost button, (c) populated → render filtered list.  Stat tiles still read the unfiltered list so "Total Groups" doesn't lie when a filter is active.
- The disabled "Filter" button (`onPressed: null`) is gone.

Code targets that landed:
- `apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart` — `_GroupsLoaded` → `_GroupsLoadedState` conversion, `_filteredGroups` getter, `_GroupsSearchField`, `_GroupsStatusFilter`, table-row + empty-state wiring.

---

**Original M4 plan (preserved for reference):**

**Goal:** Wire the disabled Filter button.

- Status filter: `FluxTabBar` or chip row (All / Active / Inactive) above the table.
- Name search box (live filter, no API hit — 50-row cap means client-side is fine).
- Mirror the Clients screen filter pattern.
- State lives in `_GroupsLoaded` (extend with `searchQuery: String` + `statusFilter: GroupStatus?`); cubit has a `setFilter` method already in the pattern.

**Code targets:**

| Path | Change |
|---|---|
| [`groups_screen.dart`](../../apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart) | Wire the Filter button + add a search field; filter `state.groups` client-side. |
| [`groups_state.dart`](../../apps/desktop/lib/features/groups/presentation/cubit/groups_state.dart) | Add `searchQuery` + `statusFilter` to `GroupsLoaded`. |
| [`groups_cubit.dart`](../../apps/desktop/lib/features/groups/presentation/cubit/groups_cubit.dart) | Add `setSearchQuery(String)` + `setStatusFilter(GroupStatus?)`. |

---

### 5.5 M5 — Mobile 403 UX polish ✅ shipped 2026-05-07

**Shipped:**

- New `PlayerGated(reason: String)` state class in `player_state.dart`, modelled on the existing `PlayerTierLimit` precedent ("not an error, but you can't play this").
- `PlayerCubit.startStream` 403 routing reworked:
  - `e.isTierLimit` (429) → `PlayerTierLimit` (existing).
  - `e.isForbidden` AND message matches `_isGroupGateMessage` → new `PlayerGated(e.message)`.  Substring match against `'group(s)'` and `'time window'` — distinctive markers that won't false-positive on unrelated 403s (e.g. an admin endpoint reached from off-loopback).
  - Anything else → `PlayerFailure` (existing).
- New `_GatedView` widget in `player_screen.dart`, modelled on `_TierLimitView` but with parental-control framing instead of an upgrade prompt.  Violet lock icon (vs the upgrade-prompt's gradient + premium icon).  Title heuristic: "Outside playback hours" / "Not in your library access" / "Not available right now" depending on which gate-string keyword the reason carries — friendlier than echoing the raw server detail as the headline.  Reason text rendered verbatim below as the body.  Single "Got it" button → `Navigator.pop`.
- `PlayerCubit._handleStreamStartError` (the build-time `switch` over states in `player_screen.dart`) gains the `PlayerGated(:final reason) => _GatedView(reason: reason)` case.
- **Tests** in `player_cubit_test.dart`: 3 new bloc-test cases — `startStream emits PlayerGated on 403 with library-deny message`, `… on 403 with time-window-deny message`, `… falls through to PlayerFailure on unrelated 403`.  The third case is the important one: pins the conservative match so a future agent broadening the matcher doesn't accidentally classify every 403 as a gate.

Code targets that landed:
- `apps/mobile/lib/features/player/presentation/cubit/player_state.dart` — `PlayerGated`.
- `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` — 403 routing + `_isGroupGateMessage` helper.
- `apps/mobile/lib/features/player/presentation/screens/player_screen.dart` — `_GatedView` + `switch` case.
- `apps/mobile/test/features/player/player_cubit_test.dart` — +3 cases.

---

**Original M5 plan (preserved for reference):**

**Goal:** Kid sees a clear "outside allowed time window" card instead of "Stream failed: 403".

- Mobile `PlayerCubit._handleStreamStartError` (or equivalent) parses the 403 `detail` field. When it matches one of the group-gate strings emitted by `reason_to_deny`:
  - `"Library not allowed for this client's group(s)"`
  - `"Outside the allowed streaming time window"`
  - …surface a dedicated `PlayerGated` state with a friendly card instead of `PlayerFailure`.
- Pattern mirrors the existing `PlayerTierLimit` state class (free-tier-rejected) so all the routing + view-switching code already exists.
- New `_GatedView` widget: lock icon (violet), gate-reason copy as the explanatory text, "Got it" close button that returns to the previous screen.
- Server already supplies the reason verbatim — just stop blowing it away on the client.

**Tests:** cubit-level test for the parser + state classification.

**Code targets:**

| Path | Change |
|---|---|
| [`apps/mobile/lib/features/player/presentation/cubit/player_state.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_state.dart) | New `PlayerGated(reason: String)` state class. |
| [`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart) | `_handleStreamStartError`: parse 403 detail, classify gate strings, emit `PlayerGated`. |
| [`apps/mobile/lib/features/player/presentation/screens/player_screen.dart`](../../apps/mobile/lib/features/player/presentation/screens/player_screen.dart) | New `_GatedView` rendered when state is `PlayerGated`. |
| `apps/mobile/test/features/player/player_cubit_test.dart` | Cubit test for the 403 parser + state emission. |

---

## 6 · Test Strategy

### Unit / cubit
Each milestone lands with focused tests against the cubit / service layer (no real network). Mock `GroupsRepository` / `ClientsRepository` / `LibraryRepository` for desktop tests.

### Server integration
Extend [`tests/test_groups.py`](../../apps/server/tests/test_groups.py):
- Full-restrictions round-trip (M1).
- `auth_service.list_clients` returns groups (M3).

Extend [`tests/test_stream.py`](../../apps/server/tests/test_stream.py) for the actual gate trigger:
- Stream-start denied with library not in allowlist → 403 with the specific reason.
- Stream-start denied outside time window → 403 with the specific reason.
- Stream-start allowed when group is `inactive` (gate skips inactive groups).

### Manual smoke (operator-facing)
After M1 lands, the operator should be able to:
1. Create a "Kids" group with restrictions: allowed_libraries = ["Movies"], time_window = `{18:00-22:00, Mon-Sun}`.
2. Add their kid's tablet client to the group.
3. From the tablet, attempt to play a TV show (different library) → see a clear "library not allowed" message.
4. From the tablet, attempt to play a movie at 23:00 → see a clear "outside time window" message.
5. From the tablet, attempt to play a movie at 19:00 → succeeds.

After M3 the operator should be able to do all the above without ever leaving the Clients screen.

---

## 7 · Risks & Open Questions

| Risk | Mitigation |
|---|---|
| **Library list unstable across operator's devices.** Operator has 12 libraries, picks 3 for the gate, then renames "Movies" to "Films". Library id is stable so the gate keeps working — the picker just needs to refetch on dialog open. | Make the picker re-resolve names on every dialog open; never persist names client-side. |
| **Time window confusion across timezones.** "9 PM" on a remote-streaming kid means server-time 9 PM, not their local 9 PM. | Document in the picker's helper text + a global gotcha. v2 fix would persist windows in UTC + per-client TZ. |
| **Group membership change mid-stream.** Active sessions don't get re-checked; documented in §4.4. | Operator-visible message in the detail panel: "Membership changes apply to new streams only." |
| **Mobile gate UX may feel like a permissions error vs a parental block.** The "Got it" copy needs to read like a soft restriction, not a security wall. | UX copy passes through the operator persona — phrasing should be "Movies aren't available right now" not "ACCESS DENIED". |
| **`max_rating` UI shows but doesn't enforce.** Operator may set it expecting it to work. | Tooltip on every greyed-out advisory field: "Recorded but not enforced in v1; see roadmap." Plus mention in §4 of this doc. |

**Open question — should the operator be allowed to assign themselves to a group?** Today nothing prevents it. The desktop CP is localhost-only and never pairs as a client (per the F9 design call), so in practice the operator's own desktop isn't in any group anyway. Mobile clients paired by the operator are the only entries. Document, don't enforce.

---

## 8 · Out of Scope (this plan)

- **Real `bandwidth_cap_mbps` enforcement** (§4.1) — multi-day project, defer to v2.
- **`max_rating` enforcement** (§4.2) — needs schema + data source + ladder; defer.
- **Timezone-aware time windows** (§4.3) — defer.
- **Mid-stream gate violation kills active sessions** (§4.4) — defer.
- **Per-group bandwidth metering / quota** — separate concept; not in scope.
- **Group templates / presets** ("create from Kids template") — nice-to-have; defer.
- **Audit log of who-changed-what on group restrictions** — `activity_events` could carry it but UX implications haven't been thought through. Defer.

---

## 9 · Cross-references

- Roadmap milestones: [`01_roadmap.md`](./01_roadmap.md) — Phase 5 §5 row "Client Groups (M0 §7.1)" is marked ✅ Done because the backend shipped; this plan is the UI completion work.
- Ship-readiness: [`05_ship_readiness.md`](./05_ship_readiness.md) — Groups isn't currently listed as a blocker. After this audit, add a row under "Polish gaps (look weak but won't block ship)" pointing here.
- ADRs: none of the decisions here rise to ADR level (they're all UI-completion within the existing architecture). When M1 ships, capture the design choice "intersect-most-restrictive across groups" if it's not already implicit.
- Manual tasks: none — this is all code work, no external service config.
- Desktop redesign plan: [`docs/11_design/desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md) M5 is marked ✅ Done because the screen layout shipped. The §11.1 follow-ups menu (F1-F10) doesn't currently track Groups completion; consider adding an F11 row for M1 if we want the closed-cosmetic-loop view of §11.1 to include this work.
