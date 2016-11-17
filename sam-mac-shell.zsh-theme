local nvm_status="%{$fg_bold[yellow]%}⬢ "
local ret_status="%(?:%{$fg_bold[green]%}:%{$fg_bold[red]%})"

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"

SAM_THEME_NVM_SIMBOL="%{$fg_bold[green]%}⬢"
SAM_THEME_NVM_PREFIX="%{$fg_bold[yellow]%}("
SAM_THEME_NVM_SUFFIX="%{$fg_bold[yellow]%})"

function nvm_prompt_info {
    local result
    result+=$SAM_THEME_NVM_SIMBOL" "
    result+=$SAM_THEME_NVM_PREFIX
    result+=$(nvm current)
    result+=$SAM_THEME_NVM_SUFFIX

    echo "$result"
}


PROMPT='${ret_status} %{$fg[cyan]%}%c%{$reset_color%} $(git_prompt_info)$(nvm_prompt_info)🔥 $reset_color '
