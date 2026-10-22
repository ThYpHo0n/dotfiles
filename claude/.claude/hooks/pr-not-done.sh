#!/usr/bin/env bash
# Stop hook. When this session pushed or opened a PR and that PR still has
# failing checks, unresolved review threads, or merge conflicts, block the
# stop once with the concrete list. Pending checks only produce a notice.
# A second stop on an unchanged PR state is allowed through, so the model
# is nudged once per change, never looped.
set -uo pipefail

INPUT=$(cat)
if [[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" == "true" ]]; then
  echo '{}'; exit 0
fi

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
if [[ -n "$CWD" && -d "$CWD" ]]; then cd "$CWD" || { echo "{}"; exit 0; }; fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo '{}'; exit 0; }

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
if [[ -n "$TRANSCRIPT" && -r "$TRANSCRIPT" ]]; then
  grep -qE 'gh pr (create|edit|merge)|git push' "$TRANSCRIPT" || { echo '{}'; exit 0; }
fi

PR=$(gh pr view --json number,url,state,mergeable,headRefOid 2>/dev/null) || { echo '{}'; exit 0; }
STATE=$(printf '%s' "$PR" | jq -r '.state')
[[ "$STATE" == "OPEN" ]] || { echo '{}'; exit 0; }
NUMBER=$(printf '%s' "$PR" | jq -r '.number')
URL=$(printf '%s' "$PR" | jq -r '.url')
MERGEABLE=$(printf '%s' "$PR" | jq -r '.mergeable')
HEAD_SHA=$(printf '%s' "$PR" | jq -r '.headRefOid')

CHECKS=$(gh pr checks "$NUMBER" --json name,bucket 2>/dev/null || echo '[]')
FAILING=$(printf '%s' "$CHECKS" | jq -r '[.[] | select(.bucket == "fail") | .name] | join(", ")')
PENDING=$(printf '%s' "$CHECKS" | jq -r '[.[] | select(.bucket == "pending")] | length')

OWNER_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
UNRESOLVED=0
if [[ -n "$OWNER_REPO" ]]; then
  UNRESOLVED=$(gh api graphql \
    -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved isOutdated}}}}}' \
    -F o="${OWNER_REPO%/*}" -F r="${OWNER_REPO#*/}" -F n="$NUMBER" 2>/dev/null \
    | jq -r '[.data.repository.pullRequest.reviewThreads.nodes[]? | select(.isResolved | not)] | length' 2>/dev/null || echo 0)
fi

PROBLEMS=()
[[ -n "$FAILING" ]] && PROBLEMS+=("failing checks: ${FAILING}")
[[ "$MERGEABLE" == "CONFLICTING" ]] && PROBLEMS+=("merge conflicts with the base branch")
[[ "${UNRESOLVED:-0}" -gt 0 ]] && PROBLEMS+=("${UNRESOLVED} unresolved review thread(s)")

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-pr-not-done"
mkdir -p "$STATE_DIR" 2>/dev/null
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"')
STATE_FILE="$STATE_DIR/${SESSION}"
FINGERPRINT="${HEAD_SHA}|${FAILING}|${MERGEABLE}|${UNRESOLVED}"

if [[ ${#PROBLEMS[@]} -eq 0 ]]; then
  if [[ "$PENDING" -gt 0 ]]; then
    jq -n --arg msg "PR #${NUMBER}: ${PENDING} check(s) still running. Keep watching it (the harness's PR watch tool, or gh pr checks --watch)." '{systemMessage: $msg}'
  else
    echo '{}'
  fi
  exit 0
fi

if [[ -f "$STATE_FILE" && "$(cat "$STATE_FILE")" == "$FINGERPRINT" ]]; then
  jq -n --arg msg "PR #${NUMBER} is still not mergeable: $(IFS='; '; echo "${PROBLEMS[*]}")" '{systemMessage: $msg}'
  exit 0
fi
printf '%s' "$FINGERPRINT" > "$STATE_FILE"

REASON="PR #${NUMBER} (${URL}) is not done: $(IFS='; '; echo "${PROBLEMS[*]}"). Fix the red checks, answer and resolve the review threads, merge the base branch if conflicting, then report 'Mergeable now: yes/no'. If a check is red for a reason outside this PR, say exactly which and why."
jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
