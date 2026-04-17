#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="${HOME:?HOME must be set}"

tmp_home="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_home"
}
trap cleanup EXIT

mkdir -p "$tmp_home/.cache" "$tmp_home/.ssh"
ln -s "$repo_root/zsh/.zsh_plugins.txt" "$tmp_home/.zsh_plugins.txt"
ln -s "$real_home/.oh-my-zsh" "$tmp_home/.oh-my-zsh"

forwarded_sock="$tmp_home/.ssh/forwarded-agent.sock"

shell_output="$(
  env -i \
    HOME="$tmp_home" \
    PATH="$PATH" \
    SHELL="${SHELL:-/bin/zsh}" \
    TERM="${TERM:-dumb}" \
    LANG="${LANG:-C.UTF-8}" \
    LC_COLLATE="${LC_COLLATE:-C}" \
    LANGUAGE="${LANGUAGE:-C}" \
    SSH_AUTH_SOCK="$forwarded_sock" \
    SSH_CONNECTION="client 12345 server 22" \
    zsh -f -c "source '$repo_root/zsh/.zshrc'; printf '%s\n%s\n' \"\$SSH_AUTH_SOCK\" \"\${SSH_AGENT_PID:-}\""
)"

actual_sock="$(printf '%s\n' "$shell_output" | sed -n '1p')"
actual_pid="$(printf '%s\n' "$shell_output" | sed -n '2p')"

if [[ "$actual_sock" != "$forwarded_sock" ]]; then
  echo "expected SSH_AUTH_SOCK to remain unchanged in a remote shell" >&2
  echo "expected: $forwarded_sock" >&2
  echo "actual:   $actual_sock" >&2
  exit 1
fi

if [[ -n "$actual_pid" ]]; then
  echo "expected remote shell startup not to bootstrap a local ssh-agent" >&2
  echo "actual SSH_AGENT_PID: $actual_pid" >&2
  exit 1
fi

echo "ssh agent forwarding environment preserved"
