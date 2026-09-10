#!/usr/bin/env bash
# Post-install smoke test: verifies the dotfiles are actually WIRED and
# USABLE after install.sh runs - real aliases in a real zsh, git include
# resolution, the tmux bar rendering with its click ranges, tmux.conf
# parsing - not just that the installer exited 0.
#
# Run right after the installer (CI install matrix) or manually:
#   bash scripts/smoke-test.sh
# Safe on machines with a live tmux server: tmux checks use a private socket.

set -u

ROOT="$HOME/dotfiles"
# shellcheck source=scripts/get_os_name.sh
. "$ROOT/scripts/get_os_name.sh"
OS_NAME="$(get_os_name)"

CHECKS_FAILED=0
announce_fail() {
    printf '  [FAIL] %s\n' "$1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    [ -n "${GITHUB_ACTIONS:-}" ] && printf '::error::smoke: %s\n' "$1"
    return 0
}
check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '  [ok]   %s\n' "$desc"
    else
        announce_fail "$desc"
    fi
}
check_cmd() {
    local desc="$1" cmd="$2"
    if bash -c "$cmd" >/dev/null 2>&1; then
        printf '  [ok]   %s\n' "$desc"
    else
        announce_fail "$desc"
    fi
}

echo "==> smoke test on: $OS_NAME"

# --- checks common to every OS -------------------------------------------------
echo "==> common wiring"
check "~/.gitconfig wired"        grep -qF '[include] path = ~/dotfiles/gitconfig' "$HOME/.gitconfig"
check_cmd "git resolves the include" 'git config --global --get include.path | grep -q dotfiles/gitconfig'
check "~/.vimrc wired"            grep -qF 'source ~/dotfiles/vimrc' "$HOME/.vimrc"
check "dotfiles repo present"     test -f "$ROOT/tmux.conf"

case "$OS_NAME" in
    linux*|osx)
        echo "==> zsh / oh-my-zsh / tools"
        check "zsh present"              command -v zsh
        check "nvm installed"            test -s "$HOME/.nvm/nvm.sh"
        # node lives under nvm; non-interactive shells need it sourced explicitly
        [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
        check "oh-my-zsh installed"      test -d "$HOME/.oh-my-zsh"
        check "ozono theme linked"       test -e "$HOME/.oh-my-zsh/custom/themes/ozono.zsh-theme"
        check "~/.zshrc wired"           grep -qF 'source ~/dotfiles/zshrc' "$HOME/.zshrc"
        check "zshrc loads end-to-end"   bash -c 'zsh -ic "true"'
        check "alias bat (real zsh)"     bash -c 'zsh -ic "type bat"'
        check "alias ca (real zsh)"      bash -c 'zsh -ic "type ca"'
        check "z function (real zsh)"    bash -c 'zsh -ic "type z"'
        check "fzf key bindings (real zsh)" bash -c 'zsh -ic "whence -w fzf-history-widget" | grep -q function'
        check "bat renders a file"       bash -c 'b="$(command -v batcat || command -v bat)"; "$b" --style=plain --color=never "'"$ROOT"'/README.md" >/dev/null'
        check "node present"             command -v node
        check "npm present"              command -v npm
        check "turbo-git installed"      bash -c 'npm ls -g --depth=0 2>/dev/null | grep -q turbo-git'
        check "diff-so-fancy installed"  bash -c 'npm ls -g --depth=0 2>/dev/null | grep -q diff-so-fancy'
        check "nvim init wired"          test -f "$HOME/.config/nvim/init.vim"
        if [[ "$OS_NAME" == osx ]]; then
            check "smctemp present (chip temps)" command -v smctemp
        fi
        check "nerd font installed (Hack)" bash -c 'fc-list 2>/dev/null | grep -qi "hack nerd font" || compgen -G "$HOME/Library/Fonts/*Hack*" >/dev/null || compgen -G "$HOME/.local/share/fonts/*Hack*" >/dev/null || compgen -G "$HOME/.fonts/*Hack*" >/dev/null'

        echo "==> tmux bar"
        check "tmux-powerline cloned"    test -d "$HOME/.tmux/tmux-powerline"
        check "powerline left renders"   bash -c '"$HOME/.tmux/tmux-powerline/powerline.sh" left | grep -q .'
        check "powerline right renders"  bash -c '"$HOME/.tmux/tmux-powerline/powerline.sh" right | grep -q .'
        check "close segment has click range" bash -c '"$HOME/.tmux/tmux-powerline/powerline.sh" right | grep -q "range=user|closepane"'

        # parse the whole tmux.conf in an isolated-socket server (never touches
        # a live tmux server) and verify the clickable-segment bindings loaded;
        # single invocation: restarting the socket back-to-back is flaky
        tmux_conf_check() {
            tmux -L smokecfg -f "$ROOT/tmux.conf" new-session -d -s smoke || return 1
            tmux -L smokecfg list-keys -T root | grep -q "MouseDown1Status"
            rc=$?
            tmux -L smokecfg kill-server 2>/dev/null
            return "$rc"
        }
        check "tmux.conf parses + click bindings load" tmux_conf_check
        ;;
    windows)
        echo "==> windows wiring"
        check "~/.bashrc wired"          grep -qF 'source ~/dotfiles/bashrc' "$HOME/.bashrc"
        check "node present"             command -v node
        check "npm present"              command -v npm
        check "turbo-git installed"      bash -c 'npm ls -g --depth=0 2>/dev/null | grep -q turbo-git'
        check "git resolves include"     bash -c 'git config --global --list | grep -q dotfiles/gitconfig'
        ;;
esac

echo
if [ "$CHECKS_FAILED" -gt 0 ]; then
    printf 'SMOKE TEST FAILED (%s check(s))\n' "$CHECKS_FAILED"
    exit 1
fi
echo "SMOKE TEST PASSED"
