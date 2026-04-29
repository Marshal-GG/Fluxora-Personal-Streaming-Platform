# Fluxora — Project Overview

> **Status:** Phases 1-4 complete. Phase 5 active.  
> **Created:** 2026-04-27  
> **Last Updated:** 2026-04-29

---

## What is Fluxora?

Fluxora is a **self-hosted hybrid media streaming system** — think "Plex meets Syncthing."
It lets users stream their personal media library (movies, TV, music, documents) to any device,
automatically switching between LAN (fast, direct) and Internet (WebRTC/STUN/TURN) connections
without user intervention.

**Key constraint:** Everything must work with zero cloud dependency. The server runs as a standalone
Python/FastAPI executable on the user's home machine.

---

## Documentation Index

| # | Category | Description | Status |
|---|----------|-------------|--------|
| 00 | [Overview](../00_overview/) | Project summary, folder structure, index | ✅ Written |
| 01 | [Product](../01_product/) | Vision, requirements, user stories | ✅ Written |
| 02 | [Architecture](../02_architecture/) | System design, tech stack, component diagrams | ✅ Written |
| 03 | [Data](../03_data/) | Data models, schemas, flows | ✅ Written |
| 04 | [API](../04_api/) | REST + WebSocket API contracts | ✅ Written |
| 05 | [Infrastructure](../05_infrastructure/) | Deployment, CI/CD, distribution | ✅ Written |
| 06 | [Security](../06_security/) | Auth, permissions, threat model | ✅ Written |
| 07 | [AI & ML](../07_ai_ml/) | AI features — Phase 5 only | ✅ Written |
| 08 | [Frontend](../08_frontend/) | Flutter architecture, screen map | ✅ Written |
| 09 | [Backend](../09_backend/) | FastAPI structure, service map | ✅ Written |
| 10 | [Planning](../10_planning/) | Roadmap, milestones, ADRs | ✅ Written |
| 11 | [Design](../11_design/) | Brand system, color palette, UI concepts | ✅ Written |

---

## Repository Root Files

| File | Purpose |
|------|---------|
| [`CLAUDE.md`](../../CLAUDE.md) | AI agent onboarding guide and mandatory rules |
| [`AGENT_LOG.md`](../../AGENT_LOG.md) | Append-only log of all agent work sessions |
| [`DESIGN.md`](../../DESIGN.md) | Design system — Google Stitch spec format |
| [`README.md`](../../README.md) | Project introduction and structure |
| [`.gitignore`](../../.gitignore) | Git ignore rules for Python + Flutter + OS artifacts |

---

## Quick Links

- [Vision & Goals](../01_product/01_vision.md)
- [System Architecture](../02_architecture/01_system_overview.md)
- [Tech Stack](../02_architecture/02_tech_stack.md)
- [Data Models](../03_data/01_data_models.md)
- [API Contracts](../04_api/01_api_contracts.md)
- [Roadmap](../10_planning/01_roadmap.md)
- [Folder Structure](./folder_structure.md)
- [Agent Work Log](../../AGENT_LOG.md)
