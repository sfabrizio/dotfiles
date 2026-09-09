# modern CLI tools wiring (all optional, guarded, loaded from zshrc)

# installers drop modern tools in ~/.local/bin (zoxide, fzf, ...); make sure
# it is on PATH inside interactive zsh (non-login shells may not have it)
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# macOS: /etc/zshrc's path_helper resets PATH in non-login interactive shells,
# dropping the brew prefix - re-add it ourselves (arm + intel locations)
if [ -x /opt/homebrew/bin/brew ]; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
elif [ -x /usr/local/bin/brew ]; then
    export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
fi

# fzf: fuzzy history (Ctrl-R), file insert (Ctrl-T), cd (Alt-C)
# modern fzf emits its own zsh wiring; older distro packages ship script files
if command -v fzf >/dev/null 2>&1 && fzf --zsh </dev/null 2>/dev/null | grep -q "fzf-history-widget"; then
    eval "$(fzf --zsh 2>/dev/null)"
else
    FZF_DOC=/usr/share/doc/fzf/examples
    [ -d ~/.local/share/fzf/examples ] && FZF_DOC=~/.local/share/fzf/examples
    command -v brew >/dev/null 2>&1 && [ -d "$(brew --prefix)/opt/fzf/shell" ] && FZF_DOC="$(brew --prefix)/opt/fzf/shell"
    [ -f $FZF_DOC/key-bindings.zsh ] && source $FZF_DOC/key-bindings.zsh
    [ -f $FZF_DOC/completion.zsh ] && source $FZF_DOC/completion.zsh
fi

# fzf: preview files with bat on Ctrl-T (when bat is present)
if command -v batcat >/dev/null 2>&1; then
    alias bat='batcat'
    # ca: bat like plain cat - no line numbers, no header, keeps colors
    alias ca='batcat -p'
    export FZF_CTRL_T_OPTS="--preview 'batcat --color=always {}'"
elif command -v bat >/dev/null 2>&1; then
    # macOS: brew installs the binary as `bat` (no alias needed for bat)
    alias ca='bat -p'
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always {}'"
fi

# zoxide: z <query> jumps to your most-used dirs
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# manual dotfiles update (same as the background auto-update check, but now)
dotfiles-update() { bash "$HOME/dotfiles/scripts/auto-update.sh" --force; }
