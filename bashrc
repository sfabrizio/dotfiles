#load global alias:
source ~/dotfiles/alias

#specific windows alias:
alias ll='ls -l'
alias ls='ls -F --color=auto --show-control-chars'
alias node='winpty node.exe'
alias re-bash='source ~/.bashrc'
# Work specifics

alias tfs='git ls-files | grep '\''\.tfs$'\'''
#alias tfs-del='tfs | xargs git rm'
#alias copy-config-code='mkdir -p .vscode && cp ~/dotfiles/vscode/tasks.json ./.vscode/'

# open-files
#alias sprite='code "$(configurator -g atlasConfigGamesFolder)\\$(configurator -g gameName)SpritesheetBuildConfig.xml"'
#alias content='code "$(configurator -g contentDescGamesFolder)\\HTML5$(configurator -g gameName)Description.xml"'
#alias release='code "$(configurator -g workspacePath)\deployment\Release $(git branch | grep \* | cut -d '/' -f2)\\ReleaseConfiguration.xml"'

# utils
#alias forcebuild='find . | grep -i "$(configurator -g gameName)[a-z\/-]*forcebuild.txt" | while read -r line; do echo `date +%s` > "$line" ; done'
alias mg='~/dotfiles/scripts/multi-git/multi-git.sh'
alias mg-init='~/dotfiles/scripts/multi-git/path-generator.sh'

# browsing
#alias game='cd "$(configurator -g gtkjsGames)\\$(configurator -g gameName)"'
#alias gtkjs='cd "$(configurator -g gtkjs)"'
#alias art='cd "$(configurator -g spriteSourceDir)"'
#alias scripts='cd "$(configurator -g ScriptsRTG)"'
#alias casino='cd "$(configurator -g CasinoRTG)"'
#alias desc='cd "$(configurator -g ContentDescGamesFolder)"'
#alias work='cd "$(configurator -g workspacePath)"'
