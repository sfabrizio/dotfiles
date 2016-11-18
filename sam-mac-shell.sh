local ret_status="%(?:%{$fg_bold[green]%}:%{$fg_bold[red]%})"

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"

SAM_THEME_NVM_SIMBOL="%{$fg_bold[green]%}⬢"
SAM_THEME_NVM_PREFIX="%{$fg_bold[green]%}(%{$reset_color%}"
SAM_THEME_NVM_SUFFIX="%{$fg_bold[green]%})%{$reset_color%}"
SAM_THEME_ICON="🔥"
SAM_THEME_ICON2="💥"

function nvm_prompt_info {
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


PROMPT=''
PROMPT+='${ret_status}'
PROMPT+=' %{$fg[cyan]%}%c%{$reset_color%}'
PROMPT+='$(git_prompt_info)'
PROMPT+='$(nvm_prompt_info)'
PROMPT+=' $SAM_THEME_ICON '
