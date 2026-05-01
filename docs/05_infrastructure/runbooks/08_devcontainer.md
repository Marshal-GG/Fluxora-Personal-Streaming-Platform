# Runbook: Devcontainer / consistent local dev environment

> **What:** A `.devcontainer/` config so contributors get an identical dev environment in seconds, not "works on my machine" hours. Works locally with VS Code's Dev Containers extension, and remotely via GitHub Codespaces with zero extra setup.
> **Estimated time:** 30 minutes to set up the first time; 1 minute for any contributor to start using it.

---

## When this is worth doing

- ✅ The "first 30 minutes" setup in your `CONTRIBUTING.md` has more than 5 steps
- ✅ Your project requires specific tool versions (Python 3.11, Node 22, Flutter 3.32)
- ✅ Contributors include people on different OSes (Windows, macOS, Linux)
- ✅ You want GitHub Codespaces support
- ✅ You hit "works on my machine" issues during pair debugging

If your project is single-language, single-OS, single-developer, and the install is `pip install -e .[dev]`, you can skip this runbook.

---

## What devcontainers do

Define a Docker image + VS Code config in a `.devcontainer/devcontainer.json` file. Anyone who opens the repo in VS Code with the Dev Containers extension gets prompted to "Reopen in Container." VS Code spins up a fresh container with all your tools pre-installed, mounts the repo into it, attaches the editor.

The container is **ephemeral** — it's recreated from scratch on demand. You don't manage it; you just edit `devcontainer.json` and rebuild.

In Codespaces, the same `devcontainer.json` powers the cloud-hosted dev environment. Free tier covers 60 hours/month for personal accounts.

---

## Step 1 — Pick a base image

Microsoft maintains official "dev container" images for common languages. Use these as a base — they include the language runtime, common tools, and a non-root user:

| Tooling | Image |
|---------|-------|
| Python | `mcr.microsoft.com/devcontainers/python:1-3.11` |
| Node | `mcr.microsoft.com/devcontainers/javascript-node:22` |
| Go | `mcr.microsoft.com/devcontainers/go:1` |
| Rust | `mcr.microsoft.com/devcontainers/rust:1` |
| .NET | `mcr.microsoft.com/devcontainers/dotnet:1-8.0` |
| Multi-language base | `mcr.microsoft.com/devcontainers/universal:2` |

For Fluxora's stack (Python + Flutter + Node), the Universal base or a custom Dockerfile is the right choice. Flutter is too heavy / bespoke for any official base.

---

## Step 2 — Create `.devcontainer/devcontainer.json`

Here's a working template for a Python-server project (Fluxora's `apps/server` for example):

```json
{
  "name": "Project Dev Container",
  "image": "mcr.microsoft.com/devcontainers/python:1-3.11",

  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true,
      "configureZshAsDefaultShell": true
    }
  },

  "postCreateCommand": "pip install -e '.[dev]' && pre-commit install",

  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.black-formatter",
        "charliermarsh.ruff",
        "ms-python.mypy-type-checker",
        "tamasfe.even-better-toml",
        "redhat.vscode-yaml"
      ],
      "settings": {
        "python.defaultInterpreterPath": "/usr/local/bin/python",
        "[python]": {
          "editor.formatOnSave": true,
          "editor.defaultFormatter": "ms-python.black-formatter",
          "editor.codeActionsOnSave": {
            "source.fixAll.ruff": "explicit",
            "source.organizeImports.ruff": "explicit"
          }
        }
      }
    }
  },

  "forwardPorts": [8080],
  "portsAttributes": {
    "8080": {
      "label": "Server",
      "onAutoForward": "notify"
    }
  },

  "remoteUser": "vscode"
}
```

Key parts:

- **`image`** — base image with Python + tools
- **`features`** — pre-built add-ons (GitHub CLI, common shells, etc.) — see [containers.dev/features](https://containers.dev/features)
- **`postCreateCommand`** — runs once, after the container is built. Install your project deps here
- **`customizations.vscode.extensions`** — VS Code auto-installs these inside the container
- **`forwardPorts`** — exposes container ports to your host so `localhost:8080` works
- **`remoteUser`** — runs commands as a non-root user (matches host UID for clean file permissions)

---

## Step 3 — For multi-language projects, use a Dockerfile

If you need Python AND Node AND Flutter in the same container, the official base images won't cut it. Create `.devcontainer/Dockerfile`:

```dockerfile
FROM mcr.microsoft.com/devcontainers/python:1-3.11

# Node
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y nodejs

# Flutter
ARG FLUTTER_VERSION=3.32.0
RUN apt-get update && apt-get install -y curl unzip xz-utils libglu1-mesa \
 && curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
    | tar xJ -C /opt \
 && chown -R vscode:vscode /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

# Cloudflared (for tunnel testing)
RUN curl -L --output /usr/local/bin/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
 && chmod +x /usr/local/bin/cloudflared

USER vscode
RUN flutter doctor
```

And in `devcontainer.json`:

```json
{
  "name": "Fluxora dev",
  "build": {
    "dockerfile": "Dockerfile"
  },
  ...
}
```

---

## Step 4 — Mount secrets without committing them

Secrets don't go in the container image — see [`05_secrets_management.md`](./05_secrets_management.md). Mount them at runtime instead.

For Codespaces / VS Code Dev Containers:

```json
{
  ...
  "mounts": [
    "source=${localEnv:HOME}/.fluxora,target=/home/vscode/.fluxora,type=bind,consistency=cached"
  ]
}
```

This mounts the host's `~/.fluxora` (where the `.env` lives) into the container at the same path. Your code reads `~/.fluxora/.env` exactly like it does on the host.

For Codespaces specifically, secrets can come from GitHub Codespaces secrets:

```json
{
  ...
  "remoteEnv": {
    "TOKEN_HMAC_KEY": "${localEnv:TOKEN_HMAC_KEY}"
  }
}
```

GitHub Settings → Codespaces → Codespaces secrets → add per-secret values, scope them to specific repos. The container gets them as env vars without ever being in source.

---

## Step 5 — `postCreateCommand` patterns

Common things to run once after the container is built:

```json
"postCreateCommand": "bash .devcontainer/post-create.sh"
```

`.devcontainer/post-create.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Install Python deps
pip install -e 'apps/server/[dev]'

# Install pre-commit hooks
pre-commit install

# Pull Flutter packages
(cd packages/fluxora_core && flutter pub get) || true
(cd apps/mobile && flutter pub get) || true
(cd apps/desktop && flutter pub get) || true

# Pull Node deps
(cd apps/web_landing && npm ci) || true

echo "Dev container ready."
```

Keeping this in a script (vs. inline JSON) lets you `chmod +x` it, version-control it, and edit without re-typing escapes.

---

## Step 6 — Test the container

Local (VS Code Dev Containers extension):
1. Open the repo in VS Code
2. Press F1 → "Dev Containers: Rebuild and Reopen in Container"
3. Wait for build (first time: 5–10 min, then cached for next time)
4. Run your normal dev commands inside the container's terminal

Codespaces:
1. Push the `.devcontainer/` to a branch
2. GitHub repo → Code → Codespaces tab → Create codespace
3. Same `.devcontainer/` powers the cloud env

---

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| File permission errors after editing in container | Container user UID doesn't match host UID | Use `remoteUser: "vscode"` (UID 1000) — matches most host setups; on weirder hosts, set `containerUser` and `updateRemoteUserUID` |
| `flutter doctor` shows missing Android SDK | Android SDK is huge, not in the image | Don't try to support Android builds inside the container — use the host for that |
| `git push` from container prompts for password | Container has no SSH keys | Mount `~/.ssh` in: `"mounts": ["source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"]` |
| Slow file system performance on macOS | Default Docker file mount is slow on Mac | Add `,consistency=cached` to mounts |
| Container builds every time you open the repo | No cache | Use `"runArgs": ["--cache-from", "type=gha"]` or accept the rebuild on cold start |

---

## When NOT to use devcontainers

- **Native dev requiring host hardware:** GPU, Bluetooth, USB devices, iOS Simulator — these don't pass through into containers cleanly. Build for those on the host.
- **Performance-critical local builds:** Container file I/O has overhead. If you're rebuilding 10x per minute, the host is faster.
- **Tiny solo projects:** The container config is more code than your project. Use a simple `.envrc` instead.

---

## Cross-references

- **Repo init checklist:** [`07_repo_init_checklist.md`](./07_repo_init_checklist.md)
- **Where secrets live (don't bake into image):** [`05_secrets_management.md`](./05_secrets_management.md)
- **Containers.dev spec:** [containers.dev/implementors/json_reference](https://containers.dev/implementors/json_reference/)
