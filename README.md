# sync-dropbox

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

## First-time setup — linking your account

On the first run the container waits for you to authorise it. Check the logs:

```bash
docker logs dropbox
```

You will see a message like:

```
┌─────────────────────────────────────────────────────────┐
│  Dropbox account not linked.                            │
│                                                         │
│  Open a second terminal and run:                        │
│                                                         │
│    docker exec -it <container_name> maestral auth link  │
│                                                         │
│  Then follow the on-screen instructions to authorise.   │
└─────────────────────────────────────────────────────────┘
```

Run the link command:

```bash
docker exec -it dropbox maestral auth link
```

This will:
1. Print a Dropbox authorisation URL — open it in your browser
2. Authorise the "Maestral" app in Dropbox
3. Paste the resulting code back into the terminal

The container detects the link automatically and begins syncing immediately. **No restart needed.**

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PUID` | `1000` | UID of the user that owns synced files |
| `PGID` | `1000` | GID of the user that owns synced files |
| `TZ` | `UTC` | Timezone (e.g. `Europe/London`, `America/New_York`) |
| `DROPBOX_CONFIG_NAME` | `personal` | Maestral config profile name |
| `DROPBOX_PATH` | `/dropbox` | Where files are synced inside the container |

> **Unraid note:** Use `PUID=99` / `PGID=100` (nobody/users) unless you have a specific user configured.

---

## Volumes

| Mount point | Purpose |
|---|---|
| `/config` | Maestral config files and OAuth credentials — **must be persistent** |
| `/dropbox` | Synced Dropbox files — map this to your host storage path |

---

## Useful commands

```bash
# Check sync status
docker exec dropbox maestral status

# Pause / resume syncing
docker exec dropbox maestral pause
docker exec dropbox maestral resume

# List recent file activity
docker exec dropbox maestral ls

# Check for sync errors
docker exec dropbox maestral errors

# Unlink the account
docker exec dropbox maestral auth unlink

# View all config settings
docker exec dropbox maestral config-files
```

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

## Selective sync

To exclude specific folders from syncing:

```bash
# Exclude a folder
docker exec dropbox maestral excluded add /Dropbox/folder-to-skip

# Show excluded folders
docker exec dropbox maestral excluded show
```

---

## Multiple accounts

Set a different `DROPBOX_CONFIG_NAME` for each container instance:

```yaml
# Second account
environment:
  DROPBOX_CONFIG_NAME: "work"
volumes:
  - dropbox-work-config:/config
  - /mnt/user/DropboxWork:/dropbox
```

---

## Building locally

```bash
docker build -t sync-dropbox .

# Pin a specific Maestral version
docker build --build-arg MAESTRAL_VERSION=1.9.5 -t sync-dropbox .
```

---

## Migrating from otherguy/dropbox

1. Stop the old container
2. Start this container pointing at the same host directory for your Dropbox files
3. Link the account with `docker exec -it dropbox maestral auth link`
4. Maestral will index existing files and sync only changes — no full re-download
