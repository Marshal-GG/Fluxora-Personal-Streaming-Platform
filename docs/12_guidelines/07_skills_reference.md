# Claude Code Skills — Fluxora Reference

> Operational doc for the project-specific skills wired into Claude Code under `.claude/skills/`.
> Set up 2026-05-12. Lives in `docs/12_guidelines/` because the mirror-public workflow strips this folder — repo-internal tooling doesn't ship to the public mirror.
> Companion to [06_mcp_setup_and_usage.md](06_mcp_setup_and_usage.md).

---

## Why these exist

Skills are reusable instruction bundles loaded into Claude's context on demand. They encode a recurring Fluxora workflow (e.g. how to format an AGENT_LOG entry) so the agent doesn't have to re-read the spec doc on every session start. Two payoffs:

- **Less context burned** on boilerplate doc reads — the skill file is only loaded when invoked.
- **Consistency across sessions** — the canonical workflow is defined in one place; the skill points there.

Skills live in `.claude/skills/<name>/SKILL.md`. Each has YAML frontmatter (`name`, `description`) that Claude Code uses to surface the skill at the right moment, plus a body that becomes the operating prompt when invoked.

## Fluxora-specific skills

Five skills are checked into the repo. The `.claude/` folder used to be gitignored but is now tracked (with `.claude/scheduled_tasks.lock` and `.claude/settings.local.json` as targeted exclusions); the public-mirror workflow scrubs the whole `.claude/` tree at mirror time so internal tooling doesn't leak.

| Skill | What it does | Invoke when |
|---|---|---|
| **archive-plan** | Moves a fully-shipped plan from `docs/10_planning/<N>_<slug>.md` -> `docs/10_planning/archive/<N>_<slug>.md`, then updates every doc that links to it (roadmap, CLAUDE.md "Where the detail lives" table, current_status, cross-references). Includes a grep sweep for stale links. | "archive plan N", "plan N is done", or after the doc-sweep that closes out a milestone |
| **ci-status** | Runs `gh run list --limit 5 --branch=main`, parses the table, and if any recent run is `failure` auto-pulls the failing log lines through the standard error-grep regex. Encodes the common failure-shape -> root-cause table (black drift, FFmpeg missing on runner, ruff F401, etc.). | At session start (per CLAUDE.md mandatory rule), after the operator confirms a push, or any "check CI" / "is CI passing" / "did my push break anything" prompt |
| **doc-sweep** | Walks the Fluxora documentation update protocol checklist after a non-trivial code change. Cross-references the affected-file matrix from `docs/12_guidelines/02_documentation_update_protocol.md` so the agent doesn't re-read the protocol every time. | "update docs", "doc sweep", "make sure docs are aligned", or after any change that touches schema / endpoints / architecture / migrations / planning |
| **log-entry** | Appends a canonical AGENT_LOG.md entry following the format spec in `docs/12_guidelines/04_agent_log_format.md` (Title Case headers, `[tagged]` header line, 3-column Files Created / Modified table, Docs Updated section, Next Agent Should section). Encodes the append-only rule. | When closing out a session that produced meaningful work |
| **new-plan** | Scaffolds a new planning doc at `docs/10_planning/<N>_<slug>.md` using the canonical structure from plans 18-21 (Context / Decisions / Behavior matrix / Migration / Server changes / Client changes / Tests / Milestones / Files touched / Sharp edges). Auto-picks the next plan number by scanning both active and archive dirs. | "create a plan", "draft a plan", "new plan doc", or whenever a feature warrants planning before code — DB migrations, multi-app changes, new endpoint families, architectural shifts |

## Built-in vs project-specific

Claude Code also ships **built-in** and **plugin-provided** skills (visible in the system-reminder list at session start). Examples:

- `update-config`, `keybindings-help`, `fewer-permission-prompts` — Claude Code config helpers
- `simplify`, `review`, `security-review`, `init` — code-quality / review helpers
- `loop`, `schedule` — execution control (recurring tasks, cron-like remote agents)
- `claude-api` — Anthropic SDK migration helper

These are not stored in `.claude/skills/` and are not Fluxora-specific. Treat them as part of Claude Code itself; this doc only covers the five we added.

## Invoking a skill

Two ways:

1. **Type the slash command** — `/archive-plan`, `/ci-status`, `/doc-sweep`, `/log-entry`, `/new-plan`. Claude Code surfaces a one-line confirmation, then the skill body loads as Claude's operating prompt.
2. **Phrase-trigger** — the descriptions above each match natural phrasings ("plan 21 is done" -> archive-plan, "check CI" -> ci-status). Claude reads the descriptions on every turn and self-invokes when one matches.

Both routes go through the `Skill` tool internally. Agents can invoke their own skills — no human-in-the-loop needed once the trigger fires.

## Adding a new skill

Two files, two minutes:

1. **`.claude/skills/<kebab-name>/SKILL.md`** — frontmatter + body.

   ```yaml
   ---
   name: my-skill-slug
   description: One paragraph. Be specific about the trigger phrases and what the skill does — Claude reads this description on every turn to decide when to surface the skill. Vague descriptions get missed; concrete ones get used.
   ---

   # Skill title

   Body becomes Claude's operating prompt when the skill is invoked. Write it as instructions, not docs. Reference canonical specs by path (e.g. `docs/12_guidelines/04_agent_log_format.md`) instead of inlining them — keeps the skill small and the spec authoritative.
   ```

2. **Test it** — restart Claude Code (or run `/help` to refresh the skill list), then type `/<your-skill>` to verify it surfaces.

No package install, no separate registry, no allowlisting needed — `.claude/skills/` is loaded automatically.

## Where this overlaps with MCP

| Concern | Skill or MCP? |
|---|---|
| "Encode a project-specific text workflow" (log format, plan structure, doc sweep) | **Skill** |
| "Call an external tool / service" (Dart Analyzer, SQLite, GitHub) | **MCP** |
| "Encode a workflow that calls an MCP" | Both — skill body invokes MCP tools |

The `ci-status` skill is a good example of the overlap: it's a skill (encodes the agent prompt + failure-shape table), but its action is to call `Bash(gh run list ...)`, which is just a shell tool. The MCP layer is for true protocol-level integrations (Dart DTD, SQLite); skills are a lighter wrapper around any tool the agent already has.

## Public mirror behavior

The `.claude/` folder ships in the **private** repo but is scrubbed from the **public mirror** by `.github/workflows/mirror-public.yml`. The mirror also strips `docs/12_guidelines/` — so this doc itself, plus 05 (gh CLI) and 06 (MCP setup), are private-only. If you fork the public mirror, you won't see the skills or this doc; that's intentional.
