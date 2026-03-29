# Personal Codex Skills

This directory is the tracked source of truth for personal Codex skills that
should be available on every machine managed by this dotfiles repo.

## Layout

Put each skill in its own directory:

```text
~/.codex/skills/
  my-skill/
    SKILL.md
```

Optional supporting files can live next to `SKILL.md` inside the same skill
directory when the skill needs examples, templates, reference assets, or small
portable helper scripts.

## What Belongs Here

- personal reusable skills
- prompt/instruction bundles
- lightweight templates and references that travel cleanly between machines

## What Does Not Belong Here

- secrets, tokens, or private host-specific paths
- machine-only configuration
- plugin packaging metadata for distribution
- MCP/app wiring that should be managed as a real plugin

If a skill grows beyond a portable instruction bundle and starts needing formal
packaging, install-time setup, secrets, or broader distribution, promote it
into a Codex plugin instead of expanding this directory into a pseudo-plugin
system.
