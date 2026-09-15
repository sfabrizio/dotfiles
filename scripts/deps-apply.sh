#!/usr/bin/env bash
# deps-apply: bring THIS machine's dependencies in line with the repo pins and
# upstream, after showing exactly what will be updated.
#
# Discovers updates via scripts/deps-check.sh --local --machine, prints the
# plan, then (with a tty or --yes / DOTFILES_UPDATE_MODE=auto) applies it:
#   - Tier 1 drift: re-clone/re-download per the new pin
#   - Tier 2 behind: update the floating checkout / single npm install
#   - OS packages: offered separately (they run through sudo / brew)
#
# Called by scripts/auto-update.sh after a successful pull; direct use:
#   bash scripts/deps-apply.sh [--yes]
#
# DOTFILES_INSTALL_DRY_RUN=1 prints the plan + steps without executing.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/install-lib.sh
. "$SELF_DIR/install-lib.sh"
# shellcheck source=scripts/deps-versions.sh
. "$SELF_DIR/deps-versions.sh"
# shellcheck source=scripts/deps-lib.sh
. "$SELF_DIR/deps-lib.sh"

MODE="${DOTFILES_UPDATE_MODE:-prompt}"
YES=0
for arg in "$@"; do
    case "$arg" in
        --yes)         YES=1 ;;
        --post-update) : ;;   # invoked from auto-update.sh: same behaviour
        *) printf 'unknown flag: %s (use --yes)\n' "$arg" >&2; exit 2 ;;
    esac
done

# discovery: by default deps-check probes upstream live; tests (and callers
# that already have a report) can inject one via DOTFILES_DEPS_REPORT_FILE
if [ -n "${DOTFILES_DEPS_REPORT_FILE:-}" ] && [ -f "$DOTFILES_DEPS_REPORT_FILE" ]; then
    REPORT="$(cat "$DOTFILES_DEPS_REPORT_FILE")"
else
    REPORT="$(bash "$SELF_DIR/deps-check.sh" --local --machine 2>/dev/null)"
fi
if [ -z "$REPORT" ]; then
    say "dependency check produced no report - nothing to do"
    exit 0
fi

# --- build the plan -----------------------------------------------------------------------
# only actionable lines enter the plan: ok/info/unknown rows are skipped
# (outdated pins are repo-level actions - shown as info, applied by merging
# the weekly deps PR)
PLAN=()        # T1/T2 machine lines that may need a local action
OS_NAMES=()    # upgradable OS package names (separate confirmation)
while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "${line%%$'\t'*}" in
        T1|T2)
            case "${line##*$'\t'}" in
                ok|info|unknown) : ;;
                *) PLAN+=("$line") ;;
            esac
            ;;
        OS) OS_NAMES+=("$(printf '%s' "$line" | cut -f2)") ;;
    esac
done <<EOF
$REPORT
EOF

if [ "${#PLAN[@]}" -eq 0 ] && [ "${#OS_NAMES[@]}" -eq 0 ]; then
    say "all dependencies current"
    exit 0
fi

describe_line() { # machine line -> "- human description" (empty = no action)
    local kind name a b c status
    IFS=$'\t' read -r kind name a b c status <<< "$1"
    case "$kind:$name:$status" in
        T1:tmux-powerline:drift)
            printf '%s: apply pin %s (local %s)\n' "$name" "$a" "$c" ;;
        T1:zoxide:drift)
            printf '%s: local %s is older than pin %s (re-download)\n' "$name" "$c" "$a" ;;
        T1:nvm:drift)
            printf '%s: local %s is older than pin %s (re-run installer)\n' "$name" "$c" "$a" ;;
        T1:nerd-font:drift)
            printf '%s: not found locally - install %s %s\n' "$name" "$NF_FONT" "$a" ;;
        T1:*:outdated)
            printf '%s: pin %s -> %s (merge the weekly deps PR)\n' "$name" "$a" "$b" ;;
        T1:*:drift)
            # a drifted pin that is itself outdated: apply the pin now, note the PR
            printf '%s: apply pin %s (note: pin is outdated, %s is upstream - merge the deps PR)\n' "$name" "$a" "$b" ;;
        T2:fzf:behind|T2:fzf:missing)
            printf 'fzf: %s (%s -> %s)\n' "$status" "${a:--}" "${b:--}" ;;
        T2:autoenv:behind|T2:autoenv:missing)
            printf 'autoenv: %s (%s -> %s)\n' "$status" "${a:--}" "${b:--}" ;;
        T2:*:behind)
            printf '%s: %s -> %s (npm install -g)\n' "$name" "$a" "$b" ;;
        T2:*:missing)
            printf '%s: not installed - install (latest %s)\n' "$name" "$b" ;;
        *) : ;;
    esac
}

apply_line() { # machine line -> guarded, idempotent action (run() = dry-run aware)
    local kind name a b c status
    IFS=$'\t' read -r kind name a b c status <<< "$1"
    case "$kind:$name:$status" in
        T1:tmux-powerline:drift)
            run "tmux-powerline: checkout pin ${a}" deps_install_tmux_powerline ;;
        T1:zoxide:drift)
            run "zoxide: install pinned ${a}" deps_install_zoxide ;;
        T1:nvm:drift)
            run "nvm: install pinned ${a}" deps_install_nvm ;;
        T1:nerd-font:drift)
            run "nerd font: install ${NF_FONT} ${a}" bash "$SELF_DIR/nerd-font-download.sh" "$NF_FONT" "$NF_VERSION" ;;
        T2:fzf:behind|T2:fzf:missing)
            run "fzf: update checkout" deps_install_fzf ;;
        T2:autoenv:behind|T2:autoenv:missing)
            run "autoenv: update checkout" deps_install_autoenv ;;
        T2:*:behind|T2:*:missing)
            run "npm: install ${name} (latest ${b})" deps_update_npm_package "$name" ;;
    esac
}

# --- show what will be updated -------------------------------------------------------------
say "dependency updates available:"
for line in "${PLAN[@]}"; do
    d="$(describe_line "$line")"
    [ -n "$d" ] && printf '  - %s\n' "$d"
done
if [ "${#OS_NAMES[@]}" -gt 0 ]; then
    printf '  - os packages: %s (upgraded via apt/brew)\n' "${OS_NAMES[*]}"
fi

if [ "$DRY_RUN" = "1" ]; then
    for line in "${PLAN[@]}"; do apply_line "$line"; done
    if [ "${#OS_NAMES[@]}" -gt 0 ]; then
        if command -v apt-get >/dev/null 2>&1; then
            run "apt upgrade: ${OS_NAMES[*]}" apt-get install -y "${OS_NAMES[@]}"
        elif command -v brew >/dev/null 2>&1; then
            run "brew upgrade: ${OS_NAMES[*]}" env HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade "${OS_NAMES[@]}"
        fi
    fi
    say "dry run - nothing applied"
    exit 0
fi

# --- confirmation --------------------------------------------------------------------------
deps_tty_open() {
    # DOTFILES_DEPS_TTY=0 forces the no-tty path (tests, scripted runs);
    # otherwise the prompt reads the controlling terminal like auto-update does
    if [ "${DOTFILES_DEPS_TTY:-1}" = "0" ]; then
        return 1
    fi
    { exec 3</dev/tty; } 2>/dev/null
}

if [ "$YES" -eq 0 ] && [ "$MODE" != "auto" ]; then
    if ! deps_tty_open; then
        say "dependency updates need confirmation - run: dotfiles-update"
        exit 0
    fi
    printf '[dotfiles] apply dependency updates? [y/N] '
    if ! read -r answer <&3; then
        exec 3<&-
        printf '\n[dotfiles] no answer - run: dotfiles-update\n'
        exit 0
    fi
    exec 3<&-
    case "$answer" in
        n*|N*) say "skipped (nothing applied)"; exit 0 ;;
    esac
fi

# --- apply ------------------------------------------------------------------------------------
for line in "${PLAN[@]}"; do
    apply_line "$line"
done

if [ "${#OS_NAMES[@]}" -gt 0 ]; then
    # separate confirmation: OS upgrades go through sudo and touch packages
    # beyond the dotfiles' scope
    if [ "$YES" -eq 0 ] && [ "$MODE" != "auto" ]; then
        if ! deps_tty_open; then
            say "os package upgrades need confirmation - run: dotfiles-update"
            OS_NAMES=()
        else
            printf '[dotfiles] upgrade OS packages (%s)? [y/N] ' "${OS_NAMES[*]}"
            if ! read -r answer <&3; then
                exec 3<&-
                OS_NAMES=()
            else
                exec 3<&-
                case "$answer" in n*|N*) OS_NAMES=() ;; esac
            fi
        fi
    fi
    if [ "${#OS_NAMES[@]}" -gt 0 ]; then
        if command -v apt-get >/dev/null 2>&1; then
            SUDO=()
            [ "$(id -u)" -ne 0 ] && SUDO=(sudo)
            if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
                warn "no sudo available: upgrade manually -> apt-get install -y ${OS_NAMES[*]}"
            else
                run "apt upgrade: ${OS_NAMES[*]}" ${SUDO[@]+"${SUDO[@]}"} apt-get install -y "${OS_NAMES[@]}"
            fi
        elif command -v brew >/dev/null 2>&1; then
            run "brew upgrade: ${OS_NAMES[*]}" env HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade "${OS_NAMES[@]}"
        fi
    fi
fi

install_summary || exit 1
