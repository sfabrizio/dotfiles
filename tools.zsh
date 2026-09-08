# modern CLI tools wiring (all optional, guarded, loaded from zshrc)

# fzf: fuzzy history (Ctrl-R), file insert (Ctrl-T), cd (Alt-C)
FZF_DOC=/usr/share/doc/fzf/examples
[ -d ~/.local/share/fzf/examples ] && FZF_DOC=~/.local/share/fzf/examples
[ -f $FZF_DOC/key-bindings.zsh ] && source $FZF_DOC/key-bindings.zsh
[ -f $FZF_DOC/completion.zsh ] && source $FZF_DOC/completion.zsh

# fzf: preview files with bat on Ctrl-T (when bat is present)
if command -v batcat >/dev/null 2>&1; then
    alias bat='batcat'
    # ca: bat like plain cat - no line numbers, no header, keeps colors
    alias ca='batcat -p'
    export FZF_CTRL_T_OPTS="--preview 'batcat --color=always {}'"
fi

# zoxide: z <query> jumps to your most-used dirs
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
