#load global alias:
source ~/dotfiles/alias

#specific windows alias:
alias ll='ls -l'
alias ls='ls -F --color=auto --show-control-chars'
alias node='winpty node.exe'
alias re-bash='source ~/.bashrc'

#work specifics:
alias mgit='~/dotfiles/scripts/multi-git/multi-git.sh'
alias mg='mgit'
alias mg-init='~/dotfiles/scripts/multi-git/path-generator.sh'
alias tfs='git ls-files | grep '\''\.tfs$'\'''
alias tfs-del='tfs | xargs git rm'
alias forcebuild='find .  | grep  "fuchi[a-z\/-]*forcebuild.txt"  | while read -r line; do echo `date +%s` > "$line" ; done'
alias art="cd ~/workspace/art"
alias int="cd ~/internalTools"

