#!/usr/bin/env bash
# Shared helpers for the dependency tooling (deps-check.sh, deps-apply.sh,
# install.sh, install-pi.sh, doctor.sh). Library only: defines functions, no
# top-level code beyond sourcing semver.sh.
#
# Contract for every network probe: timeout-guarded, returns EMPTY output on
# failure - callers must treat empty as "unknown", never as an error. A flaky
# upstream must never fail a shell startup, the doctor, or CI.

DEPS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/semver.sh
. "$DEPS_LIB_DIR/semver.sh"

# --- network guard ---------------------------------------------------------------------
deps_net() {
    # prefix a command with timeout(1) when available so a hanging network
    # never stalls the check (same pattern as auto-update.sh)
    if command -v timeout >/dev/null 2>&1; then
        timeout 20 "$@"
    else
        "$@"
    fi
}

# --- compare helpers ----------------------------------------------------------------------
deps_norm_version() { printf '%s' "${1#v}"; }

deps_is_newer() {
    # 0 when $1 (latest) is strictly newer than $2 (current); version strings,
    # leading "v" tolerated
    [ -n "${1:-}" ] && [ -n "${2:-}" ] || return 1
    [ "$(deps_norm_version "$1")" != "$(deps_norm_version "$2")" ] || return 1
    [ "$(checkIsLowerVerion "$(deps_norm_version "$2")" "$(deps_norm_version "$1")")" = "true" ]
}

deps_sha_matches() {
    # 0 when $1 (a full sha) equals or starts with $2 (a pin that may be a
    # short sha)
    case "${1:-}" in
        "${2:-}"|"${2:-}"*) return 0 ;;
    esac
    return 1
}

deps_max_version() {
    # stdin: one version per line -> stdout: the highest (v-prefix tolerated)
    local max="" v
    while IFS= read -r v; do
        [ -n "$v" ] || continue
        if [ -z "$max" ] \
            || [ "$(checkIsLowerVerion "$(deps_norm_version "$max")" "$(deps_norm_version "$v")")" = "true" ]; then
            max="$v"
        fi
    done
    printf '%s\n' "$max"
}

# --- upstream queries -----------------------------------------------------------------------
deps_latest_git_sha() {
    deps_net git ls-remote "$1" HEAD 2>/dev/null | cut -f1 | head -1
}

deps_latest_git_tag() {
    deps_net git ls-remote --tags --refs "$1" 2>/dev/null \
        | awk -F/ '{print $NF}' \
        | grep -E '^v?[0-9]+(\.[0-9]+)+$' \
        | deps_max_version
}

deps_latest_github_release() {
    # $1 = owner/repo -> tag_name of the latest release (empty on any failure)
    command -v curl >/dev/null 2>&1 || return 1
    local auth=()
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth=(-H "Authorization: token ${GITHUB_TOKEN}")
    fi
    deps_net curl -fsSL --max-time 20 ${auth[@]+"${auth[@]}"} \
        "${GH_API_BASE}/repos/$1/releases/latest" 2>/dev/null \
        | grep -m1 '"tag_name"' | cut -d'"' -f4
}

deps_url_exists() {
    # HEAD request -> 0 when the URL is reachable (release assets redirect
    # 302 -> 200; both count). A 404 here means that OS's artifact is missing.
    local url="$1" code
    command -v curl >/dev/null 2>&1 || return 1
    code="$(deps_net curl -sIL -o /dev/null -w '%{http_code}' --max-time 20 "$url" 2>/dev/null)"
    case "$code" in
        200|301|302) return 0 ;;
    esac
    return 1
}

deps_artifacts_exist() {
    # $1 = dep name, $2 = candidate version. Verifies the release has an
    # artifact for EVERY OS the pin serves, before a bump is offered - one
    # pin is one version for linux/osx/windows, so upstream shipping an
    # incomplete release set must not enter deps-versions.sh.
    # (Only binary/font releases need this: git tags and npm tarballs are
    # OS-agnostic by nature.)
    case "$1" in
        zoxide)
            local v="${2#v}" base t
            base="https://github.com/ajeetdsouza/zoxide/releases/download/v${v}/zoxide-${v}"
            for t in x86_64-unknown-linux-musl \
                     aarch64-unknown-linux-musl \
                     x86_64-apple-darwin \
                     aarch64-apple-darwin; do
                deps_url_exists "${base}-${t}.tar.gz" || return 1
            done
            ;;
        nerd-font)
            local v="$2"
            # linux/osx zip (the installer's default) must exist, plus the
            # windows TTF in either repo layout: upstream flattened
            # patched-fonts/<font>/Regular/ away in v3.3+ (trap 29)
            deps_url_exists "https://github.com/ryanoasis/nerd-fonts/releases/download/${v}/Hack.zip" || return 1
            if deps_url_exists "https://github.com/ryanoasis/nerd-fonts/raw/${v}/patched-fonts/Hack/Regular/HackNerdFontMono-Regular.ttf"; then
                return 0
            fi
            if deps_url_exists "https://github.com/ryanoasis/nerd-fonts/raw/${v}/patched-fonts/Hack/HackNerdFontMono-Regular.ttf"; then
                return 0
            fi
            return 1
            ;;
    esac
    return 0
}

# --- installed probes (local machine only) -----------------------------------------------------
deps_installed_zoxide_version() {
    local zbin
    zbin="$(command -v zoxide 2>/dev/null || printf '%s' "$HOME/.local/bin/zoxide")"
    [ -x "$zbin" ] || return 1
    "$zbin" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1
}

_DEPS_NVM_SOURCED=0
deps_installed_nvm_version() {
    [ -s "$HOME/.nvm/nvm.sh" ] || return 1
    if [ "$_DEPS_NVM_SOURCED" -eq 0 ]; then
        # source nvm.sh ourselves: the interactive lazy loader may not have
        # loaded it yet (AGENTS.md trap 18)
        . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
        _DEPS_NVM_SOURCED=1
    fi
    nvm --version 2>/dev/null
}

deps_installed_tmux_powerline_sha() {
    [ -d "$HOME/.tmux/tmux-powerline/.git" ] || return 1
    git -C "$HOME/.tmux/tmux-powerline" rev-parse HEAD 2>/dev/null
}

deps_font_present() {
    if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qiE 'nerd font'; then
        return 0
    fi
    case "$(uname -s)" in
        # macOS ships no fontconfig by default: check the user font dir it
        # installs into (nerd-font-download.sh's Darwin target) directly
        Darwin)
            compgen -G "$HOME/Library/Fonts/*NerdFont*" >/dev/null 2>&1 && return 0
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # git-bash LOCALAPPDATA is 'C:\...' (backslashes): globs treat
            # them as escape characters and never match - glob the POSIX
            # form ($HOME) first, then a cygpath-converted LOCALAPPDATA
            compgen -G "$HOME/AppData/Local/Microsoft/Windows/Fonts/*NerdFont*" >/dev/null 2>&1 && return 0
            local lad=""
            command -v cygpath >/dev/null 2>&1 && lad="$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null)"
            [ -n "$lad" ] && compgen -G "$lad/Microsoft/Windows/Fonts/*NerdFont*" >/dev/null 2>&1 && return 0
            ;;
    esac
    return 1
}

deps_npm_bin() {
    # resolve npm the way the interactive shell sees it: nvm's current node
    # first (the lazy loader keeps it off PATH until the first node-family
    # command - AGENTS.md trap 18 - and the dotfiles install their globals
    # through it), then PATH (CI runners' system npm)
    local nvm_sh="${NVM_DIR:-$HOME/.nvm}/nvm.sh" nnode ndir
    if [ -s "$nvm_sh" ]; then
        if [ "$_DEPS_NVM_SOURCED" -eq 0 ]; then
            . "$nvm_sh" >/dev/null 2>&1
            _DEPS_NVM_SOURCED=1
        fi
        nnode="$(nvm which current 2>/dev/null)"
        if [ -n "$nnode" ] && [ -x "$nnode" ]; then
            ndir="${nnode%/*}"
            if [ -x "$ndir/npm" ]; then
                printf '%s\n' "$ndir/npm"
                return 0
            fi
        fi
    fi
    if command -v npm >/dev/null 2>&1; then
        command -v npm
        return 0
    fi
    return 1
}

deps_npm_run() {
    # run npm with its own node dir on PATH (npm's shebang resolves `env node`)
    local nbin ndir
    nbin="$(deps_npm_bin)" || return 1
    ndir="${nbin%/*}"
    PATH="$ndir:$PATH" "$nbin" "$@"
}

deps_npm_installed_version() {
    # installed -g version of $1 (an "npm ls -g" tree line "pkg@1.2.3");
    # empty output / rc 1 = absent or npm unavailable
    local line
    line="$(deps_npm_run ls -g --depth=0 2>/dev/null | grep -F "$1@" | tail -1)"
    [ -n "$line" ] || return 1
    printf '%s\n' "${line##*@}"
}

deps_npm_latest_version() {
    deps_npm_run view "$1" version 2>/dev/null | tail -1
}

# --- OS package parsing ---------------------------------------------------------------------------
deps_parse_apt_upgradable() {
    # stdin: `apt list --upgradable` output
    # stdout: TSV name<TAB>installed<TAB>candidate (only real upgradable lines)
    local line name candidate installed
    while IFS= read -r line; do
        case "$line" in *"upgradable from:"*) ;; *) continue ;; esac
        name="${line%%/*}"
        [ -n "$name" ] || continue
        candidate="$(printf '%s\n' "$line" | awk '{print $2}')"
        installed="$(printf '%s\n' "$line" | sed -n 's/.*\[upgradable from: \([^]]*\)\]/\1/p')"
        [ -n "$installed" ] || installed="?"
        printf '%s\t%s\t%s\n' "$name" "$installed" "$candidate"
    done
}

# --- install / update commands (shared by install.sh, install-pi.sh, deps-apply.sh) ----------------
deps_install_zoxide() {
    local version="${ZOXIDE_VERSION#v}" target tmp
    case "$(uname -s)-$(uname -m)" in
        Darwin-arm64)              target="aarch64-apple-darwin" ;;
        Darwin-x86_64)             target="x86_64-apple-darwin" ;;
        Linux-aarch64|Linux-arm64) target="aarch64-unknown-linux-musl" ;;
        *)                         target="x86_64-unknown-linux-musl" ;;
    esac
    tmp="$(mktemp -d)" || return 1
    if ! curl -sSfL "https://github.com/ajeetdsouza/zoxide/releases/download/v${version}/zoxide-${version}-${target}.tar.gz" \
            | tar xz -C "$tmp"; then
        rm -rf "$tmp"
        return 1
    fi
    mkdir -p "$HOME/.local/bin"
    find "$tmp" -type f -name zoxide -exec cp {} "$HOME/.local/bin/" \; 2>/dev/null
    chmod +x "$HOME/.local/bin/zoxide" 2>/dev/null
    rm -rf "$tmp"
    [ -x "$HOME/.local/bin/zoxide" ]
}

deps_install_tmux_powerline() {
    # fresh clone at the pin, or checkout the pin in an existing clone
    # (the apply path for pin drift; never destroys a working clone)
    local dir="$HOME/.tmux/tmux-powerline"
    if [ -d "$dir/.git" ]; then
        git -C "$dir" fetch origin --quiet 2>/dev/null || return 1
        git -C "$dir" checkout --quiet "$TMUX_POWERLINE_PIN" 2>/dev/null
        return $?
    fi
    git clone -q "$TMUX_POWERLINE_REPO" "$dir" 2>/dev/null || return 1
    git -C "$dir" checkout --quiet "$TMUX_POWERLINE_PIN" 2>/dev/null
}

deps_install_nvm() {
    # download-then-run: unlike `curl | bash` this fails when the download
    # fails instead of silently running an empty script
    local tmp rc
    tmp="$(mktemp /tmp/nvm-install-XXXXXX.sh)" || return 1
    if ! curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" -o "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    bash "$tmp"
    rc=$?
    rm -f "$tmp"
    return "$rc"
}

deps_fzf_has_bindings() {
    local fzf_bin="${1:-fzf}"
    if [ -x "$fzf_bin" ] && "$fzf_bin" --zsh </dev/null 2>/dev/null | grep -q "fzf-history-widget"; then
        return 0
    fi
    [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] \
        || [ -f "$HOME/.local/share/fzf/examples/key-bindings.zsh" ]
}

deps_install_fzf() {
    # pull+rebuild an existing checkout, or clone+build+symlink a fresh one
    if [ -d "$HOME/.fzf/.git" ]; then
        git -C "$HOME/.fzf" pull --ff-only -q 2>/dev/null || return 1
    else
        git clone -q --depth 1 "$FZF_REPO_URL" "$HOME/.fzf" 2>/dev/null || return 1
    fi
    "$HOME/.fzf/install" --bin || return 1
    mkdir -p "$HOME/.local/bin" || return 1
    ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
}

deps_install_autoenv() {
    if [ -d "$HOME/.autoenv/.git" ]; then
        git -C "$HOME/.autoenv" pull --ff-only --quiet 2>/dev/null || return 1
    else
        git clone -q "$AUTOENV_REPO_URL" "$HOME/.autoenv" 2>/dev/null || return 1
    fi
    [ -f "$HOME/.autoenv/activate.sh" ]
}

deps_update_npm_package() {
    # single-package install: a blanket `npm install -g` re-resolves the whole
    # dep tree on every re-run (AGENTS.md trap 22)
    deps_npm_run install -g "$1"
}
