#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install-hacs.sh — One-time HACS installer for HA Container
#
# Run from the htpc-box-docker project root on the NAS:
#   bash install-hacs.sh
#
# HACS (Home Assistant Community Store) installs as a custom_component.
# After running this script, restart HA and then enable it via:
#   UI → Settings → Integrations → Add Integration → HACS
# -----------------------------------------------------------------------------
set -euo pipefail

# Load CONFIG and other vars from .env
if [[ ! -f .env ]]; then
  echo "✗ .env not found. Run this script from the htpc-box-docker project root."
  exit 1
fi
set -a && source .env && set +a

CUSTOM_COMPONENTS="${CONFIG}/homeassistant/custom_components"
HACS_DIR="${CUSTOM_COMPONENTS}/hacs"
TMP_ZIP="/tmp/hacs.zip"

# Guard: skip if already installed
if [[ -d "${HACS_DIR}" ]]; then
  echo "⚠ HACS already exists at ${HACS_DIR}"
  read -rp "  Reinstall / update? [y/N] " confirm
  [[ "${confirm}" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

echo "→ Creating custom_components directory..."
mkdir -p "${HACS_DIR}"

echo "→ Downloading latest HACS release..."
wget -q --show-progress \
  "https://github.com/hacs/integration/releases/latest/download/hacs.zip" \
  -O "${TMP_ZIP}"

echo "→ Extracting into ${HACS_DIR}..."
unzip -o "${TMP_ZIP}" -d "${HACS_DIR}"
rm -f "${TMP_ZIP}"

echo "→ Restarting Home Assistant..."
docker compose restart homeassistant

echo ""
echo "✓ Done. Next steps:"
echo "  1. Open ha.${SERVERNAME} → Settings → Integrations"
echo "  2. + Add Integration → search 'HACS'"
echo "  3. Follow the GitHub OAuth prompt (needs a GitHub account)"
echo ""
echo "  Useful HACS integrations for your setup:"
echo "    - Philips AirPurifier Coap  (for Philips ACs via local CoAP protocol)"
echo "    - Yeelight BLE              (if any Mi bulbs are Bluetooth-only)"
