---
description: "Move machine-local sediment out of shared dotfiles into .local overrides."
disable-model-invocation: true
---

# Config Hygiene

Installers append to whatever rc file they find. In a stow'd repo that file is
the shared one, so `~/.rd/bin` PATH lines, `[user]` identity, and
`### MANAGED BY …` blocks land in config that every machine pulls. Call the
accumulation **sediment**: it settles at the bottom of a file, it arrives
without anyone deciding to add it, and it is invisible until another machine
breaks or a public repo publishes a username.

This skill moves sediment into the **override** — the untracked `.local` file
the shared config already sources.

`bin/check-shared-config-hygiene.sh` decides what counts as sediment. Read it
when you need the current rules; do not restate them here.

## 1. Find it

```bash
./bin/check-shared-config-hygiene.sh
```

Each finding prints as `file:line: reason`. Done when you have the full list —
the script exits 0 only when the tree is clean, so a non-zero exit with no
output means the script itself is broken and needs fixing first.

## 2. Sort each finding into rewrite or move

Two destinations, and the choice is the whole judgment:

- **Rewrite in place** when the line is portable and merely written badly — a
  hardcoded home that `$HOME` expresses exactly. `export
  PATH="/Users/you/.local/bin:$PATH"` is the same instruction on every machine
  once it says `$HOME`. It stays in shared config.
- **Move to the override** when the line is true only on this machine — a tool
  installed only here, an installer block, an identity, a credential path.
  Rewrite its home path to `$HOME` on the way, so the line survives a rename.

Identity always moves: `git/.gitconfig` already ends with `[include] path =
~/.gitconfig.local` for exactly this.

Done when every finding has a destination.

## 3. Move it, preserving behaviour

Append moved lines to the override under a header naming where they came from,
so the next person can tell sediment from lines someone chose to write:

```bash
# --- Moved out of the shared zsh/.zshrc (machine-local installer output) ---
```

Order matters: the shared file sources the override at a fixed point, so lines
that were running late now run there instead. Check anything that depends on
earlier PATH entries.

Guard every `eval` of a command that may be absent, since the override is no
longer protected by the shared file's `source_if_exists` discipline:

```bash
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
```

Done when the shared file holds only portable lines and the override holds the
rest.

## 4. Teach the next machine

When a moved line is one another machine will also want — a hook the shared
config calls, a variable it expects — add it commented-out to the tracked
`.example` beside the override. That file is how a fresh clone learns which
overrides exist.

Done when a fresh clone could reconstruct the override from the example.

## 5. Prove it

```bash
./bin/check-shared-config-hygiene.sh   # exits 0
./tests/shared_config_hygiene_test.sh  # detector still catches all three shapes
zsh -n zsh/.zshrc                      # shared config parses
zsh -i -c true                         # interactive shell starts without errors
git config --get user.email            # identity still resolves from the override
```

Done when all five pass. The pre-push hook runs the first of these, so a push
that still trips it means the move is incomplete rather than that the hook is
wrong.
