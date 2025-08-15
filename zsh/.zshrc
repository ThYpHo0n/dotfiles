# Plugins via antidote
if [[ -n "$HOMEBREW_PREFIX" ]]; then
    source $HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh
fi
# TODO: ArchLinux/WSL/Debian
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
export LC_ALL=C
export EDITOR='vim'

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias g='git'
alias dc='docker-compose'
alias d='docker'
alias less='less -R'
alias ls='ls --color=auto'
alias l='ls -lah'
alias ll='ls -lah'
alias kctx="kubie ctx"
alias kns="kubie ns"
alias kmode="export PS1='\$(kube_ps1)'\$PS1"
alias cdw='cd ~/workspace'
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
fi

# NVM - Node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# Jabba - Java version manager
[ -s "$HOME/.jabba/jabba.sh" ] && source "$HOME/.jabba/jabba.sh"

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

# PIP package installs
export PATH="$HOME/Library/Python/3.9/bin:$PATH"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

eval
AI_AC_ZSH_SETUP_PATH=/home/nik/.cache/ai/autocomplete/zsh_setup && test -f $AI_AC_ZSH_SETUP_PATH && source $AI_AC_ZSH_SETUP_PATH; # ai autocomplete setup
