---
name: new-plan
description: Scaffold a new Fluxora planning doc at docs/10_planning/<N>_<slug>.md with the canonical structure used by plans 18-21 (Context / Decisions / Behavior matrix / Migration / Server / Client / Tests / Milestones / Files touched / Sharp edges). Use when the user says "create a plan", "draft a plan", "new plan doc", or names a feature that warrants planning before code (DB migration, multi-app change, new endpoint family, architectural shift). The skill picks the next plan number automatically and emits a complete skeleton the agent fills in.
---

# Scaffold a new planning doc

## Step 1 — Pick the next plan number

```
ls docs/10_planning/*.md | grep -oE '^docs/10_planning/[0-9]+' | sed 's|.*/||' | sort -n | tail -1
```

Then `N = highest + 1`. Don't reuse archived numbers — they live in `docs/10_planning/archive/` and the next number must clear both directories. Confirm with a parallel `ls docs/10_planning/archive/*.md` check.

If the user didn't specify a slug, ask: short kebab-case name (e.g. `audio_decoding`, `webrtc_signaling`, `live_transcode_quality`). Keep it under 4 words. Look at sibling plans for the conventions; some use snake_case (`19_library_transcode_followups`) — match whatever the latest 3 plans use.

## Step 2 — Write the file

Path: `docs/10_planning/<N>_<slug>.md`. Use this template, filling in every `<placeholder>`:

```markdown
# Plan <N> — <Title Case Plan Name>

> **Status:** 🚧 Drafted <YYYY-MM-DD> — awaiting M1 sign-off
> **Layers on top of:** <prior plan numbers if any, e.g. "plan 20 (auto-mode fallback)">

## Context

<2-4 paragraphs. Why are we doing this? What real-world report or constraint
triggered the work? What's the current behavior + why is it inadequate?>

## Design decisions (locked in <YYYY-MM-DD>)

| Q | Decision |
|---|---|
| <design question> | <decision + 1-line rationale> |
| ... | ... |

## Behavior matrix

<When a feature has 2+ modes / 2+ codecs / 2+ states that interact, draw the
matrix BEFORE writing code. Saves the "wait we didn't think about X+Y" round-
trip. Copy plan 20's `| Mode | First attempt | On error |` shape or plan 21's
`| Mode | Source codec | Audio path | On error |` shape.>

## Migration

### <NNN> — <one-line purpose>

```sql
-- SQL, append-only per CLAUDE.md hard prohibition #9
```

<Repeat for every migration this plan needs. Pick the next migration number
from `apps/server/database/migrations/` — append-only, never reuse.>

## Server changes

### `services/<service>.py`

- <Bullet list of changes — new helpers, new constants, modified behavior>

### `routers/<router>.py`

- New endpoint `<METHOD> /api/v1/<path>` — body shape, response shape, status codes
- ...

### `models/<model>.py`

- New / extended Pydantic models

## Mobile + desktop player

### Mobile (`apps/mobile/lib/features/<feature>/...`)

- <What the player cubit / repository / screen needs>

### Desktop (`apps/desktop/lib/features/<feature>/...`)

- <Mirror the mobile pattern OR explain why desktop differs>

## Desktop UI

### `apps/desktop/lib/features/<feature>/...`

- <New screens / widgets / settings cards>

## Tests

### Server (~N new tests)

- `<test_name>` — what it asserts
- ...

### Mobile (~N new tests)

- ...

### Desktop (~N new tests)

- ...

## Milestones

| M | Title | Est. | Files |
|---|---|---|---|
| **M1** | <Migration + service> | <Xh> | <comma-separated paths> |
| **M2** | <Resolver / pipeline> | <Xh> | ... |
| **M3** | <Endpoint + response wiring> | <Xh> | ... |
| **M4** | <Mobile + desktop client> | <Xh> | ... |
| **M5** | <Tests sweep + doc-update protocol> | <Xh> | All `docs/` touched, AGENT_LOG entry |

**Total: ~<total>h**

## Files touched

```
apps/server/database/migrations/<NNN>_<slug>.sql            (new)
apps/server/models/<model>.py
apps/server/services/<service>.py                           (new if applicable)
apps/server/routers/<router>.py
apps/server/tests/<test>.py
apps/mobile/lib/features/<feature>/...
apps/desktop/lib/features/<feature>/...
docs/00_overview/current_status.md
docs/03_data/02_database_schema.md
docs/03_data/04_migration_guide.md
docs/04_api/01_api_contracts.md
docs/08_frontend/01_frontend_architecture.md
docs/09_backend/01_backend_architecture.md
docs/10_planning/01_roadmap.md
docs/12_guidelines/03_gotchas.md
```

## Sharp edges to watch

1. **<sharp edge title>** — <description; how to detect; mitigation if applicable>
2. ...

## Out of scope / future work

Deliberately not in plan <N>; surface as separate plans if needed:

- **<feature>** — <one-line reason it's deferred>
- ...
```

## Step 3 — Update roadmap

Add a row to `docs/10_planning/01_roadmap.md` after the latest plan's row:

```
| <Plan title> (plan <N>) | <Must|Should|Nice-to-have> | 🚧 Drafted <YYYY-MM-DD> — awaiting M1 sign-off | Plan: [`docs/10_planning/<N>_<slug>.md`](./<N>_<slug>.md).  <1-2 sentence summary of behavior + scope>. |
```

## Step 4 — Update CLAUDE.md

Add a row to the "Where the detail lives" table in CLAUDE.md, placed after the previous plan's row:

```
| <plan summary in 1 sentence (drafted YYYY-MM-DD or shipped YYYY-MM-DD)> | `docs/10_planning/<N>_<slug>.md` |
```

## Step 5 — Report

Tell the user: number picked, file created, roadmap + CLAUDE.md updated. Offer to start M1 if they sign off.

## Anti-patterns to avoid

- **Don't reserve numbers in advance** — only pick a number when actually drafting. The "drafted but never written" footprint pollutes search.
- **Don't write the implementation while drafting** — the plan is for alignment with the operator. Code comes after sign-off.
- **Don't skip the behavior matrix** when there are multiple modes / codecs / states. The matrix is the cheapest way to surface "wait, what about X+Y" before code is committed.
- **Don't forget archived numbers** when picking N. Always check both `docs/10_planning/` and `docs/10_planning/archive/`.
- **Don't pad with placeholder sections** — if a plan has no mobile changes, drop the "Mobile + desktop player" header entirely. Keep the doc honest.
