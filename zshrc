# Path to your oh-my-zsh installation.
export ZSH=/Users/sfabrizio/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="sam-mac-shell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
#ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=~/dotfiles/

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git git-extra git-remote-branch nvm)

# User configuration

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# export MANPATH="/usr/local/man:$MANPATH"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# set where virutal environments will live
 export WORKON_HOME=$HOME/.virtualenvs
# # ensure all new environments are isolated from the site-packages directory
 export VIRTUALENVWRAPPER_VIRTUALENV_ARGS='--no-site-packages'
# # use the same directory for virtualenvs as virtualenvwrapper
 export PIP_VIRTUALENV_BASE=$WORKON_HOME
# # makes pip detect an active virtualenv and install to it
 export PIP_RESPECT_VIRTUALENV=true
 if [[ -r /usr/local/bin/virtualenvwrapper.sh ]]; then
     source /usr/local/bin/virtualenvwrapper.sh
     else
         echo "WARNING: Can't find virtualenvwrapper.sh"
         fi

#disable share history of zsh 
setopt no_share_history

alias st='git status'
alias gl='git l'
alias b='byobu'
alias bn='byobu new'
alias v='nvim'
alias vim="nvim"

# force 256 color for byobu
export TERM=screen-256color

export HOMEBREW_GITHUB_API_TOKEN=c4942d9e260a9cea09f526e0299e83414212cc6f
# for stating docker machine
#docker-machine start default
#eval "$(docker-machine env default)"

#load tmux status bar:
tmux source-file ~/.tmux.conf

export NVM_DIR="/Users/sfabrizio/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
export PATH="/usr/local/sbin:$PATH"

#load autoevn
source /usr/local/opt/autoenv/activate.sh
