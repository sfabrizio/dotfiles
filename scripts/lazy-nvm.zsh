# lazy nvm loader (sourced from zshrc; plain POSIX-compatible so shunit2 can
# test it under bash).
#
# Why: sourcing nvm.sh costs ~350ms on EVERY shell start (zprof: nvm_auto +
# version scan) - by far the biggest item in the startup profile. These
# wrappers defer that cost to the first node-family command; the load also
# runs nvm_auto, so the default node version lands on PATH exactly like the
# old eager `source nvm.sh` did, just later and only once per shell.
#
# npm-global binaries not in the wrapper list (tgit, diff-so-fancy, ...) are
# caught by command_not_found_handler in zshrc: they live under
# $NVM_DIR/versions/node/*/bin.

: "${NVM_DIR:=$HOME/.nvm}"
export NVM_DIR

_lazy_nvm_load() {
    [ -n "${_NVM_LAZY_LOADED:-}" ] && return 0
    _NVM_LAZY_LOADED=1
    # drop the wrappers (keep _lazy_nvm_load: command_not_found_handler and
    # repeat calls rely on it staying defined); real nvm.sh then defines nvm
    unset -f nvm node npm npx yarn pnpm
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    # lazy autoenv (scripts/lazy-autoenv.zsh): a shell that never cd'd still
    # needs its start dir's .env nvm auto-switch when the first node-family
    # command fires - load autoenv now; its source-time cd self-activates
    if [ -n "${_AUTOENV_LAZY_PENDING:-}" ] && [ -f "$HOME/.autoenv/activate.sh" ]; then
        . "$HOME/.autoenv/activate.sh"
        unset _AUTOENV_LAZY_PENDING
    fi
}

# only wrap when nvm is actually installed; if a system node exists instead,
# the wrappers are still correct: the first call loads nvm and nvm_auto
# prepends the nvm default, matching the old eager behavior
if [ -s "$NVM_DIR/nvm.sh" ]; then
    nvm()  { _lazy_nvm_load; nvm "$@"; }
    node() { _lazy_nvm_load; node "$@"; }
    npm()  { _lazy_nvm_load; npm "$@"; }
    npx()  { _lazy_nvm_load; npx "$@"; }
    yarn() { _lazy_nvm_load; yarn "$@"; }
    pnpm() { _lazy_nvm_load; pnpm "$@"; }
fi
