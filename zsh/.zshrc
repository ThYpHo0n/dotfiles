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

print_dep_status() {
    local dep_state="$1"
    local name="$2"
    local detail="${3:-}"

    printf '[%-7s] %s' "$dep_state" "$name"
    [[ -n "$detail" ]] && printf ' (%s)' "$detail"
    printf '\n'
}

check_command_dep() {
    local name="$1"
    local cmd="${2:-$1}"

    if command -v "$cmd" >/dev/null 2>&1; then
        print_dep_status "ok" "$name" "$(command -v "$cmd")"
        return 0
    fi

    print_dep_status "missing" "$name" "$cmd not on PATH"
    return 1
}

check_file_dep() {
    local name="$1"
    local dep_path="$2"

    if [[ -e "$dep_path" ]]; then
        print_dep_status "ok" "$name" "$dep_path"
        return 0
    fi

    print_dep_status "missing" "$name" "$dep_path"
    return 1
}

check_antidote_dep() {
    local detail="antidote.zsh not found"
    local dep_state="missing"

    if typeset -f antidote >/dev/null; then
        detail="loaded in current shell"
        dep_state="ok"
    elif [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh" ]]; then
        detail="$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh"
        dep_state="ok"
    elif [[ -f /usr/share/zsh-antidote/antidote.zsh ]]; then
        detail="/usr/share/zsh-antidote/antidote.zsh"
        dep_state="ok"
    elif [[ -f /usr/share/antidote/antidote.zsh ]]; then
        detail="/usr/share/antidote/antidote.zsh"
        dep_state="ok"
    fi

    print_dep_status "$dep_state" "antidote" "$detail"
    [[ "$dep_state" == "ok" ]]
}

has_hack_nerd_font() {
    local font_dir
    local -a matches

    if command -v fc-match >/dev/null 2>&1; then
        local match
        match="$(fc-match --format '%{family}\n' 'Hack Nerd Font' 2>/dev/null)"
        [[ "$match" == *'Hack Nerd Font'* ]] && return 0
    fi

    for font_dir in \
        "$HOME/Library/Fonts" \
        "/Library/Fonts" \
        "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" \
        "$HOME/.local/share/fonts" \
        "$HOME/.fonts" \
        "/usr/local/share/fonts" \
        "/usr/share/fonts"; do
        [[ -d "$font_dir" ]] || continue
        matches=("$font_dir"/**/*Hack*Nerd*Font*(N))
        (( ${#matches[@]} > 0 )) && return 0
    done

    return 1
}

check_hack_nerd_font_dep() {
    if has_hack_nerd_font; then
        print_dep_status "ok" "Hack Nerd Font" "font files available"
        return 0
    fi

    print_dep_status "missing" "Hack Nerd Font" "font files not found"
    return 1
}

check_dotfile_deps() {
    local missing_required=0
    local missing_optional=0

    print "Required dependencies:"
    check_command_dep "git" || ((missing_required++))
    check_command_dep "stow" || ((missing_required++))
    check_command_dep "zsh" || ((missing_required++))
    check_file_dep "oh-my-zsh" "$ZSH/oh-my-zsh.sh" || ((missing_required++))
    check_antidote_dep || ((missing_required++))

    print
    print "Optional dependencies:"
    check_command_dep "claude" || ((missing_optional++))
    check_command_dep "codex" || ((missing_optional++))
    check_command_dep "forge" || ((missing_optional++))
    check_command_dep "rtk" || ((missing_optional++))
    check_command_dep "pnpm" || ((missing_optional++))
    check_command_dep "lsd" || ((missing_optional++))
    check_command_dep "fzf" || ((missing_optional++))
    check_command_dep "keychain" || ((missing_optional++))
    check_command_dep "gpg" || ((missing_optional++))
    check_hack_nerd_font_dep || ((missing_optional++))
    check_command_dep "ghostty" || ((missing_optional++))

    print
    print "Summary: ${missing_required} required missing, ${missing_optional} optional missing"
    (( missing_required == 0 ))
}

has_live_socket() {
    local sock="${1:-${SSH_AUTH_SOCK:-}}"
    local probe_fd
    [[ -n "$sock" && -S "$sock" ]] || return 1

    zmodload zsh/net/socket 2>/dev/null || return 0
    zsocket "$sock" 2>/dev/null || return 1

    probe_fd="${REPLY:-}"
    if [[ -n "$probe_fd" ]]; then
        exec {probe_fd}>&-
        unset REPLY
    fi

    return 0
}

is_remote_ssh_session() {
    [[ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-}" ]]
}

is_forwarded_ssh_session() {
    is_remote_ssh_session && [[ -n "${SSH_AUTH_SOCK:-}" ]]
}

ssh_key_fingerprint() {
    local identity="$1"
    local fingerprint=""

    command -v ssh-keygen >/dev/null 2>&1 || return 1

    if [[ -f "${identity}.pub" ]]; then
        fingerprint="$(ssh-keygen -lf "${identity}.pub" 2>/dev/null | awk 'NR == 1 { print $2 }')"
    elif [[ -f "$identity" ]]; then
        fingerprint="$(ssh-keygen -lf "$identity" 2>/dev/null | awk 'NR == 1 { print $2 }')"
    fi

    [[ -n "$fingerprint" ]] || return 1
    print -r -- "$fingerprint"
}

ssh_agent_has_fingerprint() {
    local fingerprint="$1"
    [[ -n "$fingerprint" ]] || return 1

    ssh-add -l 2>/dev/null | awk '{print $2}' | grep -Fxq -- "$fingerprint"
}

load_default_ssh_identity() {
    local identity="$HOME/.ssh/id_ed25519"
    local fingerprint=""

    [[ "$OSTYPE" == darwin* ]] && return
    command -v ssh-add >/dev/null 2>&1 || return
    [[ -f "$identity" ]] || return
    has_live_socket || return

    fingerprint="$(ssh_key_fingerprint "$identity")" || fingerprint=""
    if [[ -n "$fingerprint" ]] && ssh_agent_has_fingerprint "$fingerprint"; then
        return
    fi

    if [[ -t 0 ]]; then
        ssh-add "$identity" >/dev/null 2>&1 || true
    else
        ssh-add "$identity" </dev/null >/dev/null 2>&1 || true
    fi
}

setup_shared_agents() {
    local short_host="${SHORT_HOST:-${(%):-%m}}"
    local ssh_env_cache="$HOME/.ssh/environment-$short_host"

    # Preserve a forwarded agent inside remote SSH sessions.
    # Some forwarded sockets are not probeable during shell startup, but
    # replacing SSH_AUTH_SOCK with a local agent breaks agent forwarding.
    if is_forwarded_ssh_session; then
        return
    fi

    # Reuse any already available local agent socket.
    if has_live_socket; then
        # macOS: the launchd agent may be alive but have no identities.
        # Load any passphrases saved in the system Keychain.
        if [[ "$OSTYPE" == darwin* ]]; then
            ssh-add -l &>/dev/null || ssh-add --apple-load-keychain 2>/dev/null
        fi
        load_default_ssh_identity
        return
    fi

    if command -v keychain >/dev/null 2>&1; then
        keychain --quiet --inherit any-once --agents gpg,ssh --host "$short_host" >/dev/null 2>&1
        source_if_exists "$HOME/.keychain/$short_host-sh"
        source_if_exists "$HOME/.keychain/$short_host-sh-gpg"

        if has_live_socket; then
            load_default_ssh_identity
            return
        fi
    fi

    command -v ssh-agent >/dev/null 2>&1 || return
    [[ -d "$HOME/.ssh" ]] || mkdir -p "$HOME/.ssh"

    if [[ -f "$ssh_env_cache" ]]; then
        source "$ssh_env_cache" >/dev/null 2>&1
        if has_live_socket; then
            load_default_ssh_identity
            return
        fi
    fi

    ssh-agent -s | sed '/^echo/d' >! "$ssh_env_cache"
    chmod 600 "$ssh_env_cache"
    source "$ssh_env_cache" >/dev/null 2>&1
    load_default_ssh_identity
}

# Ghostty terminfo compatibility: when SSH-ing from Ghostty into a host that
# lacks the xterm-ghostty terminfo, fall back to xterm-256color so terminal
# input and rendering work correctly. To install the full terminfo instead:
#   infocmp -x xterm-ghostty | ssh <host> tic -x -
if [[ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}" ]] \
   && [[ "$TERM" == "xterm-ghostty" ]] \
   && ! infocmp "$TERM" &>/dev/null; then
    export TERM=xterm-256color
fi

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

export ZSH="$HOME/.oh-my-zsh"
SHORT_HOST="${SHORT_HOST:-${(%):-%m}}"

setup_shared_agents

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
alias deps='check_dotfile_deps'
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
    source_if_exists /opt/homebrew/share/google-cloud-sdk/path.zsh.inc
    source_if_exists /opt/homebrew/share/google-cloud-sdk/completion.zsh.inc
fi

export NVM_DIR="$HOME/.nvm"
source_if_exists "$NVM_DIR/nvm.sh"
source_if_exists "$NVM_DIR/bash_completion"

prepend_path "$HOME/.local/bin"
append_path "$HOME/go/bin"
append_path "$HOME/.pulumi/bin"
append_path "$HOME/.cargo/bin"
append_path "$HOME/.rvm/bin"
append_path "$HOME/.npm-global/bin"

AI_AC_ZSH_SETUP_PATH="$HOME/.cache/ai/autocomplete/zsh_setup"
source_if_exists "$AI_AC_ZSH_SETUP_PATH"

if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    prepend_path "$BUN_INSTALL/bin"
fi
source_if_exists "$HOME/.bun/_bun"

[[ -t 1 ]] && export GPG_TTY="$(tty)"

source_if_exists "$HOME/.zshrc.local"

if command -v forge >/dev/null 2>&1; then
    # >>> forge initialize >>>
    # !! Contents within this block are managed by 'forge zsh setup' !!
    # !! Do not edit manually - changes will be overwritten !!

    # Add required zsh plugins if not already present
    if [[ ! " ${plugins[@]} " =~ " zsh-autosuggestions " ]]; then
        plugins+=(zsh-autosuggestions)
    fi
    if [[ ! " ${plugins[@]} " =~ " zsh-syntax-highlighting " ]]; then
        plugins+=(zsh-syntax-highlighting)
    fi

    # Load forge shell plugin (commands, completions, keybindings) if not already loaded
    if [[ -z "$_FORGE_PLUGIN_LOADED" ]]; then
        eval "$(forge zsh plugin)"
    fi

    # Load forge shell theme (prompt with AI context) if not already loaded
    if [[ -z "$_FORGE_THEME_LOADED" ]]; then
        eval "$(forge zsh theme)"
    fi
    # <<< forge initialize <<<
fi
