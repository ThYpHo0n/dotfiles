# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

```text
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

- `lsd` for the enhanced `ls` alias
- `fzf`
- `keychain`
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
stow zsh git
```

For a workstation with Ghostty installed:

```bash
stow zsh git ghostty
```

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
- secrets or local environment variables such as `KUBECONFIG` or vault password files

Examples that belong in the local override instead of the shared tracked config:

- `~/workspace` aliases
- Google Cloud SDK or Rancher Desktop paths
- iCloud/Obsidian paths
- homelab-specific kubeconfig paths

## Notes for Debian/Ubuntu Servers

- The shared `zsh/.zshrc` avoids GUI-only Linux assumptions so remote shells start cleanly on headless systems.
- If `lsd` is not installed, the shell falls back to the platform `ls`.
- If `ghostty` is not installed, skip `stow ghostty`.
- WSL-specific behavior stays isolated to WSL and does not affect normal Debian/Ubuntu hosts.

Inspired by [aeolyus/dotfiles](https://github.com/aeolyus/dotfiles)
