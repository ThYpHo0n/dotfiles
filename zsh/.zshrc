is_wsl() {
    [[ -r /proc/sys/kernel/osrelease ]] && grep -qi microsoft /proc/sys/kernel/osrelease
}

prepend_path() {
    [[ -d "$1" ]] || return
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$1:$PATH" ;;
    esac
}

append_path() {
    [[ -d "$1" ]] || return
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$PATH:$1" ;;
    esac
}

source_if_exists() {
    [[ -f "$1" ]] && source "$1"
}

ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$ZSH_CACHE_DIR/completions" ]] || mkdir -p "$ZSH_CACHE_DIR/completions"
fpath=("$ZSH_CACHE_DIR/completions" $fpath)
autoload -Uz compinit && compinit

# Plugins via antidote
if [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh" ]]; then
    source "$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh"
elif [[ -f /usr/share/zsh-antidote/antidote.zsh ]]; then
    source /usr/share/zsh-antidote/antidote.zsh
elif [[ -f /usr/share/antidote/antidote.zsh ]]; then
    source /usr/share/antidote/antidote.zsh
fi

if typeset -f antidote >/dev/null && [[ -f "$HOME/.zsh_plugins.txt" ]]; then
    antidote load "$HOME/.zsh_plugins.txt"
fi

zstyle :omz:plugins:keychain agents gpg,ssh
zstyle :omz:plugins:keychain options --quiet

export ZSH="$HOME/.oh-my-zsh"

setopt extended_history
setopt inc_append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt hist_expire_dups_first
setopt hist_save_no_dups
setopt hist_ignore_space
setopt hist_verify
HIST_STAMPS="yyyy-mm-dd"

ZSH_THEME="thyphoon"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"

source_if_exists "$ZSH/oh-my-zsh.sh"

export LANG="${LANG:-en_US.UTF-8}"
export LC_COLLATE="${LC_COLLATE:-C}"
export LANGUAGE="${LANGUAGE:-en_US:en}"
export EDITOR="${EDITOR:-nano}"

alias g='git'
alias d='docker'
alias less='less -R'
alias l='ls -lah'
alias ll='ls -lah'
alias co='copilot'
alias cx='codex -c model_reasoning_effort="high"'
alias cxx='codex -c model_reasoning_effort="xhigh"'
# Keep unrestricted AI aliases in ~/.zshrc.local.

if command -v docker-compose >/dev/null 2>&1; then
    alias dc='docker-compose'
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    alias dc='docker compose'
fi

if command -v lsd >/dev/null 2>&1; then
    alias ls='lsd'
elif [[ "$OSTYPE" == linux-gnu* ]]; then
    alias ls='ls --color=auto'
else
    alias ls='ls -G'
fi

if command -v kubie >/dev/null 2>&1; then
    alias kctx='kubie ctx'
    alias kns='kubie ns'
fi

if is_wsl; then
    export DONT_PROMPT_WSL_INSTALL=1
fi

if [[ "$OSTYPE" == darwin* ]]; then
    [[ -d /usr/local/opt/groovy/libexec ]] && export GROOVY_HOME=/usr/local/opt/groovy/libexec
    prepend_path /usr/local/opt/mysql-client@5.7/bin
    prepend_path /usr/local/opt/postgresql@9.6/bin
    prepend_path /opt/homebrew/opt/php@8.3/bin
    prepend_path /opt/homebrew/opt/php@8.3/sbin
    append_path /usr/local/opt/gettext/bin
    prepend_path /usr/local/opt/helm@2/bin
    append_path "$HOME/Library/Python/3.9/bin"
fi

export NVM_DIR="$HOME/.nvm"
source_if_exists "$NVM_DIR/nvm.sh"
source_if_exists "$NVM_DIR/bash_completion"

prepend_path "$HOME/.local/bin"
append_path "$HOME/.pulumi/bin"
append_path "$HOME/.cargo/bin"
append_path "$HOME/.rvm/bin"

AI_AC_ZSH_SETUP_PATH="$HOME/.cache/ai/autocomplete/zsh_setup"
source_if_exists "$AI_AC_ZSH_SETUP_PATH"

if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    prepend_path "$BUN_INSTALL/bin"
fi
source_if_exists "$HOME/.bun/_bun"

[[ -t 1 ]] && export GPG_TTY="$(tty)"

source_if_exists "$HOME/.zshrc.local"
