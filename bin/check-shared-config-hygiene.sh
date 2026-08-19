#!/usr/bin/env bash
# Report machine-local sediment in tracked (shared) config.
#
# Installers append to whatever rc file they find. In a stow'd dotfiles repo
# that file is the shared one, so machine-local PATHs and identity end up
# committed and break every other machine. This is the source of truth for
# what counts as sediment; the config-hygiene skill does the moving.
#
# Exit 0 = clean, 1 = sediment found (paths printed as file:line).

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

# .example files document these patterns on purpose; the skill quotes them as
# samples; .local files are exactly where sediment belongs.
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

while IFS= read -r file; do
    is_exempt "$file" && continue
    [ -f "$file" ] || continue

    # A home directory spelled out instead of $HOME breaks on every other
    # machine and publishes the username.
    while IFS=: read -r line _; do
        [ -n "${line:-}" ] && report "$file" "$line" "absolute home path — use \$HOME, or move the line to a .local override"
    done < <(grep -nE '(/Users/|/home/)[A-Za-z][A-Za-z0-9._-]*/' "$file" \
        | grep -vE '/home/linuxbrew/' || true)

    # Blocks an installer wrote into a file it does not own.
    while IFS=: read -r line _; do
        [ -n "${line:-}" ] && report "$file" "$line" "installer-managed block — move it to a .local override"
    done < <(grep -nE '^(### MANAGED BY |# >>> .* >>>|# Added by |# <<< .* <<<)' "$file" || true)

    # Identity is per-machine and per-persona; git/.gitconfig already includes
    # ~/.gitconfig.local for it.
    case "$file" in
        */.gitconfig)
            while IFS=: read -r line _; do
                [ -n "${line:-}" ] && report "$file" "$line" "git identity — belongs in ~/.gitconfig.local"
            done < <(awk -F: '
                /^[[:space:]]*\[/ { in_user = ($0 ~ /^[[:space:]]*\[user\]/); next }
                in_user && /^[[:space:]]*(email|name)[[:space:]]*=/ { print NR }
            ' "$file" || true)
            ;;
    esac
done < <(git ls-files)

if [ "$findings" -gt 0 ]; then
    printf '\n%s machine-local finding(s) in shared config. Run the config-hygiene skill to move them.\n' "$findings" >&2
    exit 1
fi
exit 0
