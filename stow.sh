#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(bash nvim opencode tmux)

# ──────────────────────────────────────────────
# Dependencies the bash config benefits from
# ──────────────────────────────────────────────
DEPS=(fzf direnv bash-completion)

check_deps() {
    local missing=()
    for dep in "${DEPS[@]}"; do
        case "$dep" in
            bash-completion)
                [[ -f /usr/share/bash-completion/bash_completion ]] || \
                [[ -f /etc/bash_completion ]] || missing+=("$dep")
                ;;
            *)
                command -v "$dep" &>/dev/null || missing+=("$dep")
                ;;
        esac
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        echo "All dependencies found."
        return
    fi

    echo ""
    echo "Missing optional dependencies: ${missing[*]}"
    echo ""

    # Try to detect package manager
    local pm=""
    local install_cmd=""
    if command -v apt &>/dev/null; then
        pm="apt"
        install_cmd="sudo apt install -y ${missing[*]}"
    elif command -v pacman &>/dev/null; then
        pm="pacman"
        install_cmd="sudo pacman -S --noconfirm ${missing[*]}"
    elif command -v dnf &>/dev/null; then
        pm="dnf"
        install_cmd="sudo dnf install -y ${missing[*]}"
    elif command -v brew &>/dev/null; then
        pm="brew"
        install_cmd="brew install ${missing[*]}"
    fi

    if [[ -n "$pm" ]]; then
        echo "Detected package manager: $pm"
        echo "Install command: $install_cmd"
        echo ""
        read -rp "Install now? [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "Installing..."
            eval "$install_cmd"
        else
            echo "Skipping. You can install later with:"
            echo "  $install_cmd"
        fi
    else
        echo "Could not detect package manager. Install manually:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
    fi
    echo ""
}

# ──────────────────────────────────────────────
# Stow
# ──────────────────────────────────────────────
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
    stow -t "$HOME" "$pkg"
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

# Check dependencies before stowing
check_deps

for pkg in "${selected[@]}"; do
    stow_pkg "$pkg"
done

echo "Done."
