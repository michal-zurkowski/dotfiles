#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

git pull

# Check out submodules that aren't initialized yet. Initialized ones are left
# alone: `submodule update` would detach them from their branch.
git submodule status | awk '/^-/ { print $2 }' | while read -r path; do
    git submodule update --init --recursive -- "$path"
done

# Pull each submodule's own branch, switching from a detached HEAD to the
# remote's default branch first.
git submodule foreach --recursive '
    branch=$(git branch --show-current)
    if [ -z "$branch" ]; then
        branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
        branch=${branch#origin/}
        git switch "$branch"
    fi
    git pull
'
