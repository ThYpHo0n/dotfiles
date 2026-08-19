#!/usr/bin/env bash
set -euo pipefail

# GitHub Issue Reference Checker Hook
# PreToolUse hook for Bash(gh pr create*) — warns when gh pr create
# is run without referencing related GitHub issues.

INPUT=$(cat)

# Check if the command already contains a Closes/Fixes/Resolves reference
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
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

# Resolve the issue repo the same way gh will: an explicit -R/--repo or GH_REPO
# on the command wins, otherwise the current checkout's default repo. Suggesting
# issues from the wrong project is worse than suggesting none.
#
# This reads a shell string without parsing it, so a repo-shaped token inside a
# quoted argument can still win. The cost is a wrong suggestion, never a wrong
# action, so the simple match is worth more than a real parser here.
ISSUE_REPO=$(printf '%s' "$COMMAND" \
  | grep -oE '(^|[[:space:]])(-R|--repo)[[:space:]]+[^[:space:]]+|--repo=[^[:space:]]+|GH_REPO=[^[:space:]]+' \
  | sed -E 's/.*[[:space:]=]//' \
  | grep -E '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$' | head -1 || true)
if [[ -z "$ISSUE_REPO" ]]; then
  ISSUE_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi
if [[ -z "$ISSUE_REPO" ]]; then
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
    --repo "$ISSUE_REPO" \
    --state open \
    --search "$KEYWORDS" \
    --limit 5 \
    --json number,title,url \
    2>/dev/null || true)

  if [[ -n "$SEARCH_RESULT" && "$SEARCH_RESULT" != "[]" ]]; then
    FOUND_ISSUES="$SEARCH_RESULT"
  fi
fi

# Check direct issue numbers from branch name
DIRECT_ISSUES="[]"
for NUM in $ISSUE_NUMBERS; do
  # Skip very small numbers that are likely not issue refs
  if [[ "$NUM" -lt 10 ]]; then
    continue
  fi
  ISSUE_INFO=$(gh issue view "$NUM" \
    --repo "$ISSUE_REPO" \
    --json number,title,url,state \
    2>/dev/null || true)

  if [[ -n "$ISSUE_INFO" ]]; then
    STATE=$(echo "$ISSUE_INFO" | jq -r '.state // empty')
    if [[ "$STATE" == "OPEN" ]]; then
      DIRECT_ISSUES=$(jq -n --argjson acc "${DIRECT_ISSUES:-[]}" --argjson issue "$ISSUE_INFO" \
        '$acc + [{number: $issue.number, title: $issue.title, url: $issue.url}]')
    fi
  fi
done

# Merge results, deduplicate by issue number
ALL_ISSUES="[]"
if [[ -n "$FOUND_ISSUES" && "$FOUND_ISSUES" != "[]" ]]; then
  ALL_ISSUES="$FOUND_ISSUES"
fi
if [[ -n "$DIRECT_ISSUES" && "$DIRECT_ISSUES" != "[]" ]]; then
  if [[ "$ALL_ISSUES" == "[]" ]]; then
    ALL_ISSUES="$DIRECT_ISSUES"
  else
    ALL_ISSUES=$(echo "$ALL_ISSUES $DIRECT_ISSUES" | jq -s 'add | unique_by(.number)')
  fi
fi

# If no issues found, exit silently
if [[ "$ALL_ISSUES" == "[]" || -z "$ALL_ISSUES" ]]; then
  echo '{}'
  exit 0
fi

# Build a readable issue list
ISSUE_LIST=$(echo "$ALL_ISSUES" | jq -r '.[] | "- #\(.number): \(.title) (\(.url))"')
ISSUE_COUNT=$(echo "$ALL_ISSUES" | jq 'length')

# Build the context message
CONTEXT="Found ${ISSUE_COUNT} potentially related open issue(s) in ${ISSUE_REPO} for branch '${BRANCH}':
${ISSUE_LIST}

Consider updating the PR description to reference the relevant issue(s) using 'Closes #NNN' or 'Fixes #NNN'. You can use 'gh pr edit --body' to update."

# Return additionalContext so Claude sees the warning
jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    additionalContext: $ctx
  }
}'
