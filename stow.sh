#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(bash nvim pi tmux)

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
    echo "  --pi         Stow pi config"
    echo "  --tmux       Stow tmux config"
    echo "  --all        Stow all packages"
    echo "  --fallback   Use the built-in symlinker even if stow is installed"
    echo "  -h, --help   Show this help"
}

# ──────────────────────────────────────────────
# Fallback for systems without GNU stow
# ──────────────────────────────────────────────
# Mimics `stow -t $HOME`: relative symlinks, directory folding (unless
# --no-folding), the same ignore lists, and no changes if any conflict exists.
# It does not unfold directories already folded by another package.

# Built-in ignore list of GNU Stow 2.4.1.
DEFAULT_IGNORE='RCS
.+,v
CVS
\.\#.+
\.cvsignore
\.svn
_darcs
\.hg
\.git
\.gitignore
\.gitmodules
.+~
\#.*\#
^/README.*
^/LICENSE.*
^/COPYING'

# Sets IGNORE_PATH_RE / IGNORE_SEGMENT_RE the way stow compiles them: patterns
# containing '/' match the package-relative path, the rest match the basename.
load_ignore() {
    local pkg_dir="$1" list line
    if [[ -f "$pkg_dir/.stow-local-ignore" ]]; then
        list="$(cat "$pkg_dir/.stow-local-ignore")"
    elif [[ -f "$HOME/.stow-global-ignore" ]]; then
        list="$(cat "$HOME/.stow-global-ignore")"
    else
        list="$DEFAULT_IGNORE"
    fi
    list+=$'\n^/\\.stow-local-ignore$'

    local segs=() paths=()
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        line="$(sed -E 's/[[:space:]]+#.+//; s/\\#/#/g' <<<"$line")"
        if [[ "$line" == */* ]]; then paths+=("$line"); else segs+=("$line"); fi
    done <<<"$list"

    local IFS='|'
    IGNORE_SEGMENT_RE="" IGNORE_PATH_RE=""
    [[ ${#segs[@]} -gt 0 ]] && IGNORE_SEGMENT_RE="^(${segs[*]})\$"
    [[ ${#paths[@]} -gt 0 ]] && IGNORE_PATH_RE="(^|/)(${paths[*]})(/|\$)"
    return 0
}

is_ignored() {
    local rel="$1"
    [[ -n "$IGNORE_PATH_RE" && "/$rel" =~ $IGNORE_PATH_RE ]] && return 0
    [[ -n "$IGNORE_SEGMENT_RE" && "${rel##*/}" =~ $IGNORE_SEGMENT_RE ]] && return 0
    return 1
}

# Relative path from directory $2 to path $1 (both absolute, physical).
relpath() {
    local target="$1" base="$2" up=""
    while [[ "$target" != "$base" && "$target" != "$base"/* ]]; do
        base="${base%/*}"
        up+="../"
    done
    if [[ "$target" == "$base" ]]; then
        printf '%s\n' "${up:-.}"
    else
        printf '%s\n' "$up${target#"$base"/}"
    fi
}

# Absolute physical path of a (possibly not yet existing) target path.
physical() {
    local p="$1" rest=""
    while [[ ! -d "$p" ]]; do
        rest="/${p##*/}$rest"
        p="${p%/*}"
    done
    printf '%s\n' "$(cd "$p" && pwd -P)$rest"
}

# Walks package dir $1 against target dir $2, appending planned actions to
# PLAN ("mkdir\t<dir>" / "link\t<src>\t<dst>") and paths in the way to
# CONFLICTS.
plan_dir() {
    local src_dir="$1" dst_dir="$2" rel_dir="$3" entry name rel src dst
    for entry in "$src_dir"/* "$src_dir"/.*; do
        name="${entry##*/}"
        [[ "$name" == "." || "$name" == ".." ]] && continue
        [[ -e "$entry" || -L "$entry" ]] || continue
        rel="${rel_dir:+$rel_dir/}$name"
        is_ignored "$rel" && continue
        src="$entry"
        dst="$dst_dir/$name"

        if [[ -L "$dst" ]]; then
            if [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
                continue
            fi
            CONFLICTS+=("$dst")
        elif [[ -d "$src" && ! -L "$src" && -d "$dst" ]]; then
            plan_dir "$src" "$dst" "$rel"
        elif [[ -e "$dst" ]]; then
            CONFLICTS+=("$dst")
        elif [[ -d "$src" && ! -L "$src" && "$NO_FOLDING" == 1 ]]; then
            PLAN+=("mkdir"$'\t'"$dst")
            plan_dir "$src" "$dst" "$rel"
        else
            PLAN+=("link"$'\t'"$src"$'\t'"$dst")
        fi
    done
}

plan_pkg() {
    local pkg_dir
    pkg_dir="$(cd "$DOTFILES_DIR/$1" && pwd -P)"
    PLAN=() CONFLICTS=()
    load_ignore "$pkg_dir"
    plan_dir "$pkg_dir" "$HOME" ""
}

# Offers to move every path in CONFLICTS aside so the package can be linked.
# A fresh system almost always ships its own ~/.bashrc.
backup_conflicts() {
    local pkg="$1" suffix dst answer
    suffix=".bak.$(date +%Y%m%d-%H%M%S)"
    echo "Existing files are in the way of $pkg:"
    for dst in "${CONFLICTS[@]}"; do
        if [[ -L "$dst" ]]; then
            echo "  $dst (symlink to $(readlink "$dst"))"
        else
            echo "  $dst"
        fi
    done
    read -rp "Move them to <name>$suffix and link $pkg? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "ERROR: not stowing $pkg"
        return 1
    fi
    for dst in "${CONFLICTS[@]}"; do
        if [[ -e "$dst$suffix" || -L "$dst$suffix" ]]; then
            echo "ERROR: $dst$suffix already exists, not stowing $pkg"
            return 1
        fi
        mv "$dst" "$dst$suffix"
        echo "  moved $dst -> $dst$suffix"
    done
}

apply_plan() {
    local action kind src dst link_dir
    for action in "${PLAN[@]}"; do
        IFS=$'\t' read -r kind src dst <<<"$action"
        case "$kind" in
            mkdir)
                mkdir -p "$src"
                ;;
            link)
                link_dir="$(physical "${dst%/*}")"
                ln -s "$(relpath "$src" "$link_dir")" "$dst"
                ;;
        esac
    done
}

stow_pkg() {
    local pkg="$1"
    if [[ ! -d "$DOTFILES_DIR/$pkg" ]]; then
        echo "WARNING: package dir '$pkg' not found, skipping"
        return
    fi
    local extra=()
    NO_FOLDING=0
    # pi writes runtime state (auth.json, trust.json, sessions/) into
    # ~/.pi/agent. Without --no-folding stow would symlink the whole ~/.pi tree
    # back into this repo and that state would land in git.
    if [[ "$pkg" == "pi" ]]; then
        extra+=(--no-folding)
        NO_FOLDING=1
    fi

    echo "Stowing $pkg..."
    plan_pkg "$pkg"
    if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
        backup_conflicts "$pkg" || return 1
        plan_pkg "$pkg"
    fi

    if [[ "$USE_FALLBACK" == 1 ]]; then
        apply_plan
        return
    fi
    cd "$DOTFILES_DIR"
    stow "${extra[@]}" -t "$HOME" "$pkg"
}

selected=()
USE_FALLBACK=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fallback)  USE_FALLBACK=1 ;;
        --bash)      selected+=(bash) ;;
        --nvim)      selected+=(nvim) ;;
        --pi)        selected+=(pi) ;;
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

if [[ "$USE_FALLBACK" == 0 ]] && ! command -v stow &>/dev/null; then
    echo "GNU stow is not installed."
    read -rp "Create the symlinks with the built-in fallback instead? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Aborting. Install stow or rerun with --fallback."
        exit 1
    fi
    USE_FALLBACK=1
fi

# Check dependencies before stowing
check_deps

failed=0
for pkg in "${selected[@]}"; do
    stow_pkg "$pkg" || failed=1
done

if [[ "$failed" == 1 ]]; then
    echo "Done, with errors."
    exit 1
fi
echo "Done."
