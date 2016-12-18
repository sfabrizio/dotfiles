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

#final prompt separator:
# spectrum_ls for see all colors
SAM_THEME_PROMPT_FINAL="%{$FG[063]%}"'\uf0da '"%{$reset_color%}"

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

# Git: branch/detached head, dirty status
prompt_git_status() {
  (( $+commands[git] )) || return
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      echo -n "%{$fg_bold[red]%}"
    else
      echo -n "%{$fg_bold[cyan]%}"
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr "%{$FG[154]%}"'\uf103 '
    zstyle ':vcs_info:*' unstagedstr "%{$FG[197]%}"'\uf0c3 '
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${vcs_info_msg_0_%%}${mode}"
  fi
  echo -n "%{$reset_color%}"
}

#Final prompt concat
PROMPT=''
PROMPT+='${ret_status}'
PROMPT+='  %{$fg[cyan]%}%c%{$reset_color%}'
PROMPT+=' $(git_prompt_info)'
PROMPT+='$(print_nvm_info)'
PROMPT+='$(prompt_git_status)'
PROMPT+='$(echo -n $SAM_THEME_PROMPT_FINAL)'
