#!/usr/bin/env bash
set -euo pipefail

# GitHub Issue Reference Checker Hook
# PreToolUse hook for Bash(gh pr create*) — warns when gh pr create
# is run without referencing related GitHub issues.

INPUT=$(cat)

# Check if the command already contains a Closes/Fixes/Resolves reference
COMMAND=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty')
if echo "$COMMAND" | grep -qiE '(closes|fixes|resolves)\s+#[0-9]+'; then
  echo '{}'
  exit 0
fi

# Get current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [[ -z "$BRANCH" || "$BRANCH" =~ ^(main|master|develop)$ ]]; then
  echo '{}'
  exit 0
fi

# Extract keywords from branch name
# Strip common prefixes: feature/, fix/, bugfix/, hotfix/, chore/, refactor/, etc.
KEYWORDS=$(echo "$BRANCH" | sed -E 's#^(feature|fix|bugfix|hotfix|chore|refactor|docs|ci|test|improvement|enhancement|task)/##' | tr '/-' ' ')

# Extract any issue numbers from branch name (e.g. "fix/526-some-desc" → 526)
ISSUE_NUMBERS=$(echo "$BRANCH" | grep -oE '[0-9]+' || true)

FOUND_ISSUES=""

# Search by keywords (skip if keywords are too short/generic)
KEYWORD_COUNT=$(echo "$KEYWORDS" | wc -w | tr -d ' ')
if [[ "$KEYWORD_COUNT" -gt 0 ]]; then
  SEARCH_RESULT=$(gh issue list \
    --repo hero-handwerk/infrastructure \
    --state open \
    --search "$KEYWORDS" \
    --limit 5 \
    --json number,title,url \
    2>/dev/null || true)

  if [[ -n "$SEARCH_RESULT" && "$SEARCH_RESULT" != "[]" ]]; then
    FOUND_ISSUES="$SEARCH_RESULT"
  fi
fi

# Check direct issue numbers from branch name, accumulating every open issue
DIRECT_ISSUES="[]"
for NUM in $ISSUE_NUMBERS; do
  # Skip very small numbers that are likely not issue refs
  if [[ "$NUM" -lt 10 ]]; then
    continue
  fi
  ISSUE_INFO=$(gh issue view "$NUM" \
    --repo hero-handwerk/infrastructure \
    --json number,title,url,state \
    2>/dev/null || true)

  if [[ -n "$ISSUE_INFO" ]]; then
    STATE=$(printf '%s\n' "$ISSUE_INFO" | jq -r '.state // empty')
    if [[ "$STATE" == "OPEN" ]]; then
      DIRECT_ISSUES=$(printf '%s\n' "$ISSUE_INFO" | jq --argjson acc "$DIRECT_ISSUES" '$acc + [{number, title, url}]')
    fi
  fi
done

# Merge results, deduplicate by issue number
ALL_ISSUES="[]"
if [[ -n "$FOUND_ISSUES" && "$FOUND_ISSUES" != "[]" ]]; then
  ALL_ISSUES="$FOUND_ISSUES"
fi
if [[ "$DIRECT_ISSUES" != "[]" ]]; then
  ALL_ISSUES=$(jq -n --argjson all "$ALL_ISSUES" --argjson direct "$DIRECT_ISSUES" '$all + $direct | unique_by(.number)')
fi

# If no issues found, exit silently
if [[ "$ALL_ISSUES" == "[]" || -z "$ALL_ISSUES" ]]; then
  echo '{}'
  exit 0
fi

# Build a readable issue list
ISSUE_LIST=$(printf '%s\n' "$ALL_ISSUES" | jq -r '.[] | "- #\(.number): \(.title) (\(.url))"')
ISSUE_COUNT=$(printf '%s\n' "$ALL_ISSUES" | jq 'length')

# Build the context message
CONTEXT="Found ${ISSUE_COUNT} potentially related open issue(s) in hero-handwerk/infrastructure for branch '${BRANCH}':
${ISSUE_LIST}

Consider updating the PR description to reference the relevant issue(s) using 'Closes #NNN' or 'Fixes #NNN'. You can use 'gh pr edit --body' to update."

# Return additionalContext so Claude sees the warning
jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    additionalContext: $ctx
  }
}'
