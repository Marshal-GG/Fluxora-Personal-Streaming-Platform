# Groups v2 — Content Spaces Redesign

> **Category:** Planning
> **Status:** ✅ Core ship complete 2026-05-07 — M1-M3 server ✅, M4 (shared-PIN) server + desktop + mobile ✅, M5 migration ✅ (folded into 025), **M6 mobile UX ✅**, **M7 desktop polish ✅** (icon + color + concurrent-stream cap; producer aggregation + bulk grants reset), **M8 hybrid PIN (per-client enrollment) server + desktop + mobile ✅**
> **Scope:** Reworks the v1 Groups feature (shipped 2026-05-01, polished 2026-05-07 via [`12_groups_remediation_plan.md`](./12_groups_remediation_plan.md)) from a *subtractive restriction layer* to an *additive content-spaces* model with a mandatory Public group and optional PIN-gated groups.  Defines schema migrations, a single-source-of-truth visibility resolution function, mobile + desktop flows, a 7-milestone remediation, a tiered feature catalog, and a migration path from the existing data.
> **Triggered by:** owner discussion 2026-05-07 — after the v1 plan shipped end-to-end, the operator-side model felt wrong: clients in zero groups got *full* access (rather than a sane default), multi-group semantics were intersection (least-permissive wins) which surprised operators who expected union, and there was no story for genuinely shared libraries (everyone sees Movies) vs gated content (PIN required for adult library).  This plan flips the semantic and adds the missing pieces.

---

## 1 · Executive Summary

The v1 Groups model is **subtractive**: groups *take away* access from a default-everything baseline.  A client in zero groups sees everything; adding to "Kids" narrows that to a subset.

The v1.5 model is **additive**: groups *grant* access from a default-nothing baseline.  Every paired client auto-joins the **Public** group; that group exposes whatever libraries the operator wants household-shared.  Additional groups expose more libraries (Family, Adults, Guests).  Some groups require a PIN to enter; PIN-gated libraries are *invisible* until unlocked, not just blocked at play-time.

**Headline gains:**

- **Cleaner mental model.** "What's in this group's content space?" replaces "what restrictions does this group apply?"  Multi-group is a union; new groups *expand* what a device sees.
- **Sane defaults.** Pair a device → it sees Public's libraries + nothing else.  No more "client in zero groups sees everything" trap.
- **PIN gating that earns its keep.** Adults-only libraries are *invisible* on the kid's tablet rather than just blocked at play-time.  Knowing what exists is itself the leak.
- **List + stream gates aligned.** Browser surfaces show exactly what's playable.  No more "see it, can't play it" UX from v1.
- **Migration is clean.** Existing rows + members carry; semantics flip + a Public group is manufactured to preserve current visibility.

**What's added beyond the v1 surface area:** mandatory Public group, PIN-gated groups + grant table + lockout, per-group streaming presets, per-member time-window overrides, master operator override, group activity feed, "view as" debug mode, group icons + descriptions, group cloning.  Detail in [§6](#6--feature-catalog).

**Sequencing:** seven milestones, ~5 days for the core (M1-M6).  M7 is +1 day operator quality of life.  Tier 3 features ship as v1.6 follow-ups.  Detail in [§7](#7--remediation-plan).

---

## 2 · Why This Redesign

The v1 model worked but produced friction the moment the operator tried to use it for anything beyond a single restricted device:

| Pain point (v1) | Why | v1.5 fix |
|---|---|---|
| Client in zero groups gets full access | Subtractive default — no group = no restrictions | Public is mandatory; default is Public's libraries, not "everything" |
| Multi-group semantics confuses operators | Intersection: client in Kids + Family sees Kids ∩ Family.  Counter-intuitive. | Union: client in Kids + Family sees Kids ∪ Family.  Adding groups grants more access. |
| No story for "everyone sees X" | Every group is a restriction; no positive default | Public group exists to be that positive default |
| List endpoints unfiltered | M1-M5 only gates at stream-start | Single visibility function consumed by every list endpoint + the stream gate |
| Adult content visible-but-unplayable | Library list shows it; play denies it | Invisible-until-unlocked via PIN; library disappears from the list entirely |
| `bandwidth_cap_mbps` + `max_rating` advisory only | No enforcement plumbing | Same — but new per-group concurrent stream cap is enforced (real value-add) |
| Operator can't preview kid's view | No "view as" surface | Tier 2 — desktop CP renders the kid's library list as they'd see it |

**This plan is not a v2 multi-tenant rewrite.** It stays single-operator, single-server.  Multi-tenant cloud licensing is locked deferred per `02_decisions.md` ADR-013.

---

## 3 · Current Architecture (post-M1–M5)

### 3.1 Data model

```
groups (id, name, description, status, created_at, updated_at)
group_members (group_id, client_id, added_at)
group_restrictions (
    group_id,
    allowed_libraries,        -- JSON array — "client can ONLY stream from these"
    bandwidth_cap_mbps,       -- advisory
    time_window,              -- JSON {start_h, end_h, days[]}
    max_rating                -- advisory
)
```

### 3.2 Stream-gate logic ([`group_service.py:reason_to_deny`](../../apps/server/services/group_service.py#L366))

```
client → group_members → groups → group_restrictions
       → effective = INTERSECTION across active groups
       → if file's library_id NOT IN effective.allowed_libraries → deny
       → if NOW NOT IN effective.time_windows → deny
       → else allow
```

### 3.3 Surfaces consuming the gate

- **`stream.py:100-107`** — `/stream/start` — sole enforcement site; lists are unfiltered (the M6 hole identified during owner-side discussion 2026-05-07)
- **Desktop M1-M4** — restriction editor, client picker, cross-link, filter chip
- **Mobile M5** — `PlayerCubit` parses 403 detail → `PlayerGated` state → `_GatedView`

---

## 4 · Proposed Model

### 4.1 Data Model

```sql
-- Migration 025_groups_v2_content_spaces.sql

-- New columns on groups.  Public is special-cased; only one row may carry
-- is_public = 1 (UNIQUE partial index enforces).
ALTER TABLE groups ADD COLUMN is_public      INTEGER NOT NULL DEFAULT 0;
ALTER TABLE groups ADD COLUMN icon           TEXT;            -- e.g. 'home', 'kids', 'lock'
ALTER TABLE groups ADD COLUMN color          TEXT;            -- hex like '#A855F7'
ALTER TABLE groups ADD COLUMN requires_pin   INTEGER NOT NULL DEFAULT 0;
ALTER TABLE groups ADD COLUMN pin_hash       TEXT;            -- HMAC-SHA256(pin, server_secret)
ALTER TABLE groups ADD COLUMN pin_mode       TEXT NOT NULL DEFAULT 'session'
                                             CHECK(pin_mode IN ('session','per-entry'));
ALTER TABLE groups ADD COLUMN max_concurrent_streams INTEGER;  -- per-group, NULL = unlimited

CREATE UNIQUE INDEX idx_groups_public
    ON groups(is_public) WHERE is_public = 1;

-- Per-member overrides (Tier 2 feature).  Optional; NULL = use group's
-- time_window.  Resolves the "older kid stays up later in same group"
-- pattern without forcing the operator to create per-kid groups.
ALTER TABLE group_members ADD COLUMN time_window_override TEXT;  -- JSON, same shape as group_restrictions.time_window

-- group_restrictions.allowed_libraries semantics flips meaning:
--   v1: "client can ONLY stream from these libraries"   (subtractive)
--   v2: "this group EXPOSES these libraries to members" (additive)
-- bandwidth_cap_mbps + max_rating stay advisory until v2 enforcement work.

-- New: PIN grant ledger.  A client unlocks a PIN-gated group → grant row
-- inserted; expires per the group's pin_mode.  Grant lookup is the
-- gating step in get_visible_libraries.
CREATE TABLE IF NOT EXISTS group_pin_grants (
    client_id   TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    group_id    TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    granted_at  TEXT NOT NULL,
    expires_at  TEXT NOT NULL,
    PRIMARY KEY (client_id, group_id)
);
CREATE INDEX IF NOT EXISTS idx_grants_expiry ON group_pin_grants(expires_at);

-- New: PIN failed-attempt ledger for brute-force protection.  Per-client
-- per-group.  Attempts are pruned after 24 h via the existing housekeeping
-- task in main.py.
CREATE TABLE IF NOT EXISTS group_pin_attempts (
    client_id   TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    group_id    TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    attempted_at TEXT NOT NULL,
    success     INTEGER NOT NULL  -- 0 = failed, 1 = success
);
CREATE INDEX IF NOT EXISTS idx_pin_attempts_client_group_time
    ON group_pin_attempts(client_id, group_id, attempted_at DESC);
```

### 4.2 Visibility Resolution

The single function every consumer calls.  Pure (no side effects) → easy to test exhaustively.

```python
@dataclass(frozen=True)
class VisibleLibraries:
    """The set of library_ids a client can see right now, with provenance.

    `library_ids` is the set the list endpoints filter by.
    `groups_contributing` lists which groups granted which library — used
    by the desktop's "view as" debug mode + the operator's audit needs.
    `pin_locked_groups` lists groups the client is a member of but hasn't
    unlocked — populated so the mobile "Unlock libraries" surface knows
    what's hidden.
    """
    library_ids: frozenset[str]
    groups_contributing: dict[str, frozenset[str]]    # group_id -> library_ids
    pin_locked_groups: frozenset[str]


async def get_visible_libraries(
    db, client_id: str, *, now: datetime | None = None
) -> VisibleLibraries:
    """Resolve the visible-libraries set for a client at a given moment.

    Walk every active group the client belongs to:
      - Skip if status != 'active'
      - Skip if group has time_window AND now is outside it (after applying
        the member's override, if any)
      - Skip if group requires_pin AND no valid grant exists for this client
        (record group_id in pin_locked_groups so the mobile UI can offer
        unlock)
      - Otherwise UNION the group's allowed_libraries into the visible set
    """
    ...
```

The resolution always includes Public (every paired client is auto-added on approve).  No-group state is impossible by construction.

### 4.3 PIN Grant Flow

```
POST /api/v1/groups/{id}/enter
  body: {"pin": "1234"}
  → server checks group.requires_pin = true
  → server checks pin attempt rate (5 fails in 1 min → 429 with retry-after)
  → server compares HMAC(body.pin) to group.pin_hash
  → on success:
      INSERT INTO group_pin_grants
          (client_id, group_id, granted_at, expires_at)
      → expires_at = now + (12 hours if pin_mode='session', 5 minutes if 'per-entry')
      → activity_event 'group.pin.unlock' recorded
      → 200 with {expires_at}
  → on failure:
      INSERT INTO group_pin_attempts (..., success=0)
      → 401 with attempts_remaining_in_window

DELETE /api/v1/groups/{id}/grant
  → DELETE FROM group_pin_grants WHERE client_id=? AND group_id=?
  → 204
  → mobile "Lock" button hits this; operator's master override can also lock anyone
```

PIN format: 4–8 digit numeric, server-rejects sequences (1234, 1111, 0000) by default.  Operator-set; recoverable via Reset PIN on the desktop CP (which simply rewrites `pin_hash` and DELETES all grants for that group).

---

## 5 · End-to-End Flows

### 5.1 First-time setup (server boot)

1. Server starts → migration 025 applied → Public group auto-created if not present:
   ```
   INSERT INTO groups (id, name, status, is_public, ...) VALUES
       ('public', 'Public', 'active', 1, ...)
   INSERT INTO group_restrictions (group_id, allowed_libraries) VALUES
       ('public', NULL)         -- empty by default
   ```
2. Operator opens desktop CP → Groups screen → sees Public listed first with a 🌐 PUBLIC pill.
3. Operator creates Movies library.  Library is invisible to all paired clients until added to a group.
4. Operator opens Public → adds Movies library → save.  All paired clients now see Movies on next list-endpoint poll.

### 5.2 Pairing a new device

1. Kid's tablet → mobile pair flow → operator approves on desktop.
2. Server-side `auth_service.approve_client` is extended to insert `(public_group_id, client_id)` into `group_members` automatically.
3. Kid's library list = Public's libraries.  No "client in zero groups" trap.

### 5.3 Operator adds the kid to "Kids" group

1. Desktop Clients screen → kid's tablet detail panel → Groups section + button → picker.
2. Pick "Kids" (already configured with libraries=[Movies, Cartoons], time_window=18:00-22:00, no PIN).
3. Server inserts membership row + activity_event `group.member.add`.
4. Kid's library list updates on next poll: Public + Kids = Movies + Cartoons during 18:00-22:00.
5. Outside window: just Public = Movies.

### 5.4 PIN-gated group: Adults

1. Operator creates "Adults" group → adds "Adults Only" library → sets PIN `8472` → pin_mode `session`.
2. Operator's tablet → desktop adds it to Adults → kid's tablet stays out.
3. Operator's tablet on next poll: library list = Public + Kids — *still no Adults Only*.  PIN-gated until unlocked.
4. Operator's tablet → Settings → "Unlock libraries" → sees "Adults" with a lock icon → tap → PIN entry modal → enter 8472 → server records grant valid 12 h → mobile-side `unlocked_groups: {adults}` cache.
5. Library list re-polled: Public + Kids + Adults.  Adults Only library now visible.
6. After 12 h: grant expires → list reverts to Public + Kids on next poll.  Mobile prompts re-PIN if operator was browsing inside Adults.

### 5.5 Stream attempt at the boundary

- **Inside time_window, library visible** → server checks `library_id IN visible_libraries` → allowed → proceeds.
- **Outside time_window** → library has already dropped from `visible_libraries` → mobile Library list doesn't even show it.  But if mobile attempts a stream-start with a stale `file_id` (cached UI), server rejects with 403 + reason "Outside the allowed streaming time window" → `PlayerGated` (M5 surface still applies).
- **PIN expired mid-session** → same as above; library disappears from list, stale stream-start is rejected.

### 5.6 "View as" debug

1. Operator opens desktop CP → Clients screen → kid's tablet detail panel → "View library as this device" button.
2. Desktop renders a simulation overlay: `get_visible_libraries(kid_client_id, now)` is called server-side, results rendered in a panel.
3. Operator confirms config does what they expect.  Closes overlay.

This is the single most-requested debug feature for any access-control system; ship it Tier 2.

---

## 6 · Feature Catalog

### 6.1 Tier 1 — Core Model (must ship as v1.5)

These are the model itself.  Without them, the redesign is incomplete.

| Feature | Why |
|---|---|
| **Public group + auto-membership on approve** | Default sane behavior; no "zero-group" trap |
| **Additive `allowed_libraries` semantics** | Multi-group as union; intuitive |
| **`get_visible_libraries(client_id, now)` function** | Single source of truth |
| **All list endpoints filtered** | List + stream surfaces aligned |
| **PIN-gated groups** + `group_pin_grants` table | Real value-add for adult content / sensitive libraries |
| **PIN brute-force protection** + `group_pin_attempts` ledger | Prevents a 4-digit PIN from being defeated in 30 seconds |
| **Master operator override** (localhost CP can unlock anything without PIN) | Forgot-PIN recovery; required for any access-control system |
| **Migration 025** + back-fill (existing groups + members + Public manufactured) | No data loss; existing operator's deployment keeps working |

### 6.2 Tier 2 — Operator Quality of Life (should ship as v1.5)

These earn their keep on day one of an operator with multiple groups.

| Feature | Why |
|---|---|
| **Group icons + colors** | Visual identity — "Kids" with a 🎮 icon + green is faster to scan than just "Kids" |
| **Group descriptions** | Schema column already exists; surface in detail panel |
| **"View as" debug mode** | Most-requested debug for any ACL system |
| **Activity events for PIN unlock / lock / failed attempts** | Operator audit needs; integrate with existing activity feed |
| **PIN reset action** (desktop CP, with confirmation + grants cascade) | Forgot-PIN flow |
| **Per-group concurrent stream cap** (real enforcement, replacing v1's advisory `bandwidth_cap_mbps`) | Promotes one of the v1 advisory fields to actual functionality |
| **"Unlock libraries" mobile surface** | The PIN entry UX |
| **Mobile "Locked groups" indicator** on Profile screen | Lets the operator's tablet know which groups it's a member of but doesn't have grants for |
| **Operator notification on gate denials** | Subtle activity feed entry; helps debug "why is the kid complaining" |

### 6.3 Tier 3 — Polish (nice; ship as v1.6 follow-up)

These are real value but not blocking.

| Feature | Why |
|---|---|
| **Per-member `time_window_override`** | "Older kid in same Kids group stays up to 23:00" without forcing per-kid groups |
| **Per-group streaming presets** (max resolution, force tonemap, encoder pref) | Pre-configured per-group transcoding, e.g. "Kids group always streams 720p libx264" |
| **Group cloning / templates** | New group from template: Kids → pre-fills time_window + libraries |
| **Group activity feed** (per-group filter on operator dashboard) | "What's been streamed from each group recently" |
| **PIN strength policy** (rejects 1234 / 1111 / sequential / repeated) | Defensive; minor server-side change |
| **PIN hint** (operator-set text on the entry modal — "Adult's birthday year") | Memory aid, optional |
| **Group "shared with" indicator** on library detail | When operator opens a library, see which groups expose it.  Useful when deleting libraries. |

### 6.4 Tier 4 — Deferred to v2

Out of scope for v1.5 / v1.6.  Listed for completeness; revisit when v2 multi-tenant work begins.

| Feature | Why deferred |
|---|---|
| **Group invitations / pre-assigned pairing** (operator generates QR that pre-assigns groups on pair) | Multi-step UX; nice but not essential when the operator can add post-pair |
| **Biometric unlock** (fingerprint / face ID instead of PIN) | OS-specific plumbing; v2.5 |
| **Group expiration** (time-limited groups that auto-delete) | Schedule task + UX work; rare use case |
| **Group export / import** (JSON config dump) | Multi-server backup story; v2 |
| **Cross-server group federation** | Multi-tenant; v2 |
| **Smart group suggestions** ("Add Kids tablet to Family group?") | Magic; risk of being annoying |
| **Per-group themes** (colored chrome when in that group's content) | UX bloat |
| **Group analytics** (most-watched titles per group, total stream time) | Defer until operators ask |
| **Cross-device PIN federation** (unlock on phone → tablet inherits) | Adds infra for marginal UX gain |
| **Real `bandwidth_cap_mbps` enforcement** (FFmpeg `-maxrate` injection) | Wide refactor; v2 |
| **Real `max_rating` enforcement** (needs `media_files.rating` column + ladder) | Wide refactor; v2 |

---

## 7 · Remediation Plan

### Sequencing

```
M1 — Schema + visibility resolution      ~1 day      foundational                    ✅ 2026-05-07
M2 — List endpoint filtering             ~1 day      headline UX fix                 ✅ 2026-05-07
M3 — Public group + auto-membership      ~0.5 day    enables M1's defaults           ✅ 2026-05-07
M4 — PIN flow (server + mobile + desktop) ~1.5 days   the headline new feature        ✅ 2026-05-07 (server + desktop + mobile)
M5 — Migration from M1-M5 data            ~0.5 day    no data loss for existing ops   ✅ 2026-05-07 (folded into migration 025)
M6 — Mobile UX polish                     ~0.5 day    Profile + lock controls         ✅ 2026-05-07
M7 — Operator quality of life (Tier 2)    ~1 day      "view as", icons, activity      ✅ 2026-05-07 (incl. activity aggregation + bulk grants reset)
M8 — Hybrid PIN mode (per-client)         ~1.5 days   per-client enrollment opt-in    ✅ 2026-05-07 (server + desktop + mobile)
─────────────────────────────────────────  ───────
Total                                      ~7.5 days end-to-end (Tier 1 + 2 + hybrid PIN)
```

Tier 3 ships as v1.6 follow-up; ~2 additional days when operators actually ask for those polish items.

### M1 — Schema + visibility resolution ✅ 2026-05-07

**Goal:** Migration 025 applied; `get_visible_libraries` shipped + tested.  No surface changes yet.

**Server changes:**
- Migration `025_groups_v2_content_spaces.sql` — adds columns + tables per [§4.1](#41-data-model).
- `services/group_service.py` reworked:
  - Replace `get_effective_restrictions` with `get_visible_libraries(db, client_id, *, now=None) -> VisibleLibraries`.
  - Replace `reason_to_deny` with `reason_to_deny_stream(db, client_id, file_row, *, now=None)` that checks: file's library_id IS IN visible_libraries (covers all flavors of denial — invisible group, time window, PIN-locked).
  - Helper `enter_pin_grant(db, client_id, group_id, pin)` — handles HMAC compare, attempt logging, rate limiting, grant insertion.
  - Helper `revoke_pin_grant(db, client_id, group_id)` — for lock buttons.
  - Helper `housekeep_pin_grants(db)` — prunes expired rows; called from the existing startup background task.
- New tests in `test_groups.py`:
  - Visibility resolution matrix (8+ combinations across multi-group, time-window, PIN-grant, inactive group, member override).
  - PIN compare (HMAC equality, brute-force lockout, grant TTL).
  - Migration round-trip: pre-M1 row + restrictions → post-migration row reads identical.

**Acceptance:** `python -m pytest tests/test_groups.py -k visibility` covers every branch in `get_visible_libraries`.

### M2 — List endpoint filtering ✅ 2026-05-07

**Goal:** Every endpoint that returns library/file rows applies `get_visible_libraries`.  Mobile lists shrink to what the device should see.

**Endpoints to filter:**
| Endpoint | Filter |
|---|---|
| `GET /library` | `library.id IN visible_libraries` |
| `GET /files?library_id=X` | If X NOT IN visible_libraries → 403 (don't 200 with empty — explicit deny) |
| `GET /files/recent` | `media_files.library_id IN visible_libraries` |
| `GET /files/search` | same |
| `GET /auth/clients/me/continue-watching` | same |
| `GET /files/{id}` | If file's library NOT IN visible_libraries → 404 (not 403 — don't even confirm existence) |
| `POST /stream/start/{id}` | Same as before (M1-M5's gate — but now the only call site that *should* hit denial in normal use is via stream attempt with a stale file_id) |

**Why 404 on `/files/{id}` and 403 on `/files?library_id=X`:**
- Library-id supplied → operator knows it's a library → 403 "you don't have access" is honest.
- Bare file-id → could be guessed or stale → 404 "doesn't exist (to you)" prevents enumeration.

**Tests:** integration test per endpoint asserting the filtered result for a kid client + a no-restriction client.

### M3 — Public group + auto-membership ✅ 2026-05-07

**Goal:** Public group manufactured on first-run; every paired client auto-joins.

**Server changes:**
- `main.py` startup hook: `INSERT OR IGNORE INTO groups (id, name, status, is_public, ...) VALUES ('public', 'Public', 'active', 1, ...)`.  Idempotent — re-runs don't duplicate.
- `auth_service.approve_client` extended: after marking `status = 'approved'`, `INSERT OR IGNORE INTO group_members (group_id, client_id, added_at) VALUES ('public', client_id, now)`.
- `group_service.delete_group` rejects deletes when `is_public = 1`.
- Desktop CP: Public group renders with a 🌐 PUBLIC pill, no delete button; Edit dialog allows changing libraries + name + description but not is_public/requires_pin.

**Tests:**
- New paired client → assert `(public_id, client_id)` row exists in `group_members`.
- Migration creates Public for an existing server with prior state.
- Delete-Public attempt → 400 with "cannot delete the public group".

### M4 — PIN flow (server + mobile + desktop) 🔵 server ✅ + desktop ✅ (2026-05-07); mobile pending

**Goal:** Operator can flag a group as PIN-protected; mobile clients can unlock; lockout protects against brute force.

#### 4a · Server

- New endpoints:
  - `POST /api/v1/groups/{id}/enter` — body `{pin: str}`.  Rate-limited 5 attempts / minute / client / group via the existing `slowapi` Limiter.  HMAC-compare + insert grant + record activity event + return `{expires_at}`.
  - `DELETE /api/v1/groups/{id}/grant` — drops the grant for the calling client (or for an arbitrary client when invoked from localhost — master override).
  - `GET /api/v1/groups/{id}/grant-status` — returns `{unlocked: bool, expires_at: str?}` for the calling client.

- Server-side PIN strength policy:
  - 4–8 digits numeric.
  - Reject `1234`, `4321`, `1111`, `0000`, `2580` and other obvious sequences.  Configurable list in `config.py`.
  - Reject if PIN equals last-3 PINs (PIN history; optional, skip for v1.5).

- `groups.pin_hash` storage: `HMAC-SHA256(pin, settings.pin_hmac_key)` — same key as bearer tokens (re-use the existing key-rotation discipline).

#### 4b · Mobile

- `_UnlockLibrariesSurface` on the Profile screen:
  - Lists every group the device is a member of with `requires_pin = true` AND no active grant.
  - Each entry: 🔒 icon + group name + group icon (Tier 2) + tap to PIN entry modal.
  - PIN entry modal: 4–8 digit numeric input + "Unlock" button + per-attempt feedback ("3 attempts remaining").
  - On success: server returns expires_at; mobile caches `unlocked_groups: {group_id: expires_at}` in memory; library cubit silently refetches `/library` (which now includes the unlocked content).

- `_LockedGroupsCard` (companion surface on Profile):
  - Lists currently-unlocked groups with their expiry times + per-group "Lock" button.
  - Global "Lock all" button.

- New mobile `PaymentExceptions` parser: when a `/library` poll comes back with the unlocked group's libraries newly missing, emit a transient toast "Adults locked — re-enter PIN to access".

#### 4c · Desktop

- Group create / edit dialog gains a section:
  - `requires_pin: FluxSwitch` toggle.
  - When on: PIN entry field (masked, 4–8 numeric, server-validated) + `pin_mode` selector (Session / Per-entry).
  - "Reset PIN" action: prompts confirmation, generates a new server-side hash, cascades grant deletion (so all member devices PIN-prompt next access).
- Group detail panel shows lock icon + pin_mode + last-PIN-changed timestamp (Tier 2).
- "Unlock for me" button on the operator's own desktop CP detail (master override convenience — doesn't hit the rate limit since it's localhost).

#### 4d · Tests

- HMAC compare round-trip.
- Rate-limit fires after 5 fails in 60s.
- Successful PIN inserts grant + activity event.
- Per-entry mode: grant expires in 5 min; session: 12 h.
- Reset PIN cascades grant deletion (all member devices PIN-prompt next access).
- Master override (localhost) bypasses PIN compare; logs activity event with `actor=operator-override`.

### M5 — Migration from M1-M5 data ✅ 2026-05-07 (folded into migration 025)

**Goal:** Existing operator deployments don't lose visibility; semantic flip is clean.

**Migration logic** (in `025_groups_v2_content_spaces.sql` + a one-shot data migration in main.py startup):

1. Add new columns + tables (DDL).
2. Manufacture Public group: `INSERT OR IGNORE INTO groups (id='public', name='Public', is_public=1, ...)`.
3. **Critical step:** populate Public's `allowed_libraries` with EVERY existing library so paired clients don't lose visibility on the upgrade.
   ```sql
   UPDATE group_restrictions
      SET allowed_libraries = (SELECT json_group_array(id) FROM libraries)
    WHERE group_id = 'public';
   ```
4. Auto-add every paired client to Public:
   ```sql
   INSERT OR IGNORE INTO group_members (group_id, client_id, added_at)
   SELECT 'public', id, datetime('now') FROM clients
    WHERE status = 'approved';
   ```
5. **Existing groups + restrictions stay as-is.**  The semantic flip in `group_restrictions.allowed_libraries` is interpretation-only — the JSON value (list of library ids) means the same thing in both models, just with different "who's denied" implications.  Members of "Kids" group who previously saw Movies-only because of restrictions will now see Public's libraries (everything) UNION Kids' libraries (Movies) = everything.  **Operator must audit existing groups post-migration.**
6. Server logs a one-time INFO at startup: `"Migration 025 applied. Existing operators should review their groups — semantic has flipped from subtractive to additive."`

**Risk:** the back-fill step (3) means the migration is *more permissive* than the v1 state for clients in groups.  Operator who set up "Kids" with `allowed_libraries=[Movies]` to *deny* TV access will find that post-migration the kid sees Public's libraries (which include TV) UNION Movies = TV is back.

**Mitigation:** The migration ships with a desktop banner ("Groups feature was upgraded — review your group config; access semantics changed.  Click for details").  Banner persists until the operator dismisses or 7 days pass.

### M6 — Mobile UX polish ✅ 2026-05-07

**Goal:** Profile screen surfaces the new model coherently.  Restrictions card from `12_groups_remediation_plan.md` §5.5 is reworked.

- New "Visible Libraries" card on Profile: explicit list of what this device sees right now.  Each library entry shows which group(s) granted it.
- "Locked Groups" surface: groups the device is a member of but hasn't unlocked.  Tap → PIN entry → unlock.
- "Unlocked Groups" surface: groups currently unlocked + per-group expiry + lock buttons.
- PIN entry validates client-side (length + numeric); server-side compare authoritative.

### M7 — Operator quality of life ✅ 2026-05-07

**Goal:** Tier 2 features ship together as a coherent operator-side polish round.

- **"View as" debug mode**: desktop CP renders the kid's library list as they'd see it.  New endpoint `GET /api/v1/auth/clients/{id}/visible-libraries` (localhost only) returning `VisibleLibraries`.  Desktop renders the result in a side panel.
- **Group icons + colors**: 12-icon picker (home, kids, lock, family, music, video, etc.) + 6-color picker on group create / edit.
- **Group activity feed**: extend `activity_events` query with `target_kind = 'group'` filter.  New tab on the desktop activity screen: "Group Activity".
- **PIN reset action**: surface in Edit dialog + Reset button on the detail panel.  Cascades grant deletion + activity event.
- **Per-group concurrent stream cap**: `groups.max_concurrent_streams` field; checked at stream-start by counting active sessions among members.  If exceeded → 503 with reason "Group concurrent stream limit reached".
- **Operator notification on gate denials**: when `reason_to_deny_stream` returns non-None, emit a notification to the operator (`category=transcode + related_id=client_id`).  Dedupe at the activity-event layer.

### M8 — Hybrid PIN mode (per-client enrollment) 🔵 server + desktop ✅ 2026-05-07; mobile pending

**Goal:** Operator can flip a PIN-gated group from the default *shared-PIN* mode (current M4 ship — one PIN per group, every member uses it) to *per-client enrollment* mode where each member device sets and remembers its own PIN.  Smaller compromise blast radius — a leaked PIN affects exactly one device, not the household.

**Triggered by:** owner discussion 2026-05-07 — concern that a shared PIN is a single secret that, once leaked (kid sees parent type it, friend looks over shoulder, …), forces a household-wide rotation.  Per-client enrollment confines the leak to one device.

#### 8a · Schema (additive — no rewrite of M4 data)

```sql
-- Migration 026_groups_per_client_pins.sql

ALTER TABLE groups ADD COLUMN pin_model TEXT NOT NULL DEFAULT 'shared'
    CHECK(pin_model IN ('shared', 'per-client'));

CREATE TABLE IF NOT EXISTS group_member_pins (
    group_id    TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    client_id   TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    pin_hash    TEXT NOT NULL,
    enrolled_at TEXT NOT NULL,
    PRIMARY KEY (group_id, client_id)
);
```

`groups.pin_hash` stays the household PIN for `pin_model='shared'` rows; ignored for `'per-client'`.  Existing rows default to `'shared'` — no behavior change for already-shipped data.

#### 8b · Server flow

- **`POST /groups/{id}/enroll`** — bearer-token only.  Body `{pin}`.  400 if group is shared-mode; 409 if calling client already has an enrollment row (use change-PIN endpoint instead).  On success: HMAC-hash + INSERT into `group_member_pins` + immediately issue a session-length grant (no need to re-enter what they just typed).
- **`POST /groups/{id}/enroll/change`** — bearer-token only.  Body `{old_pin, new_pin}`.  Verifies old, replaces hash; existing grant carries.
- **`DELETE /groups/{id}/members/{client_id}/pin`** — localhost only.  Operator clears a specific member's enrollment so they re-enroll on next access.  Useful when a device is suspected compromised but the operator doesn't want to evict the member entirely.
- **Modified `POST /groups/{id}/enter`** — branches on `pin_model`: `'shared'` compares against `groups.pin_hash` (current); `'per-client'` compares against `group_member_pins(group_id, client_id).pin_hash`.  Same rate limit + grant insert.
- **Modified `GET /groups/{id}/grant-status`** — adds `enrollment_state: 'not_required' | 'enrolled' | 'enrollment_required'` so mobile knows to route to the enrollment surface vs the entry surface.
- **`get_visible_libraries`** is unaffected — the grant table is mode-agnostic; a grant is a grant.  `pin_locked_groups` is split into `awaiting_pin` and `awaiting_enrollment` in the `VisibleLibraries` dataclass.
- **Master override** (`POST /groups/{id}/master-override?client_id=...`) keeps working unchanged for both modes — issues a 12 h grant on the target client without consulting any PIN.  For per-client mode this is the recovery path when a member forgets their own PIN.

#### 8c · Mode-switching semantics

| Transition | What happens |
|---|---|
| shared → per-client | `groups.pin_hash` cleared.  Existing grants kept (members aren't kicked off mid-session).  When each grant expires, the next access prompts enrollment. |
| per-client → shared | Operator must supply a new shared PIN.  All `group_member_pins` rows for the group deleted.  Existing grants kept; expire normally. |

#### 8d · Mobile

- Locked-libraries surface gains an `enrollment_required` branch: card title "Set up a PIN for this group" instead of "Enter PIN", explanatory copy ("Each device picks its own PIN.  Only this device knows it.  If forgotten, your operator can reset.").  Routes to enrollment modal.
- Enrollment modal: PIN field + "Confirm PIN" re-entry to catch typos + Submit.
- Unlocked groups card unchanged (a grant is a grant).

#### 8e · Desktop

- Edit / Create dialog PIN section — segmented picker at the top: **Shared PIN** vs **Per-client PIN**.
  - Shared (default): existing shared-PIN UI (current M4).
  - Per-client: PIN field hidden; explanatory text + footnote "Members enroll on first access; reset individual PINs from the Members tab."
- Detail panel — when group is per-client mode, member list rows gain an *enrollment state* badge (Enrolled / Not enrolled) + per-row "Clear PIN" action.

#### 8f · Tests

- Per-client enroll → enter (correct + wrong) → rate limit → master override → clear by operator → re-enroll.
- Mode switch shared→per-client clears `pin_hash`, keeps grants.
- Mode switch per-client→shared deletes `group_member_pins`, keeps grants.
- Visibility resolution: `enrollment_required` and `awaiting_pin` correctly populated for the right group + member combinations.

#### 8g · Acceptance

- Operator can flip an existing shared-PIN group to per-client without losing visibility for any currently-unlocked member.
- A compromised device's PIN can be invalidated in isolation without forcing other members to re-enter.
- Forgot-PIN recovery path documented for both modes (shared = reset group PIN; per-client = operator clears that member's row, member re-enrolls).
- Migration 026 round-trip: pre-state with shipped M4 PIN groups → post-state has those groups still in `pin_model='shared'` with the same hash + same member behavior.

---

## 8 · Migration Strategy

Detail in §M5 above.  Three-line summary:

1. Manufacture Public; populate with every library; auto-add every approved client.
2. Existing groups + members carry; semantic of `allowed_libraries` flips (subtractive → additive).
3. One-time desktop banner warns operator that group visibility is now more permissive; they should audit.

**Rollback path:** keep migration 025 idempotent.  Down migration drops the new columns + tables but leaves data intact; an operator who wants to revert restores from a backup.

**Pre-migration audit checklist** (operator-facing doc, ships with the v1.5 release notes):

- For each existing group: is it acceptable that members will now see Public's libraries IN ADDITION to the group's restrictions?
- For PIN-able content: is it currently in a library that should be removed from Public + added to a new PIN-gated group?
- Are there any clients in zero groups today?  Post-migration they auto-join Public; verify Public has only the libraries they should see.

---

## 9 · Test Strategy

### 9.1 Unit / pure
- `get_visible_libraries` — exhaustive matrix over multi-group × time-window × PIN-grant × inactive × member-override (8+ combinations).
- PIN HMAC compare round-trip.
- PIN strength policy (reject 1234, 1111, sequences, repeats).
- Grant TTL math (session = 12 h, per-entry = 5 min).

### 9.2 Server integration
- Each list endpoint with a kid client + an unrestricted client → assert filtered result.
- PIN unlock end-to-end: enter wrong PIN 5x → lockout → wait 60s → enter right PIN → grant created.
- Master override: localhost call to `POST /groups/{id}/enter` without PIN body → 200, grant created.
- Migration 025 round-trip: pre-state with v1 groups + members + restrictions → post-state has Public + grants table + same memberships.

### 9.3 Manual smoke (operator on user's box)
1. Boot fresh server → Public auto-created with 0 libraries.
2. Create Movies + TV libraries → add Movies to Public.
3. Pair kid's tablet → on approve, joins Public.  Kid sees Movies; doesn't see TV.
4. Create Adults group with PIN 8472 + Adults Only library.  Add operator's tablet.  Operator's tablet sees Movies (Public).
5. Operator's tablet → Settings → Unlock libraries → see Adults locked → tap → PIN entry → enter 8472 → library list refreshes → Adults Only visible.
6. Wait 12 h (or short-circuit by editing the grant row) → library disappears → operator's tablet PIN-prompts on Adults navigation.
7. Reset PIN on Adults via desktop CP → operator's tablet's grant invalidated → re-PIN required.
8. Operator desktop CP → Clients screen → kid's tablet → "View as" → see kid's library list (Movies only).

### 9.4 Regression matrix
After M1-M7 lands, run the existing 577-test server suite + 14-mobile + desktop analyze.  Net new tests should land at +30 to +45 across the seven milestones.

---

## 10 · Edge Cases & Issues

These were flagged during owner-side discussion + earlier audit; pin them in the test suite or document explicitly.

### 10.1 Migration / data integrity

| # | Case | Handling |
|---|---|---|
| M1 | Operator's existing "Kids" group used `allowed_libraries=[Movies]` to *deny* TV.  Post-migration, kids see TV via Public. | Operator banner + audit checklist (§M5).  Operator manually moves TV out of Public and into an Adults / Family group. |
| M2 | Existing PIN-less groups with strict restrictions become more permissive | Same banner + audit. |
| M3 | Server upgrade in flight while a stream is active | Stream stays alive; gate decisions don't change mid-stream (`stream_sessions` semantic carries from §4.4 of `12_groups_remediation_plan.md`). |
| M4 | Two-stage migration (servers paused for the upgrade) | Migration is single-step; no two-stage required. |

### 10.2 Public group

| # | Case | Handling |
|---|---|---|
| P1 | Operator adds Movies to Public, then deletes Movies library | Public's `allowed_libraries` JSON references the deleted id; visibility resolution silently drops missing libraries.  No-op. |
| P2 | Operator removes all libraries from Public | Newly-paired clients see nothing.  Desktop CP banner: "Public group is empty — paired clients see no libraries". |
| P3 | Operator tries to delete Public via SQL CLI | `is_public` UNIQUE index doesn't prevent DELETE.  The `delete_group` API route does (rejects with 400).  Direct SQL writes are operator self-harm; not blocked by software. |
| P4 | Public group's status flipped to inactive | Server gate skips inactive groups.  All paired clients see only what other groups grant them.  If they're in zero other groups, they see nothing.  Operator-facing toggle: warn before allowing. |

### 10.3 PIN

| # | Case | Handling |
|---|---|---|
| PN1 | Operator forgets PIN | Reset PIN action on desktop CP.  Master override on localhost.  Worst case: SQLite CLI rewrites `pin_hash` directly (operator's machine, operator's call). |
| PN2 | Brute-force attack on the PIN | Rate limit: 5 fails in 60s per (client, group).  After 5 fails, lockout for 1 min escalating to 5 min after 20 fails in an hour. |
| PN3 | Operator distributes PIN to a kid (intentional or by accident) | Out of scope.  PIN is barrier-to-casual-access on a shared device; not real auth.  Documented in the create-PIN dialog: "Anyone who reads this PIN over your shoulder can access this group's content on this device." |
| PN4 | PIN mode `per-entry` is impractical | Documented as the strict mode for adult / sensitive content where the operator wants every visit to require PIN.  Default is `session`. |
| PN5 | Operator's own tablet locks itself out forever | Master override from localhost CP.  Always-available recovery path. |
| PN6 | PIN attempt ledger grows unbounded | Housekeep task prunes rows older than 24 h.  Same pattern as the existing `_close_orphaned_sessions`. |

### 10.4 Multi-group / membership

| # | Case | Handling |
|---|---|---|
| MG1 | Client in Public + Kids + Adults; only Adults has PIN | Pre-PIN: visible = Public ∪ Kids.  Post-PIN: visible = Public ∪ Kids ∪ Adults.  Lock: visible reverts. |
| MG2 | Time window on Public itself (operator sets 06:00-22:00) | Public group becomes time-gated.  Outside window, all paired clients see ONLY what their other groups grant.  Documented as a powerful but easily-misconfigured feature. |
| MG3 | Member's `time_window_override` extends past the group's window | Member's override wins.  Documented: override extends OR contracts the group's window for that member only. |
| MG4 | Member is removed from a group mid-stream | In-flight stream continues; next stream-start applies the new visibility. |
| MG5 | All groups inactive | Visibility = empty.  Mobile UI shows empty state with explanatory copy: "Server admin has disabled access to all groups.  Contact the operator." |

### 10.5 Mobile state

| # | Case | Handling |
|---|---|---|
| MS1 | Mobile app crashes / reinstalls | All in-memory grant state lost.  Server-side grants survive (they're per-client, not per-app-install).  On reopen, mobile re-fetches `/groups/{id}/grant-status` for each PIN-gated group it's a member of. |
| MS2 | Mobile shows a stale library list after the operator changes group config | `refreshSilent` polling already handles this (per `12_groups_remediation_plan.md` polling-cubit gotcha).  Cadence ~30s for the library list. |
| MS3 | Mobile attempts a stream-start with a stale file_id (after library was removed from a group) | Server returns 403 → `PlayerGated` (M5 surface from `12_groups_remediation_plan.md` still applies).  Library list re-poll on `_GatedView` close. |
| MS4 | Mobile is paired with a server that's behind on the v1.5 migration | Server returns the v1 response shape (no `groups[].requires_pin` field).  Mobile's defaulted parser handles missing fields → falls back to v1 behavior.  Document the contract. |

### 10.6 "View as" debug

| # | Case | Handling |
|---|---|---|
| VA1 | Operator views as a client; client's PIN-gated grants don't apply (operator hasn't entered the kid's PIN) | "View as" simulates *current* visibility for the target client.  If client hasn't unlocked Adults, the operator sees what they'd see now (no Adults).  Honest. |
| VA2 | "View as" is exposed off-loopback | NEVER.  Endpoint is `require_local_caller` only.  Cross-tunnel callers get 403. |
| VA3 | Operator wants to see "what would the kid see if they were in 'Family' group right now" | Out of scope.  "View as" reflects current membership; for hypotheticals the operator manipulates membership directly. |

---

## 11 · Risks

| Risk | Mitigation |
|---|---|
| **Migration is more permissive** — existing groups grant more access post-migration than pre-migration | Operator audit banner (§M5).  Document explicitly in release notes.  Provide a "Group access audit" page on the desktop CP that lists every paired client's current visible libraries before + after migration. |
| **PIN flow on a shared family tablet is theater** | Documented in PIN create dialog.  Defense-in-depth: PIN is a barrier-to-casual-access; real security is the device-pairing layer + the operator's PIN secrecy. |
| **Mobile parser breakage on the v1.5 response shape** | All new fields defaulted on the Dart entity side.  Older mobile binaries pointed at a v1.5 server keep working with v1 semantics. |
| **Operator confusion about subtractive→additive flip** | One-page release notes + the desktop banner.  Audit checklist in `13_groups_v2_content_spaces.md` migration section. |
| **PIN brute-force from a sophisticated attacker** | 4-digit PIN has 10,000 combinations.  Rate limit + lockout caps attempts at ~7,200/day under sustained attack — meaningful but not impossible.  Honest about it: "PIN is barrier-to-casual-access; consider 6-digit minimum if the content is sensitive." |
| **Library list UI scales poorly with 50+ libraries** | Out of scope; v2 multi-tenant introduces this scale.  v1.5 home server has 5-10 libraries typically. |
| **Tier 2 "view as" reveals visibility logic to a savvy operator** | Acceptable; no security harm.  Power tool. |

---

## 12 · Out of Scope

This plan is the v1.5 / v1.6 redesign of an existing v1 feature.  Out of scope:

- **Multi-tenant cloud licensing** (v2; locked deferred per ADR-013).
- **Multi-server pairing on a single mobile client** (orthogonal to groups; documented in `03_open_questions.md`).
- **Real `bandwidth_cap_mbps` enforcement** (FFmpeg `-maxrate`/HLS rate-limit work — multi-day refactor of the streaming pipeline).
- **Real `max_rating` enforcement** (needs `media_files.rating` column + TMDB-side data + comparison ladder — multi-week project).
- **Group invitation / pre-paired groups** (Tier 4; defer to v2 multi-tenant).
- **Biometric unlock on mobile** (defer to v2.5).
- **Cross-server group federation** (v2 multi-tenant).
- **Per-group themes / chrome customization** (UX bloat; defer).
- **Per-user (vs per-device) profile model** (architectural rewrite; v2).

---

## 13 · Cross-references

- Roadmap: [`01_roadmap.md`](./01_roadmap.md) — Client Groups row currently ✅ Done (post-M1-M5); flip to "🔵 v1.5 redesign in progress" when M1 of this plan starts.
- Predecessor plan: [`12_groups_remediation_plan.md`](./12_groups_remediation_plan.md) — M1-M5 of the v1 model.  This plan reworks the model + adds PIN + Public + Tier 2 polish.
- Decisions: [`02_decisions.md`](./02_decisions.md) — when M1 lands, capture the subtractive→additive semantic flip as ADR-NN ("Groups model — content spaces, not restrictions").
- Manual tasks: [`04_manual_tasks.md`](./04_manual_tasks.md) — none here; all code work, no external service config.
- Ship readiness: [`05_ship_readiness.md`](./05_ship_readiness.md) — when M1 starts, restore a "Groups v2 redesign in progress" row under polish gaps.
- Database schema: [`../03_data/02_database_schema.md`](../03_data/02_database_schema.md) — update on migration 025 land with the new columns + tables.
- API contracts: [`../04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) — update on M1 (visible_libraries) + M4 (PIN endpoints) + M7 (view-as) lands.
- Backend architecture: [`../09_backend/01_backend_architecture.md`](../09_backend/01_backend_architecture.md) — group_service section gets the visibility-resolution function summary.
- Gotchas: [`../12_guidelines/03_gotchas.md`](../12_guidelines/03_gotchas.md) — v1 → v1.5 migration semantic flip is worth a gotcha entry; PIN-brute-force-on-shared-device is worth one too.
- Stream-gate work: predecessor / sibling plan in [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md) — informs the "in-flight streams continue past gate change" trade-off referenced in §10.4.
