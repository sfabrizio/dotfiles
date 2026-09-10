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

# tmux-powerline commit this dotfiles config is tested against: newer master
# restructured its config system (lib/rcfile.sh gone) and silently ignores
# ~/.tmux-powerlinerc + user themes/segments
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
    run "brew install byobu tmux neovim git-extras htop node bat" \
        brew install byobu tmux neovim git-extras htop node bat
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

# --- zoxide (direct release download: the official installer queries the
# --- github API, which is rate-limited on shared CI/shared-IP machines) ---------
install_zoxide() {
    local version="0.10.0" target tmp
    case "$(uname -s)-$(uname -m)" in
        Darwin-arm64)              target="aarch64-apple-darwin" ;;
        Darwin-x86_64)             target="x86_64-apple-darwin" ;;
        Linux-aarch64|Linux-arm64) target="aarch64-unknown-linux-musl" ;;
        *)                         target="x86_64-unknown-linux-musl" ;;
    esac
    tmp=$(mktemp -d)
    curl -sSfL "https://github.com/ajeetdsouza/zoxide/releases/download/v${version}/zoxide-${version}-${target}.tar.gz" \
        | tar xz -C "$tmp" || { rm -rf "$tmp"; return 1; }
    mkdir -p "$HOME/.local/bin"
    find "$tmp" -type f -name zoxide -exec cp {} "$HOME/.local/bin/" \; 2>/dev/null
    chmod +x "$HOME/.local/bin/zoxide" 2>/dev/null
    rm -rf "$tmp"
    [ -x "$HOME/.local/bin/zoxide" ]
}
if [ ! -x "$HOME/.local/bin/zoxide" ] && ! command -v zoxide >/dev/null 2>&1; then
    say "installing zoxide"
    if run "install zoxide" install_zoxide; then
        say "zoxide installed to ~/.local/bin"
    else
        warn "zoxide could not be installed - the 'z' command will be missing"
    fi
else
    say "zoxide already installed - skip"
fi

# --- fzf: distro versions can lack shell bindings (ubuntu 24.04 ships 0.44) -----
fzf_has_bindings() {
    local fzf_bin="${1:-fzf}"
    if [ -x "$fzf_bin" ] && "$fzf_bin" --zsh </dev/null 2>/dev/null | grep -q "fzf-history-widget"; then
        return 0
    fi
    [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] \
        || [ -f "$HOME/.local/share/fzf/examples/key-bindings.zsh" ]
}
if ! fzf_has_bindings; then
    say "installing a current fzf (distro one lacks shell key bindings)"
    run "install fzf via its installer" bash -c "
        git clone -q --depth 1 https://github.com/junegunn/fzf.git '$HOME/.fzf' &&
        '$HOME/.fzf/install' --bin &&
        mkdir -p '$HOME/.local/bin' &&
        ln -sf '$HOME/.fzf/bin/fzf' '$HOME/.local/bin/fzf'"
else
    say "fzf with shell bindings already present - skip"
fi

# --- nvm (before npm: node may only exist after this) ---------------------------
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
    say "installing nvm"
    run "install nvm" \
        bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
else
    say "nvm already installed - skip"
fi

# --- npm global packages (installs node LTS via nvm when no runtime exists) ------
NPM_PACKAGES=(turbo-git diff-so-fancy)
if is_node; then
    say "installing npm global packages: ${NPM_PACKAGES[*]}"
    run "npm install -g ${NPM_PACKAGES[*]}" npm install -g "${NPM_PACKAGES[@]}"
elif [ -s "$HOME/.nvm/nvm.sh" ]; then
    say "no node runtime found - installing node LTS via nvm, then npm globals"
    run "nvm install --lts + npm install -g ${NPM_PACKAGES[*]}" bash -c '
        . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
        nvm install --lts >/dev/null 2>&1
        nvm alias default lts >/dev/null 2>&1
        npm install -g '"${NPM_PACKAGES[*]}" >/dev/null 2>&1'
else
    warn "node/npm not found and nvm missing - install node, then run: npm i -g ${NPM_PACKAGES[*]}"
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
    say "cloning tmux-powerline (pinned: newer upstream restructured its config system)"
    run "clone+pin tmux-powerline" bash -c "
        git clone -q https://github.com/erikw/tmux-powerline.git '$HOME/.tmux/tmux-powerline' &&
        git -C '$HOME/.tmux/tmux-powerline' checkout --quiet $TMUX_POWERLINE_PIN"
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

# machine-local override files (sourced by the configs above; never committed)
say "creating local override files (kept even across reinstalls, never overwritten)"
for f in .gitconfig.local .vimrc.local .tmux.local .bash.local .zshrc.local; do
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

# --- patched nerd font (auto-installed when missing; the bar icons need it) ---------
NERD_FONT_PRESENT=0
if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qiE 'nerd font'; then
    NERD_FONT_PRESENT=1
fi
case "${DOTFILES_INSTALL_FONT:-}" in
    0)
        say "skipping nerd font install (DOTFILES_INSTALL_FONT=0)"
        ;;
    *)
        if [ "$NERD_FONT_PRESENT" = "1" ]; then
            say "a nerd font is already installed - skip"
        elif [[ "$OS_NAME" == windows* || "$OS_NAME" == unknown ]]; then
            warn "no nerd font detected and auto-install is not supported on this OS - run: bash ~/dotfiles/scripts/nerd-font-download.sh"
        else
            say "no nerd font found - installing Hack (the font this setup standardizes on)"
            run "install patched nerd font (Hack)" bash "$HOME/dotfiles/scripts/nerd-font-download.sh"
        fi
        ;;
esac

# --- summary ----------------------------------------------------------------------------
install_summary || exit 1
