#!/usr/bin/env bash
# deps-check: compare the dotfiles dependencies against their upstreams.
#
# Usage:
#   deps-check.sh              Tier 1 pins vs upstream (weekly CI; exit 10 =
#                              pin bumps available)
#   deps-check.sh --local      + this machine: Tier 1 drift, Tier 2 floating
#                              deps (fzf / autoenv / npm globals), OS packages
#   deps-check.sh --os         OS packages only (apt/brew; no dotfiles probes)
#   --machine                  tab-separated lines instead of a human table
#
# Machine line format (KIND TAB name TAB colA TAB colB TAB colC TAB status):
#   T1 <name> <pin> <latest> <installed> <status>   ok|outdated|drift|unknown
#   T2 <name> <installed> <latest> - <status>       ok|behind|missing|info|unknown
#   OS <name> <installed> <candidate> - <upgradable>
#
# Status semantics:
#   outdated = the repo pin is behind upstream (CI opens a pin-bump PR)
#   drift    = this machine differs from the pin (deps-apply re-installs)
#   behind   = floating dep older than upstream (deps-apply updates it)
#   unknown  = upstream query failed; tolerated, never fatal
#
# Exit codes: 0 = nothing to do, 10 = updates available.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/deps-versions.sh
. "$SELF_DIR/deps-versions.sh"
# shellcheck source=scripts/deps-lib.sh
. "$SELF_DIR/deps-lib.sh"

MODE_LOCAL=0 MODE_OS=0 MACHINE=0
for arg in "$@"; do
    case "$arg" in
        --local)   MODE_LOCAL=1 ;;
        --os)      MODE_OS=1 ;;
        --machine) MACHINE=1 ;;
        *) printf 'unknown flag: %s (use --local / --os / --machine)\n' "$arg" >&2; exit 2 ;;
    esac
done

UPDATES=0
T1_ROWS=() T2_ROWS=() OS_ROWS=()

# Windows scope: the windows installer only ships Windows Terminal + the font
# (tmux lives on the server; zoxide/nvm/fzf/autoenv are not installed there).
# Checking them would report "missing" and offer installs Windows must not get.
DEPS_IS_WINDOWS=0
case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) DEPS_IS_WINDOWS=1 ;;
esac

# row helpers append machine lines AND count actionable statuses (called in
# the main shell, never in a subshell, so UPDATES survives). Empty fields get
# a "-" placeholder so both the machine lines and the human table stay aligned.
t1_row() { # name pin latest installed status
    case "$5" in outdated|drift) UPDATES=$((UPDATES + 1)) ;; esac
    T1_ROWS+=("$(printf 'T1\t%s\t%s\t%s\t%s\t%s' "$1" "$2" "${3:--}" "${4:--}" "$5")")
}
t2_row() { # name installed latest status
    case "$4" in behind|missing) UPDATES=$((UPDATES + 1)) ;; esac
    T2_ROWS+=("$(printf 'T2\t%s\t%s\t%s\t-\t%s' "$1" "${2:--}" "${3:--}" "$4")")
}
os_row() { # name installed candidate
    OS_ROWS+=("$(printf 'OS\t%s\t%s\t%s\t-\tupgradable' "$1" "$2" "$3")")
}

check_t1() {
    local latest="" status="unknown" installed=""

    # linux/osx-only deps: tmux (server-side on windows), zoxide, nvm
    if [ "$DEPS_IS_WINDOWS" -eq 0 ]; then
        # tmux-powerline: sha pin
        latest="$(deps_latest_git_sha "$TMUX_POWERLINE_REPO")"
        if [ -n "$latest" ]; then
            if deps_sha_matches "$latest" "$TMUX_POWERLINE_PIN"; then status="ok"; else status="outdated"; fi
        fi
        if [ "$MODE_LOCAL" -eq 1 ]; then
            installed="$(deps_installed_tmux_powerline_sha)"
            if [ -n "$installed" ] && ! deps_sha_matches "$installed" "$TMUX_POWERLINE_PIN"; then
                status="drift"
            fi
        fi
        [ -n "$installed" ] || installed="-"
        t1_row tmux-powerline "$TMUX_POWERLINE_PIN" "${latest:0:7}" "${installed:0:7}" "$status"

        # zoxide: version pin, direct release download
        status="unknown"; latest=""; installed=""
        latest="$(deps_latest_github_release "$ZOXIDE_REPO")"
        if [ -n "$latest" ]; then
            if deps_is_newer "$latest" "$ZOXIDE_VERSION"; then status="outdated"; else status="ok"; fi
        fi
        if [ "$MODE_LOCAL" -eq 1 ]; then
            installed="$(deps_installed_zoxide_version)"
            if [ -n "$installed" ] && deps_is_newer "$ZOXIDE_VERSION" "$installed"; then
                status="drift"
            fi
        fi
        [ -n "$installed" ] || installed="-"
        t1_row zoxide "$ZOXIDE_VERSION" "$latest" "$installed" "$status"

        # nvm: version (tag) pin
        status="unknown"; latest=""; installed=""
        latest="$(deps_latest_git_tag "$NVM_REPO_URL")"
        if [ -n "$latest" ]; then
            if deps_is_newer "$latest" "$NVM_VERSION"; then status="outdated"; else status="ok"; fi
        fi
        if [ "$MODE_LOCAL" -eq 1 ]; then
            installed="$(deps_installed_nvm_version)"
            if [ -n "$installed" ] && deps_is_newer "$NVM_VERSION" "$installed"; then
                status="drift"
            fi
        fi
        [ -n "$installed" ] || installed="-"
        t1_row nvm "$NVM_VERSION" "$latest" "$installed" "$status"
    fi

    # nerd font: release pin. Installed fonts carry no detectable version, so
    # the local check is presence-only: absent = drift, present = ok (to
    # upgrade an existing font, re-run scripts/nerd-font-download.sh).
    status="unknown"; latest=""; installed=""
    latest="$(deps_latest_github_release "$NF_REPO")"
    if [ -n "$latest" ]; then
        if deps_is_newer "$latest" "$NF_VERSION"; then status="outdated"; else status="ok"; fi
    fi
    if [ "$MODE_LOCAL" -eq 1 ]; then
        if deps_font_present; then installed="present"; else installed="absent"; status="drift"; fi
    fi
    [ -n "$installed" ] || installed="-"
    t1_row nerd-font "$NF_VERSION" "$latest" "$installed" "$status"

    # shunit2: test-only pin (no local apply - test.sh fetches on demand)
    status="unknown"; latest=""
    latest="$(deps_latest_git_tag "$SHUNIT2_REPO_URL")"
    if [ -n "$latest" ]; then
        if deps_is_newer "$latest" "$SHUNIT2_VERSION"; then status="outdated"; else status="ok"; fi
    fi
    t1_row shunit2 "$SHUNIT2_VERSION" "$latest" "-" "$status"
}

check_t2() {
    local pair name dir url installed latest status pkg

    # fzf / autoenv: floating git checkouts vs upstream HEAD (linux/osx only)
    if [ "$DEPS_IS_WINDOWS" -eq 0 ]; then
        for pair in "fzf:$HOME/.fzf" "autoenv:$HOME/.autoenv"; do
        name="${pair%%:*}"
        dir="${pair#*:}"
        case "$name" in
            fzf)     url="$FZF_REPO_URL" ;;
            autoenv) url="$AUTOENV_REPO_URL" ;;
        esac
        status="unknown"; installed=""; latest=""
        [ -d "$dir/.git" ] && installed="$(git -C "$dir" rev-parse HEAD 2>/dev/null)"
        latest="$(deps_latest_git_sha "$url")"
        if [ -n "$latest" ]; then
            if [ -z "$installed" ]; then
                status="missing"
                # a distro fzf with working shell bindings needs no checkout
                if [ "$name" = "fzf" ] && deps_fzf_has_bindings fzf; then
                    status="ok"
                fi
            elif deps_sha_matches "$latest" "$installed"; then
                status="ok"
            else
                status="behind"
            fi
        fi
        t2_row "$name" "${installed:0:7}" "${latest:0:7}" "$status"
        done
    fi

    # npm globals: installed -g version vs the registry
    if [ "$MODE_LOCAL" -eq 1 ]; then
        for pkg in "${NPM_PACKAGES[@]}"; do
            installed="$(deps_npm_installed_version "$pkg")"
            latest="$(deps_npm_latest_version "$pkg")"
            if [ -n "$latest" ]; then
                if [ -z "$installed" ]; then status="missing"
                elif deps_is_newer "$latest" "$installed"; then status="behind"
                else status="ok"; fi
            else
                status="unknown"
            fi
            [ -n "$installed" ] || installed="-"
            t2_row "$pkg" "$installed" "$latest" "$status"
        done
    else
        # CI/default mode has no machine state: report the latest as info
        for pkg in "${NPM_PACKAGES[@]}"; do
            latest="$(deps_npm_latest_version "$pkg")"
            [ -n "$latest" ] || latest="-"
            t2_row "$pkg" "-" "$latest" "info"
        done
    fi
}

check_os() {
    local line name installed candidate
    # apt uses its cached package lists: no sudo, no network, no update run
    if command -v apt-get >/dev/null 2>&1 && command -v dpkg-query >/dev/null 2>&1; then
        while IFS=$'\t' read -r name installed candidate; do
            [ -n "$name" ] || continue
            case " ${OS_PKGS_UBUNTU[*]} " in
                *" $name "*) os_row "$name" "$installed" "$candidate" ;;
            esac
        done <<EOF
$(apt list --upgradable 2>/dev/null | deps_parse_apt_upgradable)
EOF
    fi
    if command -v brew >/dev/null 2>&1; then
        # HOMEBREW_NO_AUTO_UPDATE=1: brew outdated must not fetch (slow+noisy)
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            name="${line%% *}"
            case " ${OS_PKGS_BREW[*]} " in
                *" $name "*) os_row "$name" "?" "?" ;;
            esac
        done <<EOF
$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated 2>/dev/null)
EOF
    fi
    # the OS set is a single action (one apt/brew call), counted once
    if [ "${#OS_ROWS[@]}" -gt 0 ]; then
        UPDATES=$((UPDATES + 1))
    fi
    return 0
}

if [ "$MODE_OS" -eq 0 ]; then
    check_t1
    check_t2
fi
if [ "$MODE_LOCAL" -eq 1 ] || [ "$MODE_OS" -eq 1 ]; then
    check_os
fi

if [ "$MACHINE" -eq 1 ]; then
    for r in ${T1_ROWS[@]+"${T1_ROWS[@]}"}; do printf '%s\n' "$r"; done
    for r in ${T2_ROWS[@]+"${T2_ROWS[@]}"}; do printf '%s\n' "$r"; done
    for r in ${OS_ROWS[@]+"${OS_ROWS[@]}"}; do printf '%s\n' "$r"; done
else
    if [ "${#T1_ROWS[@]}" -gt 0 ]; then
        echo "== pinned dependencies (vs upstream)"
        printf '%-16s %-12s %-12s %-10s %s\n' "name" "pin" "latest" "local" "status"
        for r in "${T1_ROWS[@]}"; do
            IFS=$'\t' read -r _ name a b c status <<< "$r"
            printf '%-16s %-12s %-12s %-10s %s\n' "$name" "$a" "$b" "$c" "$status"
        done
    fi
    if [ "${#T2_ROWS[@]}" -gt 0 ]; then
        echo "== floating dependencies"
        printf '%-16s %-12s %-12s %-10s %s\n' "name" "installed" "latest" "-" "status"
        for r in "${T2_ROWS[@]}"; do
            IFS=$'\t' read -r _ name a b c status <<< "$r"
            printf '%-16s %-12s %-12s %-10s %s\n' "$name" "$a" "$b" "$c" "$status"
        done
    fi
    if [ "${#OS_ROWS[@]}" -gt 0 ]; then
        echo "== os packages (apt/brew)"
        printf '%-16s %-24s %-24s %-10s %s\n' "name" "installed" "candidate" "-" "status"
        for r in "${OS_ROWS[@]}"; do
            IFS=$'\t' read -r _ name a b c status <<< "$r"
            printf '%-16s %-24s %-24s %-10s %s\n' "$name" "$a" "$b" "$c" "$status"
        done
    fi
    if [ "$UPDATES" -eq 0 ]; then
        echo "(no updates found; unknown = upstream query failed, ignored)"
    else
        echo
        echo "local apply: dotfiles-update    repo pins: merge the weekly deps PR"
    fi
fi

if [ "$UPDATES" -gt 0 ]; then
    exit 10
fi
exit 0
