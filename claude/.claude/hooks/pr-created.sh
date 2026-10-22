#!/usr/bin/env bash
# PostToolUse hook for Bash. Fires after `gh pr create` succeeds: reads the PR
# back from GitHub so the model sees the title and body it actually published
# (two sessions sharing $TMPDIR have clobbered a body file before), and
# injects the definition-of-done checklist at the moment it applies.
set -uo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
case "$COMMAND" in
  *"gh pr create"*) ;;
  *) echo '{}'; exit 0 ;;
esac

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
if [[ -n "$CWD" && -d "$CWD" ]]; then cd "$CWD" || { echo "{}"; exit 0; }; fi

STDOUT=$(printf '%s' "$INPUT" | jq -r '.tool_response.stdout // .tool_response.output // empty')
URL=$(printf '%s\n' "$STDOUT" | grep -oE 'https://github\.com/[^/ ]+/[^/ ]+/pull/[0-9]+' | tail -1)
if [[ -z "$URL" ]]; then
  URL=$(gh pr view --json url -q .url 2>/dev/null || true)
fi
[[ -z "$URL" ]] && { echo '{}'; exit 0; }

PR_JSON=$(gh pr view "$URL" --json number,title,body,isDraft,baseRefName,headRefName 2>/dev/null) || { echo '{}'; exit 0; }
TITLE=$(printf '%s' "$PR_JSON" | jq -r '.title')
BODY_HEAD=$(printf '%s' "$PR_JSON" | jq -r '.body' | head -c 400)
CLOSES=$(printf '%s' "$PR_JSON" | jq -r '.body' | grep -oiE '(closes|fixes|resolves) #[0-9]+' | tr '\n' ' ')
HEAD=$(printf '%s' "$PR_JSON" | jq -r '.headRefName')
BASE=$(printf '%s' "$PR_JSON" | jq -r '.baseRefName')

CONTEXT="PR published: ${URL}
Title on GitHub: ${TITLE}
Branch: ${HEAD} -> ${BASE}
Linked issues: ${CLOSES:-none}
Body as published (first 400 chars):
${BODY_HEAD}

Check the title and body above against the diff you pushed; fix with 'gh pr edit' if they belong to another PR.
This PR is yours until it is mergeable: watch it now (the harness's PR watch tool if it has one, else 'gh pr checks ${URL} --watch'); fix red checks; answer and resolve every bot thread; keep the branch conflict-free; after merge, watch the delivery run. End with 'Mergeable now: yes/no'."

jq -n --arg ctx "$CONTEXT" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
