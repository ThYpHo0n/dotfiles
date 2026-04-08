# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

```text
claude   shared Claude Code settings, hooks, and sound effects
codex    shared Codex configuration and personal skills
git      global git configuration
ghostty  Ghostty terminal settings
zsh      shared Zsh configuration, theme, and plugin list
```

## Support Targets

- macOS workstation
- Debian/Ubuntu workstation
- Debian/Ubuntu headless/server environments such as a homelab box

The shared shell config is intentionally portable. Machine-specific paths, secrets, cloud SDK installs, and personal aliases belong in local untracked override files.

## Dependencies

### Required on all machines

- `git`
- `stow`
- `zsh`
- `oh-my-zsh`
- `antidote`

### Optional

- `claude` (Claude Code CLI)
- `codex`
- `forge` for AI shell integration (plugin, theme, completions)
- `rtk` (Rust Token Killer) for token-optimized CLI proxying in Claude Code hooks
- `pnpm`
- `lsd` for the enhanced `ls` alias
- `fzf`
- `keychain` to bootstrap a local SSH/GPG agent when no agent is already present
- `gpg`
- `Hack Nerd Font` for the prompt and Ghostty font setup
- `ghostty` for desktop/workstation machines

## Install Packages

### macOS

Install [Homebrew](https://brew.sh/) first, then:

```bash
brew install stow antidote git zsh fzf lsd gnupg pinentry-mac keychain
brew install --cask font-hack-nerd-font
```

Install `oh-my-zsh` separately if it is not already present.

### Debian / Ubuntu

For workstations:

```bash
sudo apt update
sudo apt install -y git stow zsh curl fzf keychain gnupg
```

Install `antidote` using the distro package when available:

```bash
sudo apt install -y zsh-antidote
```

If your release does not provide `zsh-antidote`, install `antidote` manually and keep the script at one of the paths sourced by `zsh/.zshrc`, or adapt your local override.

Install `oh-my-zsh` separately if it is not already present.

Optional workstation packages:

```bash
sudo apt install -y lsd
```

Ghostty and Nerd Font setup are optional on Debian/Ubuntu and are not required for server usage.

## Usage

Clone the repo and use `stow` from the repository root:

```bash
git clone git@github.com:ThYpHo0n/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### Recommended Stow Profiles

For a Debian/Ubuntu server or homelab host:

```bash
stow zsh git codex claude
```

For a workstation with Ghostty installed:

```bash
stow zsh git codex claude ghostty
```

## Codex Skills

The tracked Codex package lives at [`codex/.codex/skills`](codex/.codex/skills).
Stowing `codex` creates `~/.codex/skills`, which is the shared home for personal
skills that should exist everywhere.

If `~/.codex` does not exist yet on a machine, create it before running
`stow codex` so Stow links `skills` inside the existing Codex home instead of
turning the whole `~/.codex` path into a symlink:

```bash
mkdir -p ~/.codex
stow codex
```

Add each skill as its own directory containing `SKILL.md`:

```text
codex/.codex/skills/
  my-skill/
    SKILL.md
```

Use the dotfiles-managed skills directory for personal portable skills. If a
skill later needs plugin packaging, marketplace metadata, scripts, or broader
distribution, split it into a Codex plugin at that point instead of storing it
under dotfiles.

## Claude Code Settings

The tracked Claude package lives at [`claude/.claude/`](claude/.claude/).
Stowing `claude` creates `~/.claude/settings.json` and symlinks for each hook
script inside `~/.claude/hooks/`.

If `~/.claude` does not exist yet on a machine, create it before running
`stow claude` so Stow links individual items inside the existing Claude home
instead of turning the whole `~/.claude` path into a symlink:

```bash
mkdir -p ~/.claude ~/.claude/hooks
stow claude
```

Creating `~/.claude/hooks` before stowing ensures per-file symlinks so that
plugin-managed files (like skill hooks) and local-only files (like sound
effects) can coexist in the same directory without touching the dotfiles repo.

The shared settings assume `node` is on `PATH` (for the HUD status line).
Sound effect hooks and audio files are not tracked and should be configured
per-machine in `settings.local.json`.

### Claude machine-specific overrides

Claude Code deep-merges `~/.claude/settings.local.json` over `settings.json`.

```bash
cp ~/dotfiles/claude/.claude/settings.local.json.example ~/.claude/settings.local.json
```

Use `settings.local.json` for:

- machine-specific permission grants (MCP, Notion, Slack, etc.)
- sound effect hooks (audio files and playback commands are local-only)
- host-specific model or plugin overrides

## Local Machine Overrides

### Git identity

The shared git config in [`git/.gitconfig`](git/.gitconfig) includes `~/.gitconfig.local`.

```bash
cp ~/dotfiles/git/.gitconfig.local.example ~/.gitconfig.local
```

Then edit `~/.gitconfig.local` with your name, email, signing key, and any machine-specific Git tooling.

### Zsh host-specific settings

The shared Zsh config sources `~/.zshrc.local` if it exists.

```bash
cp ~/dotfiles/zsh/.zshrc.local.example ~/.zshrc.local
```

Use `~/.zshrc.local` for:

- private paths
- workstation-only tools
- host-specific aliases
- host-specific SSH or GPG agent overrides
- secrets or local environment variables such as `KUBECONFIG` or vault password files

Examples that belong in the local override instead of the shared tracked config:

- `~/workspace` aliases
- Google Cloud SDK or Rancher Desktop paths
- iCloud/Obsidian paths
- homelab-specific kubeconfig paths
- machine-specific `gpg-agent` SSH socket integration

## Notes for macOS

- The shared `zsh/.zshrc` auto-loads SSH passphrases from the macOS Keychain into the launchd-managed agent on shell startup.
- To store a key's passphrase in the Keychain for the first time: `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`
- After that one-time step, new shells load the passphrase automatically and SSH operations (including `git pull`) will not prompt.

## Notes for Debian/Ubuntu Servers

- The shared `zsh/.zshrc` avoids GUI-only Linux assumptions so remote shells start cleanly on headless systems.
- In SSH sessions with agent forwarding, the shared shell preserves the forwarded `SSH_AUTH_SOCK` instead of replacing it with a server-local agent.
- When no agent is already available, the shared shell bootstraps a local agent with `keychain` if installed, otherwise falls back to `ssh-agent`.
- If `lsd` is not installed, the shell falls back to the platform `ls`.
- If `ghostty` is not installed, skip `stow ghostty`.
- If you want one machine to use `gpg-agent` as its SSH agent, keep that override in `~/.zshrc.local` on that machine.
- If you SSH from Ghostty into a remote host, the `xterm-ghostty` terminfo may not be installed. The shared shell auto-falls back to `xterm-256color`. For full Ghostty terminal features, install the terminfo on the remote host: `infocmp -x xterm-ghostty | ssh <host> tic -x -`
- WSL-specific behavior stays isolated to WSL and does not affect normal Debian/Ubuntu hosts.

Inspired by [aeolyus/dotfiles](https://github.com/aeolyus/dotfiles)
