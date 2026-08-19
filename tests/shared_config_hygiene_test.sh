#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
detector="$repo_root/bin/check-shared-config-hygiene.sh"

tmp_repo="$(mktemp -d)"
cleanup() { rm -rf "$tmp_repo"; }
trap cleanup EXIT

cd "$tmp_repo"
git init -q .
git config user.email t@example.test
git config user.name Test
mkdir -p zsh git bin
cp "$detector" bin/check-shared-config-hygiene.sh

# Every fixture is written from scratch, so each assertion exercises exactly
# one detector -- a restore step could otherwise leave the previous shape in
# place and let a broken detector pass on the earlier one's finding.
reset_fixture() {
    printf 'export PATH="$HOME/.local/bin:$PATH"\n' > zsh/.zshrc
    printf '[github]\n\tname = someone\n' > git/.gitconfig
    rm -f zsh/.zshenv zsh/.zshrc.local zsh/.zshrc.local.example
}

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

expect_rev() {
    local want="$1" rev="$2" desc="$3" got=0
    ./bin/check-shared-config-hygiene.sh "$rev" >/dev/null 2>&1 || got=$?
    if [[ "$got" != "$want" ]]; then
        echo "FAIL: $desc (expected exit $want, got $got)" >&2
        exit 1
    fi
    echo "ok: $desc"
}

reset_fixture
expect 0 "clean shared config passes"

reset_fixture
printf 'export PATH="/Users/someone/.rd/bin:$PATH"\n' >> zsh/.zshrc
expect 1 "hardcoded home path is caught"

reset_fixture
printf '### MANAGED BY SOME INSTALLER START (DO NOT EDIT)\n' >> zsh/.zshrc
expect 1 "installer-managed block is caught"

reset_fixture
printf '[user]\n\temail = someone@example.com\n' >> git/.gitconfig
expect 1 "git identity is caught"

# Git reads sections and keys case-insensitively, so the detector must too.
reset_fixture
printf '[User]\n\tEmail = someone@example.com\n' >> git/.gitconfig
expect 1 "capitalised [User]/Email is caught"

reset_fixture
printf 'export PATH="/Users/someone/.rd/bin:$PATH"\n' > zsh/.zshrc.local
printf '# export PATH="/Users/someone/.rd/bin:$PATH"\n' > zsh/.zshrc.local.example
expect 0 ".local and .example files are exempt"

reset_fixture
printf 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"\n' > zsh/.zshenv
expect 0 "linuxbrew prefix is not treated as a home path"

# The push path: a commit carrying sediment must be caught even when the
# working tree has since been cleaned, which is what a pre-push hook faces.
reset_fixture
git add -A >/dev/null && git commit -qm clean
printf 'export PATH="/Users/someone/.rd/bin:$PATH"\n' >> zsh/.zshrc
git add -A >/dev/null && git commit -qm dirty
dirty_rev="$(git rev-parse HEAD)"
reset_fixture
git add -A >/dev/null && git commit -qm "cleaned again"
expect 0 "worktree is clean after the fix"
expect_rev 1 "$dirty_rev" "committed sediment is caught by revision even when the worktree is clean"
expect_rev 0 HEAD "the cleaned commit passes by revision"

# The hook itself: it must walk every commit in the pushed range, since the
# tip tree of a branch can be clean while an earlier commit still carries the
# secret onto the remote.
mkdir -p .githooks
cp "$repo_root/.githooks/pre-push" .githooks/pre-push
chmod +x .githooks/pre-push
git config --local core.hooksPath .githooks

run_hook() {  # <local_sha> <remote_sha>
    printf 'refs/heads/probe %s refs/heads/probe %s\n' "$1" "$2" | ./.githooks/pre-push
}

base="$(git rev-parse HEAD)"
printf 'export PATH="/Users/someone/.rd/bin:$PATH"\n' >> zsh/.zshrc
git add -A >/dev/null && git commit -qm "sediment"
reset_fixture
git add -A >/dev/null && git commit -qm "cleaned"
tip="$(git rev-parse HEAD)"

got=0; run_hook "$tip" "$base" >/dev/null 2>&1 || got=$?
[[ "$got" == 1 ]] || { echo "FAIL: hook missed sediment in an intermediate commit (exit $got)" >&2; exit 1; }
echo "ok: hook rejects sediment in an intermediate commit"

printf 'export PATH="$HOME/.local/bin:$PATH"\n' >> zsh/.zshrc
git add -A >/dev/null && git commit -qm "portable change"
clean_tip="$(git rev-parse HEAD)"
got=0; run_hook "$clean_tip" "$tip" >/dev/null 2>&1 || got=$?
[[ "$got" == 0 ]] || { echo "FAIL: hook rejected a clean range (exit $got)" >&2; exit 1; }
echo "ok: hook accepts a clean range"

echo "PASS: shared config hygiene"
