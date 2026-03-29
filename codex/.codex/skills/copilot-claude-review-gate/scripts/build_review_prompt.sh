#!/usr/bin/env bash
set -euo pipefail

mode="plan+code"
declare -a context_files=()

usage() {
  cat <<'USAGE'
Usage:
  build_review_prompt.sh [--mode plan|code|plan+code] --context-file <path> [--context-file <path> ...]

Build a single Copilot prompt for external review.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --mode" >&2
        exit 2
      fi
      mode="$2"
      shift 2
      ;;
    --context-file)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --context-file" >&2
        exit 2
      fi
      context_files+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$mode" in
  plan|code|plan+code) ;;
  *)
    echo "Invalid --mode: $mode" >&2
    exit 2
    ;;
esac

if [[ ${#context_files[@]} -eq 0 ]]; then
  echo "At least one --context-file is required" >&2
  exit 2
fi

for path in "${context_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "Context file not found: $path" >&2
    exit 2
  fi
done

cat <<EOF_PROMPT
You are an independent senior reviewer. Review the provided context for $mode quality gates.

Primary objectives:
1. Find behavioral regressions, incorrect assumptions, missing edge-case handling, and unsafe changes.
2. Verify the plan and implementation align.
3. Identify testing gaps and rollout risk.
4. Recommend only concrete and high-value changes.

Strict output format (required):
VERDICT: PASS|REVISE
BLOCKING_ISSUES:
1. ...
NON_BLOCKING_NOTES:
1. ...
REQUIRED_CHANGES:
1. ...
CONFIDENCE: high|medium|low

Rules:
- Use REVISE if any blocker exists.
- If there are no blockers, write "none" under BLOCKING_ISSUES.
- Keep findings specific and actionable.
- Do not include extra top-level sections.

Context begins below.
EOF_PROMPT

max_chars_per_file=30000
for path in "${context_files[@]}"; do
  echo
  echo "===== BEGIN CONTEXT: $path ====="
  content=$(cat "$path")
  content_len=${#content}
  if (( content_len > max_chars_per_file )); then
    printf '%s' "$content" | head -c "$max_chars_per_file"
    echo
    echo
    echo "[TRUNCATED] Original length: ${content_len} chars"
  else
    printf '%s\n' "$content"
  fi
  echo "===== END CONTEXT: $path ====="
done
