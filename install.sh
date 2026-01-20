#!/usr/bin/env bash
# SM - SSH Manager Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-SecureShellManager/main/install.sh | bash
#        ./install.sh --user | --global | --all

set -euo pipefail

REPO="BPMspaceUG/bpm-SecureShellManager"
VERSION="${SM_VERSION:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${VERSION}"

USER_DIR="${HOME}/.local/bin"
GLOBAL_DIR="/usr/local/bin"

# Check if running from local repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || echo "")"
LOCAL_SM="${SCRIPT_DIR}/sm"

# Parse arguments
MODE=""
for arg in "$@"; do
    case "$arg" in
        --user)   MODE="user" ;;
        --global) MODE="global" ;;
        --all)    MODE="all" ;;
        --help|-h)
            echo "Usage: $0 [--user|--global|--all]"
            echo "  --user    Install to ~/.local/bin"
            echo "  --global  Install to /usr/local/bin (requires sudo)"
            echo "  --all     Install to both locations"
            echo "  (none)    Interactive prompt"
            exit 0
            ;;
    esac
done

# Interactive prompt if no flag
if [[ -z "$MODE" ]]; then
    echo "Where would you like to install SM?"
    echo "  1) User only (~/.local/bin)"
    echo "  2) System-wide (/usr/local/bin) - requires sudo"
    echo "  3) Both locations"
    read -rp "Choice [1-3]: " choice
    case "$choice" in
        1) MODE="user" ;;
        2) MODE="global" ;;
        3) MODE="all" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

install_to() {
    local dir="$1"
    mkdir -p "$dir"

    if [[ -n "$SCRIPT_DIR" && -f "$LOCAL_SM" ]]; then
        cp "$LOCAL_SM" "${dir}/sm"
    else
        curl -fsSL -o "${dir}/sm" "${BASE_URL}/sm"
    fi
    chmod +x "${dir}/sm"
    ln -sf "${dir}/sm" "${dir}/smd"
    ln -sf "${dir}/sm" "${dir}/sml"

    echo "✓ Installed to ${dir}/sm"

    if [[ ":$PATH:" != *":${dir}:"* ]]; then
        echo "  ⚠ Add to PATH: export PATH=\"\${PATH}:${dir}\""
    fi
}

# Execute based on mode
case "$MODE" in
    user)
        install_to "$USER_DIR"
        ;;
    global)
        if [[ $EUID -ne 0 ]]; then
            echo "Error: --global requires sudo"
            exit 1
        fi
        install_to "$GLOBAL_DIR"
        ;;
    all)
        install_to "$USER_DIR"
        if [[ $EUID -eq 0 ]]; then
            install_to "$GLOBAL_DIR"
        else
            echo ""
            echo "Note: Run with sudo to also install to $GLOBAL_DIR"
        fi
        ;;
esac

echo ""
echo "Commands: sm, smd (default), sml (list)"
