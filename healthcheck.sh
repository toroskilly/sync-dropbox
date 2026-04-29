#!/bin/bash
# Returns 0 (healthy) when maestral daemon is running and responsive.
# Returns 1 (unhealthy) if the daemon is not running or reports a hard error.

CONFIG_NAME=${DROPBOX_CONFIG_NAME:-personal}

status=$(gosu dropbox maestral status -c "$CONFIG_NAME" 2>&1) || true

# Healthy states emitted by `maestral status`
if echo "$status" | grep -qiE \
    "up to date|syncing|paused|connecting|indexing|setting up"; then
    exit 0
fi

# Unhealthy: daemon not running or unrecoverable error
exit 1
