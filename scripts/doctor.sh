#!/usr/bin/env bash
# dotfiles-doctor: interactive health check for the dotfiles install.
# Tiered output: [ok] / [warn] (nice-to-have or environmental) / [FAIL]
# (broken install). Exit 1 only when at least one FAIL.
# Read-only: never modifies anything; tmux checks use an isolated socket.
# Run via the bin/ shim: dotfiles-doctor

set -u

ROOT="$HOME/dotfiles"
# shellcheck source=scripts/get_os_name.sh
. "$ROOT/scripts/get_os_name.sh" 2>/dev/null
OS_NAME="$(get_os_name)"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_BAD=$'\033[31m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'
else
    C_OK=""; C_WARN=""; C_BAD=""; C_DIM=""; C_0=""
fi

OK=0; WARN=0; FAIL=0
ok()   { printf '  %s[ok]%s   %s\n' "$C_OK" "$C_0" "$1"; OK=$((OK + 1)); }
warn() { printf '  %s[warn]%s %s\n' "$C_WARN" "$C_0" "$1"; WARN=$((WARN + 1)); }
bad()  { printf '  %s[FAIL]%s %s\n' "$C_BAD" "$C_0" "$1"; FAIL=$((FAIL + 1)); }
note() { printf '  %s%s%s\n' "$C_DIM" "$1" "$C_0"; }

# check <tier: ok|warn|fail> <desc> <cmd...>
check() {
    local tier="$1" desc="$2"
    shift 2
    if "$@" >/dev/null 2>&1; then
        ok "$desc"
    elif [ "$tier" = "fail" ]; then
        bad "$desc"
    else
        warn "$desc"
    fi
}

echo "==> dotfiles doctor - $OS_NAME"

# --- repo ------------------------------------------------------------------------
echo "== repo"
check fail "repository present at ~/dotfiles" test -d "$ROOT/.git"
if [ -d "$ROOT/.git" ]; then
    if [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
        warn "uncommitted changes in ~/dotfiles (git -C ~/dotfiles status)"
    else
        ok "working tree clean"
    fi
    branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ] && [ "$branch" != "HEAD" ] \
        && git -C "$ROOT" fetch origin "$branch" --quiet 2>/dev/null; then
        behind=$(git -C "$ROOT" rev-list --count "HEAD..origin/$branch" 2>/dev/null)
        if [ "${behind:-0}" -gt 0 ]; then
            warn "$behind commit(s) behind origin - run: dotfiles-update"
        else
            ok "up to date with origin"
        fi
    else
        warn "could not check origin (offline or no remote)"
    fi
fi

# --- config wiring ------------------------------------------------------------------
echo "== wiring"
check fail "~/.gitconfig wired"  grep -qF '[include] path = ~/dotfiles/gitconfig' "$HOME/.gitconfig"
check warn "git include resolves" bash -c 'git config --global --get include.path | grep -q dotfiles/gitconfig'
check fail "~/.zshrc wired"      grep -qF 'source ~/dotfiles/zshrc' "$HOME/.zshrc"
check warn "~/.vimrc wired"      grep -qF 'source ~/dotfiles/vimrc' "$HOME/.vimrc"
check warn "~/.tmux.conf wired"  grep -qF 'source ~/dotfiles/tmux.conf' "$HOME/.tmux.conf"
check warn "~/.tmux-powerlinerc wired" grep -qF 'source ~/dotfiles/tmux-powerlinerc' "$HOME/.tmux-powerlinerc"

# --- personal commands (bin/) ---------------------------------------------------------
echo "== commands"
for cmd in re-commit multi-git dotfiles-update dotfiles-doctor; do
    check warn "bin command: $cmd" test -x "$ROOT/bin/$cmd"
done

# --- tools -----------------------------------------------------------------------------
echo "== tools"
check fail "git present" command -v git
check warn "zsh present" command -v zsh
check warn "tmux present" command -v tmux
check warn "fzf present" command -v fzf
check warn "zoxide present" command -v zoxide
check warn "bat present (batcat or bat)" bash -c 'command -v batcat || command -v bat'
check warn "ripgrep present" command -v rg
check warn "jq present" command -v jq

# --- tmux bar ----------------------------------------------------------------------------
echo "== tmux bar"
check warn "tmux-powerline present" test -d "$HOME/.tmux/tmux-powerline"
if [ -d "$HOME/.tmux/tmux-powerline" ]; then
    # pin drift: newer upstream restructured its config system and silently
    # ignores ~/.tmux-powerlinerc + user themes/segments
    head_sha=$(git -C "$HOME/.tmux/tmux-powerline" log -1 --format=%h 2>/dev/null)
    if [ "$head_sha" = "fca0d61" ]; then
        ok "tmux-powerline at pinned commit (fca0d61)"
    else
        warn "tmux-powerline drifted from pin fca0d61 (at ${head_sha:-none}) - re-clone: rm -rf ~/.tmux/tmux-powerline && dotfiles-update ... or reinstall"
    fi
    check warn "powerline left renders"  bash -c '"$HOME/.tmux/tmux-powerline/powerline.sh" left | grep -q .'
    check warn "powerline right renders" bash -c '"$HOME/.tmux/tmux-powerline/powerline.sh" right | grep -q .'
    check warn "close segment has click range" bash -c '"$HOME/.tmux/tmux-powerline/powerline.sh" right | grep -q "range=user|closepane"'
    tmux_conf_check() {
        tmux -L doctorcfg -f "$ROOT/tmux.conf" new-session -d -s doctor || return 1
        tmux -L doctorcfg list-keys -T root | grep -q "MouseDown1Status"
        rc=$?
        tmux -L doctorcfg kill-server 2>/dev/null
        return "$rc"
    }
    check warn "tmux.conf parses + click bindings load" tmux_conf_check
fi

# --- CI (best effort; skipped on rate limit) ----------------------------------------------
echo "== ci"
ci=$(curl -fsSL --max-time 5 "https://api.github.com/repos/sfabrizio/dotfiles/actions/runs?per_page=1" 2>/dev/null \
    | grep -m1 '"conclusion"' | sed 's/[^a-z]*//g')
case "$ci" in
    success) ok "latest CI run: success" ;;
    failure) warn "latest CI run: FAILURE - check github.com/sfabrizio/dotfiles/actions" ;;
    *)       note "ci status unavailable (rate limited or offline) - skipped" ;;
esac

# --- summary ------------------------------------------------------------------------------
echo
if [ "$FAIL" -gt 0 ]; then
    printf '%sdoctor: %d FAIL, %d warn, %d ok%s\n' "$C_BAD" "$FAIL" "$WARN" "$OK" "$C_0"
    exit 1
fi
printf '%sdoctor: healthy - %d warn, %d ok%s\n' "$C_OK" "$WARN" "$OK" "$C_0"
exit 0
