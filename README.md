# sync-dropbox

[![Build & Publish](https://github.com/toroskilly/sync-dropbox/actions/workflows/build.yml/badge.svg)](https://github.com/toroskilly/sync-dropbox/actions/workflows/build.yml)

A modern, headless Dropbox container built on **[Maestral](https://maestral.app)** — an open-source Dropbox client that uses the official Dropbox HTTP API v2. Designed for Unraid but works anywhere Docker runs.

**Why Maestral instead of the official daemon?**

| | Official daemon | This image (Maestral) |
|---|---|---|
| Architecture | x86-64 only | amd64 + arm64 |
| Source | Proprietary binary | Open source (MIT) |
| Display server | Required (Xvfb hack) | Not required |
| Maintenance | Infrequent updates | Actively maintained |
| API | Proprietary | Dropbox HTTP API v2 |

---

## Quick start

### Docker Compose

```yaml
services:
  dropbox:
    image: ghcr.io/toroskilly/sync-dropbox:latest
    container_name: dropbox
    restart: unless-stopped
    environment:
      PUID: "1000"   # host UID that owns your files
      PGID: "1000"   # host GID that owns your files
      TZ: "Europe/London"
    volumes:
      - dropbox-config:/config
      - /mnt/user/Dropbox:/dropbox

volumes:
  dropbox-config:
```

### Docker CLI

```bash
docker run -d \
  --name dropbox \
  --restart unless-stopped \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -v dropbox-config:/config \
  -v /mnt/user/Dropbox:/dropbox \
  ghcr.io/toroskilly/sync-dropbox:latest
```

---

## Unraid

Install via the Community Applications plugin:

1. In CA, search for **sync-dropbox** or add the template URL manually:
   ```
   https://raw.githubusercontent.com/toroskilly/sync-dropbox/main/unraid-template.xml
   ```
2. Set `PUID=99`, `PGID=100` (Unraid's nobody/users), and your timezone.
3. Set **Dropbox Config** to `/mnt/user/appdata/dropbox` and **Dropbox Files** to your desired share path (avoid `/mnt/user` — see note below).
4. Apply and start. Then follow the [first-time setup](#first-time-setup--linking-your-account) steps below.

> **Note on path selection:** For reliable local change detection, use a direct disk or cache path rather than `/mnt/user`:
> - Share with cache **No**: `/mnt/disk1/Dropbox`
> - Share with cache **Only**: `/mnt/cache/Dropbox`
>
> `/mnt/user` may work but inotify events don't always propagate reliably through Unraid's union filesystem, which can delay detection of local file changes.

---

## First-time setup — linking your account

On first run the container waits for you to authorise it. Check the logs:

```bash
docker logs dropbox
```

You will see the container ID printed in the log. Run the link command using either the container name or that ID:

```bash
docker exec -it -u dropbox dropbox maestral auth link -c maestral
```

Two important flags:
- **`-u dropbox`** — must run as the `dropbox` user, not root, so credentials are written to the right location
- **`-c maestral`** — selects the `maestral` config profile (see [below](#why-you-dont-need-dropbox_config_name))

This will:
1. Print a Dropbox authorisation URL — open it in your browser
2. Select **"Print auth URL to console"** when prompted
3. Authorise the "Maestral" app and copy the code
4. Paste the code back into the terminal

The container detects the link automatically and begins syncing. No restart needed.

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PUID` | `1000` | UID of the user that owns synced files |
| `PGID` | `1000` | GID of the user that owns synced files |
| `TZ` | `UTC` | Timezone (e.g. `Europe/London`, `America/New_York`) |
| `DROPBOX_PATH` | `/dropbox` | Where files are synced inside the container |
| `DROPBOX_CONFIG_NAME` | `maestral` | Maestral config profile — only change for multiple accounts |

> **Unraid note:** Use `PUID=99` / `PGID=100` (nobody/users) unless you have a specific user configured.

### Why you don't need `DROPBOX_CONFIG_NAME`

Maestral's own default config profile name is `maestral`. This container defaults to the same value, so the profile used by the daemon and the profile written by `maestral auth link` (when run without `-c`) are always the same. You only need to set `DROPBOX_CONFIG_NAME` if you are running **multiple Dropbox accounts** in separate containers and want to distinguish them.

If you set it to anything other than `maestral`, you must pass the same value to every `maestral` command you run via `docker exec`, e.g. `maestral auth link -c myprofile`, `maestral status -c myprofile`, etc.

---

## Volumes

| Mount point | Purpose |
|---|---|
| `/config` | Maestral config, OAuth credentials, and sync index — **must be persistent** |
| `/dropbox` | Synced Dropbox files — map this to your host storage path |

---

## Useful commands

```bash
# Check account auth status
docker exec -u dropbox dropbox maestral auth status -c maestral

# Unlink the account
docker exec -u dropbox dropbox maestral auth unlink -c maestral

# Exclude a folder from syncing (selective sync)
docker exec -u dropbox dropbox maestral excluded add /folder-name -c maestral
docker exec -u dropbox dropbox maestral excluded show -c maestral
```

Note: `maestral status`, `maestral pause`, and similar daemon-control commands require
the Maestral IPC socket, which this container does not expose. Use `docker logs` to
monitor sync activity instead.

---

## LAN sync

To enable Dropbox LAN sync, expose port 17500 or use host networking:

```yaml
# Option A — expose the port
ports:
  - "17500:17500"

# Option B — full host networking (also enables device discovery)
network_mode: host
```

---

## Multiple accounts

Run a second container instance with a different config profile and file path:

```yaml
services:
  dropbox-work:
    image: ghcr.io/toroskilly/sync-dropbox:latest
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: "Europe/London"
      DROPBOX_CONFIG_NAME: "work"   # must differ from the personal container
      DROPBOX_PATH: "/dropbox"
    volumes:
      - dropbox-work-config:/config
      - /mnt/user/DropboxWork:/dropbox
```

Then link with `-c work`:
```bash
docker exec -it -u dropbox dropbox-work maestral auth link -c work
```

---

## Building locally

```bash
docker build -t sync-dropbox .

# Pin a specific Maestral version
docker build --build-arg MAESTRAL_VERSION=1.9.5 -t sync-dropbox .

# Multi-arch build (requires docker buildx)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg MAESTRAL_VERSION=1.9.5 \
  -t sync-dropbox .
```

---

## Versioning & updates

Image tags on GHCR:

| Tag | Updated when |
|---|---|
| `latest` | Every push to `main` |
| `1.9.5` / `1.9` | Git tag `v1.9.5` pushed |

[Renovate](https://docs.renovatebot.com) is configured to open automated PRs when a new Maestral version is published to PyPI, keeping the `ARG MAESTRAL_VERSION` in the Dockerfile current.

---

## Migrating from otherguy/dropbox or roninkenji/dropbox-docker

### Unraid settings — field by field

| Field | Old value | New value / action |
|---|---|---|
| **Repository** | `ghcr.io/otherguy/dropbox:latest` (or similar) | `ghcr.io/toroskilly/sync-dropbox:latest` |
| **Network Type** | Bridge | Keep Bridge |
| **Privileged** | ON | **Turn OFF** |
| **Dropbox files** — container path | `/opt/dropbox/Dropbox` | `/dropbox` |
| **Dropbox config** — container path | `/opt/dropbox/.dropbox` | `/config` |
| **Dropbox files** — host path | *(your existing share path)* | Keep the same host path |
| **Dropbox config** — host path | *(your existing appdata path)* | **Use a new, empty directory** (e.g. `/mnt/user/appdata/dropbox`) |
| `DROPBOX_UID` | `99` | Rename to **`PUID`**, keep value `99` |
| `DROPBOX_GID` | `100` | Rename to **`PGID`**, keep value `100` |
| `DROPBOX_SKIP_UPDATE` | *(any value)* | **Remove entirely** — not used |
| `TZ` | *(missing)* | **Add** with your timezone, e.g. `Europe/London` |

> **Why a fresh config directory?** The old container stores proprietary daemon state files that are incompatible with Maestral. Using the same directory will cause errors. Your Dropbox *files* directory can remain exactly where it is — Maestral will index the existing files and sync only differences, so there is no full re-download.

### Steps

1. Stop and remove the old container (keep the old appdata folder as a backup if you want).
2. Create a new, **empty** directory for config, e.g. `/mnt/user/appdata/dropbox`.
3. Apply the field changes above and start the new container.
4. Link your account:
   ```bash
   docker exec -it -u dropbox Dropbox maestral auth link -c maestral
   ```
5. Maestral will scan your existing files and resume syncing — no full re-download.
