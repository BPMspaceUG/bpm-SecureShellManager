#!/usr/bin/env bash
# SM - SSH Manager Installer

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing SM - SSH Manager..."

# Create bin directory if needed
mkdir -p "$BIN_DIR"

# Copy main script
cp "${SCRIPT_DIR}/sm" "${BIN_DIR}/sm"
chmod +x "${BIN_DIR}/sm"

# Create symlinks
ln -sf "${BIN_DIR}/sm" "${BIN_DIR}/sml"
ln -sf "${BIN_DIR}/sm" "${BIN_DIR}/smd"

echo "Installed to ${BIN_DIR}/sm"
echo "Symlinks created: sml, smd"
echo ""
echo "Make sure ${BIN_DIR} is in your PATH"
echo ""
echo "Usage:"
echo "  sm              - Connect to default or show list"
echo "  sm <alias>      - Connect to specific alias"
echo "  sm list         - Show all connections"
echo "  sm set <alias>  - Set default connection"
echo "  sml             - Interactive selection"
echo "  smd             - Quick connect to default"
