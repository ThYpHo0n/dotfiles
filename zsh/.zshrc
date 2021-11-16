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

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

export PATH=$PATH:$HOME/.cargo/bin

# WSL or real unix?
if [[ "$(< /proc/sys/kernel/osrelease)" == *microsoft* ]]; then 
    export $(dbus-launch)
    export LIBGL_ALWAYS_INDIRECT=1
    export WSL_VERSION=$(wsl.exe -l -v | grep -a '[*]' | sed 's/[^0-9]*//g')
    export WSL_HOST=$(tail -1 /etc/resolv.conf | cut -d' ' -f2)
    export DISPLAY=$WSL_HOST:0
    # pip path if using --user 
    export PATH=$PATH:$HOME/.local/bin
    # SSH
    eval $(/mnt/c/weasel-pageant/weasel-pageant -r)
else
    export DISPLAY=:0
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
