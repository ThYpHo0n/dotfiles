ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d $ZSH_CACHE_DIR/completions ]] || mkdir -p $ZSH_CACHE_DIR/completions  # For kubectl completions
fpath=($ZSH_CACHE_DIR/completions $fpath)
autoload -Uz compinit && compinit

# Plugins via antidote
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    source $HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh
elif [[ -f /usr/share/zsh-antidote/antidote.zsh ]]; then
    source /usr/share/zsh-antidote/antidote.zsh
fi
antidote load

zstyle :omz:plugins:keychain agents gpg,ssh
zstyle :omz:plugins:keychain options --quiet

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# ZSH History
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

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8
export LC_COLLATE=C
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
export EDITOR='vim'

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias g='git'
alias dc='docker-compose'
alias d='docker'
alias less='less -R'
alias ls='lsd'
alias l='ls -lah'
alias ll='ls -lah'
alias kctx="kubie ctx"
alias kns="kubie ns"
alias kmode="export PS1='\$(kube_ps1)'\$PS1"
alias cdw='cd ~/workspace'
alias cdn='cd ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/Documents/Obsidian/notes/'
alias aiac='/home/nik/workspace/aiac/aiac'
alias sops='sops --config ~/.sops.yaml'

# WSL context?
if [[ -f "/proc/sys/kernel/osrelease" && "$(</proc/sys/kernel/osrelease)" == *microsoft* ]]; then
    export DONT_PROMPT_WSL_INSTALL=1
    # Start Docker daemon automatically when logging in if not running
    RUNNING=$(ps aux | grep dockerd | grep -v grep)
    if [ -z "$RUNNING" ]; then
        sudo dockerd >/dev/null 2>&1 &
        disown
    fi
fi

if [[ "$OSTYPE" == "linux-gnu" ]]; then
    # Linux specific stuff goes here
    export DISPLAY=:0
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # OS X specific stuff goes here
    export GROOVY_HOME=/usr/local/opt/groovy/libexec
    # Homebrew custom paths
    if [ -f "/usr/local/opt/mysql-client@5.7/bin" ]; then export PATH="/usr/local/opt/mysql-client@5.7/bin:$PATH"; fi
    if [ -f "/usr/local/opt/postgresql@9.6/bin" ]; then export PATH="/usr/local/opt/postgresql@9.6/bin:$PATH"; fi

    ### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
    export PATH="/Users/niklas.grebe/.rd/bin:$PATH"
    ### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

    # pnpm
    export PNPM_HOME="/Users/niklas.grebe/Library/pnpm"
    case ":$PATH:" in
      *":$PNPM_HOME:"*) ;;
      *) export PATH="$PNPM_HOME:$PATH" ;;
    esac
    # pnpm end

    # PIP package installs
    export PATH="$HOME/Library/Python/3.9/bin:$PATH"

    # The next line updates PATH for the Google Cloud SDK.
    if [ -f '/Users/niklas.grebe/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/niklas.grebe/Downloads/google-cloud-sdk/path.zsh.inc'; fi
    # The next line enables shell command completion for gcloud.
    if [ -f '/Users/niklas.grebe/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/niklas.grebe/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

    # php
    export PATH="/opt/homebrew/opt/php@8.3/bin:$PATH"
    export PATH="/opt/homebrew/opt/php@8.3/sbin:$PATH"
fi

export KUBECONFIG=~/.kube/configs/k3s-lyke.yaml

# NVM - Node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# Add pip path for using --user if exists
if [ -f "$HOME/.local/bin" ]; then export PATH="$PATH:$HOME/.local/bin"; fi

# Add Pulumi to the PATH if exists
if [ -f "$HOME/.pulumi/bin" ]; then export PATH="$PATH:$HOME/.pulumi/bin"; fi

# Add cargo to PATH if exists
if [ -f "$HOME/.cargo/bin" ]; then export PATH="$PATH:$HOME/.cargo/bin"; fi

# Add gettext bin to PATH if exists
if [ -f "/usr/local/opt/gettext/bin" ]; then export PATH="$PATH:/usr/local/opt/gettext/bin"; fi

export ANSIBLE_VAULT_PASSWORD_FILE="~/.vault_pass.txt"

if [ -f "/usr/local/opt/helm@2/bin" ]; then export PATH="/usr/local/opt/helm@2/bin:$PATH"; fi

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

eval
AI_AC_ZSH_SETUP_PATH=$HOME/.cache/ai/autocomplete/zsh_setup && test -f $AI_AC_ZSH_SETUP_PATH && source $AI_AC_ZSH_SETUP_PATH; # ai autocomplete setup

export PATH="$HOME/.local/bin:$PATH"

export GPG_TTY=$(tty)

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
if [ -f "$HOME/.bun" ]; then export BUN_INSTALL="$HOME/.bun"; fi
if [ -f "$HOME/.bun/bin" ]; then export PATH="$BUN_INSTALL/bin:$PATH"; fi
