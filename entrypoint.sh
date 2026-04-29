#!/bin/bash
set -euo pipefail

PUID=${PUID:-1000}
PGID=${PGID:-1000}
CONFIG_NAME=${DROPBOX_CONFIG_NAME:-personal}
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
    local cfg="/config/maestral/${CONFIG_NAME}.ini"
    if ! grep -q "^local_dropbox_path" "$cfg" 2>/dev/null; then
        echo "[dropbox] Setting sync path to ${SYNC_PATH}"
        run_maestral config set local_dropbox_path "${SYNC_PATH}" -c "$CONFIG_NAME"
    fi
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
    echo "  docker exec -it -u dropbox $(hostname) maestral auth link"
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
    configure_sync_path
fi

# ── Logging ───────────────────────────────────────────────────────────────────
# Ensure sync activity is visible via `docker logs` at INFO level (20).
run_maestral config set log_level 20 -c "$CONFIG_NAME" 2>/dev/null || true

# ── Start Maestral ────────────────────────────────────────────────────────────
echo "[dropbox] Starting Maestral (config: ${CONFIG_NAME}, path: ${SYNC_PATH})"
exec gosu dropbox maestral start --foreground --verbose -c "$CONFIG_NAME"
