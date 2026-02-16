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

# Check if running from local repo (BASH_SOURCE unset when piped)
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo "")"
fi
LOCAL_SM="${SCRIPT_DIR:+${SCRIPT_DIR}/sm}"
LOCAL_SM2="${SCRIPT_DIR:+${SCRIPT_DIR}/sm2}"

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

# Extract version from sm script
get_sm_version() {
    local file="$1"
    grep -m1 '^SM_VERSION=' "$file" 2>/dev/null | cut -d'"' -f2 || echo "unknown"
}

install_to() {
    local dir="$1"
    local old_version=""
    local new_version=""
    local install_type="New install"

    mkdir -p "$dir"

    # Check for existing installation (check sm2 first since sm may be a symlink)
    if [[ -f "${dir}/sm2" ]]; then
        old_version=$(get_sm_version "${dir}/sm2")
        install_type="Update"
    elif [[ -f "${dir}/sm" && ! -L "${dir}/sm" ]]; then
        old_version=$(get_sm_version "${dir}/sm")
        install_type="Update"
    fi

    # Stamp version from HEAD commit date (installed copy has no git repo)
    local ver="" suffix=""
    if [[ -n "$SCRIPT_DIR" ]] && git -C "$SCRIPT_DIR" rev-parse --git-dir &>/dev/null; then
        ver=$(git -C "$SCRIPT_DIR" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "")
        if ! git -C "$SCRIPT_DIR" diff --quiet HEAD 2>/dev/null || ! git -C "$SCRIPT_DIR" diff --cached --quiet HEAD 2>/dev/null; then
            suffix="-dirty"
        elif ! git -C "$SCRIPT_DIR" diff --quiet HEAD "@{upstream}" 2>/dev/null; then
            suffix="-draft"
        fi
    fi

    # Install sm1 (Zellij legacy)
    if [[ -n "$SCRIPT_DIR" && -f "$LOCAL_SM" ]]; then
        cp "$LOCAL_SM" "${dir}/sm1"
    else
        curl -fsSL -o "${dir}/sm1" "${BASE_URL}/sm"
    fi
    chmod +x "${dir}/sm1"
    if [[ -n "$ver" ]]; then
        sed -i "0,/^SM_VERSION=/{s/^SM_VERSION=.*/SM_VERSION=\"${ver}${suffix}\"/}" "${dir}/sm1"
    fi
    ln -sf "${dir}/sm1" "${dir}/sm1d"
    ln -sf "${dir}/sm1" "${dir}/sm1l"

    # Install sm2 (tmux, default)
    if [[ -n "$SCRIPT_DIR" && -f "$LOCAL_SM2" ]]; then
        cp "$LOCAL_SM2" "${dir}/sm2"
    else
        curl -fsSL -o "${dir}/sm2" "${BASE_URL}/sm2"
    fi
    chmod +x "${dir}/sm2"
    if [[ -n "$ver" ]]; then
        sed -i "0,/^SM_VERSION=/{s/^SM_VERSION=.*/SM_VERSION=\"${ver}${suffix}\"/}" "${dir}/sm2"
    fi
    ln -sf "${dir}/sm2" "${dir}/sm2d"
    ln -sf "${dir}/sm2" "${dir}/sm2l"

    # sm/smd/sml → sm2 (tmux is the new default)
    ln -sf "${dir}/sm2" "${dir}/sm"
    ln -sf "${dir}/sm2" "${dir}/smd"
    ln -sf "${dir}/sm2" "${dir}/sml"

    # Get new version
    new_version=$(get_sm_version "${dir}/sm2")

    # Display result
    if [[ "$install_type" == "Update" ]]; then
        if [[ "$old_version" == "$new_version" ]]; then
            echo "✓ Reinstalled v${new_version} to ${dir}"
        else
            echo "✓ Updated ${old_version} → ${new_version} in ${dir}"
        fi
    else
        echo "✓ Installed v${new_version} to ${dir}"
    fi

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
echo "Commands: sm, smd, sml          → tmux (default)"
echo "         sm2, sm2d, sm2l        → tmux (explicit)"
echo "         sm1, sm1d, sm1l        → Zellij (legacy)"
