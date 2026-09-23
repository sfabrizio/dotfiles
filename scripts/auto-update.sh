#!/usr/bin/env bash
# oh-my-zsh style auto-update for these dotfiles.
# Called NON-BLOCKING in the background from zshrc/bashrc; direct use:
#   auto-update.sh [--force]
#
# Behaviour (DOTFILES_UPDATE_MODE, default "prompt" - like omz):
#   prompt    ask "update now? [Y/n]" when updates are available
#   reminder  only print that updates are available
#   auto      pull and print what changed, no questions
#   disabled  do nothing (or export DOTFILES_DISABLE_AUTO_UPDATE=1)
# Interval: DOTFILES_UPDATE_INTERVAL_DAYS (default 13, like omz).
# The last-check epoch is recorded even when the check fails, so a flaky
# network never turns into a per-shell fetch storm.

set -u

D="$HOME/dotfiles"
EPOCH_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/last-update"
# turbo-commit tag colors for the post-update changelog (may not exist in a
# clone that is ABOUT to receive it - the pipe below degrades to plain text)
[ -f "$D/scripts/turbo-colors.sh" ] && . "$D/scripts/turbo-colors.sh"
INTERVAL="${DOTFILES_UPDATE_INTERVAL_DAYS:-13}"
MODE="${DOTFILES_UPDATE_MODE:-prompt}"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

[ "$MODE" = "disabled" ] && exit 0
[ "${DOTFILES_DISABLE_AUTO_UPDATE:-0}" = "1" ] && exit 0
[ -d "$D/.git" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0

mkdir -p "$(dirname "$EPOCH_FILE")"
now=$(date +%s)
last=$(cat "$EPOCH_FILE" 2>/dev/null || echo 0)
if [ "$FORCE" -ne 1 ] && [ $((now - last)) -lt $((INTERVAL * 86400)) ]; then
    exit 0
fi
# record the attempt now (omz does the same): one check per interval, max
echo "$now" > "$EPOCH_FILE"

branch=$(git -C "$D" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -n "$branch" ] && [ "$branch" != "HEAD" ] || exit 0

# fetch with a soft timeout so a hanging network never blocks shell startup
if command -v timeout >/dev/null 2>&1; then
    timeout 8 git -C "$D" fetch origin "$branch" --quiet 2>/dev/null || exit 0
else
    git -C "$D" fetch origin "$branch" --quiet 2>/dev/null || exit 0
fi

local_rev=$(git -C "$D" rev-parse HEAD)
remote_rev=$(git -C "$D" rev-parse "origin/$branch" 2>/dev/null) || exit 0
[ "$local_rev" = "$remote_rev" ] && exit 0

behind=$(git -C "$D" rev-list --count "HEAD..origin/$branch" 2>/dev/null)
[ -n "$behind" ] && [ "$behind" -gt 0 ] || exit 0

update_dotfiles() {
    if ! git -C "$D" pull --ff-only --quiet origin "$branch" 2>/dev/null; then
        printf '[dotfiles] update skipped: your clone diverged from origin - see: git -C ~/dotfiles status\n'
        return 1
    fi
    printf '[dotfiles] updated (%s new commit(s)):\n' "$behind"
    # the lib may have ARRIVED with this very update - re-source after the pull
    # so the first colored changelog is this one (guarded: no lib = plain text)
    [ -f "$D/scripts/turbo-colors.sh" ] && . "$D/scripts/turbo-colors.sh"
    # colorize the [TAG] prefixes with the turbo-git palette; the guard keeps
    # the changelog plain instead of erroring when the function is missing
    if command -v turbo_colorize >/dev/null 2>&1; then
        git -C "$D" log --oneline --no-decorate "${local_rev}..origin/$branch" | head -10 | turbo_colorize
    else
        git -C "$D" log --oneline --no-decorate "${local_rev}..origin/$branch" | head -10
    fi
    # after a pull the dependency pins may have moved (e.g. the weekly deps
    # PR merged): show what drifted locally and ask to apply it. deps-apply
    # prompts only with a tty; DOTFILES_DEPS_APPLY=0 switches it off.
    if [ "${DOTFILES_DEPS_APPLY:-1}" = "1" ] && [ -f "$D/scripts/deps-apply.sh" ]; then
        bash "$D/scripts/deps-apply.sh" --post-update || true
    fi
}

if [ "$FORCE" -eq 1 ]; then
    update_dotfiles
    exit $?
fi

case "$MODE" in
    auto)
        update_dotfiles
        ;;
    reminder)
        printf "[dotfiles] %s update(s) available - run 'dotfiles-update'\n" "$behind"
        ;;
    prompt)
        printf "[dotfiles] %s update(s) available. Update now? [Y/n] " "$behind"
        # DOTFILES_DEPS_TTY=0 forces the skip path (deterministic tests)
        if [ "${DOTFILES_DEPS_TTY:-1}" = "1" ] && read -r answer </dev/tty 2>/dev/null; then
            case "$answer" in
                n*|N*) printf '[dotfiles] update skipped (next check in %s days)\n' "$INTERVAL" ;;
                *)     update_dotfiles ;;
            esac
        fi
        ;;
esac
exit 0
