#!/usr/bin/env bash
# Sam's dotfiles installer for Raspberry Pi (raspbian).
#
# Works when run any of these ways:
#   ./install-pi.sh | bash install-pi.sh | sh install-pi.sh
# Reliability notes: see scripts/install-lib.sh (dry-run, backups, summary).

# --- bash guard ---------------------------------------------------------------
if [ -z "${BASH_VERSION:-}" ]; then
    if [ -f "$0" ] && [ "$(basename -- "$0")" != "sh" ] && [ "$(basename -- "$0")" != "dash" ]; then
        exec bash "$0" "$@"
    fi
    echo "==> re-running under bash (POSIX sh cannot run this installer)"
    exit 1
fi

set -u

# tmux-powerline commit this dotfiles config is tested against (see install.sh)
TMUX_POWERLINE_PIN="fca0d61"

command -v git >/dev/null 2>&1 || { echo "git is required. Please install it first."; exit 1; }

# --- locate / clone the dotfiles (plain git: helpers come from the repo) ------
cd "$HOME"
if [ ! -d "$HOME/dotfiles" ]; then
    echo "==> cloning dotfiles repository"
    if ! git clone https://github.com/sfabrizio/dotfiles.git "$HOME/dotfiles"; then
        echo "clone failed - check your network and retry"
        exit 1
    fi
fi
[ -d "$HOME/dotfiles" ] || { echo "dotfiles directory missing; abort."; exit 1; }

# --- shared helpers (after the clone: the lib lives in the repo) ---------------
LIB="$HOME/dotfiles/scripts/install-lib.sh"
[ -f "$LIB" ] || { echo "missing $LIB - git pull inside ~/dotfiles and retry"; exit 1; }
# shellcheck source=scripts/install-lib.sh
source "$LIB"

# --- apt packages ---------------------------------------------------------------
PKGS=(curl wget git zsh tmux byobu htop fzf ripgrep jq unzip)
if command -v apt-get >/dev/null 2>&1; then
    MISSING=()
    for p in "${PKGS[@]}"; do
        dpkg -s "$p" >/dev/null 2>&1 || MISSING+=("$p")
    done
    if [ "${#MISSING[@]}" -gt 0 ]; then
        SUDO=()
        [ "$(id -u)" -ne 0 ] && SUDO=(sudo)
        if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
            warn "no sudo available: install these manually -> apt install ${MISSING[*]}"
        else
            say "installing missing apt packages: ${MISSING[*]}"
            run "apt-get update" ${SUDO[@]+"${SUDO[@]}"} apt-get update -y
            run "apt-get install ${MISSING[*]}" ${SUDO[@]+"${SUDO[@]}"} apt-get install -y "${MISSING[@]}"
        fi
    else
        say "all apt packages already installed - skip"
    fi
fi

# --- nvm -----------------------------------------------------------------------
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
    say "installing nvm"
    run "install nvm" \
        bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
else
    say "nvm already installed - skip"
fi

# --- oh-my-zsh (unattended) ------------------------------------------------------
if [ -d "$HOME/.oh-my-zsh" ]; then
    say "oh-my-zsh already installed - skip"
else
    say "installing oh-my-zsh (unattended)"
    run "install oh-my-zsh" \
        env RUNZSH=no CHSH=no bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" '' --unattended
fi

# --- backups ---------------------------------------------------------------------
say "backing up existing configs (.bak, never overwritten)"
backup_configs "$HOME/.gitconfig" "$HOME/.vimrc" "$HOME/.zshrc" \
    "$HOME/.tmux.conf" "$HOME/.tmux-powerlinerc"

# --- folders + symlinks ------------------------------------------------------------
say "creating folders and symlinks"
run "create folders" mkdir -p "$HOME/workspace" "$HOME/.tmux" "$HOME/.autoenv" "$HOME/.config/nvim"
run "symlink ~/.env -> dotfiles/env" ln -sfn "$HOME/dotfiles/env" "$HOME/.env"

# --- tmux-powerline (pinned: newer upstream ignores this config's rc) -----------------
if [ -d "$HOME/.tmux/tmux-powerline" ]; then
    printf '    [skip] tmux-powerline already installed\n'
else
    say "cloning tmux-powerline (pinned)"
    run "clone+pin tmux-powerline" bash -c "
        git clone -q https://github.com/erikw/tmux-powerline.git '$HOME/.tmux/tmux-powerline' &&
        git -C '$HOME/.tmux/tmux-powerline' checkout --quiet $TMUX_POWERLINE_PIN"
fi

# --- helper repos ---------------------------------------------------------------------
if [ -f "$HOME/.autoenv/activate.sh" ]; then
    printf '    [skip] autoenv already installed\n'
else
    run "clone autoenv" git clone https://github.com/hyperupcall/autoenv.git "$HOME/.autoenv"
fi
if [ -d "$HOME/workspace/ozono-zsh-theme" ]; then
    printf '    [skip] ozono-zsh-theme already cloned\n'
else
    run "clone ozono-zsh-theme" git clone https://github.com/sfabrizio/ozono-zsh-theme.git "$HOME/workspace/ozono-zsh-theme"
fi

# --- config entrypoints -----------------------------------------------------------------
say "wiring config files to dotfiles"
write_config "$HOME/.gitconfig"   '[include] path = ~/dotfiles/gitconfig'
write_config "$HOME/.vimrc"       'source ~/dotfiles/vimrc'
write_config "$HOME/.config/nvim/init.vim" 'source ~/.vimrc'
write_config "$HOME/.zshrc"       'source ~/dotfiles/zshrc'
write_config "$HOME/.tmux.conf"   'source ~/dotfiles/tmux.conf'
write_config "$HOME/.tmux-powerlinerc" 'source ~/dotfiles/tmux-powerlinerc'
run "expose ozono theme to oh-my-zsh" \
    bash -c "mkdir -p '$HOME/.oh-my-zsh/custom/themes' && ln -sfn '$HOME/dotfiles/ozono.zsh-theme' '$HOME/.oh-my-zsh/custom/themes/ozono.zsh-theme'"

# machine-local override files (sourced by the configs above; never committed)
say "creating local override files (kept even across reinstalls, never overwritten)"
for f in .gitconfig.local .vimrc.local .tmux.local .bash.local .zshrc.local .tmux-powerline.local; do
    if [ -f "$HOME/$f" ]; then
        printf '    [skip] %s exists\n' "$f"
    elif [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] create %s\n' "$f"
    else
        if printf '# machine-local overrides (never committed)\n' > "$HOME/$f"; then
            printf '    [ok] created %s\n' "$f"
        else
            fail "create $f"
        fi
    fi
done
if [ -f "$HOME/.tmux-powerline.local" ] && ! grep -q "TMUX_POWERLINE_LEFT_STATUS_SEGMENTS+=" "$HOME/.tmux-powerline.local" 2>/dev/null; then
    printf '# extra tmux bar segments, e.g.:\n# TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS+=("uptime 235 136")\n' >> "$HOME/.tmux-powerline.local"
fi

# --- summary ------------------------------------------------------------------------------
install_summary || exit 1
