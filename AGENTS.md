# Agent Instructions

## Project Overview

Docker Compose HTPC stack: media automation, reverse proxy, VPN, home automation, and cloud storage on a TrueNAS host with NVIDIA GPU.

## Architecture

- **Reverse proxy**: Traefik with Let's Encrypt ACME (HTTP challenge)
- **Auth**: PocketID (OIDC IdP) → traefik-forward-auth → Traefik middleware chain
- **Media pipeline**: Prowlarr → Radarr/Sonarr → qBittorrent (via Gluetun VPN) → Plex (NVIDIA HW transcode)
- **Network**: All services on `npm_proxy` bridge (192.168.89.0/24) with static IPs; exception: Home Assistant uses `network_mode: host` for mDNS discovery
- **Storage**: NAS mounts via `.env` vars `$CONFIG` (app configs) and `$ROOT` (media library)

## Key Conventions

### Adding a New Service

Follow the existing pattern in `docker-compose.yml`:

1. Use `<<: *common-keys-media` anchor (sets network, restart policy, `no-new-privileges`)
2. Assign a **unique static IP** on `npm_proxy` (next available in 192.168.89.x)
3. Set `mem_limit` on every container
4. Use `<<: *common-env` for PUID/PGID/TZ
5. Add Traefik labels (copy from an existing service and adjust):
   - Router rule: `Host(\`<name>.${SERVERNAME}\`)`
   - Middlewares: `sanitize-headers,forward-auth,auth-admin` (admin) or `sanitize-headers,forward-auth,auth-user` (regular users)
   - TLS via `certresolver=letsencrypt`
6. Add `com.centurylinklabs.watchtower.enable=true` label for auto-updates
7. Add `depends_on: [traefik]`
8. Expose only internal port (no host-mapped ports unless required, e.g., Plex 32400)

### Auth Middleware Levels

| Middleware | Access |
|---|---|
| `auth-admin` | Admin users only (infrastructure/config services) |
| `auth-user` | All authenticated users (media request/consumption services) |

### Theming

LinuxServer.io images: add `DOCKER_MODS: ghcr.io/themepark-dev/theme.park:<app>` + `TP_THEME: overseerr`.

### Environment Variables (`.env`)

Required vars: `PUID`, `PGID`, `TZ`, `CONFIG`, `ROOT`, `SERVERNAME`, `EMAIL`, `ENCRYPTIONKEY`, `HOST_IP`, `NETWORK`, `VPN_USER`, `VPN_PWD`, `VPN_COUNTRY`, `RADARR_API_KEY`, `SONARR_API_KEY`, `MYSQL_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `DUPLICATI__WEBSERVICE_PASSWORD`.

### Secrets

`tfa-config.yaml` holds OIDC credentials (not committed). See [tfa-config.example.yaml](tfa-config.example.yaml) for structure.

## Commands

```bash
# Start the full stack
docker compose up -d

# Restart a single service
docker compose restart <service>

# View logs
docker compose logs -f <service>

# First-time PlexTraktSync setup
docker compose run --rm plextraktsync sync

# Install HACS into Home Assistant
bash install-hacs.sh
```

## File Map

| File | Purpose |
|---|---|
| `docker-compose.yml` | Full stack definition (~30 services) |
| `.env` | All environment variables (not committed) |
| `tfa-config.yaml` | Forward-auth OIDC config (not committed) |
| `tfa-config.example.yaml` | Template for `tfa-config.yaml` |
| `homeassistant-configuration.yaml` | HA config mounted read-only into container |
| `nginx.conf.example` | Nginx reverse-proxy template for TrueNAS UI |
| `install-hacs.sh` | One-time HACS installer script |
| `TO_CHECK.md` | Ideas for new containers to evaluate |

## Pitfalls

- **Port 8123 conflict**: qBittorrent WebUI uses 8123 via Gluetun; Home Assistant is on 8124.
- **Host networking**: Home Assistant uses `network_mode: host` — incompatible with `common-keys-media` anchor and Docker networks. Traefik reaches it via `HOST_IP:8124`.
- **GPU services**: Plex and Tdarr reserve the NVIDIA GPU; both need `NVIDIA_VISIBLE_DEVICES` and deploy resource reservations.
- **qBittorrent networking**: Runs via `network_mode: service:gluetun` — its Traefik labels are on the `gluetun` container, not qBittorrent itself.
