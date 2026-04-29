#!/usr/bin/env python3
"""
Runs the Maestral sync engine in-process, bypassing the CLI startup_dialog
which requires an interactive TTY and crashes in Docker.
"""
import logging
import os
import signal
import socket
import sys
import time

config_name = os.environ.get("DROPBOX_CONFIG_NAME", "maestral")
sync_path   = os.environ.get("DROPBOX_PATH", "/dropbox")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s: %(message)s",
    stream=sys.stderr,
)
log = logging.getLogger("dropbox")

from maestral.main import Maestral


def make_maestral() -> Maestral:
    return Maestral(config_name=config_name)


# ── Wait for account to be linked ────────────────────────────────────────────
# Retry in a loop so the container stays alive while the user runs
# `docker exec -it -u dropbox <name> maestral auth link -c <config>`

m = make_maestral()

if m.pending_link:
    container_id = socket.gethostname()
    log.warning("Dropbox account not linked.")
    log.warning(
        f"Run: docker exec -it -u dropbox {container_id} "
        f"maestral auth link -c {config_name}"
    )
    log.warning("Waiting for account to be linked...")

    while m.pending_link:
        time.sleep(5)
        m = make_maestral()   # re-read credentials each poll

    log.info("Account linked — starting sync.")

# ── Configure sync path ───────────────────────────────────────────────────────
try:
    current_path = m.config.get("sync", "path")
except Exception:
    current_path = ""

default_path = os.path.join(os.path.expanduser("~"), "Dropbox")
if not current_path or current_path == default_path:
    log.info(f"Setting sync path to {sync_path}")
    try:
        m.config.set("sync", "path", sync_path)
    except Exception as e:
        log.warning(f"Could not set sync path: {e} — using default ({default_path})")

# ── Start sync ────────────────────────────────────────────────────────────────
m.start_sync()
log.info("Dropbox sync started")


def shutdown(sig, frame):
    log.info("Shutting down...")
    try:
        m.stop_sync()
    except Exception:
        pass
    sys.exit(0)


signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)

while True:
    time.sleep(60)
