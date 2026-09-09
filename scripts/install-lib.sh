#!/usr/bin/env bash
# Shared helpers for the dotfiles installers (install.sh, install-pi.sh,
# install-windows.sh). Sourced AFTER the bash guard and `set -u`.
#
# Reliability contract:
#   - every mutating step goes through run()/write_config()/backup_configs()
#   - DOTFILES_INSTALL_DRY_RUN=1 prints actions without executing them
#   - failures are collected, reported in a summary, and reflected in exit code

DRY_RUN="${DOTFILES_INSTALL_DRY_RUN:-0}"
FAILURES=()
DONE_STEPS=()

say()  { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "    [warn] $*"; }
fail() { printf '%s\n' "    [FAIL] $*"; FAILURES+=("$*"); return 1; }

# run "<description>" <command...>
# Executes the command (or prints it in dry-run) and records failures.
run() {
    local desc="$1"
    shift
    printf '    %s\n' "$desc"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] %s\n' "$*"
        DONE_STEPS+=("$desc")
        return 0
    fi
    if "$@"; then
        DONE_STEPS+=("$desc")
        return 0
    fi
    FAILURES+=("$desc")
    warn "step failed: $desc"
    return 1
}

# write_config <dest> <single-line-content>
# Writes a one-line "source/include dotfiles" entrypoint. Idempotent: skips
# when the file already contains exactly that line. Existing files with other
# content are overwritten (a .bak backup is taken beforehand by the caller).
write_config() {
    local dest="$1" line="$2"
    if [ "$DRY_RUN" = "1" ]; then
        printf '    [dry-run] write %s\n' "$dest"
        return 0
    fi
    if [ -f "$dest" ] && grep -qxF "$line" "$dest"; then
        printf '    [skip] %s already wired to dotfiles\n' "$dest"
        return 0
    fi
    if printf '%s\n' "$line" > "$dest"; then
        printf '    [ok] wrote %s\n' "$dest"
    else
        fail "write $dest"
    fi
}

# backup_configs <file...>
# Copies each existing file to <file>.bak. Never overwrites an existing .bak,
# never errors when the source does not exist (fresh machine).
backup_configs() {
    local f
    for f in "$@"; do
        if [ -f "$f" ] && [ ! -f "$f.bak" ]; then
            run "backup $(basename "$f")" cp "$f" "$f.bak"
        fi
    done
}

# is_node: 0 when node/npm are usable
is_node() {
    command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}

# install_summary: print the outcome; non-zero exit on any failed step.
# Usage: at the very end of the installer: install_summary || exit 1
install_summary() {
    echo
    if [ "${#FAILURES[@]}" -gt 0 ]; then
        say "install finished WITH ERRORS (${#FAILURES[@]} failed step(s)):"
        local f
        for f in "${FAILURES[@]}"; do
            printf '  - %s\n' "$f"
        done
        printf 'Re-run the installer to retry; it is safe to run again.\n'
        return 1
    fi
    say "Everything Done. Open a new shell (or run: zsh) to load the new config."
    return 0
}
