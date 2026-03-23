# Basic history settings (ignore duplicates)
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# A clean, simple prompt (Green user@host, blue directory)
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Handy aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Conditionally load opencode/private secrets safely
if [ -f "$HOME/.config/opencode/.bash_secrets" ]; then
    source "$HOME/.config/opencode/.bash_secrets"
fi
