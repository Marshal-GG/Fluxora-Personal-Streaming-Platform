# Claude Code MCP Servers — Setup & Usage

> Operational doc for the Model Context Protocol servers wired into Claude Code on this machine.
> Set up 2026-05-12. Lives in `docs/12_guidelines/` because the mirror-public workflow strips this folder — repo-internal tooling doesn't ship to the public mirror.

---

## Why it exists

MCP (Model Context Protocol) gives Claude Code structured tool access beyond what `Bash`/`Read`/`Edit` provide. For Fluxora we wire two:

| MCP | Purpose | Backend |
|---|---|---|
| **dart** | Inspect a live Flutter app (widget tree, runtime errors, logs), trigger hot reload/restart, drive the UI, list devices. Also exposes Dart Analysis Server tools but those are unusably slow on this monorepo — see Gotchas. | `dart mcp-server` (stdio) |
| **fluxora-db** | Query the server's SQLite DB at `~/AppData/Roaming/Fluxora/fluxora.db` — list tables, read schema, run SELECTs. Useful for inspecting library scans, session state, migration verification without hand-rolling SQL through `sqlite3`. | `npx -y mcp-sqlite` (stdio) |

Saves the "screenshot the widget inspector / paste a sql query into a separate terminal" round-trip during agent sessions.

## What's configured

Verify with:

```powershell
claude mcp list
```

Expected output:

```
claude.ai Google Drive: https://drivemcp.googleapis.com/mcp/v1 - ! Needs authentication
dart: dart mcp-server - + Connected
fluxora-db: npx -y mcp-sqlite C:/Users/marsh/AppData/Roaming/Fluxora/fluxora.db - + Connected
```

Both Fluxora-relevant MCPs are at **user scope** (`~/.claude.json` under the `mcpServers` key). User scope means they're available in every project on this machine, not pinned to this repo. The Google Drive MCP is Claude.ai's hosted server — not used for Fluxora, listed for completeness.

## Install / setup (one-time, already done on this machine)

### Dart MCP

```powershell
# Requires Dart SDK 3.7+ already on PATH (the Flutter SDK ships it).
claude mcp add dart "dart mcp-server" --scope user
```

The Dart MCP ships as part of the Dart SDK starting 3.7 — nothing to pub-install. The command above just registers it with Claude Code.

### fluxora-db MCP

```powershell
claude mcp add-json fluxora-db '{"type":"stdio","command":"npx","args":["-y","mcp-sqlite","C:/Users/marsh/AppData/Roaming/Fluxora/fluxora.db"]}' --scope user
```

Notes:
- Package name is `mcp-sqlite` (NPM, by jparkerweb) — *not* `jparkerweb-mcp-sqlite` or similar. We learned this the hard way.
- The DB path is passed as a **positional CLI arg**, not an env var.
- Use **forward slashes** in the path. Backslashes in the path stored in `~/.claude.json` triggered a slash-mismatch with the project-key lookup on Windows that prevented the MCP from loading; user scope sidesteps that issue.
- `npx -y` auto-installs the package on first invocation; cached after.

### Re-adding after a wipe

If `claude mcp remove <name>` was run and you need to put it back, just rerun the `add` / `add-json` command. No other state to restore.

## How to use

### Dart MCP — connecting to a running Flutter app

Most Dart MCP tools need a **Dart Tooling Daemon (DTD)** connection to your running app. The DTD URI is per-app-launch — it changes every time you restart the app.

**Workflow:**
1. Start the desktop or mobile app (VS Code debug button, or `flutter run` from the app dir).
2. In VS Code: `Ctrl+Shift+P` -> **"Dart: Copy DTD Uri to Clipboard"**.
3. Tell Claude "connect" — it runs `scripts/get-dtd-uri.ps1` to read the URI from your clipboard, validate the `ws://127.0.0.1:PORT/TOKEN=` shape, cache to `.claude/dtd_uri.txt` (gitignored), and call `connect_dart_tooling_daemon`.

The connection persists for the rest of that Claude Code session (across hot reloads / restarts of the app). It does NOT persist across:
- App full restart (new DTD URI generated — re-copy)
- Closing/reopening Claude Code (MCP process resets)

**Tools that work fast (running-app VM service):**

| Tool | What it does |
|---|---|
| `get_widget_tree` | Full widget hierarchy with properties + layout sizes |
| `get_selected_widget` | The widget you picked in DevTools' Inspector |
| `get_runtime_errors` | Recent uncaught exceptions in the running app |
| `get_app_logs` | Logger output (only for apps Claude launched via `launch_app`) |
| `get_active_location` | Current editor cursor file/line |
| `hot_reload` / `hot_restart` | Push code changes to the live app |
| `launch_app` / `stop_app` | Spawn / kill a Flutter app from Claude |
| `flutter_driver` | Programmatically tap/scroll/navigate |
| `list_devices` / `list_running_apps` | Inventory |
| `set_widget_selection_mode` | Toggle DevTools' Inspector pick mode |

**Tools that work but are slow on this codebase (subprocess CLI):** `dart_format`, `pub_dev_search`, `pub`, `run_tests`, `dart_fix`. Allowlisted only where they save the agent a Bash round-trip.

### fluxora-db MCP — read-only inspection

No connection step — the MCP opens the SQLite file directly.

| Tool | What it does |
|---|---|
| `list_tables` | All tables in the DB |
| `get_table_schema` | CREATE TABLE statement for one table |
| `query` | Run arbitrary SQL (read or write) |
| `read_records` | SELECT with filter |
| `db_info` | DB metadata (size, page count, etc.) |
| `create_record` / `update_records` / `delete_records` | Write helpers — **not allowlisted** by default; require approval per call |

Useful for: verifying a migration ran, checking what's in `client_codec_blocklist` after an auto-fallback fired, inspecting `media_files` after a scan.

## Allowlist (`.claude/settings.json`)

Currently allowlisted under `permissions.allow`:

- **Dart MCP read-only / running-app**: `mcp__dart__list_running_apps`, `list_devices`, `connect_dart_tooling_daemon`, `get_widget_tree`, `get_selected_widget`, `get_runtime_errors`, `get_app_logs`, `get_active_location`, `pub_dev_search`, `dart_format`
- **DTD URI script**: `Bash(powershell.exe -NoProfile -File scripts/get-dtd-uri.ps1)`

**Deliberately NOT allowlisted** — require per-call approval:
- Dart MCP **analysis-server family** (`analyze_files`, `resolve_workspace_symbol`, `read_package_uris`, `hover`, `signature_help`) — see Gotchas. Use Bash `flutter analyze` / Grep instead.
- Dart MCP **app-control** (`launch_app`, `stop_app`, `hot_reload`, `hot_restart`, `flutter_driver`, `set_widget_selection_mode`) — these mutate your running session.
- fluxora-db **writes** (`create_record`, `update_records`, `delete_records`, `query` when SQL contains INSERT/UPDATE/DELETE/DROP/etc.).

To add or remove, edit `.claude/settings.json` directly or via the `/permissions` slash command in Claude Code.

## Gotchas

### Dart MCP analysis-server tools are unusably slow (~2 min per call)

The `analyze_files`, `resolve_workspace_symbol`, `read_package_uris`, `hover`, and `signature_help` tools all talk to an embedded **Dart Analysis Server**. On this monorepo the DAS has to walk 3 pubspecs (`apps/desktop`, `apps/mobile`, `packages/fluxora_core`) plus everything else under the workspace root (`apps/server`, `apps/web_landing/node_modules` — huge on Windows + Defender). Cold start is 2-5 minutes. The MCP doesn't keep DAS warm in a useful way for our calling pattern.

**Workaround:** use Bash equivalents — they return in 5-10s because they talk to a long-lived DAS spawned by VS Code:
- `analyze_files` -> `cd <app dir> && flutter analyze`
- `resolve_workspace_symbol` -> Grep tool
- `read_package_uris` -> Glob / Read under `lib/`
- `hover` / `signature_help` -> Read the source directly

The running-app tools (above) don't go through DAS and are instant.

### DTD URI is ephemeral

Restarting the app generates a new DTD URI (new port + new token). The cached `.claude/dtd_uri.txt` will be stale after a restart — re-copy before reconnecting. `scripts/get-dtd-uri.ps1` warns when it falls back to cache.

### `npx -y` first-run latency

`fluxora-db`'s first invocation after a clean npm cache takes ~10-20s to download `mcp-sqlite`. Cached invocations are sub-second. If the MCP fails to connect on a brand-new machine, that's why — give it one more try after npm finishes.

### MCP server logs

Claude Code writes MCP server stderr to `~/.claude/projects/<project-slug>/mcp-logs-<name>/`. Useful when an MCP claims to be "Connected" in `claude mcp list` but tools time out or return empty.

## Verifying the setup end-to-end

1. `claude mcp list` -> both `dart` and `fluxora-db` show `+ Connected`.
2. Start the desktop app, copy DTD URI, run `powershell.exe -NoProfile -File scripts/get-dtd-uri.ps1` -> prints the URI.
3. In a Claude session: ask for `list_devices` (Dart MCP) -> returns Windows + Chrome + Edge. Ask for `list_tables` (fluxora-db) -> returns the Fluxora schema.

If any of those fail, check `claude mcp list` first, then the MCP server logs.
