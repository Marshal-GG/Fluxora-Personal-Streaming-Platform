# Documentation Update Protocol

> Follow this protocol when the user asks you to update docs — or when any code change requires a doc update.
> Never stop after updating just the obvious file.

---

## Step 1 — Identify every file that could be affected

Before writing a single word, run a mental (or literal `grep`) sweep against this checklist:

| File | Update when... |
|------|---------------|
| `docs/04_api/01_api_contracts.md` | Any endpoint added, removed, renamed, or response schema changed |
| `docs/03_data/01_data_models.md` | Any entity field added, removed, or renamed |
| `docs/03_data/02_database_schema.md` | Any table or column added, removed, or altered |
| `docs/03_data/03_data_flows.md` | Any data flow between layers changed |
| `docs/02_architecture/01_system_overview.md` | Any system-level design decision changed |
| `docs/02_architecture/02_tech_stack.md` | Any technology added, removed, or swapped |
| `docs/02_architecture/03_component_architecture.md` | Any component boundary or responsibility changed |
| `docs/09_backend/01_backend_architecture.md` | Any backend structure, service, or pattern changed |
| `docs/08_frontend/01_frontend_architecture.md` | Any Flutter screen, navigation, or pattern changed |
| `docs/05_infrastructure/01_infrastructure.md` | Any CI workflow, build process, or distribution method changed |
| `docs/05_infrastructure/02_url_inventory.md` | Any new URL surface (REST, WS, public host, third-party dep) added |
| `docs/06_security/01_security.md` | Any auth flow, threat model, or security control changed |
| `docs/10_planning/01_roadmap.md` | Any milestone started, completed, or descoped |
| `docs/10_planning/02_decisions.md` | Any architectural decision locked in |
| `docs/10_planning/03_open_questions.md` | Any open question answered or added |
| `docs/10_planning/04_manual_tasks.md` | Any manual / external operational task discovered, completed, cancelled, or changed (third-party signups, dashboard config, etc.). Code-side TODOs stay as `# TODO:` comments / GitHub issues — do NOT put them here |
| `docs/01_product/06_polar_product_setup.md` | Configuration steps for Polar.sh products changed |
| `docs/00_overview/README.md` | Status column of any doc changes; new doc added |
| `docs/00_overview/current_status.md` | Any significant progress is made (test counts, milestone status, feature lists) |
| `DESIGN.md` | Any color, spacing, typography, or component spec changed |
| `README.md` | Project-level summary, structure, or setup steps changed |
| `CLAUDE.md` | Any rule change. Tech stack / repo layout / phase status now live in `current_status.md` and the relevant docs — do NOT duplicate them in CLAUDE.md |
| `AGENT_LOG.md` | Every session — always append an entry |

## Step 2 — Cross-reference sweep

After identifying the files, **grep across all `.md` files** for the thing you changed:
- Renamed a field? Search for the old name — it may appear in 4 different docs.
- Changed an endpoint path? Search for the old path string everywhere.
- Changed a folder name? Search for the old path in every doc.
- Changed a tech decision? Search for the old technology name.

Never assume a term only appears in one place.

## Step 3 — Stale-section self-check

These surfaces silently rot:

| File / section | Goes stale when... |
|----------------|--------------------|
| `docs/00_overview/current_status.md` | Test counts, migration ranges, or feature lists change |
| `docs/00_overview/folder_structure.md` | Folders or major files added / renamed / removed |
| `docs/02_architecture/02_tech_stack.md` | Any dependency added, swapped, or removed |
| `docs/10_planning/01_roadmap.md` | Phase / milestone status changes |
| `docs/12_guidelines/03_gotchas.md` | A risk is mitigated or a new one discovered |

## Step 4 — Consistency checks

- All code examples in docs must use the **real current paths and API shapes** — not hypothetical ones.
- All cross-links between docs must resolve (no broken `[see X](../Y/Z.md)` links).
- All table columns must be complete — no empty cells unless the column is optional by design.
- All milestone statuses in `docs/10_planning/01_roadmap.md` must match `docs/00_overview/current_status.md`.
- All doc statuses in `docs/00_overview/README.md` must match the actual content state of each file.

## Step 5 — Completion declaration

Only declare the doc update complete when:
- [ ] Every file in Step 1 that is affected has been updated
- [ ] The cross-reference sweep in Step 2 found no stale references
- [ ] The stale-section self-check in Step 3 passed
- [ ] The consistency checks in Step 4 passed
- [ ] The AGENT_LOG.md entry lists every doc file touched
