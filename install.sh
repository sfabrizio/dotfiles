#!/usr/bin/env bash
# Sam's dotfiles installer (linux / osx).
#
# Works when run any of these ways:
#   ./install.sh | bash install.sh | sh install.sh | sh -c "$(curl -fsSL <url>)"
#
# Reliability notes:
#   - re-execs itself under bash if started by another shell (dash/POSIX sh):
#     the README's `sh -c "$(...)"` one-liner lands here first
#   - idempotent: safe to re-run (backups never overwritten, clones and config
#     writes are skipped when already present)
#   - optional steps (nerd font) are skipped non-interactively unless
#     DOTFILES_INSTALL_FONT=1
#   - DOTFILES_INSTALL_DRY_RUN=1 prints every action without executing it

# --- bash guard: this script uses arrays/[[ ]] -> must run under bash --------
if [ -z "${BASH_VERSION:-}" ]; then
    if [ -f "$0" ] && [ "$(basename -- "$0")" != "sh" ] && [ "$(basename -- "$0")" != "dash" ]; then
        # started as a file under another shell: re-exec the file with bash
        exec bash "$0" "$@"
    fi
    # started as `sh -c "<script text>"`: refetch to a temp file, run under bash
    echo "==> re-running under bash (POSIX sh cannot run this installer)"
    TMP_SCRIPT="$(mktemp /tmp/dotfiles-install-XXXXXX.sh)"
    if ! curl -fsSL "${DOTFILES_INSTALL_URL:-https://raw.githubusercontent.com/sfabrizio/dotfiles/master/install.sh}" -o "$TMP_SCRIPT"; then
        echo "could not download the installer - run: bash <(curl -fsSL <installer url>)"
        exit 1
    fi
    exec bash "$TMP_SCRIPT" "$@"
fi

set -u

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

# --- detect OS ----------------------------------------------------------------
# shellcheck source=scripts/get_os_name.sh
. "$HOME/dotfiles/scripts/get_os_name.sh"
OS_NAME="$(get_os_name)"
say "detected OS: $OS_NAME"

case "$OS_NAME" in
    windows*)
        say "windows detected -> running install-windows.sh"
        if [ "$DRY_RUN" = "1" ]; then
            echo "[dry-run] bash $HOME/dotfiles/install-windows.sh"
            install_summary || exit 1
            exit 0
        fi
        exec bash "$HOME/dotfiles/install-windows.sh"
        ;;
esac

# --- OS packages ---------------------------------------------------------------
if [[ "$OS_NAME" == 'osx' ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        say "installing Homebrew"
        run "install Homebrew" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    say "installing OSX packages via brew"
    run "brew install byobu tmux neovim git-extras htop node" \
        brew install byobu tmux neovim git-extras htop node
    # osx-cpu-temp is a cosmetic segment; a failed build (e.g. on arm64) is
    # reported as a warning, not an install failure
    say "building osx-cpu-temp"
    run "init submodule externals/osx-cpu-temp" \
        git -C "$HOME/dotfiles" submodule update --init externals/osx-cpu-temp
    if bash -c "cd '$HOME/dotfiles/externals/osx-cpu-temp' && make"; then
        printf '    [ok] built osx-cpu-temp\n'
    else
        warn "osx-cpu-temp build failed (non-fatal) - the osx cpu-temp bar segment will be empty"
    fi
elif [[ "$OS_NAME" == linux* ]]; then
    if [[ "$OS_NAME" == *ubuntu* ]] && command -v apt-get >/dev/null 2>&1; then
        PKGS_LINUX=(curl wget git zsh tmux byobu neovim htop fzf ripgrep bat jq unzip)
        MISSING=()
        for p in "${PKGS_LINUX[@]}"; do
            dpkg -s "$p" >/dev/null 2>&1 || MISSING+=("$p")
        done
        if [ "${#MISSING[@]}" -gt 0 ]; then
            SUDO=()
            [ "$(id -u)" -ne 0 ] && SUDO=(sudo)
            if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
                warn "no sudo available: install these manually -> apt install ${MISSING[*]}"
            else
                say "installing missing apt packages: ${MISSING[*]}"
                # apt mirrors flake occasionally: one retry covers transient hits
                if run "apt-get update" ${SUDO[@]+"${SUDO[@]}"} apt-get update -y; then
                    run "apt-get install ${MISSING[*]}" ${SUDO[@]+"${SUDO[@]}"} apt-get install -y "${MISSING[@]}" \
                        || { warn "apt install failed once - retrying after update"
                             run "apt-get update (retry)" ${SUDO[@]+"${SUDO[@]}"} apt-get update -y
                             run "apt-get install ${MISSING[*]} (retry)" ${SUDO[@]+"${SUDO[@]}"} apt-get install -y "${MISSING[@]}"; }
                fi
            fi
        else
            say "all apt packages already installed - skip"
        fi
    else
        warn "non-apt linux: install dependencies manually from os-dependencies.txt"
    fi
fi

# --- nvm (before npm: node may only exist after this) ---------------------------
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
    say "installing nvm"
    run "install nvm" \
        bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
else
    say "nvm already installed - skip"
fi

# --- npm global packages ---------------------------------------------------------
NPM_PACKAGES=(turbo-git diff-so-fancy)
if is_node; then
    say "installing npm global packages: ${NPM_PACKAGES[*]}"
    run "npm install -g ${NPM_PACKAGES[*]}" npm install -g "${NPM_PACKAGES[@]}"
else
    warn "node/npm not found - after opening a new shell run:"
    warn "  nvm install --lts && npm i -g ${NPM_PACKAGES[*]}"
fi

# --- oh-my-zsh (unattended: never hijack this terminal) --------------------------
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
    "$HOME/.tmux.conf" "$HOME/.tmux-powerlinerc" "$HOME/.bashrc"

# --- folders + symlinks ------------------------------------------------------------
say "creating folders and symlinks"
run "create folders" mkdir -p "$HOME/workspace" "$HOME/.tmux" "$HOME/.autoenv" "$HOME/.config/nvim"
run "symlink ~/.env -> dotfiles/env" ln -sfn "$HOME/dotfiles/env" "$HOME/.env"

# --- clone helper repos -------------------------------------------------------------
say "cloning helper repositories"
if [ -f "$HOME/.autoenv/activate.sh" ]; then
    printf '    [skip] autoenv already installed\n'
else
    run "clone autoenv" git clone https://github.com/hyperupcall/autoenv.git "$HOME/.autoenv"
fi
if [ -d "$HOME/.tmux/tmux-powerline" ]; then
    printf '    [skip] tmux-powerline already installed\n'
else
    run "clone tmux-powerline" git clone https://github.com/erikw/tmux-powerline.git "$HOME/.tmux/tmux-powerline"
fi
if [ -d "$HOME/workspace/ozono-zsh-theme" ]; then
    printf '    [skip] ozono-zsh-theme already cloned\n'
else
    run "clone ozono-zsh-theme" git clone https://github.com/sfabrizio/ozono-zsh-theme.git "$HOME/workspace/ozono-zsh-theme"
fi

# --- config entrypoints ---------------------------------------------------------------
say "wiring config files to dotfiles"
write_config "$HOME/.gitconfig"   '[include] path = ~/dotfiles/gitconfig'
write_config "$HOME/.vimrc"       'source ~/dotfiles/vimrc'
write_config "$HOME/.config/nvim/init.vim" 'source ~/.vimrc'
write_config "$HOME/.zshrc"       'source ~/dotfiles/zshrc'
write_config "$HOME/.tmux.conf"   'source ~/dotfiles/tmux.conf'
write_config "$HOME/.tmux-powerlinerc" 'source ~/dotfiles/tmux-powerlinerc'
run "expose ozono theme to oh-my-zsh" \
    bash -c "mkdir -p '$HOME/.oh-my-zsh/custom/themes' && ln -sfn '$HOME/dotfiles/ozono.zsh-theme' '$HOME/.oh-my-zsh/custom/themes/ozono.zsh-theme'"

# --- patched nerd font (optional; auto-skipped when non-interactive) ------------------
if [ "${DOTFILES_INSTALL_FONT:-}" != "0" ] && [ -t 0 ]; then
    printf 'Install a patched Nerd Font now (needed by the tmux bar icons)? [y/N] '
    read -r answer
    case "$answer" in
        [yY]*) run "install patched nerd font" bash "$HOME/dotfiles/scripts/nerd-font-download.sh" ;;
        *)     say "skipping nerd font install" ;;
    esac
else
    say "skipping nerd font install (run scripts/nerd-font-download.sh, or DOTFILES_INSTALL_FONT=1)"
fi

# --- summary ----------------------------------------------------------------------------
install_summary || exit 1
