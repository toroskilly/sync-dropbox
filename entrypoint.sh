#!/bin/bash
set -euo pipefail

PUID=${PUID:-1000}
PGID=${PGID:-1000}

# ── Timezone ──────────────────────────────────────────────────────────────────
if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
fi

# ── UID / GID remapping ───────────────────────────────────────────────────────
if [ "$(id -g dropbox)" != "$PGID" ]; then
    groupmod -o -g "$PGID" dropbox
fi
if [ "$(id -u dropbox)" != "$PUID" ]; then
    usermod -o -u "$PUID" dropbox
fi

# ── Directory permissions ─────────────────────────────────────────────────────
mkdir -p "/config/maestral" "${DROPBOX_PATH:-/dropbox}"
chown -R dropbox:dropbox /config "${DROPBOX_PATH:-/dropbox}"

# ── Start ─────────────────────────────────────────────────────────────────────
# run_daemon.py handles link detection, waiting, path config, and sync start.
exec gosu dropbox python3 /run_daemon.py
