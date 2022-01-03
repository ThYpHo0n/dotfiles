# Plugins via antibody
alias antibody='antibody bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.sh'
[[ ! -f ~/.zsh_plugins.sh ]] && antibody
source ~/.zsh_plugins.sh

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

#setopt nonomatch

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

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

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

# Aliases
alias g='git'
alias dc='docker-compose'
alias d='docker'
alias less='less -R'
alias ls='ls --group-directories-first --color=auto'
alias l='ls -lah'
alias ll='ls -lh'

export PATH=$PATH:$HOME/.cargo/bin

eval $(keychain --eval --quiet id_rsa)

export DISPLAY=:0

# WSL or real unix?
if [[ "$(< /proc/sys/kernel/osrelease)" == *microsoft* ]]; then 
    # Start Docker daemon automatically when logging in if not running.
    RUNNING=`ps aux | grep dockerd | grep -v grep`
    if [ -z "$RUNNING" ]; then
        sudo dockerd > /dev/null 2>&1 &
	disown
    fi
    # pip path if using --user 
    export PATH=$PATH:$HOME/.local/bin
else
    export DOCKER_HOST=localhost:2375
    # SSH
    export SSH_AUTH_SOCK=~/.ssh/ssh-agent.sock
    ssh-add -l 2>/dev/null >/dev/null
    if [ $? -ge 2 ]; then
        ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
    fi
    ssh-add -l | grep -q "$HOME/.ssh/id_rsa" || ssh-add $HOME/.ssh/id_rsa
fi


# NVM - Node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Jabba - Java version manager
[ -s "$HOME/.jabba/jabba.sh" ] && source "$HOME/.jabba/jabba.sh"

# add Pulumi to the PATH
export PATH=$PATH:$HOME/.pulumi/bin
