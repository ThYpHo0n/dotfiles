#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
detector="$repo_root/bin/check-shared-config-hygiene.sh"

tmp_repo="$(mktemp -d)"
cleanup() { rm -rf "$tmp_repo"; }
trap cleanup EXIT

cd "$tmp_repo"
git init -q .
mkdir -p zsh git bin
cp "$detector" bin/check-shared-config-hygiene.sh

expect() {
  local want="$1" desc="$2" got=0
  git add -A >/dev/null
  ./bin/check-shared-config-hygiene.sh >/dev/null 2>&1 || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: $desc (expected exit $want, got $got)" >&2
    exit 1
  fi
  echo "ok: $desc"
}

# A shared file with nothing machine-local passes.
printf 'export PATH="$HOME/.local/bin:$PATH"\n' > zsh/.zshrc
printf '[github]\n\tname = someone\n' > git/.gitconfig
expect 0 "clean shared config passes"

# The three shapes that actually bit this repo, one at a time.
printf 'export PATH="/Users/someone/.rd/bin:$PATH"\n' >> zsh/.zshrc
expect 1 "hardcoded home path is caught"
git checkout -- zsh/.zshrc 2>/dev/null || printf 'export PATH="$HOME/.local/bin:$PATH"\n' > zsh/.zshrc

printf '### MANAGED BY SOME INSTALLER START (DO NOT EDIT)\n' >> zsh/.zshrc
expect 1 "installer-managed block is caught"
printf 'export PATH="$HOME/.local/bin:$PATH"\n' > zsh/.zshrc

printf '[user]\n\temail = someone@example.com\n' >> git/.gitconfig
expect 1 "git identity is caught"
printf '[github]\n\tname = someone\n' > git/.gitconfig

# Exemptions: overrides and examples are where machine-local lines belong.
printf 'export PATH="/Users/someone/.rd/bin:$PATH"\n' > zsh/.zshrc.local
printf '# export PATH="/Users/someone/.rd/bin:$PATH"\n' > zsh/.zshrc.local.example
expect 0 ".local and .example files are exempt"

# Linuxbrew's prefix is a fixed system path, not a user home.
printf 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"\n' > zsh/.zshenv
expect 0 "linuxbrew prefix is not treated as a home path"

echo "PASS: shared config hygiene"
