#!/usr/bin/env python3
"""
Start the Maestral daemon directly via the Python API, bypassing the CLI's
startup_dialog. That dialog requires an interactive TTY and crashes in Docker
with: termios.error: (25, 'Inappropriate ioctl for device')
"""
import logging
import os
import sys

config_name = os.environ.get("DROPBOX_CONFIG_NAME", "maestral")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s: %(message)s",
    stream=sys.stderr,
)

from maestral.daemon import start_maestral_daemon_foreground

start_maestral_daemon_foreground(config_name=config_name)
