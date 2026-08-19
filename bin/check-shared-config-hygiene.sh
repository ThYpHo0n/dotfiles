#!/usr/bin/env bash
# Report machine-local sediment in tracked (shared) config.
#
# Installers append to whatever rc file they find. In a stow'd dotfiles repo
# that file is the shared one, so machine-local PATHs and identity end up
# committed and break every other machine. This is the source of truth for
# what counts as sediment; the config-hygiene skill does the moving.
#
# Usage:
#   check-shared-config-hygiene.sh                 scan the working tree
#   check-shared-config-hygiene.sh <rev>            scan a commit's tree
#   check-shared-config-hygiene.sh <rev> <file>...  scan those paths at <rev>
#
# Exit 0 = clean, 1 = sediment found (printed as file:line).

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

rev="${1:-}"
[ "$#" -gt 0 ] && shift

list_files() {
    if [ "$#" -gt 0 ]; then
        printf '%s\n' "$@"
    elif [ -n "$rev" ]; then
        git ls-tree -r --name-only "$rev"
    else
        git ls-files
    fi
}

read_file() {
    if [ -n "$rev" ]; then
        git show "$rev:$1" 2>/dev/null
    else
        cat "$1" 2>/dev/null
    fi
}

# .example files document these patterns on purpose; test fixtures embed them
# as samples; the skill quotes them; .local files are where sediment belongs.
is_exempt() {
    case "$1" in
        *.example | *.local | tests/* | */skills/config-hygiene/* | bin/check-shared-config-hygiene.sh) return 0 ;;
        *) return 1 ;;
    esac
}

findings=0
report() {
    printf '%s:%s: %s\n' "$1" "$2" "$3"
    findings=$((findings + 1))
}

scan_file() {
    local file="$1" content="$2"

    # A home directory spelled out instead of $HOME breaks on every other
    # machine and publishes the username. /home/linuxbrew is a fixed prefix.
    while IFS=: read -r line _; do
        [ -n "${line:-}" ] && report "$file" "$line" \
            "absolute home path — use \$HOME, or move the line to a .local override"
    done < <(printf '%s\n' "$content" \
        | grep -nE '(/Users/|/home/)[A-Za-z][A-Za-z0-9._-]*/' \
        | grep -vE '/home/linuxbrew/' || true)

    # Blocks an installer wrote into a file it does not own.
    while IFS=: read -r line _; do
        [ -n "${line:-}" ] && report "$file" "$line" \
            "installer-managed block — move it to a .local override"
    done < <(printf '%s\n' "$content" \
        | grep -nE '^(### MANAGED BY |# >>> .* >>>|# Added by |# <<< .* <<<)' || true)

    # Identity is per-machine and per-persona; git/.gitconfig already includes
    # ~/.gitconfig.local for it. Git reads sections and keys case-insensitively.
    case "$file" in
        */.gitconfig | .gitconfig)
            while IFS= read -r line; do
                [ -n "${line:-}" ] && report "$file" "$line" \
                    "git identity — belongs in ~/.gitconfig.local"
            done < <(printf '%s\n' "$content" | awk '
                /^[[:space:]]*\[/ { in_user = (tolower($0) ~ /^[[:space:]]*\[user\]/); next }
                in_user && tolower($0) ~ /^[[:space:]]*(email|name)[[:space:]]*=/ { print NR }
            ' || true)
            ;;
    esac
}

while IFS= read -r file; do
    is_exempt "$file" && continue
    content="$(read_file "$file")" || continue
    [ -n "$content" ] || continue
    scan_file "$file" "$content"
done < <(list_files "$@")

if [ "$findings" -gt 0 ]; then
    where="the working tree"
    [ -n "$rev" ] && where="$rev"
    printf '\n%s machine-local finding(s) in %s. Run the config-hygiene skill to move them.\n' \
        "$findings" "$where" >&2
    exit 1
fi
exit 0
