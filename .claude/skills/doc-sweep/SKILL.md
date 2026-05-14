---
name: doc-sweep
description: Run the Fluxora documentation update protocol after shipping a milestone or non-trivial change. Use when the user says "update docs", "doc sweep", "make sure docs are aligned", or after any code change that affects schema / endpoints / architecture / migrations / planning. Loads the full sweep checklist + cross-reference rules without re-reading docs/12_guidelines/02_documentation_update_protocol.md every time.
---

# Documentation update protocol

Always follow this sweep in order. **Never stop after updating just the obvious file.**

## Step 1 — Identify every affected file

Match the change against this matrix:

| File | Update when... |
|------|---------------|
| `docs/04_api/01_api_contracts.md` | Endpoint added/removed/renamed; request/response schema changed; new query param, header, or status code |
| `docs/03_data/01_data_models.md` | Entity field added/removed/renamed; new entity created |
| `docs/03_data/02_database_schema.md` | Table or column added/removed/altered; new migration created; new index/constraint |
| `docs/03_data/04_migration_guide.md` | Any new migration file in `apps/server/database/migrations/` |
| `docs/03_data/03_data_flows.md` | Data flow between layers changed (e.g. new pipeline, new cache, new queue) |
| `docs/02_architecture/01_system_overview.md` | System-level design decision changed |
| `docs/02_architecture/02_tech_stack.md` | Dependency added/swapped/removed |
| `docs/02_architecture/03_component_architecture.md` | Component boundary or responsibility changed |
| `docs/09_backend/01_backend_architecture.md` | Server service, router, model, or migration added/changed; structure tree updated |
| `docs/08_frontend/01_frontend_architecture.md` | Flutter screen, navigation route, cubit, entity, or pattern changed |
| `docs/05_infrastructure/01_infrastructure.md` | CI workflow, build, or distribution changed |
| `docs/05_infrastructure/02_url_inventory.md` | New URL surface (REST, WS, public host, third-party dep) |
| `docs/06_security/01_security.md` | Auth flow, threat model, or security control changed |
| `docs/10_planning/01_roadmap.md` | Milestone started/completed/descoped; new plan drafted |
| `docs/10_planning/02_decisions.md` | Architectural decision locked in |
| `docs/10_planning/03_open_questions.md` | Open question answered or added |
| `docs/10_planning/04_manual_tasks.md` | Manual / external operational task discovered or completed |
| `docs/00_overview/current_status.md` | Test counts, migration ranges, feature lists, milestone status changed |
| `docs/00_overview/folder_structure.md` | Folders or major files added/renamed/removed |
| `docs/00_overview/README.md` | Status column of any doc; new doc added |
| `DESIGN.md` | Color, spacing, typography, or component spec changed |
| `CLAUDE.md` | A rule changed, or a new planning doc was archived (add a "Where the detail lives" row) |
| `docs/12_guidelines/03_gotchas.md` | A risk is mitigated or a new one discovered |
| `AGENT_LOG.md` | Always — follow the canonical format spec at `docs/12_guidelines/04_agent_log_format.md` |

## Step 2 — Cross-reference grep sweep

After updating, grep across **all `.md` files** for the things you changed:

- Renamed a field? Search for the **old** name (may appear in 4+ docs).
- Changed an endpoint path? Search for the old path string.
- Changed a folder name? Search for the old path.
- Changed a tech decision? Search for the old technology name.
- New migration number? Search for the previous "current migration range XXX".

Use `Grep` with the old token across `docs/` AND `apps/*/lib/**` AND `apps/server/**/*.py` — sometimes a code comment refers back to a doc heading.

## Step 3 — Stale-section self-check

Even if the change didn't touch these directly, scan them — they silently rot:

| File / section | Goes stale when... |
|----------------|--------------------|
| `docs/00_overview/current_status.md` | Test counts, migration ranges, feature lists change |
| `docs/00_overview/folder_structure.md` | Folders/files added/renamed/removed |
| `docs/02_architecture/02_tech_stack.md` | Dependency added/swapped/removed |
| `docs/10_planning/01_roadmap.md` | Phase / milestone status changes |
| `docs/12_guidelines/03_gotchas.md` | Risk mitigated or new one discovered |

## Step 4 — Consistency checks

- Code examples must use **real current paths + API shapes**, not hypothetical
- Cross-links between docs must resolve — no broken `[see X](../Y/Z.md)`
- Milestone statuses in `roadmap.md` must match `current_status.md`
- Doc statuses in `00_overview/README.md` must match each file's actual content state
- `current_status.md` lead paragraph dates must be in descending order (newest first)

## Step 5 — Plan archival (if shipping a plan to completion)

When a plan in `docs/10_planning/<N>_<name>.md` ships fully:

1. Move it to `docs/10_planning/archive/<N>_<name>.md`
2. Update the roadmap row's link to the new path + append "archived YYYY-MM-DD"
3. Update CLAUDE.md "Where the detail lives" row — keep the row but flip path to archive/
4. Search for any other docs that linked to the old path; update those too

## Step 6 — Completion gate

Don't declare done until:

- [ ] Every Step 1 file affected has been updated
- [ ] Step 2 grep found no stale references
- [ ] Step 3 self-check passed
- [ ] Step 4 consistency checks passed
- [ ] `AGENT_LOG.md` entry lists every doc touched (follow `docs/12_guidelines/04_agent_log_format.md`)
