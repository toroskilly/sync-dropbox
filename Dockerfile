FROM python:3.12-slim

ARG MAESTRAL_VERSION=1.9.5

LABEL org.opencontainers.image.title="Dropbox (Maestral)" \
      org.opencontainers.image.description="Headless Dropbox sync via Maestral — supports PUID/PGID for Unraid" \
      org.opencontainers.image.source="https://github.com/toroskilly/sync-dropbox"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gosu \
        tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir \
        "maestral==${MAESTRAL_VERSION}" \
        "keyrings.alt" \
    && groupadd --system --gid 1000 dropbox \
    && useradd --system --uid 1000 --gid dropbox \
        --home-dir /home/dropbox --create-home \
        --shell /sbin/nologin dropbox \
    && mkdir -p /config /dropbox \
    && chown dropbox:dropbox /config /dropbox

COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh

VOLUME ["/config", "/dropbox"]

# /config  — maestral config + keyring (mount a named volume or host path)
# /dropbox — your synced Dropbox files (mount wherever you want them)

ENV PUID=1000 \
    PGID=1000 \
    TZ=UTC \
    DROPBOX_CONFIG_NAME=maestral \
    DROPBOX_PATH=/dropbox \
    XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/config \
    PYTHON_KEYRING_BACKEND=keyrings.alt.file.PlaintextKeyring

# Dropbox LAN sync port
EXPOSE 17500

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ["/healthcheck.sh"]

ENTRYPOINT ["/entrypoint.sh"]
