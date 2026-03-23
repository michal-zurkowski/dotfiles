#!/usr/bin/env bash
# Simple init script to stow everything

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(bash nvim opencode tmux)

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Stow dotfiles packages. If no package flags are given, all packages are stowed."
    echo ""
    echo "Options:"
    echo "  --bash       Stow bash config"
    echo "  --nvim       Stow nvim config"
    echo "  --opencode   Stow opencode config"
    echo "  --tmux       Stow tmux config"
    echo "  --all        Stow all packages"
    echo "  -h, --help   Show this help"
}

stow_pkg() {
    local pkg="$1"
    if [[ ! -d "$DOTFILES_DIR/$pkg" ]]; then
        echo "WARNING: package dir '$pkg' not found, skipping"
        return
    fi
    echo "Stowing $pkg..."
    cd "$DOTFILES_DIR"
    stow -t "$HOME" --restow "$pkg"
}

selected=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bash)      selected+=(bash) ;;
        --nvim)      selected+=(nvim) ;;
        --opencode)  selected+=(opencode) ;;
        --tmux)      selected+=(tmux) ;;
        --all)       selected=("${PACKAGES[@]}") ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

# No flags = stow everything
if [[ ${#selected[@]} -eq 0 ]]; then
    selected=("${PACKAGES[@]}")
fi

if ! command -v stow &>/dev/null; then
    echo "ERROR: GNU stow is not installed"
    exit 1
fi

for pkg in "${selected[@]}"; do
    stow_pkg "$pkg"
done

echo "Done."
