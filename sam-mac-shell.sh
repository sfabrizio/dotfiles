source ~/dotfiles/scripts/os_detection.sh

#git values
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}\ue709 (%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"

#theme values
SAM_THEME_NVM_SIMBOL="%{$fg_bold[green]%}⬢"
SAM_THEME_NVM_PREFIX="%{$fg_bold[green]%}(%{$reset_color%}"
SAM_THEME_NVM_SUFFIX="%{$fg_bold[green]%})%{$reset_color%}"
SAM_THEME_PROMPT="🔥"
SAM_THEME_CRASH="💥"
SAM_THEME_JS_ICON="%{$fg[yellow]%}"$'\ue74e'"%{$reset_color%}"

SAM_THEME_OK=$'\ue711'
SAM_THEME_OK_MAC=$'\ue711'
SAM_THEME_OK_LINUX=$'\ue712'
SAM_THEME_OK_RASPY=$'\ue722'

#set ok icon according the OS, default mac
if [[ $platform == 'linux' ]]; then
    $SAM_THEME_OK = $SAM_THEME_LIMUX
elif [[ $platform == 'raspy' ]]; then
    $SAM_THEME_OK = $SAM_THEME_RASPY
fi

#ok or wrong command
local ret_status="%(?:%{$fg_bold[grey]%}$SAM_THEME_OK:%{$fg_bold[red]%}$SAM_THEME_CRASH)"

#show nvm current version only when is necessary
function print_nvm_info {
    if command git >/dev/null 2>/dev/null; then
        return
    fi
    local mainPathPackageJson=$(git rev-parse --show-toplevel 2>/dev/null)"/package.json"
    if [[ -f $mainPathPackageJson ]]; then
        local result=""
        result+=$SAM_THEME_NVM_SIMBOL" "
        result+=$SAM_THEME_NVM_PREFIX
        result+=%{$fg[yellow]%}$(nvm current)
        result+=$SAM_THEME_NVM_SUFFIX
        echo "$result"
    fi
}

#Final prompt concat
PROMPT=''
PROMPT+='${ret_status}'
PROMPT+=' %{$fg[cyan]%}%c%{$reset_color%} '
PROMPT+='$(git_prompt_info)'
PROMPT+='$(print_nvm_info)'
PROMPT+='$SAM_THEME_PROMPT '
