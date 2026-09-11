# lazy autoenv loader (sourced from zshrc; POSIX-compatible so shunit2 can
# test it under bash).
#
# Why: activate.sh self-activates when sourced - it runs `cd "${PWD}"`, which
# walks CWD up to / looking for .env files, sha1-hashes each one and evals
# authorized files (~34ms on every shell start, measured). Worse, project
# .env files can run node/nvm - which would pull the lazy nvm load back onto
# the startup critical path in project dirs (defeats scripts/lazy-nvm.zsh).
#
# Deferral: the first real `cd` loads autoenv (its source-time `cd $PWD`
# reproduces the eager startup activation of the start dir), then performs
# the requested cd through autoenv's own machinery. Shells that never cd
# still load it from the first node-family command via the pending-marker
# hook in scripts/lazy-nvm.zsh, so the start dir's .env nvm auto-switch
# still applies.

if [ -f "$HOME/.autoenv/activate.sh" ]; then
    _AUTOENV_LAZY_PENDING=1

    _autoenv_lazy_load() {
        unset -f _autoenv_lazy_load
        unset _AUTOENV_LAZY_PENDING
        # its own source-time `cd "${PWD}"` activates the current dir
        # shellcheck source=/dev/null
        . "$HOME/.autoenv/activate.sh"
    }

    cd() {
        unset -f cd
        _autoenv_lazy_load
        if command -v autoenv_cd >/dev/null 2>&1; then
            autoenv_cd "$@"          # activate.sh replaced cd() with this
        else
            builtin cd "$@"          # no shasum found -> autoenv disabled itself
        fi
    }
fi
