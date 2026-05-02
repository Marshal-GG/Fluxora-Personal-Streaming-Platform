# Fluxora — Project Overview

> **Status:** Phases 1-4 complete. Phase 5 in progress.  
> **Created:** 2026-04-27  
> **Last Updated:** 2026-05-03

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

### Product & architecture
- [Vision & Goals](../01_product/01_vision.md)
- [Tier Feature Matrix](../01_product/08_tier_features.md) — canonical Free/Plus/Pro/Ultimate breakdown
- [System Architecture](../02_architecture/01_system_overview.md)
- [Tech Stack](../02_architecture/02_tech_stack.md)
- [Roadmap](../10_planning/01_roadmap.md)
- [Architecture Decisions (ADRs)](../10_planning/02_decisions.md)
- [Manual / External Tasks (TODO)](../10_planning/04_manual_tasks.md) — third-party signups + dashboard work
- [Desktop Redesign Plan](../11_design/desktop_redesign_plan.md)
- [Web Landing Redesign Plan](../11_design/web_landing_redesign_plan.md)

### API & data
- [API Contracts](../04_api/01_api_contracts.md)
- [API Versioning Policy](../04_api/02_versioning_policy.md)
- [Data Models](../03_data/01_data_models.md)
- [Database Schema](../03_data/02_database_schema.md)
- [Migration Writing Guide](../03_data/04_migration_guide.md)

### Infrastructure & operations
- [Infrastructure & CI/CD](../05_infrastructure/01_infrastructure.md)
- [URL Inventory](../05_infrastructure/02_url_inventory.md) — all REST/WS endpoints, public hostnames, third-party URLs, future URLs
- [Polar Webhook Deployment](../05_infrastructure/02_polar_webhook_deployment.md)
- [Public Routing Plan (v1 + v2)](../05_infrastructure/03_public_routing.md)
- [Domains & Subdomains Inventory](../05_infrastructure/04_domains_and_subdomains.md)
- [Backup & Disaster Recovery](../05_infrastructure/05_backup_and_recovery.md)
- [WebRTC & TURN Operations](../05_infrastructure/06_webrtc_and_turn.md)
- **[Reusable Runbooks](../05_infrastructure/runbooks/)** — project-agnostic playbooks (Cloudflare Tunnel, Firebase Hosting, GitHub CI, Branch/PR workflow)

### Security
- [Security Overview](../06_security/01_security.md)
- [License Key Operations](../06_security/02_license_key_operations.md)

### Repo
- [Folder Structure](./folder_structure.md)
- [Contributing Guide](../../CONTRIBUTING.md)
- [Agent Work Log](../../AGENT_LOG.md)
