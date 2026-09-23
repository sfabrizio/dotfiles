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
#
# Recursion contract (proven bug, macOS): every wrapper unsets ITSELF before
# dispatching, and a re-source never redefines wrappers once the load marker
# is set. `omz reload` / `source ~/.zshrc` used to overwrite the REAL nvm
# function with a fresh wrapper while the marker was set; the wrapper then
# re-dispatched into itself -> infinite recursion. With both guards the
# re-dispatch can only ever reach real nvm.sh's function (or, when nvm.sh
# never loaded, a clean command-not-found - never the wrapper).

: "${NVM_DIR:=$HOME/.nvm}"
export NVM_DIR

_lazy_nvm_load() {
    [ -n "${_NVM_LAZY_LOADED:-}" ] && return 0
    _NVM_LAZY_LOADED=1
    # drop the remaining wrappers (each wrapper already unset itself before
    # calling here; 2>/dev/null: zsh errors on names that are already gone).
    # Keep _lazy_nvm_load: command_not_found_handler and repeat calls rely on
    # it staying defined; real nvm.sh then defines nvm.
    unset -f nvm node npm npx yarn pnpm 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    # lazy autoenv (scripts/lazy-autoenv.zsh): a shell that never cd'd still
    # needs its start dir's .env nvm auto-switch when the first node-family
    # command fires - load autoenv now; its source-time cd self-activates
    if [ -n "${_AUTOENV_LAZY_PENDING:-}" ] && [ -f "$HOME/.autoenv/activate.sh" ]; then
        . "$HOME/.autoenv/activate.sh"
        unset _AUTOENV_LAZY_PENDING
    fi
}

# only wrap when nvm is actually installed AND not loaded yet: re-sourcing
# (omz reload) after a load must leave the real nvm function in place, not
# shadow it with fresh wrappers; if a system node exists instead, the
# wrappers are still correct: the first call loads nvm and nvm_auto
# prepends the nvm default, matching the old eager behavior
if [ -s "$NVM_DIR/nvm.sh" ] && [ -z "${_NVM_LAZY_LOADED:-}" ]; then
    nvm()  { unset -f nvm;  _lazy_nvm_load; nvm "$@"; }
    node() { unset -f node; _lazy_nvm_load; node "$@"; }
    npm()  { unset -f npm;  _lazy_nvm_load; npm "$@"; }
    npx()  { unset -f npx;  _lazy_nvm_load; npx "$@"; }
    yarn() { unset -f yarn; _lazy_nvm_load; yarn "$@"; }
    pnpm() { unset -f pnpm; _lazy_nvm_load; pnpm "$@"; }
fi
