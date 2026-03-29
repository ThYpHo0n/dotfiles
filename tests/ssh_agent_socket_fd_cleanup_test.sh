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
    zsh -f -c '
      source "'"$repo_root"'/zsh/.zshrc"
      before=$(ls /proc/$$/fd | wc -l)
      has_live_socket "'"$agent_sock"'"
      probe_status=$?
      after=$(ls /proc/$$/fd | wc -l)
      print -r -- "$before $after $probe_status ${REPLY-}"
    '
)"

before_count="$(printf '%s\n' "$shell_output" | awk '{print $1}')"
after_count="$(printf '%s\n' "$shell_output" | awk '{print $2}')"
probe_status="$(printf '%s\n' "$shell_output" | awk '{print $3}')"
reply_value="$(printf '%s\n' "$shell_output" | awk '{print $4}')"

if [[ "$probe_status" != "0" ]]; then
  echo "expected has_live_socket to succeed for a live agent socket" >&2
  exit 1
fi

if [[ "$after_count" != "$before_count" ]]; then
  echo "expected has_live_socket to close its probe file descriptor" >&2
  echo "before: $before_count" >&2
  echo "after:  $after_count" >&2
  exit 1
fi

if [[ -n "$reply_value" ]]; then
  echo "expected has_live_socket not to leave a probe fd in REPLY" >&2
  echo "reply: $reply_value" >&2
  exit 1
fi

echo "ssh agent socket probe cleans up its file descriptor"
