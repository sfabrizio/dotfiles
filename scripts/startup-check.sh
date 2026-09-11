#!/usr/bin/env bash
# zsh startup benchmark - the perf gate for every new plugin/tool this
# dotfiles repo adds (numbers are logged in AGENTS.md, "startup perf log").
#
# Usage:
#   bash scripts/startup-check.sh             # summary; exit 1 over threshold
#   bash scripts/startup-check.sh --profile   # + zprof table of top offenders
#   bash scripts/startup-check.sh --quiet 3   # print only the median (ms)
#
# Measures a full interactive zsh (your real ~/.zshrc). The background
# auto-update check is disabled for the measured shells so a due update
# can never pollute the timing. A warmup run absorbs one-off costs such
# as a zcompdump regeneration right after new completions are installed.
set -u

RUNS=5
PROFILE=0
QUIET=0
for arg in "$@"; do
    case "$arg" in
        --profile) PROFILE=1 ;;
        --quiet)   QUIET=1 ;;
        [0-9]*)    RUNS="$arg" ;;
        *) echo "usage: startup-check.sh [--profile] [--quiet] [runs]" >&2; exit 2 ;;
    esac
done

command -v zsh >/dev/null 2>&1 || { echo "zsh is required" >&2; exit 2; }

# auto-update must never run inside a benchmarked shell
export DOTFILES_UPDATE_MODE=disabled

# warmup (unmeasured)
zsh -ic 'exit' >/dev/null 2>&1

times_ms=()
i=1
while [ "$i" -le "$RUNS" ]; do
    t="$( { TIMEFORMAT='%R'; time zsh -ic 'exit' >/dev/null 2>&1; } 2>&1 )"
    times_ms+=( "$(awk -v s="$t" 'BEGIN{printf "%.0f", s*1000}')" )
    i=$((i + 1))
done

median="$(printf '%s\n' "${times_ms[@]}" | sort -n | awk -v n="$RUNS" 'NR==int((n+1)/2){print; exit}')"
min="${times_ms[0]}"
max="${times_ms[0]}"
for t in "${times_ms[@]}"; do
    [ "$t" -lt "$min" ] && min="$t"
    [ "$t" -gt "$max" ] && max="$t"
done

if [ "$QUIET" -eq 1 ]; then
    printf '%s\n' "$median"
else
    printf 'zsh startup: median %sms  min %sms  max %sms  (%s runs)\n' "$median" "$min" "$max" "$RUNS"
fi

if [ "$PROFILE" -eq 1 ]; then
    ZSRC="$HOME/.zshrc"
    [ -f "$ZSRC" ] || ZSRC="$HOME/dotfiles/zshrc"
    echo
    echo "top offenders (zprof, ms - approximate, non-interactive source of $ZSRC):"
    zsh -c "zmodload zsh/zprof; source '$ZSRC' >/dev/null 2>&1; zprof" 2>/dev/null | head -16
fi

# threshold gate (doctor hooks this)
MAX_MS="${DOTFILES_STARTUP_MAX_MS:-800}"
if [ "$median" -gt "$MAX_MS" ]; then
    if [ "$QUIET" -eq 0 ]; then
        printf 'over threshold (%sms > %sms) - run: bash scripts/startup-check.sh --profile\n' "$median" "$MAX_MS" >&2
    fi
    exit 1
fi
exit 0
