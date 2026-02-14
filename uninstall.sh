#!/usr/bin/env bash
# SM - SSH Manager Uninstaller

set -euo pipefail

# --- Defaults ---
YES=false
PURGE=false

# --- Usage ---
usage() {
    cat <<'EOF'
Usage: uninstall.sh [OPTIONS]

Remove SM (SSH Manager) binaries.

Options:
  --yes     Skip confirmation prompt (for scripting/CI)
  --purge   Also remove config directory (~/.config/sm/)
  --help    Show this help message

Examples:
  ./uninstall.sh                # Interactive uninstall
  ./uninstall.sh --yes          # Non-interactive uninstall
  ./uninstall.sh --purge        # Also remove config
  ./uninstall.sh --yes --purge  # CI: remove everything
EOF
    exit 0
}

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)  usage ;;
        --yes)   YES=true ;;
        --purge) PURGE=true ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            echo "Run './uninstall.sh --help' for usage." >&2
            exit 1
            ;;
    esac
    shift
done

# --- Install locations and binaries ---
INSTALL_DIRS=("$HOME/.local/bin" "/usr/local/bin")
BINARIES=("sm" "smd" "sml")
CONFIG_DIR="$HOME/.config/sm"

# --- Build list of files that actually exist (scan both locations) ---
targets=()
for dir in "${INSTALL_DIRS[@]}"; do
    for bin in "${BINARIES[@]}"; do
        [[ -f "$dir/$bin" ]] && targets+=("$dir/$bin")
    done
done
if $PURGE && [[ -d "$CONFIG_DIR" ]]; then
    targets+=("$CONFIG_DIR/")
fi

# --- Nothing to remove? ---
if [[ ${#targets[@]} -eq 0 ]]; then
    echo "Nothing to remove. SM is not installed."
    exit 0
fi

# --- Show what will be removed ---
echo "The following will be removed:"
for t in "${targets[@]}"; do
    echo "  $t"
done
# --- Warn about sudo + --purge targeting user config ---
if $PURGE && [[ $EUID -eq 0 ]] && [[ -d "$CONFIG_DIR" ]]; then
    echo "Warning: --purge will remove config for user: $(logname 2>/dev/null || echo unknown)"
    echo "  $CONFIG_DIR"
    echo ""
fi

# --- Confirmation ---
if ! $YES; then
    if [[ ! -t 0 ]]; then
        echo "Error: No TTY detected. Use --yes for non-interactive uninstall." >&2
        exit 1
    fi
    read -rp "Proceed? [y/N] " answer
    if [[ "$answer" != [yY] ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# --- Remove binaries ---
removed=()
for dir in "${INSTALL_DIRS[@]}"; do
    for bin in "${BINARIES[@]}"; do
        if [[ -f "$dir/$bin" ]]; then
            rm -f "$dir/$bin"
            removed+=("$dir/$bin")
        fi
    done
done

# --- Remove config if --purge ---
if $PURGE && [[ -d "$CONFIG_DIR" ]]; then
    rm -rf "$CONFIG_DIR"
    removed+=("$CONFIG_DIR/")
fi

# --- Report ---
echo ""
echo "Removed:"
for r in "${removed[@]}"; do
    echo "  $r"
done

if ! $PURGE && [[ -d "$CONFIG_DIR" ]]; then
    echo ""
    echo "Configuration remains at $CONFIG_DIR"
    echo "To remove config: ./uninstall.sh --purge"
fi
