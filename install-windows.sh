#!/usr/bin/env bash
# Sam's dotfiles installer for Windows (git-bash + Windows Terminal).
# Dispatched from install.sh, or run directly after cloning the repo.
# Reliability notes: see scripts/install-lib.sh (dry-run, backups, summary).

# --- bash guard ---------------------------------------------------------------
if [ -z "${BASH_VERSION:-}" ]; then
    if [ -f "$0" ] && [ "$(basename -- "$0")" != "sh" ] && [ "$(basename -- "$0")" != "dash" ]; then
        exec bash "$0" "$@"
    fi
    echo "==> re-run this installer with bash: bash install-windows.sh"
    exit 1
fi

set -u

DOTFILES_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
if [ -f "$DOTFILES_DIR/scripts/install-lib.sh" ]; then
    # shellcheck source=scripts/install-lib.sh
    source "$DOTFILES_DIR/scripts/install-lib.sh"
else
    # fallback: minimal inline helpers (repo layout unexpected)
    say() { printf '%s\n' "==> $*"; }
    warn() { printf '%s\n' "    [warn] $*"; }
    run() { local d="$1"; shift; printf '    %s\n' "$d"; "$@" || warn "step failed: $d"; }
    backup_configs() { :; }
    write_file_once() { [ -e "$1" ] || printf '%s\n' "$2" > "$1"; }
    install_summary() { say "Everything Done."; }
fi

command -v git >/dev/null 2>&1 || { echo "git is required. Please install it first."; exit 1; }

# --- make sure the repo sits at ~/dotfiles (config paths depend on it) ----------
if [ ! -f "$HOME/dotfiles/gitconfig" ]; then
    say "dotfiles repo not found at ~/dotfiles - cloning"
    run "clone dotfiles" git clone https://github.com/sfabrizio/dotfiles.git "$HOME/dotfiles"
fi

# --- npm global packages ---------------------------------------------------------
NPM_PACKAGES=(turbo-git)
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    say "installing npm global packages: ${NPM_PACKAGES[*]}"
    run "npm install -g ${NPM_PACKAGES[*]}" npm install -g "${NPM_PACKAGES[@]}"
else
    warn "node/npm not found - install node, then run: npm i -g ${NPM_PACKAGES[*]}"
fi

# --- Windows Terminal (the terminal window; git-bash stays the shell) -----------
# The shell wiring below is terminal-agnostic, but the mintty window git-bash
# opens by default is bare: no tabs/splits, legacy rendering. Windows Terminal
# is the modern host. The profile is wired as a WT *fragment* (user-level dir
# WT >= 1.6 scans automatically) so the user's settings.json is never touched,
# and the file is created once, never overwritten.
if command -v wt >/dev/null 2>&1; then
    say "Windows Terminal already installed - skipping"
else
    if command -v winget >/dev/null 2>&1; then
        say "installing Windows Terminal (winget)"
        run "install Windows Terminal (winget)" winget install \
            --id Microsoft.WindowsTerminal -e --source winget \
            --accept-source-agreements --accept-package-agreements \
            --disable-interactivity --silent
    else
        warn "winget not found - install Windows Terminal manually: https://aka.ms/terminal"
    fi
fi

if [ -n "${LOCALAPPDATA:-}" ]; then
    WT_FRAG_DIR="$LOCALAPPDATA/Microsoft/Windows Terminal/Fragments/dotfiles"
    run "create Windows Terminal fragments dir" mkdir -p "$WT_FRAG_DIR"
    # git-bash's own location (EXEPATH is set whenever this runs under git-bash)
    WT_GIT_ROOT="${EXEPATH:-C:/Program Files/Git}"
    WT_GIT_ROOT="${WT_GIT_ROOT//\\//}"
    WT_FRAGMENT_CONTENT="$(cat <<EOF
{
    "profiles": [
        {
            "name": "git-bash (dotfiles)",
            "commandline": "\\"$WT_GIT_ROOT/bin/bash.exe\\" --login -i",
            "startingDirectory": "%USERPROFILE%",
            "font": { "face": "Hack Nerd Font" }
        }
    ]
}
EOF
)"
    write_file_once "$WT_FRAG_DIR/fragment.json" "$WT_FRAGMENT_CONTENT"
else
    warn "LOCALAPPDATA not set - skipping the Windows Terminal profile fragment"
fi

# --- backups ---------------------------------------------------------------------
say "backing up existing configs (.bak, never overwritten)"
backup_configs "$HOME/.gitconfig" "$HOME/.vimrc" "$HOME/.bashrc"

# --- folders ------------------------------------------------------------------------
say "creating folders"
run "create folders" mkdir -p "$HOME/dotfiles" "$HOME/workspace"

# --- config entrypoints -----------------------------------------------------------------
say "wiring config files to dotfiles"
write_config "$HOME/.gitconfig" '[include] path = ~/dotfiles/gitconfig'
write_config "$HOME/.vimrc"     'source ~/dotfiles/vimrc'
write_config "$HOME/.bashrc"    'source ~/dotfiles/bashrc'

# --- summary ----------------------------------------------------------------------------
install_summary || exit 1
