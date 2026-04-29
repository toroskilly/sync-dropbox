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
CURRENT_UID=$(id -u dropbox)
CURRENT_GID=$(id -g dropbox)

if [ "$CURRENT_GID" != "$PGID" ]; then
    groupmod -o -g "$PGID" dropbox
fi
if [ "$CURRENT_UID" != "$PUID" ]; then
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
    # Only set the path if it hasn't been configured yet
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
    echo "│                                                         │"
    echo "│    docker exec -it <container_name> maestral auth link  │"
    echo "│                                                         │"
    echo "│  Then follow the on-screen instructions to authorise.   │"
    echo "│  This container will start syncing automatically once   │"
    echo "│  the account is linked.                                 │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""

    while ! is_linked; do
        sleep 5
    done

    echo "[dropbox] Account linked successfully."
    configure_sync_path
fi

# ── Start Maestral ────────────────────────────────────────────────────────────
echo "[dropbox] Starting Maestral (config: ${CONFIG_NAME}, path: ${SYNC_PATH})"
exec gosu dropbox maestral start --foreground -c "$CONFIG_NAME"
