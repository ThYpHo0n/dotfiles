#!/usr/bin/env bash
# SessionStart hook. Tells the model at the start what it would otherwise
# discover mid-task: an open PR on the current branch, read-only directories
# in the checkout, a missing git identity. Every probe is optional and silent
# when its tool is absent.
#
# Setup-specific probes (an employer's CLI, a homelab) do not belong in this
# shared file. Put them as executables into ~/.claude/session-facts.d/; each
# gets the hook input on stdin and prints one fact per line.
set -uo pipefail

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
if [[ -n "$CWD" && -d "$CWD" ]]; then cd "$CWD" || { echo "{}"; exit 0; }; fi

LINES=()

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  if [[ -n "$BRANCH" && "$BRANCH" != "HEAD" ]] && command -v gh >/dev/null 2>&1; then
    PR=$(timeout 10 gh pr view --json number,url,state,mergeable 2>/dev/null || true)
    if [[ -n "$PR" ]]; then
      LINES+=("Open PR for branch ${BRANCH}: $(printf '%s' "$PR" | jq -r '"#\(.number) \(.url) state=\(.state) mergeable=\(.mergeable)"'). It is yours to babysit.")
    fi
  fi
  for d in .github .claude; do
    if [[ -d "$d" && ! -w "$d" ]]; then
      LINES+=("${d}/ is read-only in this checkout. To change it: 'git worktree add \"\$TMPDIR/wt-\$(basename \$PWD)\" -b <branch>' and work there.")
    fi
  done
  if [[ -z "$(git config user.email 2>/dev/null)" ]]; then
    LINES+=("git user.email is unset in this worktree; commits will fail until you set it.")
  fi
fi

DROPIN_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/session-facts.d"
if [[ -d "$DROPIN_DIR" ]]; then
  for probe in "$DROPIN_DIR"/*; do
    [[ -x "$probe" ]] || continue
    while IFS= read -r line; do
      [[ -n "$line" ]] && LINES+=("$line")
    done < <(printf '%s' "$INPUT" | timeout 10 "$probe" 2>/dev/null || true)
  done
fi

if [[ ${#LINES[@]} -eq 0 ]]; then
  echo '{}'; exit 0
fi
CONTEXT=$(printf -- '- %s\n' "${LINES[@]}")
jq -n --arg ctx "Environment facts at session start:
${CONTEXT}" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
