#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

mode="plan+code"
timeout_sec=180
declare -a context_files=()

usage() {
  cat <<'USAGE'
Usage:
  run_claude_review.sh [--mode plan|code|plan+code] [--timeout-sec N] --context-file <path> [--context-file <path> ...]

Exit codes:
  0  PASS
  10 REVISE
  20 Invocation/runtime/schema failure
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --mode" >&2
        exit 20
      fi
      mode="$2"
      shift 2
      ;;
    --timeout-sec)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --timeout-sec" >&2
        exit 20
      fi
      timeout_sec="$2"
      shift 2
      ;;
    --context-file)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --context-file" >&2
        exit 20
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
      exit 20
      ;;
  esac
done

case "$mode" in
  plan|code|plan+code) ;;
  *)
    echo "Invalid --mode: $mode" >&2
    exit 20
    ;;
esac

if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || [[ "$timeout_sec" -eq 0 ]]; then
  echo "--timeout-sec must be a positive integer" >&2
  exit 20
fi

if [[ ${#context_files[@]} -eq 0 ]]; then
  echo "At least one --context-file is required" >&2
  exit 20
fi

if ! command -v copilot >/dev/null 2>&1; then
  echo "copilot CLI not found in PATH" >&2
  exit 20
fi

for path in "${context_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "Context file not found: $path" >&2
    exit 20
  fi
done

prompt_file=$(mktemp)
trap 'rm -f "$prompt_file"' EXIT

prompt_cmd=("$script_dir/build_review_prompt.sh" "--mode" "$mode")
for path in "${context_files[@]}"; do
  prompt_cmd+=("--context-file" "$path")
done
"${prompt_cmd[@]}" > "$prompt_file"

set +e
review_output=$(timeout "${timeout_sec}s" copilot \
  -p "$(cat "$prompt_file")" \
  -s \
  --model claude-opus-4.6 \
  --allow-all-tools \
  --allow-all-paths \
  --allow-all-urls 2>&1)
cmd_status=$?
set -e

if [[ $cmd_status -eq 124 ]]; then
  echo "Copilot review timed out after ${timeout_sec}s" >&2
  exit 20
fi

if [[ $cmd_status -ne 0 ]]; then
  echo "Copilot review command failed" >&2
  echo "$review_output" >&2
  exit 20
fi

printf '%s\n' "$review_output"

verdict=$(printf '%s\n' "$review_output" \
  | sed -nE 's/^[[:space:]]*VERDICT:[[:space:]]*(.*)$/\1/p' \
  | head -n1 \
  | tr -d '*`_' \
  | tr '[:lower:]' '[:upper:]' \
  | sed -nE 's/^[[:space:]]*(PASS|REVISE)[[:space:]]*$/\1/p')

if [[ -z "$verdict" ]]; then
  echo "Missing required VERDICT line in reviewer response" >&2
  exit 20
fi

if [[ "$verdict" == "PASS" ]]; then
  exit 0
fi

if [[ "$verdict" == "REVISE" ]]; then
  exit 10
fi

echo "Unexpected VERDICT value: $verdict" >&2
exit 20
