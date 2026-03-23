#!/bin/bash

# Exit early for non-interactive shells
[[ $- != *i* ]] && return

# ──────────────────────────────────────────────
# History - unlimited, shared file, local session
# ──────────────────────────────────────────────
HISTFILE="$HOME/.bash_history"
HISTSIZE=-1                # unlimited in memory
HISTFILESIZE=-1            # unlimited on disk
HISTTIMEFORMAT="%F %T  "  # timestamp each entry

shopt -s histappend        # append, never overwrite
shopt -s cmdhist           # save multi-line commands as one entry

# Write to shared file after every command, but don't reload —
# keeps this terminal's history navigation predictable
PROMPT_COMMAND="history -a"

# Don't record duplicates or commands starting with a space
HISTCONTROL=ignoreboth:erasedups

# ──────────────────────────────────────────────
# Shell options
# ──────────────────────────────────────────────
shopt -s autocd            # cd into directories by name alone
shopt -s cdspell           # fix minor typos in cd
shopt -s dirspell          # fix minor typos in tab completion
shopt -s dotglob           # include hidden files in globbing
shopt -s extglob           # extended pattern matching
shopt -s globstar          # recursive ** globbing
shopt -s checkwinsize      # update LINES/COLUMNS after each command
shopt -s no_empty_cmd_completion  # don't tab-complete on empty line

# Disable ctrl-s freezing the terminal
stty -ixon 2>/dev/null

# ──────────────────────────────────────────────
# Environment
# ──────────────────────────────────────────────
export VISUAL="nvim"
export EDITOR="nvim"
export BROWSER="google-chrome"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ──────────────────────────────────────────────
# Aliases
# ──────────────────────────────────────────────
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'

alias ls='ls --color=auto'
alias la='ls -A'

alias free='free -m'
alias df='df -h'

alias gitst='git status'
alias tmux='tmux -2'
alias k='kubectl'

alias snxput='snx -s hellfire.put.poznan.pl -u michal.zurkowski@put.poznan.pl'
alias discord-update='find ~/Downloads -maxdepth 1 -type f -iname "discord-*.*.*.deb" | sort | tail -n 1 | xargs sudo nala install -y'

# ──────────────────────────────────────────────
# Git prompt  [main|●1+2?3↑1↓2]
# ──────────────────────────────────────────────
__git_prompt() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null) || return

    local staged=0 modified=0 untracked=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local x="${line:0:1}" y="${line:1:1}"
        [[ "$x" == "?" ]]     && (( untracked++ )) && continue
        [[ "$x" =~ [MADRC] ]] && (( staged++ ))
        [[ "$y" =~ [MADRC] ]] && (( modified++ ))
    done < <(git status --porcelain=v1 2>/dev/null)

    local info=""
    (( staged > 0 ))    && info+="\e[32m●${staged}"
    (( modified > 0 ))  && info+="\e[31m+${modified}"
    (( untracked > 0 )) && info+="\e[35m?${untracked}"

    local ahead=0 behind=0 ab
    ab=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    if [[ -n "$ab" ]]; then
        ahead=$(echo "$ab" | cut -f1)
        behind=$(echo "$ab" | cut -f2)
        (( ahead > 0 ))  && info+="\e[36m↑${ahead}"
        (( behind > 0 )) && info+="\e[36m↓${behind}"
    fi

    [[ -n "$info" ]] && info="|${info}"
    printf ' \e[1;34m[\e[33m%s\e[0m%b\e[1;34m]\e[0m' "$branch" "$info"
}

# ──────────────────────────────────────────────
# Nix / direnv indicator
# ──────────────────────────────────────────────
__nix_prompt() {
    if [[ -n "$IN_NIX_SHELL" || -n "$buildInputs" || "$PATH" == */nix/store* ]]; then
        printf ' \e[1;36m❄\e[0m'
    fi
}

# ──────────────────────────────────────────────
# Prompt
# ──────────────────────────────────────────────
__build_prompt() {
    local user_color='\[\e[1;32m\]'
    [[ $EUID -eq 0 ]] && user_color='\[\e[1;31m\]'

    PS1='\[\e[1;34m\]┬[\[\e[0m\]'
    PS1+="${user_color}\u\[\e[0m\]"
    PS1+='\[\e[1;35m\]@\[\e[0m\]'
    PS1+='\[\e[1;37m\]\h\[\e[0m\]'
    PS1+='\[\e[1;34m\]]\[\e[0m\]'
    PS1+='$(__git_prompt)'
    PS1+='$(__nix_prompt)'
    PS1+=' \[\e[1;36m\]\w\[\e[0m\]'
    PS1+='\n\[\e[1;34m\]└\[\e[0m\]'
    PS1+=' \[\e[1;32m\]$ ➜\[\e[0m\] '
}

PROMPT_COMMAND="__build_prompt; ${PROMPT_COMMAND}"

# ──────────────────────────────────────────────
# Completions - navigable menu with arrows
# ──────────────────────────────────────────────
bind 'set show-all-if-ambiguous on'
bind 'set show-all-if-unmodified on'
bind 'set completion-ignore-case on'
bind 'set menu-complete-display-prefix on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set mark-symlinked-directories on'

# Tab cycles through completions, Shift-Tab goes back
bind 'TAB:menu-complete'
bind '"\e[Z":menu-complete-backward'

# Type prefix then Up/Down to search history by prefix
bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'

# Enable programmable completion
if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    . /usr/share/bash-completion/bash_completion
elif [[ -f /etc/bash_completion ]]; then
    . /etc/bash_completion
fi

# ──────────────────────────────────────────────
# FZF - fuzzy search (Ctrl-R history, Ctrl-T files, Alt-C cd)
# ──────────────────────────────────────────────
# Add ~/.fzf/bin to PATH if installed via git clone
[[ -d "$HOME/.fzf/bin" ]] && export PATH="$HOME/.fzf/bin:$PATH"

if command -v fzf &>/dev/null; then
    # Modern fzf (0.48+)
    eval "$(fzf --bash 2>/dev/null)" || {
        # Git-clone install
        [[ -f ~/.fzf.bash ]] && source ~/.fzf.bash
        # System package fallbacks
        [[ -f /usr/share/fzf/completion.bash ]] && source /usr/share/fzf/completion.bash
        [[ -f /usr/share/fzf/key-bindings.bash ]] && source /usr/share/fzf/key-bindings.bash
        [[ -f /usr/share/doc/fzf/examples/completion.bash ]] && source /usr/share/doc/fzf/examples/completion.bash
        [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
    }
fi

# ──────────────────────────────────────────────
# Direnv - auto-load .envrc / nix flakes per dir
# ──────────────────────────────────────────────
if command -v direnv &>/dev/null; then
    eval "$(direnv hook bash)"
fi
