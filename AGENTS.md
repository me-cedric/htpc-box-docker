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

1. Use `<<: *common-keys-media` anchor (sets network, restart policy, `no-new-privileges`, `read_only: true` with writable tmpfs at `/tmp`, `/run`, `/var/log:size=128m`, and the cap_drop/cap_add baseline)
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

### Security Hardening Exceptions

The `x-common-keys-media` anchor (top of `docker-compose.yml`) applies a security baseline: `read_only: true`, `cap_drop: ALL` with limited `cap_add`, `no-new-privileges`, `pids_limit: 200`, and `tmpfs: [/tmp, /run, /var/log:size=128m]`. A few services intentionally deviate from it. **Do not "fix" these back to the anchor defaults without understanding why the override exists** — each one is the result of a runtime failure.

#### `traefik`

The experimental `traefik-oidc-auth` plugin writes its downloaded source into `/plugins-storage/` at runtime — that one path must be writable even though the rest of the rootfs stays read-only. The official image also runs as UID 65532, which may not be able to read the bind-mounted `./traefik-dynamic:/etc/traefik/dynamic:ro` directory depending on host perms.

Overrides:

- `tmpfs` re-listed explicitly to add `/plugins-storage:size=64m` on top of the anchor's `/tmp` and `/run`. Only `/plugins-storage` is opened for writes; the rest of the rootfs stays read-only. (YAML merge keys replace arrays — see gotcha below.)
- `user: "0:0"` — runs as root so the re-added `DAC_OVERRIDE` capability can read the host-mounted dynamic dir regardless of owner.
- `cap_add` re-listed explicitly as `[NET_BIND_SERVICE, DAC_OVERRIDE, CHOWN]`.

What still applies: `read_only: true`, `cap_drop: ALL`, `no-new-privileges`, `pids_limit: 200`.

**YAML merge gotcha**: `<<: *common-keys-media` **replaces** arrays (not merges). Any service that declares its own `cap_add:` quietly wipes the anchor's list — a silent cap loss that only surfaces as mysterious `EACCES` errors much later. If you need extra capabilities, re-list them verbatim and keep them in sync if the anchor changes.

#### `truenas` (nginx)

`./nginx.conf` is mounted `:ro` and nginx itself writes to `/var/cache/nginx`, `/var/log/nginx`, etc. on each request, which fails on a read-only rootfs. Override: `read_only: false`. Use this as the precedent for any future service that can't enumerate its writable paths in advance.

### Hardening anchor gotchas to preserve

- **Do not remove `/var/log:size=128m` from the anchor**: every LinuxServer.io image (radarr/sonarr/prowlarr/bazarr/kavita/autobrr/duplicati) writes s6-overlay v3 supervisor logs there. Without it, those containers fail to start within ~5 s. The 128 m cap leaves headroom for theme-park init dumps on first boot.
- **Do not add `/var/run` to the anchor's `tmpfs`**: it is a symlink to `/run` on Debian/Alpine base images, and a separate tmpfs there would shadow the symlink and break pid lookups. `/run` tmpfs already covers it.

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
- **Hardening reverts**: do NOT remove `/plugins-storage:size=64m` from the `traefik` service's tmpfs override or `/var/log:size=128m` from the `common-keys-media` anchor's tmpfs in a cleanup pass — the first will silently break the OIDC plugin, the second will silently break every LinuxServer.io container. See "Security Hardening Exceptions" above for the rationale and the exact overrides.
