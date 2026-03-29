---
name: copilot-claude-review-gate
description: Run a pre-wrap external review gate using GitHub Copilot CLI with Claude Opus 4.6 before finalizing substantial implementation work. Use when Codex has produced or updated plans and code and needs an independent pass for blockers, regressions, edge cases, and test gaps. Skip for trivial or purely conversational responses.
---

# Copilot Claude Review Gate

## Overview

Run a structured external review before wrapping up substantial tasks. Use Copilot CLI with `--model claude-opus-4.6` and require a strict verdict contract: `PASS` or `REVISE` with concrete blocking issues.

## Workflow

1. Decide whether to run the gate.
- Run for substantial work: multi-file edits, architecture changes, behavior changes, risk-sensitive fixes, migration work, or anything that would normally merit a code review.
- Skip for trivial, non-implementation, or purely informational replies.

2. Build review context.
- Include a concise task summary.
- Include final plan text when available.
- Include changed file summaries and key diff snippets.
- Include testing performed, missing tests, and known risks.
- Do not include secrets or sensitive tokens.

3. Execute external review.
- Run `scripts/run_claude_review.sh --mode plan+code --context-file <file> ...`.
- Prefer 1-3 focused context files over very large raw dumps.

4. Apply verdict policy.
- `PASS`: proceed to wrap-up.
- `REVISE`: address blocking items and run one follow-up review.
- Invocation failure or timeout: ask the user how to proceed (`retry`, `continue without external review`, or `stop`).

## Commands

Use from this skill directory.

```bash
scripts/run_claude_review.sh \
  --mode plan+code \
  --context-file /tmp/task-summary.md \
  --context-file /tmp/key-diff.md
```

Plan-only pass:

```bash
scripts/run_claude_review.sh --mode plan --context-file /tmp/plan.md
```

Code-only pass:

```bash
scripts/run_claude_review.sh --mode code --context-file /tmp/diff.md
```

## Output Contract

Require response sections exactly as documented in `references/review_schema.md`:

- `VERDICT: PASS|REVISE`
- `BLOCKING_ISSUES:`
- `NON_BLOCKING_NOTES:`
- `REQUIRED_CHANGES:`
- `CONFIDENCE: high|medium|low`

Interpret exit codes from `run_claude_review.sh`:

- `0`: review passed
- `10`: review requested revisions
- `20`: invocation/runtime/schema failure

## Context and Token Discipline

Keep context compact and high signal.

- Prioritize risky files and behavioral changes.
- Truncate generated dumps before review input if needed.
- Include enough evidence for claims, but avoid full repository dumps.

For reusable prompt text patterns, read `references/prompt_templates.md`.
