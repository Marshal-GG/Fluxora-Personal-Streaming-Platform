# Groups — Dedicated Management Page

> **Category:** Planning
> **Status:** ✅ Complete — M1-M5 all shipped 2026-05-07.  Server suite 617 → 629 passing (+12 across M3 +5 and M5 +7).  Modal retired; dedicated page is the operator-facing surface for all group create / edit / member-management flows.
> **Scope:** Replaces the existing `_CreateGroupDialog` + `_EditGroupDialog` modal pair with a dedicated full-page experience for creating, editing, and managing client groups.  Consolidates v1 restriction editing, v2 (M4) shared-PIN management, M8 per-client PIN management, M7 operator-quality-of-life surfaces (icons + colors, view-as debug, group activity feed, per-group concurrent stream cap), and M8 per-member PIN clear actions into one navigable surface with tabs.
> **Triggered by:** owner review 2026-05-07 — the Edit dialog is already crowded with M4 + M8 + restrictions + advisory fields, and the M7 Tier-2 work (icons / colors / view-as / activity / per-member PIN management) has nowhere to land in a modal.  A modal also can't host a member list with per-row actions, which is the core of M8 operator UX.

---

## 1 · Executive Summary

Today's flow opens a `FluxGlassDialog` modal for both create and edit.  The dialog has accumulated 8+ stateful sections (name, description, status toggle, PIN model picker, PIN field + mode picker, library allowlist, time window, advisory fields).  Adding the M7 + M8 surfaces would push the dialog past 1000 px tall, force inner scrolling, and still leave member-PIN management without a coherent home.

**Decision:** lift to a dedicated page at `/groups/new` (create) and `/groups/:id/edit` (edit).  Familiar pattern in this codebase — Encoder Settings (`/transcoding/encoder`), Library deep-link (`/library/:id/files`), Settings six-tab side-rail.  Use a `FluxTabBar` with 6 tabs to organize the surface area.  The Groups list page (`/groups`) stays; row tap navigates to the new edit page instead of opening the modal.

**Headline gains:**
- **Member list as a real surface** — per-row enrollment state badge + Clear PIN button (M8) + per-member time-window override (v2 plan §6.3 / M5) + activity row.  Currently has no home.
- **View-as debug mode** — full-width preview of what a target member sees right now.  Cannot fit in a modal.
- **Group activity feed** — recent unlock / lock / member-add / member-remove events scoped to this group.  Operator audit need; M7 Tier-2.
- **Less crowded primary form** — Identity/Access/PIN split across tabs instead of one ~1200-px-tall column.
- **Reuses existing components** — `_PinSection`, `_GroupRestrictionsForm`, `_AddMemberDialog`, `_TimeWindowPicker`, `_LibraryAllowlistPicker` all carry over with light adapters.

**Sequencing:** five milestones, ~1.5 days end-to-end.  M1 + M2 cover the page shell + Identity tab + back-compat with the existing list-page navigation; M3 lands Members tab (the M8 home); M4 lands PIN tab consolidation + Activity tab stub; M5 lands View-As + Danger Zone polish.  Detail in [§7](#7--milestones).

**What's NOT changing:**
- Server endpoints — the page consumes the same v2 + M8 routes already shipped.  One new endpoint for view-as (`GET /api/v1/auth/clients/{id}/visible-libraries`, localhost-only) is M7 Tier-2 work that lands here naturally; can be deferred to its own milestone.
- Group entity / cubit shape — the GroupsCubit already exposes `selectedGroup`, `members`, `libraries` and we lean on it.  New cubit ops only for member-PIN-clear (already shipped in `clearMemberPin` repo method).

---

## 2 · Why This Redesign

| Pain point (current modal) | v2 / M7 / M8 surface that doesn't fit | Page fix |
|---|---|---|
| Member list nowhere to live | M8 per-client PIN enrollment state + Clear-PIN button per row | Members tab gets a dedicated table |
| No home for view-as debug | M7 Tier-2: operator wants to render kid's library list as kid sees it | View As tab — full-width preview panel |
| No home for group activity feed | M7 Tier-2: per-group filter on the existing activity log | Activity tab — paginated event list scoped to this group |
| Per-member time-window override | v2 plan §6.3: "older kid stays up later in same Kids group" | Members tab row exposes an override editor |
| Icon + color picker has no surface | M7 Tier-2: visual identity for groups | Identity tab — 12-icon grid + 6-color picker |
| Modal scroll trap on small displays | already 850+ px; M7+M8 would push past 1200 | Tabs scroll independently; no master scroll |
| Cancel discards everything | one-shot save; partial saves impossible | Per-tab dirty state + global Save / Discard footer |
| Public group special-casing leaks across sections | "name locked" + "is_public locked" + "delete forbidden" rules buried in dialog logic | Page can hide / lock entire tabs for Public coherently |

The modal isn't a sustainable surface for a feature that already has 4 milestones of UI work pending.

---

## 3 · Route Layout

```
/groups                       → list page (existing GroupsScreen — kept as-is)
/groups/new                   → GroupEditPage (create mode)
/groups/:id/edit              → GroupEditPage (edit mode)
```

`go_router` registration alongside the existing routes.  Both new routes mount inside the existing app shell (sidebar + status bar visible).  Back navigation:
- Browser / titlebar back → `/groups`.
- Cancel button → confirm-discard if dirty, else `/groups`.
- Save → stays on the page in edit mode; navigates to `/groups/:newId/edit` after creation.

The list page's existing "Edit" action + row tap navigate to the edit route instead of opening the modal.  The "+ Create Group" header button navigates to `/groups/new`.

---

## 4 · Page Layout

### 4.1 Header

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ←  Public        [Active] [Public]                       Discard   Save    │
└────────────────────────────────────────────────────────────────────────────┘
```

- **Back chevron** (existing `PageHeader.onBack` slot).
- **Group name** as the title.  In create mode: "New group".
- **Status pill** (`Active` violet, `Inactive` muted).
- **Public pill** when `is_public = 1` — visual cue that some affordances will be locked.
- **Discard / Save** in the action slot.  Save disabled when nothing dirty.  Discard prompts a `FluxGlassDialog` confirm.

### 4.2 Tab bar

`FluxTabBar` with 6 tabs.  Tab badges surface dirty state ("●") and counts where useful.

| Tab | Always present? | Notes |
|---|---|---|
| Overview | yes | Identity (name + description + icon + color) + status toggle.  Renamed in create mode to "Identity"; danger zone hidden. |
| Members | edit-only (hidden in create until first save) | M8 lives here. |
| Access | yes | Library allowlist + time window. |
| PIN | yes (always visible; copy adapts to model) | Shared / per-client picker, plus per-client member enrollment summary. |
| Activity | edit-only | Group-scoped event feed.  Hidden in create. |
| View As | edit-only | Visible only when group has members.  Hidden in create. |

Tab order is the operator's typical flow: edit identity → manage members → tune access → set PIN → audit activity → preview member view.

### 4.3 Footer

Sticky footer with global Save / Discard mirrors the header.  Some operators save from the bottom after scrolling a long tab; saves them from scrolling back up.

---

## 5 · Tabs in Detail

### 5.1 Overview / Identity tab

Reuses the existing `TextField`s for name + description.  Adds:

- **Icon picker** (M7 Tier-2 land here): 12-icon grid (`home`, `kids`, `lock`, `family`, `music`, `video`, `tv`, `gamepad`, `headphones`, `download`, `globe`, `coffee`).  Persists to `groups.icon`.  Used as the chip prefix on the list page + the avatar on the Members tab.
- **Color picker** (M7 Tier-2): 6 hex chips (violet `#A855F7`, cyan `#06B6D4`, amber `#F59E0B`, emerald `#10B981`, pink `#EC4899`, slate `#64748B`).  Persists to `groups.color`.
- **Status toggle** (existing `_SectionToggleHeader`): Active ↔ Inactive.

**Public group lockdown:** name field disabled with helper text ("Public group's name is fixed; you can change its description, icon, and color"); status toggle disabled with helper text ("The Public group cannot be deactivated").  Same pattern as the Library type-immutable lock (ADR-016).

**Danger Zone** at the bottom (collapsible card; hidden in create mode + on Public):
- **Delete group** — confirm dialog with cascade copy ("This removes the group and unassigns all `N` members.  Files are not affected.").
- **Reset all PINs** (when `requires_pin = true`) — clears `group_pin_grants` for the group; in per-client mode also clears `group_member_pins`.  Forces every member to re-enter / re-enroll on next access.

### 5.2 Members tab

The M8 home + the existing `_AddMemberDialog` flow polished.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Members (4)                                          + Add member   │
├──────────────────────────────────────────────────────────────────────┤
│  📱  Pixel 8 Pro             [Enrolled]    last seen 2 min ago   ⋯  │
│  📱  iPad Mini               [Locked out]  last seen 3 days      ⋯  │
│  💻  Marshal's MBP           [Not enrolled]                       ⋯  │
│  📱  Galaxy Tab              [Enrolled]    last seen now          ⋯  │
└──────────────────────────────────────────────────────────────────────┘
```

Per-row affordances (3-dot menu opens `FluxGlassMenu`):
- **Remove from group** (existing `removeMember` cubit op).
- **Clear PIN enrollment** — only when group is in per-client mode; calls `clearMemberPin` repo method (already shipped).  Confirm dialog: "Pixel 8 Pro will be asked to set up a new PIN on next access to this group."
- **Set time-window override** — opens an inline `_TimeWindowPicker` for this member only.  Persists to `group_members.time_window_override` (already in schema; needs a `PATCH /groups/{id}/members/{cid}` endpoint, currently missing — see §6 Server Deltas).
- **View as this member** — switches to View As tab pre-filled with this client.

Enrollment state badges (per-client mode only):
- `Enrolled` — green; client has a `group_member_pins` row.
- `Not enrolled` — amber; per-client mode but no enrollment yet (next access prompts enrollment).
- `Locked out` — red; ≥5 failed attempts in last 60 s.  Hover: "Auto-clears at HH:MM" or "Use master override" link.
- `Active grant` — violet supplementary chip; client has a non-expired `group_pin_grants` row.  Includes "Expires HH:MM" caption.

Empty state ("No members yet — add a paired device to get started") + loading skeleton + failure (existing `GroupsFailure` state piped through).

**Public group lockdown:** Add Member button + Remove action both disabled with helper text ("All paired clients are members of Public automatically").

### 5.3 Access tab

Reuses `_GroupRestrictionsForm` + `_TimeWindowPicker` + `_LibraryAllowlistPicker` widgets verbatim.  Adds:

- **Per-group concurrent stream cap** (M7 Tier-2): single integer input + tooltip "When `N` members are streaming from this group at once, the next stream-start returns 503".  Persists to `groups.max_concurrent_streams`.  Already in schema; just needs UI + cubit field.

The advisory section (Bandwidth cap + Max rating) keeps its existing "recorded but not yet enforced" disclaimer.

### 5.4 PIN tab

Reuses the existing `_PinSection` widget verbatim with one extension — when in per-client mode, append a small **Enrollment summary** card below:

```
┌────────────────────────────────────────────────────────┐
│  Enrollment status                                      │
│  3 of 4 members enrolled · 1 not yet · 0 locked out    │
│  Last enrollment: Pixel 8 Pro · 4h ago                  │
└────────────────────────────────────────────────────────┘
```

Computed client-side from the Members tab data; refreshes on the same poll cadence.  No new endpoint.

**Public group lockdown:** entire tab disabled with helper text ("Public group cannot be PIN-gated — by design every paired client is a member").  Saves the operator from creating an unrecoverable lockout for themselves.

### 5.5 Activity tab

Group-scoped slice of the existing activity feed.  Filters server-side via the existing `GET /api/v1/activity?type=group.*&target_id=<group_id>` query (already supported).

Event types shown:
- `group.member.add` / `group.member.remove`
- `group.pin.unlock` / `group.pin.lock`
- `group.pin.failed-attempt` (rate-limited; aggregates >5 fails into a single "Pixel 8 Pro: 5 failed attempts" row)
- `group.pin.master-override` (operator audit)
- `group.config.update` (PIN reset / mode flip / library list change)

Uses the existing `ActivityCubit` pattern.  Pagination via cursor.  Loading / empty / failure all reuse existing widgets.

**Note:** the producer side (writing these `activity_events` rows) is partially shipped — `auth_service.approve_client` writes `client.pair`, but `group_service` doesn't currently emit any events.  M4 of THIS plan stubs the events; tightening producers is a follow-up not blocking the page.

### 5.6 View As tab

The most-requested debug for any access-control system.  Renders the target client's library list as the client would see it right now.

```
┌────────────────────────────────────────────────────────────────────┐
│  View library access as:  [ Pixel 8 Pro    ▾ ]                      │
├────────────────────────────────────────────────────────────────────┤
│  Visible libraries (3)                                              │
│  📚 Movies          ← granted by Public                             │
│  📚 Cartoons        ← granted by Kids (Mon-Fri 18:00-22:00)         │
│  📚 Songs           ← granted by Public                             │
│                                                                     │
│  Locked groups (1)                                                  │
│  🔒 Adults          requires PIN unlock (per-client; not enrolled)  │
│                                                                     │
│  Time-locked groups (0)                                             │
│  — none right now                                                   │
└────────────────────────────────────────────────────────────────────┘
```

Calls a new localhost-only endpoint `GET /api/v1/auth/clients/{client_id}/visible-libraries` that returns the `VisibleLibraries` dataclass (already exists server-side).  Fully derived from existing service code; just needs the route exposed.

Per-row provenance (`groups_contributing` field) is already on the wire from the visibility resolver.  Time-window pretty-printer reuses `_formatTimeWindow` from the existing dialog.

---

## 6 · Server-Side Deltas

Mostly UI work; three small additions:

| Need | Endpoint | Status | Plan |
|---|---|---|---|
| Per-member time-window override | `PATCH /api/v1/groups/{id}/members/{cid}` body `{time_window_override: TimeWindow \| null}` | 🔲 missing | New route + service helper.  Schema column already in migration 025. ~40 lines server. |
| View-as | `GET /api/v1/auth/clients/{cid}/visible-libraries` (localhost only) | 🔲 missing | Wraps `group_service.get_visible_libraries(client_id)`.  Returns the `VisibleLibraries` shape as JSON.  ~25 lines. |
| Group-scoped activity events | `group_service` write-path emits `activity_event(category='auth', target_kind='group', target_id=<group_id>, ...)` on member ops + PIN ops | 🔵 partial | The `activity_events` table + the listing endpoint exist.  Producers don't emit group events yet.  Add 6 emit-call sites (`add_member`, `remove_member`, `enter_pin_grant` success/failure, master_override, `clear_member_pin`, `update_group` when PIN changes). |

Master-override path already writes a `group_pin_attempts` row with `success=1`; that's an audit trail but separate from the user-facing activity events.

No migration needed — all schema is already in 025 + 026.

---

## 7 · Milestones

```
M1 — Page shell + routing                  ~3 h    foundational
M2 — Overview tab + create/edit save flow  ~2 h    creates feature parity with the modal's name + description + status save
M3 — Members tab (M8 home)                 ~3 h    the most-requested missing UX
M4 — PIN + Access tabs (consolidate)       ~2 h    moves _PinSection + _GroupRestrictionsForm into the new layout
M5 — Activity + View As + Danger Zone      ~3 h    M7 Tier-2 surfaces; needs the 3 server endpoints from §6
─────────────────────────────────────────  ─────
Total                                       ~13 h end-to-end (~1.5 days)
```

Each milestone leaves the app in a shippable state.  M1+M2 alone deliver feature parity with the modal.  M3 unblocks the M8 per-client PIN management story.  M4 retires the modal entirely.  M5 lands the operator quality-of-life surfaces.

### M1 — Page shell + routing ✅ 2026-05-07

**Goal:** new route `/groups/:id/edit` renders an empty PageHeader + FluxTabBar + 6-tab placeholder.  Cancel returns to `/groups`.  No save logic yet; existing modal still in use.

**Work:**
- New file `apps/desktop/lib/features/groups/presentation/screens/group_edit_screen.dart`.
- Add routes to the existing `app_router.dart` (alongside `/groups`).
- `PageHeader` with back chevron + group name + status pill + Public pill + Save (disabled) + Discard.
- `FluxTabBar` with 6 tab labels; each tab renders `_TabScaffold` placeholder.
- Reuses `GroupsCubit`; loads target group on mount via `selectGroup(id)`.

**Acceptance:**
- `flutter analyze` clean.
- Navigate via direct URL → loads.
- Browser back returns to `/groups`.

### M2 — Overview tab + create/edit save flow ✅ 2026-05-07

**Goal:** Identity tab fully working — feature parity with the modal's name + description + status field set.  `/groups/new` + `/groups/:id/edit` both functional.  Existing modal still in use elsewhere; this is the new surface for direct-URL navigation.

**Work:**
- Identity tab body: name + description fields (existing controllers, lifted into a `_GroupEditState`).
- Status `_SectionToggleHeader` from the existing dialog.
- Per-tab dirty tracking (`_dirty: bool`) + Save button enabled state.
- Save calls `cubit.createGroup` or `cubit.updateGroup` with the dirty fields.  Navigate to `/groups/:newId/edit` on create.
- Discard confirms via `FluxGlassDialog`.
- Public group lockdown: name field disabled with helper text.

**Acceptance:**
- Create from `/groups/new` → row appears in list, page navigates to `/groups/:newId/edit`.
- Edit description in `/groups/:id/edit` → Save → list-page chip updates on next poll.
- Discard with dirty state shows confirm.

### M3 — Members tab (M8 home) ✅ 2026-05-07

**Goal:** members table with enrollment state badges + per-row 3-dot menu.

**Work:**
- Members tab body: table consuming `state.members` + `state.group?.pinModel` + `state.group?.requiresPin`.
- Per-row badges driven by enrollment state.  Live grant / locked-out states require an extension to the cubit's `loadMembers` to also fetch `/groups/{id}/grant-status` per-member (or a new aggregated endpoint — see §6 if not yet added).
- 3-dot menu via `FluxGlassMenu`: Remove / Clear PIN / Set time-window override (M5 deferred to its own milestone if it's tight) / View as this member.
- Reuses `_AddMemberDialog`.
- Public group lockdown: Add disabled.

**Acceptance:**
- Table shows all members of selected group with current state.
- Clear PIN action calls `clearMemberPin` + refreshes member list.
- Add Member opens existing dialog.
- Locked-out badge appears after 5 failed `/enter` attempts.

### M4 — PIN + Access tabs (consolidate) ✅ 2026-05-07

**Goal:** retire the modal.  PIN + Access tabs reuse the existing `_PinSection` and `_GroupRestrictionsForm` verbatim.  All entry points to group editing now route to the page.

**Work:**
- PIN tab embeds `_PinSection` + the new Enrollment summary card.
- Access tab embeds `_GroupRestrictionsForm` (which already wraps `_TimeWindowPicker` + `_LibraryAllowlistPicker` + advisory).
- Add `max_concurrent_streams` field to `_GroupRestrictionsForm`.
- Delete `_CreateGroupDialog` + `_EditGroupDialog` + `_showCreateDialog` + `_showEditDialog`.  All call sites updated.
- Rename Public group lockdown logic from "is `_showEditDialog`" to "is in `GroupEditScreen` for `pinModel.isPublic`".

**Acceptance:**
- All previously-modal flows now land on the page.
- `flutter analyze` clean across desktop.
- Existing `GroupsCubit` round-trip tests still pass.

### M5 — Activity + View As + Danger Zone ✅ 2026-05-07

**Goal:** M7 Tier-2 surfaces + the missing server-side endpoints.

**Work:**
- Server: `GET /api/v1/auth/clients/{cid}/visible-libraries` route (localhost only, ~25 lines).
- Server: `PATCH /api/v1/groups/{id}/members/{cid}` route accepting `time_window_override` (~40 lines + service helper + 2 tests).
- Server: 6 `activity_event` emit-call sites in `group_service` write paths.
- Activity tab: `_GroupActivityList` consuming `ActivityCubit` filtered by `target_kind=group + target_id=...`.
- View As tab: client picker + visible-libraries panel.
- Danger Zone: collapsible card on Overview with Delete + Reset all PINs.

**Acceptance:**
- Recent member adds / removes / PIN unlocks appear in Activity tab.
- View As correctly lists the kid's visible libraries with provenance.
- Danger Zone Delete prompts with cascade copy + actually deletes.
- 4 new server tests (member-PATCH happy path + visible-libraries route + 2 activity-emit tests).

---

## 8 · Component Reuse vs. Rewrite

| Existing widget | Action |
|---|---|
| `_GroupRestrictionsForm` | Reused verbatim in Access tab.  Optional `max_concurrent_streams` field added. |
| `_TimeWindowPicker` | Reused in Access tab + Members tab override editor. |
| `_LibraryAllowlistPicker` | Reused in Access tab. |
| `_HourField` | Reused (inside `_TimeWindowPicker`). |
| `_AdvisoryFieldsSection` | Reused in Access tab. |
| `_PinSection` | Reused verbatim in PIN tab.  No code changes. |
| `_AddMemberDialog` | Reused — opened from Members tab "Add member" button. |
| `_SectionToggleHeader` | Reused for status toggle in Overview tab. |
| `_CreateGroupDialog` | **Deleted** at M4. |
| `_EditGroupDialog` | **Deleted** at M4. |
| `_showCreateDialog` / `_showEditDialog` | **Deleted** at M4. |
| `_GroupDetailPanel` | **Kept** — still used on the list page right side; just loses the "Edit" button which now navigates to the page. |

Net: ~95% of the dialog's code reused as widgets; only the modal-specific scaffolding is deleted.

---

## 9 · Edge Cases & Risks

### 9.1 Navigation

| # | Case | Handling |
|---|---|---|
| N1 | Operator navigates away with dirty state | Discard confirm dialog (existing `FluxGlassDialog` + amber warning). |
| N2 | Browser refresh on `/groups/:id/edit` | Cubit reloads + page rehydrates (existing `loadAll` + `selectGroup` flow handles this). |
| N3 | Operator edits a group that gets deleted by another tab | Cubit's `selectGroup` returns `null` → page renders an "Group no longer exists" empty state with a "Back to groups" button. |
| N4 | Direct URL with invalid id | Same N3 path. |

### 9.2 Public group lockdown

Locking individual fields is fine; locking entire tabs (PIN + Members) is the dangerous move — operator might confusingly think they're broken.  Mitigation: each locked surface shows explanatory copy, not just disabled controls.  Same pattern as Library type-immutable.

### 9.3 Per-client mode + grant-status fanout

Members tab needs each member's `enrollment_state` + `grant_status`.  Two implementation options:
- **A**: Per-row HTTP call on tab mount (N members → N requests).  Simple but fan-out scales linearly.
- **B** (recommended): New aggregated endpoint `GET /api/v1/groups/{id}/members?include=pin_state` that joins `group_member_pins` + `group_pin_grants` server-side.  One request, one trip.

Pick (B) at M3 if N typically >10; pick (A) for v1 if N typically <5.  Schema is unchanged either way.  Decision deferred until M3.

### 9.4 View As accuracy

The endpoint reflects current visibility for the target client.  Operator-side caveats:
- Doesn't simulate "if I added kid to Family right now" — only current membership.  Hypotheticals are out of scope (operator manipulates membership directly to test).
- Honest about PIN-gated state — if kid hasn't unlocked Adults, View As doesn't show Adults.
- Time-window-locked groups appear in `time_locked_groups` so the operator sees "would be visible at 18:00".

### 9.5 Activity volume

A busy household might generate 50+ group events per day.  `group.pin.failed-attempt` is the noisy one — every failed PIN attempt is a row.  Mitigation: server-side aggregation in the producer ("5 failed attempts in 10 min from Pixel 8 Pro" → single row, not 5).  Tracked as a producer-side polish in M5.

### 9.6 Risks

| Risk | Mitigation |
|---|---|
| Modal users have muscle memory; sudden URL change confuses them | Keep `/groups/new` + `/groups/:id/edit` as standard route shapes; the list page's Edit button just navigates instead of opening a modal — single click cost unchanged. |
| Save-from-multiple-tabs race | Cubit's existing `update_group` is atomic per call; the page only saves the dirty fields per tab.  Two tabs with Save click ~ms apart is the same as two operators editing concurrently — last write wins; same as today. |
| Per-client mode badges flicker on poll | Cache enrollment state per (group, client) on the cubit; only fetch on group-change.  Same pattern as the Library cache. |
| View-as-localhost endpoint must be off-loopback rejected | Same `require_local_caller` dependency as the existing master-override endpoint. |
| Migration leaves the modal accessible during M1-M3 | Deliberate: modal stays during the milestone window so operators have a working flow.  Modal deletion is M4. |

---

## 10 · Cross-references

- Predecessor plans: [`12_groups_remediation_plan.md`](./12_groups_remediation_plan.md) (v1 remediation, ✅ complete) + [`13_groups_v2_content_spaces.md`](./13_groups_v2_content_spaces.md) (v2 content-spaces redesign — server done, mobile pending; this page subsumes M7 Tier-2 desktop work).
- ADRs: [`02_decisions.md`](./02_decisions.md) ADR-018 (additive content-spaces), ADR-019 (hybrid PIN), ADR-020 (master-override localhost-only) — page is the surface for these decisions; no new ADRs needed.
- Backend architecture: [`../09_backend/01_backend_architecture.md`](../09_backend/01_backend_architecture.md) — group_service section gets the 3 new producers + 2 new endpoints summary on M5 land.
- API contracts: [`../04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) — update on M5 land with `PATCH /groups/{id}/members/{cid}` + `GET /auth/clients/{cid}/visible-libraries`.
- Frontend architecture: [`../08_frontend/01_frontend_architecture.md`](../08_frontend/01_frontend_architecture.md) — `GroupEditScreen` joins the screen registry on M1.
- Database schema: [`../03_data/02_database_schema.md`](../03_data/02_database_schema.md) — no changes; everything is already in 025 + 026.
- Roadmap: [`./01_roadmap.md`](./01_roadmap.md) Client Groups row updated on each milestone.

---

## 11 · Out of Scope

This plan is the desktop CP redesign of group management.  Out of scope:

- **Mobile group management** — mobile clients consume groups (see what they're a member of, unlock PIN-gated groups via `/enter`, enroll via `/enroll`); they don't create or edit groups.  Operator surface only.
- **Multi-tenant group federation** — v2 cloud licensing concern (ADR-013).
- **Group export / import (JSON config dump)** — Tier-4 in v2 plan; defer to v2.
- **Group templates / cloning** — Tier-3 in v2 plan; possibly add to a future milestone but not now.
- **Real `bandwidth_cap_mbps` enforcement** — wide refactor of the streaming pipeline; out of scope for this UX work.
- **Per-group themes / chrome customization** — UX bloat per ADR-018 / v2 plan §6.4.

---

## 12 · Acceptance for the Whole Plan

Page ships when:
- All previously-modal flows land on `/groups/:id/edit` or `/groups/new`.
- M8 per-client PIN management is operable from the Members tab.
- View As works for any approved client + accurately reflects `get_visible_libraries`.
- Activity tab shows recent group events for the selected group.
- Public group locks down name + status + PIN tab + Members add/remove with explanatory copy.
- Existing Groups list page (`/groups`) remains the primary entry point; row tap + Edit button navigate to the new page.
- Server suite: +4 tests (visible-libraries route + member-PATCH route + 2 activity-emit producers).
- Desktop analyzer clean.
- AGENT_LOG entry + plan-doc status flip + cross-doc updates per [`docs/12_guidelines/02_documentation_update_protocol.md`](../12_guidelines/02_documentation_update_protocol.md).
