# Prompt Templates

Use these templates to build high-signal review input files passed to `run_claude_review.sh`.

## Task summary template

```markdown
# Task Summary

## Goal
- <what changed and why>

## Scope
- In scope: <items>
- Out of scope: <items>

## Plan snapshot
- <short plan bullets>

## Risk notes
- <behavioral or migration risk>

## Tests
- Ran: <commands + outcomes>
- Missing: <critical gaps>
```

## Diff context template

````markdown
# Changed Files

- `path/to/file1`: <what changed>
- `path/to/file2`: <what changed>

# Key Diffs

## `path/to/file1`
```diff
<diff snippet>
```

## `path/to/file2`
```diff
<diff snippet>
```
````

## Suggested command patterns

Full gate:

```bash
scripts/run_claude_review.sh \
  --mode plan+code \
  --context-file /tmp/task-summary.md \
  --context-file /tmp/key-diffs.md
```

Plan-only fallback:

```bash
scripts/run_claude_review.sh --mode plan --context-file /tmp/plan.md
```

Code-only fallback:

```bash
scripts/run_claude_review.sh --mode code --context-file /tmp/diff.md
```
