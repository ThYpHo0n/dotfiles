#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="${HOME:?HOME must be set}"

tmp_home="$(mktemp -d)"
cleanup() {
  if [[ -n "${agent_pid:-}" && -n "${agent_sock:-}" ]]; then
    SSH_AGENT_PID="$agent_pid" SSH_AUTH_SOCK="$agent_sock" ssh-agent -k >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_home"
}
trap cleanup EXIT

mkdir -p "$tmp_home/.cache" "$tmp_home/.ssh"
ln -s "$repo_root/zsh/.zsh_plugins.txt" "$tmp_home/.zsh_plugins.txt"
ln -s "$real_home/.oh-my-zsh" "$tmp_home/.oh-my-zsh"

ssh-keygen -q -t ed25519 -N '' -f "$tmp_home/.ssh/id_ed25519" >/dev/null
expected_fingerprint="$(ssh-keygen -lf "$tmp_home/.ssh/id_ed25519.pub" | awk 'NR == 1 { print $2 }')"

shell_output="$(
  env -i \
    HOME="$tmp_home" \
    PATH="$PATH" \
    SHELL="${SHELL:-/bin/zsh}" \
    TERM="${TERM:-dumb}" \
    LANG="${LANG:-C.UTF-8}" \
    LC_COLLATE="${LC_COLLATE:-C}" \
    LANGUAGE="${LANGUAGE:-C}" \
    zsh -f -c "source '$repo_root/zsh/.zshrc'; printf '%s\n%s\n%s\n' \"\$SSH_AUTH_SOCK\" \"\${SSH_AGENT_PID:-}\" \"\$(ssh-add -l 2>/dev/null | awk 'NR == 1 { print \$2 }')\""
)"

agent_sock="$(printf '%s\n' "$shell_output" | sed -n '1p')"
agent_pid="$(printf '%s\n' "$shell_output" | sed -n '2p')"
actual_fingerprint="$(printf '%s\n' "$shell_output" | sed -n '3p')"

if [[ -z "$agent_sock" || ! -S "$agent_sock" ]]; then
  echo "expected shell startup to expose a live SSH agent socket" >&2
  echo "actual socket: $agent_sock" >&2
  exit 1
fi

if [[ -z "$agent_pid" ]]; then
  echo "expected shell startup to expose SSH_AGENT_PID" >&2
  exit 1
fi

if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
  echo "expected shell startup to auto-load ~/.ssh/id_ed25519" >&2
  echo "expected: $expected_fingerprint" >&2
  echo "actual:   $actual_fingerprint" >&2
  exit 1
fi

echo "default ssh identity loaded into the local agent"
