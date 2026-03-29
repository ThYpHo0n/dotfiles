# Review Schema

Use this schema for every external review response.

## Required sections

```text
VERDICT: PASS|REVISE
BLOCKING_ISSUES:
1. ...
NON_BLOCKING_NOTES:
1. ...
REQUIRED_CHANGES:
1. ...
CONFIDENCE: high|medium|low
```

## Rules

- Use `REVISE` if any blocking issue exists.
- If no blockers exist, write `none` under `BLOCKING_ISSUES:`.
- Keep each item concrete and tied to the provided context.
- Avoid generic advice without a specific rationale.
- Do not add extra top-level sections.

## Exit code mapping

`run_claude_review.sh` maps verdicts to status codes:

- `0`: `VERDICT: PASS`
- `10`: `VERDICT: REVISE`
- `20`: invocation failure, timeout, or schema mismatch

When code `20` occurs, ask the user whether to retry, continue without external review, or stop.
