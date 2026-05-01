# Multi-language base for Fluxora: Python (server) + Flutter (mobile/desktop)
# + Node (web_landing) + FFmpeg (transcoding) + cloudflared (tunnel testing).
#
# Targets Linux only — devcontainer runs in a Linux container even on Windows /
# macOS hosts, so this image doesn't need to support multi-OS Flutter builds.
# Mobile/desktop release builds happen on the host or in CI, not in here.

FROM mcr.microsoft.com/devcontainers/python:1-3.11

ARG FLUTTER_VERSION=3.41.3
ARG NODE_MAJOR=22

# ── System packages ─────────────────────────────────────────────────────────
# - ffmpeg: required by the server's transcoding pipeline
# - sqlite3 CLI: lets you poke the DB directly from inside the container
# - libglu1-mesa, xz-utils, unzip: Flutter SDK dependencies
# - git, curl, ca-certificates: standard tooling Flutter + Node both rely on
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ffmpeg \
    sqlite3 \
    libglu1-mesa \
    xz-utils \
    unzip \
    git \
    curl \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# ── Node.js ─────────────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g npm@latest

# ── Flutter SDK ─────────────────────────────────────────────────────────────
RUN curl -L --output /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && chown -R vscode:vscode /opt/flutter \
 && git config --global --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

# ── cloudflared (for tunnel-related dev tasks) ──────────────────────────────
RUN curl -L \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
    -o /usr/local/bin/cloudflared \
 && chmod +x /usr/local/bin/cloudflared

USER vscode

# Pre-warm Flutter so first `flutter pub get` is fast inside the container.
# Skip Android — the container doesn't ship the Android SDK; mobile builds
# happen on the host or in CI.
RUN flutter config --no-analytics --no-cli-animations \
 && flutter precache --linux --no-android --no-ios --no-windows --no-macos \
 || true
