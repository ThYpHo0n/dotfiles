#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="${HOME:?HOME must be set}"

tmp_home="$(mktemp -d)"
cleanup() {
  if [[ -n "${agent_pid:-}" ]]; then
    SSH_AGENT_PID="$agent_pid" SSH_AUTH_SOCK="$agent_sock" ssh-agent -k >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_home"
}
trap cleanup EXIT

mkdir -p "$tmp_home/.cache" "$tmp_home/.ssh"
ln -s "$repo_root/zsh/.zsh_plugins.txt" "$tmp_home/.zsh_plugins.txt"
ln -s "$real_home/.oh-my-zsh" "$tmp_home/.oh-my-zsh"

eval "$(ssh-agent -s)" >/dev/null
agent_sock="$SSH_AUTH_SOCK"
agent_pid="$SSH_AGENT_PID"

ssh-keygen -q -t ed25519 -N '' -f "$tmp_home/.ssh/id_ed25519" >/dev/null
ssh-add "$tmp_home/.ssh/id_ed25519" >/dev/null
expected_fingerprint="$(ssh-add -l | awk 'NR == 1 { print $2 }')"

shell_output="$(
  env -i \
    HOME="$tmp_home" \
    PATH="$PATH" \
    SHELL="${SHELL:-/bin/zsh}" \
    TERM="${TERM:-dumb}" \
    LANG="${LANG:-C.UTF-8}" \
    LC_COLLATE="${LC_COLLATE:-C}" \
    LANGUAGE="${LANGUAGE:-C}" \
    SSH_AUTH_SOCK="$agent_sock" \
    SSH_CONNECTION="client 12345 server 22" \
    zsh -f -c "source '$repo_root/zsh/.zshrc'; printf '%s\n%s\n' \"\$SSH_AUTH_SOCK\" \"\$(ssh-add -l 2>/dev/null | awk 'NR == 1 { print \$2 }')\""
)"

actual_sock="$(printf '%s\n' "$shell_output" | sed -n '1p')"
actual_fingerprint="$(printf '%s\n' "$shell_output" | sed -n '2p')"

if [[ "$actual_sock" != "$agent_sock" ]]; then
  echo "expected SSH_AUTH_SOCK to remain forwarded" >&2
  echo "expected: $agent_sock" >&2
  echo "actual:   $actual_sock" >&2
  exit 1
fi

if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
  echo "expected forwarded agent identities to remain available" >&2
  echo "expected: $expected_fingerprint" >&2
  echo "actual:   $actual_fingerprint" >&2
  exit 1
fi

echo "ssh agent forwarding preserved"
