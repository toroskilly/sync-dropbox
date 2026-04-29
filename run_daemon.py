#!/usr/bin/env python3
"""
Runs the Maestral sync engine in-process, bypassing the CLI startup_dialog
which requires an interactive TTY and crashes in Docker.
"""
import logging
import os
import signal
import sys
import time

config_name = os.environ.get("DROPBOX_CONFIG_NAME", "maestral")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s: %(message)s",
    stream=sys.stderr,
)

log = logging.getLogger("dropbox")

from maestral.main import Maestral

log.info(f"Initialising Maestral (config: {config_name})")
m = Maestral(config_name=config_name)

if m.pending_link:
    log.error(
        f"Account not linked for config '{config_name}'. "
        f"Run: docker exec -it -u dropbox <container> "
        f"maestral auth link -c {config_name}"
    )
    sys.exit(1)

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
