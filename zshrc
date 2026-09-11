# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="ozono"
#ZSH_THEME="robbyrussell"

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

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

plugins=(git git-extras)

# User configuration

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
# export MANPATH="/usr/local/man:$MANPATH"

# skip omz's compaudit security scan of the completion dirs (it walks fpath
# twice on every start; this is a personal machine - see startup-check.sh)
ZSH_DISABLE_COMPFIX=true

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

#load personal alias
source ~/dotfiles/alias
#load util function
source ~/dotfiles/scripts/get_os_name.sh
OS_NAME=`get_os_name`

# disable share history of zsh
setopt no_share_history

# force 256 color for byobu
export TERM=screen-256color

# osx conf:
if [[ "$OS_NAME" == 'osx' ]]; then

    #load home brew token:
    #source ~/dotfiles/.brew-token
    # Prefix for byobu
    export BYOBU_PREFIX=$(brew --prefix)

    # for stating docker machine
    #docker-machine start default
    #eval "$(docker-machine env default)"
fi


# lazy-load nvm (see scripts/lazy-nvm.zsh): the first node-family command
# pays the ~350ms load cost once per shell, every shell start skips it.
# npm-global binaries (tgit, diff-so-fancy, ...) are caught by the
# command_not_found_handler below.
source ~/dotfiles/scripts/lazy-nvm.zsh

# zsh-only fallback: an unknown command that exists in any installed node
# version's bin dir loads nvm (node must resolve for env-shebang scripts)
# and execs it by absolute path - absolute exec cannot recurse the handler.
command_not_found_handler() {
    local candidate cmd="$1"
    for candidate in "$NVM_DIR"/versions/node/*/bin/"$cmd"(N); do
        shift
        _lazy_nvm_load
        "$candidate" "$@"
        return $?
    done
    print -u2 "command not found: $cmd"
    return 127
}

export PATH="/usr/local/sbin:$PATH"

# lazy-load autoenv (see scripts/lazy-autoenv.zsh): the first `cd` (or the
# first node-family command) pays the activation cost; project-dir .env
# nvm switches no longer run at shell startup
source ~/dotfiles/scripts/lazy-autoenv.zsh

# rust & user local bin (if present)
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"

#load modern CLI tools wiring (fzf, zoxide, bat)
#NOTE: loaded once here. Never set ZSH_CUSTOM=~/dotfiles/ — omz would auto-source it too.
source ~/dotfiles/tools.zsh

# dotfiles auto-update check (omz-style: background, ~every 13 days, asks Y/n;
# modes via DOTFILES_UPDATE_MODE=prompt|reminder|auto|disabled, manual: dotfiles-update)
bash ~/dotfiles/scripts/auto-update.sh >/dev/null 2>&1 &!

# machine-local overrides (gitignored, see README)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
