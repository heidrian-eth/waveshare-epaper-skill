#!/usr/bin/env bash
# Print the host-readable half of a board fingerprint.
# The other half is an on-device I2C scan; see references/identify.md.
set -euo pipefail

PORT="${1:-/dev/ttyACM0}"

if ! command -v esptool >/dev/null 2>&1; then
    echo "esptool not found. Install it with: pip install esptool" >&2
    exit 1
fi

echo "=== chip and flash ==="
esptool --port "$PORT" flash-id

echo
echo "=== PSRAM and flash eFuses ==="
espefuse --port "$PORT" summary 2>/dev/null \
    | grep -E 'PSRAM_CAP |PSRAM_VENDOR|FLASH_CAP|FLASH_VENDOR|FLASH_TYPE' \
    || echo "espefuse unavailable; skipping"

cat <<'NOTE'

These values identify capacity and vendor. They do NOT tell you whether PSRAM
runs in quad or octal mode, and they do not distinguish the touch variant from
the non-touch one. For that, scan I2C on the board and look for 0x38.

Next: references/identify.md
NOTE
