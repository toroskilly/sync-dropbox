#!/bin/bash
set -euo pipefail

PUID=${PUID:-1000}
PGID=${PGID:-1000}
CONFIG_NAME=${DROPBOX_CONFIG_NAME:-maestral}
SYNC_PATH=${DROPBOX_PATH:-/dropbox}

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
mkdir -p "/config/maestral" "${SYNC_PATH}"
chown -R dropbox:dropbox /config "${SYNC_PATH}"

# ── Helpers ───────────────────────────────────────────────────────────────────
run_maestral() {
    gosu dropbox maestral "$@"
}

is_linked() {
    local cfg="/config/maestral/${CONFIG_NAME}.ini"
    [ -f "$cfg" ] && grep -q "account_id" "$cfg"
}

configure_sync_path() {
    # Use Maestral's Python API directly — the CLI key name varies by version.
    gosu dropbox python3 - <<PYEOF
from maestral.config import MaestralConfig
import os
cfg = MaestralConfig("${CONFIG_NAME}")
try:
    current = cfg.get("sync", "path")
except Exception:
    current = ""
target = "${SYNC_PATH}"
if not current or current == os.path.expanduser("~/Dropbox"):
    print(f"[dropbox] Setting sync path to {target}")
    cfg.set("sync", "path", target)
PYEOF
}

# ── Account linking ───────────────────────────────────────────────────────────
if ! is_linked; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  Dropbox account not linked.                            │"
    echo "│                                                         │"
    echo "│  Open a second terminal and run:                        │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
    echo "  docker exec -it -u dropbox $(hostname) maestral auth link -c ${CONFIG_NAME}"
    echo ""
    echo "  Then follow the on-screen instructions to authorise."
    echo "  Syncing will start automatically once linked — no restart needed."
    echo ""

    # Signal trap: honour SIGTERM/SIGINT during the wait loop so
    # `docker stop` doesn't have to wait for the full timeout.
    _shutdown() { echo "[dropbox] Shutting down."; exit 0; }
    trap '_shutdown' TERM INT

    while ! is_linked; do
        # Run sleep as a background job and wait on it so that an incoming
        # signal interrupts `wait` immediately rather than hanging until the
        # sleep interval expires.
        sleep 5 &
        wait $!
    done

    trap - TERM INT
    echo "[dropbox] Account linked successfully."
    configure_sync_path || echo "[dropbox] Warning: could not set sync path, using Maestral default."
fi

# ── Start Maestral ────────────────────────────────────────────────────────────
echo "[dropbox] Starting Maestral (config: ${CONFIG_NAME}, path: ${SYNC_PATH})"
exec gosu dropbox python3 /run_daemon.py
