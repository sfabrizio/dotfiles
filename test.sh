#!/usr/bin/env bash
# Test suite for the dotfiles scripts. Self-contained:
#   1. bash -n syntax check of every shell script in the repo
#   2. shellcheck pass when shellcheck is installed (informational)
#   3. shunit2 unit tests (fetched to /tmp on demand; skipped when offline)
#   4. install.sh integration dry-run (also exercises the sh->bash re-exec guard)
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
FAILED=0
SYNTAX_ERR="$(mktemp /tmp/dotfiles-syntax-XXXXXX)"
trap 'rm -f "$SYNTAX_ERR"' EXIT

echo "==> 1. bash -n syntax check"
SCRIPTS=()
for f in "$ROOT"/*.sh "$ROOT"/scripts/*.sh "$ROOT"/segments/*.sh; do
    [ -f "$f" ] && SCRIPTS+=("$f")
done
for s in "${SCRIPTS[@]}"; do
    if bash -n "$s" 2>"$SYNTAX_ERR"; then
        printf '  [ok]   %s\n' "${s#"$ROOT"/}"
    else
        printf '  [FAIL] %s\n%s\n' "${s#"$ROOT"/}" "$(cat "$SYNTAX_ERR")"
        FAILED=1
    fi
done

echo "==> 2. shellcheck (informational)"
if command -v shellcheck >/dev/null 2>&1; then
    for s in "${SCRIPTS[@]}"; do
        shellcheck -e SC1090,SC1091 "$s" && printf '  [ok]   %s\n' "${s#"$ROOT"/}" \
            || printf '  [warn] %s has shellcheck findings\n' "${s#"$ROOT"/}"
    done
else
    echo "  [skip] shellcheck not installed (apt install shellcheck)"
fi

echo "==> 3. shunit2 unit tests"
SHUNIT2="/tmp/shunit2-2.1.6/src/shunit2"
if [ ! -f "$SHUNIT2" ]; then
    echo "  fetching shunit2 to /tmp ..."
    mkdir -p /tmp/shunit2-extract
    for url in \
        "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/shunit2/shunit2-2.1.6.tgz" \
        "https://github.com/kward/shunit2/archive/refs/tags/v2.1.6.tar.gz"; do
        if curl -fsSL "$url" | tar zx -C /tmp/shunit2-extract 2>/dev/null; then
            # locate the single-file interpreter inside whatever layout the
            # archive uses, and expose it at the path the suite expects
            found="$(find /tmp/shunit2-extract -type f -name shunit2 | head -1)"
            if [ -n "$found" ]; then
                mkdir -p "$(dirname "$SHUNIT2")"
                cp "$found" "$SHUNIT2"
                break
            fi
        fi
        echo "  [warn] mirror failed: $url"
    done
    rm -rf /tmp/shunit2-extract
fi
if [ -f "$SHUNIT2" ]; then
    # run in a subshell: shunit2 exits the shell when done
    (
        # glyph tests rely on bash printf \u: without a UTF-8 locale (bare
        # containers) it emits the literal escape instead of the bytes.
        # Guarded: macOS has no C.UTF-8 locale - leave it alone there.
        if locale -a 2>/dev/null | grep -qi '^C.UTF-8$\|^C.utf8$'; then
            export LC_ALL=C.UTF-8
        fi
        # --- get_os_name -------------------------------------------------------
        . "$ROOT/scripts/get_os_name.sh"
        test_get_os_name_returns_known_value() {
            local result
            result="$(get_os_name)"
            assertTrue "got '$result'" "[[ \"\$result\" =~ ^(osx|windows|raspy|linux|linux\ fedora|linux\ ubuntu|unknown)$ ]]"
        }
        # --- semver ----------------------------------------------------------------
        . "$ROOT/scripts/semver.sh"
        test_semver_patch_carry() {
            # regression: 1.2.9 IS lower than 1.2.10 (old code only compared minor)
            assertEquals "true"  "$(checkIsLowerVerion 1.2.9  1.2.10)"
            assertEquals "false" "$(checkIsLowerVerion 1.2.10 1.2.9)"
        }
        test_semver_basic() {
            assertEquals "true"  "$(checkIsLowerVerion 1.2.3  1.2.4)"
            assertEquals "false" "$(checkIsLowerVerion 1.2.4  1.2.3)"
            assertEquals "false" "$(checkIsLowerVerion 1.2.3  1.2.3)"
            assertEquals "true"  "$(checkIsLowerVerion 1.9.0  2.0.0)"
            assertEquals "false" "$(checkIsLowerVerion 1.10.0 1.9.0)"
            assertEquals "true"  "$(checkIsLowerVerion v0.12.0 v1.15.5)"
        }
        test_semver_does_not_exit_caller() {
            # regression: the old function called `exit 0` inside the test shell
            assertEquals "false" "$(checkIsLowerVerion 2.0.0 1.0.0)"
        }
        # --- install-lib ---------------------------------------------------------------
        # NB: shunit2 defines its own fail() - simulate lib failures by
        # appending to FAILURES directly.
        DOTFILES_INSTALL_DRY_RUN=1 . "$ROOT/scripts/install-lib.sh"
        test_run_dry_run_never_executes() {
            FAILURES=()
            run "probe" /bin/false   # would fail if actually executed
            assertEquals 0 "$?"
            assertEquals 0 "${#FAILURES[@]}"
        }
        test_fail_records_and_summary_reflects() {
            FAILURES=("simulated step")
            install_summary >/dev/null 2>&1
            assertEquals 1 "$?"
            FAILURES=()
            install_summary >/dev/null 2>&1
            assertEquals 0 "$?"
        }
        # --- install-lib write_file_once (WT fragments / ~/.local overrides) ---------
        # NB: no top-level re-source here - it would clobber DRY_RUN=1 for
        # test_run_dry_run_never_executes above (definitions run before tests).
        # Each test sets DRY_RUN itself; tests run after the DRY_RUN=1 ones.
        WF_FIX=""
        wf_setup() { WF_FIX="$(mktemp -d)"; FAILURES=(); DRY_RUN=0; }
        test_write_file_once_creates_missing_file() {
            wf_setup
            write_file_once "$WF_FIX/frag.json" '{"profiles":[]}'
            assertEquals 0 "$?"
            assertEquals '{"profiles":[]}' "$(cat "$WF_FIX/frag.json")"
            assertEquals 0 "${#FAILURES[@]}"
            rm -rf "$WF_FIX"
        }
        test_write_file_once_never_overwrites_existing() {
            wf_setup
            printf 'original\n' > "$WF_FIX/frag.json"
            write_file_once "$WF_FIX/frag.json" 'new content'
            assertEquals 0 "$?"
            assertEquals "original" "$(cat "$WF_FIX/frag.json")"
            out="$(write_file_once "$WF_FIX/frag.json" 'x' 2>&1)"
            assertTrue "skip message" "echo \"\$out\" | grep -q '\[skip\]'"
            rm -rf "$WF_FIX"
        }
        test_write_file_once_dry_run_never_writes() {
            wf_setup
            DRY_RUN=1
            out="$(write_file_once "$WF_FIX/frag.json" 'must not exist' 2>&1)"
            assertEquals 0 "$?"
            assertTrue "dry-run message" "echo \"\$out\" | grep -q '\[dry-run\]'"
            assertFalse "no file written" "[ -e '$WF_FIX/frag.json' ]"
            DRY_RUN=0
            rm -rf "$WF_FIX"
        }
        test_write_file_once_records_write_failure() {
            # fail() recording must be verified WITHOUT shunit2 in scope: shunit2
            # shadows install-lib's fail() (see NB above) - use a clean subprocess
            wf_setup
            out="$(DOTFILES_INSTALL_DRY_RUN=0 bash -c \
                ". '$ROOT/scripts/install-lib.sh'
                  write_file_once '$WF_FIX/nope/frag.json' 'x' 2>/dev/null
                  echo rc=\$?
                  echo failures=\${#FAILURES[@]}" 2>&1)"
            assertTrue "non-zero rc on write error" "echo \"\$out\" | grep -q 'rc=1'"
            assertTrue "failure recorded in FAILURES" "echo \"\$out\" | grep -q 'failures=1'"
            assertFalse "no file created" "[ -e '$WF_FIX/nope/frag.json' ]"
            rm -rf "$WF_FIX"
        }
        # --- install-lib write_file (dotfiles-owned files, e.g. the WT fragment) -----
        test_write_file_creates_and_updates() {
            wf_setup
            write_file "$WF_FIX/frag.json" 'v1'
            assertEquals 0 "$?"
            assertEquals 'v1' "$(cat "$WF_FIX/frag.json")"
            out="$(write_file "$WF_FIX/frag.json" 'v2' 2>&1)"
            assertEquals 0 "$?"
            assertEquals 'v2' "$(cat "$WF_FIX/frag.json")"   # owned files ship updates
            assertTrue "update message" "echo \"\$out\" | grep -q '\[ok\]'"
            rm -rf "$WF_FIX"
        }
        test_write_file_skips_identical_content() {
            wf_setup
            write_file "$WF_FIX/frag.json" 'same'
            out="$(write_file "$WF_FIX/frag.json" 'same' 2>&1)"
            assertEquals 0 "$?"
            assertTrue "skip message" "echo \"\$out\" | grep -q '\[skip\]'"
            assertEquals "same" "$(cat "$WF_FIX/frag.json")"
            rm -rf "$WF_FIX"
        }
        # --- auto-update ------------------------------------------------------------
        test_autoupdate_disabled_short_circuits() {
            # no fake repo needed: the disable flag exits before any git check
            TH="$(mktemp -d)"
            DOTFILES_DISABLE_AUTO_UPDATE=1 HOME="$TH" bash "$ROOT/scripts/auto-update.sh"
            assertEquals 0 "$?"
            rm -rf "$TH"
        }
        test_autoupdate_interval_gate() {
            # a fresh epoch file means the interval gate exits before touching git
            TH="$(mktemp -d)"
            mkdir -p "$TH/.cache/dotfiles"
            date +%s > "$TH/.cache/dotfiles/last-update"
            HOME="$TH" DOTFILES_DISABLE_AUTO_UPDATE=0 bash "$ROOT/scripts/auto-update.sh"
            assertEquals 0 "$?"
            # a stale epoch with no git repo also exits 0 (guards, not crashes)
            echo 0 > "$TH/.cache/dotfiles/last-update"
            HOME="$TH" bash "$ROOT/scripts/auto-update.sh"
            assertEquals 0 "$?"
            rm -rf "$TH"
        }

        # fixture-based auto-update tests: a local bare "origin" + an upstream
        # clone make "behind/up-to-date/diverged" states testable fully offline
        AU_FIX=""
        au_setup() {
            AU_FIX="$(mktemp -d)"
            git init -q --bare -b develop "$AU_FIX/origin.git"
            mkdir -p "$AU_FIX/home"
            git clone -q "$AU_FIX/origin.git" "$AU_FIX/home/dotfiles" 2>/dev/null
            git -C "$AU_FIX/home/dotfiles" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed
            git -C "$AU_FIX/home/dotfiles" push -q -u origin develop 2>/dev/null
            git clone -q "$AU_FIX/origin.git" "$AU_FIX/upstream"
        }
        au_teardown() { [ -n "$AU_FIX" ] && rm -rf "$AU_FIX"; }
        au_new_upstream_commit() {
            git -C "$AU_FIX/upstream" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "upstream $1"
            git -C "$AU_FIX/upstream" push -q origin develop 2>/dev/null
        }
        au_run() {
            # run the updater against the fixture home; stdout+stderr captured.
            # deps-apply follow-up off (it would probe real upstreams - fixture
            # tests below) and the tty prompt read disabled (deterministic runs
            # from interactive terminals too)
            HOME="$AU_FIX/home" DOTFILES_DEPS_APPLY=0 DOTFILES_DEPS_TTY=0 \
                bash "$ROOT/scripts/auto-update.sh" "$@" 2>&1
        }
        au_head() { git -C "$AU_FIX/home/dotfiles" rev-parse --short HEAD; }
        au_origin() { git -C "$AU_FIX/home/dotfiles" rev-parse --short origin/develop; }

        test_autoupdate_up_to_date_is_silent() {
            au_setup
            out="$(au_run)"
            assertEquals 0 "$?"
            assertEquals "" "$out"
            # epoch was written by the check
            assertTrue "epoch missing" "[ -s '$AU_FIX/home/.cache/dotfiles/last-update' ]"
            au_teardown
        }
        test_autoupdate_reminder_reports_without_updating() {
            au_setup
            au_new_upstream_commit one
            au_new_upstream_commit two
            before="$(au_head)"
            out="$(HOME="$AU_FIX/home" DOTFILES_UPDATE_MODE=reminder bash "$ROOT/scripts/auto-update.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "no reminder" "echo \"\$out\" | grep -q \"2 update(s) available - run 'dotfiles-update'\""
            assertEquals "$before" "$(au_head)"   # HEAD did not move
            au_teardown
        }
        test_autoupdate_auto_pulls_and_reports() {
            au_setup
            au_new_upstream_commit one
            au_new_upstream_commit two
            out="$(HOME="$AU_FIX/home" DOTFILES_UPDATE_MODE=auto bash "$ROOT/scripts/auto-update.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "no updated line" "echo \"\$out\" | grep -q 'updated (2 new commit(s))'"
            assertTrue "shortlog missing" "echo \"\$out\" | grep -q 'upstream one'"
            assertEquals "$(au_origin)" "$(au_head)"   # HEAD moved to origin
            au_teardown
        }
        test_autoupdate_prompt_without_tty_skips_cleanly() {
            au_setup
            au_new_upstream_commit one
            before="$(au_head)"
            # </dev/null: no tty for the Y/n read -> must skip without updating
            out="$(au_run </dev/null)"
            assertEquals 0 "$?"
            assertEquals "$before" "$(au_head)"
            au_teardown
        }
        test_autoupdate_force_updates_even_with_fresh_epoch() {
            au_setup
            au_run                                   # records a fresh epoch
            au_new_upstream_commit later
            out="$(au_run --force)"                  # interval gate bypassed
            assertEquals 0 "$?"
            assertTrue "no update" "echo \"\$out\" | grep -q 'updated (1 new commit(s))'"
            assertEquals "$(au_origin)" "$(au_head)"
            au_teardown
        }
        test_autoupdate_diverged_clone_is_left_alone() {
            au_setup
            git -C "$AU_FIX/home/dotfiles" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "local diverged"
            au_new_upstream_commit one
            out="$(HOME="$AU_FIX/home" DOTFILES_UPDATE_MODE=auto bash "$ROOT/scripts/auto-update.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "no skip warning" "echo \"\$out\" | grep -q 'update skipped'"
            assertTrue "local commit preserved" "git -C '$AU_FIX/home/dotfiles' log --format=%s -1 | grep -q 'local diverged'"
            au_teardown
        }
        test_autoupdate_disabled_mode_never_updates() {
            au_setup
            au_new_upstream_commit one
            before="$(au_head)"
            out="$(HOME="$AU_FIX/home" DOTFILES_UPDATE_MODE=disabled bash "$ROOT/scripts/auto-update.sh" 2>&1)"
            assertEquals 0 "$?"
            assertEquals "" "$out"
            assertEquals "$before" "$(au_head)"
            au_teardown
        }
        test_autoupdate_detached_head_is_ignored() {
            au_setup
            git -C "$AU_FIX/home/dotfiles" checkout -q --detach HEAD
            out="$(au_run)"
            assertEquals 0 "$?"
            assertEquals "" "$out"
            au_teardown
        }
        # --- lazy-nvm ----------------------------------------------------------------
        test_lazy_nvm_wrappers_forward_to_real_nvm() {
            # stub nvm.sh defines the real nvm; the wrapper must unset itself,
            # source it and forward the args
            TH="$(mktemp -d)"
            mkdir -p "$TH/.nvm"
            cat > "$TH/.nvm/nvm.sh" <<'EOS'
nvm() { printf 'real-nvm %s\n' "$*"; }
EOS
            out="$(NVM_DIR="$TH/.nvm" bash -c ". '$ROOT/scripts/lazy-nvm.zsh'; nvm use 22" 2>&1)"
            assertEquals 0 "$?"
            assertEquals "real-nvm use 22" "$out"
            rm -rf "$TH"
        }
        test_lazy_nvm_node_wrapper_resolves_path_binary() {
            # after the (empty) load, node must come from PATH - i.e. the
            # wrapper really got out of the way
            TH="$(mktemp -d)"
            mkdir -p "$TH/.nvm" "$TH/bin"
            : > "$TH/.nvm/nvm.sh"
            printf '#!/bin/sh\necho fake-node\n' > "$TH/bin/node"
            chmod +x "$TH/bin/node"
            out="$(NVM_DIR="$TH/.nvm" PATH="$TH/bin:/usr/bin:/bin" bash -c ". '$ROOT/scripts/lazy-nvm.zsh'; node --version" 2>&1)"
            assertEquals 0 "$?"
            assertEquals "fake-node" "$out"
            rm -rf "$TH"
        }
        test_lazy_nvm_skipped_without_nvm() {
            # no nvm.sh -> no wrappers at all (system node stays untouched)
            TH="$(mktemp -d)"
            out="$(NVM_DIR="$TH/absent" bash -c ". '$ROOT/scripts/lazy-nvm.zsh'; declare -F nvm node npm" 2>&1)"
            assertEquals "" "$out"
            rm -rf "$TH"
        }
        test_lazy_nvm_loads_nvm_sh_once() {
            # the load marker must make repeat loads (e.g. from the not-found
            # handler) a no-op
            TH="$(mktemp -d)"
            mkdir -p "$TH/.nvm"
            cat > "$TH/.nvm/nvm.sh" <<EOS
echo sourced >> '$TH/log'
nvm() { :; }
EOS
            NVM_DIR="$TH/.nvm" bash -c ". '$ROOT/scripts/lazy-nvm.zsh'; _lazy_nvm_load; _lazy_nvm_load; nvm" >/dev/null 2>&1
            assertEquals 0 "$?"
            assertEquals "1" "$(wc -l < "$TH/log" 2>/dev/null | tr -d ' ')"
            rm -rf "$TH"
        }
        test_lazy_nvm_triggers_pending_autoenv() {
            # a shell that never cd'd still gets its start dir's .env nvm
            # auto-switch: the pending marker makes the first node-family
            # command load autoenv (its source-time cd self-activates)
            TH="$(mktemp -d)"
            mkdir -p "$TH/.nvm" "$TH/.autoenv"
            cat > "$TH/.nvm/nvm.sh" <<'EOS'
nvm() { :; }
EOS
            printf 'touch "$HOME/autoenv-loaded"\n' > "$TH/.autoenv/activate.sh"
            NVM_DIR="$TH/.nvm" HOME="$TH" bash -c "
                . '$ROOT/scripts/lazy-nvm.zsh'
                _AUTOENV_LAZY_PENDING=1
                node --version
            " >/dev/null 2>&1
            assertTrue "autoenv loaded by the nvm hook" "[ -f '$TH/autoenv-loaded' ]"
            rm -rf "$TH"
        }
        # --- lazy-autoenv --------------------------------------------------------------
        test_lazy_autoenv_cd_defers_and_loads() {
            # stub activate.sh mimicking enable_autoenv: defines autoenv_cd and
            # replaces cd with it; the wrapper must defer the load to the first cd
            TH="$(mktemp -d)"
            mkdir -p "$TH/.autoenv"
            cat > "$TH/.autoenv/activate.sh" <<'EOS'
autoenv_cd() { printf 'autoenv-cd %s\n' "$*"; }
cd() { autoenv_cd "$@"; }
EOS
            out="$(HOME="$TH" bash -c "
                . '$ROOT/scripts/lazy-autoenv.zsh'
                [ -n \"\${_AUTOENV_LAZY_PENDING:-}\" ] || echo 'loaded-too-early'
                cd /tmp >/dev/null
                [ -z \"\${_AUTOENV_LAZY_PENDING:-}\" ] && command -v autoenv_cd >/dev/null && echo loaded
            " 2>&1)"
            assertEquals "loaded" "$out"
            rm -rf "$TH"
        }
        test_lazy_autoenv_cd_works_without_backend() {
            # activate.sh that disables itself (no shasum) -> the wrapper must
            # still perform the cd via the builtin
            TH="$(mktemp -d)"
            mkdir -p "$TH/.autoenv" "$TH/adir"
            : > "$TH/.autoenv/activate.sh"
            out="$(HOME="$TH" bash -c "
                . '$ROOT/scripts/lazy-autoenv.zsh'
                cd '$TH/adir' 2>/dev/null
                pwd
            " 2>&1)"
            assertEquals "$TH/adir" "$out"
            rm -rf "$TH"
        }
        test_lazy_autoenv_skipped_without_activate_sh() {
            TH="$(mktemp -d)"
            out="$(HOME="$TH" bash -c ". '$ROOT/scripts/lazy-autoenv.zsh'; declare -F cd" 2>&1)"
            assertEquals "" "$out"
            rm -rf "$TH"
        }
        # --- doctor -----------------------------------------------------------------
        test_doctor_fails_on_broken_home() {
            # empty home: no repo, no wiring -> FAILs -> exit 1
            TH="$(mktemp -d)"
            HOME="$TH" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
            assertEquals 1 "$?"
            rm -rf "$TH"
        }
        test_doctor_warnings_do_not_fail_exit() {
            # fixture repo (no tmux-powerline, no CI guarantee) + wiring files:
            # everything broken-tier present, everything else only warns -> exit 0
            au_setup
            printf '[include] path = ~/dotfiles/gitconfig\n' > "$AU_FIX/home/.gitconfig"
            printf 'source ~/dotfiles/vimrc\n' > "$AU_FIX/home/.vimrc"
            printf 'source ~/dotfiles/zshrc\n' > "$AU_FIX/home/.zshrc"
            printf 'source ~/dotfiles/tmux.conf\n' > "$AU_FIX/home/.tmux.conf"
            printf 'source ~/dotfiles/tmux-powerlinerc\n' > "$AU_FIX/home/.tmux-powerlinerc"
            HOME="$AU_FIX/home" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
            assertEquals 0 "$?"
            au_teardown
        }
        test_doctor_flags_old_versions_and_offers_fix() {
            # fake old toolchain shadows the real one on PATH: the doctor must
            # warn about each version problem AND print a fix: hint; warnings
            # never change the exit code
            au_setup
            printf '[include] path = ~/dotfiles/gitconfig\n' > "$AU_FIX/home/.gitconfig"
            printf 'source ~/dotfiles/zshrc\n' > "$AU_FIX/home/.zshrc"
            printf 'source ~/dotfiles/vimrc\n' > "$AU_FIX/home/.vimrc"
            printf 'source ~/dotfiles/tmux.conf\n' > "$AU_FIX/home/.tmux.conf"
            printf 'source ~/dotfiles/tmux-powerlinerc\n' > "$AU_FIX/home/.tmux-powerlinerc"
            FAKEBIN="$(mktemp -d)"
            printf '#!/bin/sh\necho v14.21.3\n' > "$FAKEBIN/node"
            printf '#!/bin/sh\necho 1.0.0\n' > "$FAKEBIN/npm"
            printf '#!/bin/sh\necho "tmux 3.2a"\n' > "$FAKEBIN/tmux"
            printf '#!/bin/sh\necho "0.44.1 (debian)"\n' > "$FAKEBIN/fzf"
            chmod +x "$FAKEBIN"/*
            out="$(HOME="$AU_FIX/home" PATH="$FAKEBIN:$PATH" NVM_DIR="$AU_FIX/home/.nvm-absent" bash "$ROOT/scripts/doctor.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "node version warning" "echo \"\$out\" | grep -q 'node v14.21.3 is old'"
            assertTrue "tmux version warning" "echo \"\$out\" | grep -q 'tmux 3.2a < 3.3.0'"
            assertTrue "fzf bindings warning" "echo \"\$out\" | grep -q 'fzf is too old for --zsh'"
            assertTrue "turbo-git missing warning" "echo \"\$out\" | grep -q 'npm global missing: turbo-git'"
            assertTrue "fix hints offered" "echo \"\$out\" | grep -q 'fix:'"
            assertTrue "recap lists warnings before the verdict" "echo \"\$out\" | grep -q '== warnings'"
            rm -rf "$FAKEBIN"
            au_teardown
        }
        # --- nerd-font-download -------------------------------------------------------
        test_nerdfont_idempotent_skip() {
            # a Hack font file already in the font dir -> skip without network
            TH="$(mktemp -d)"
            mkdir -p "$TH/.local/share/fonts"
            printf 'fake' > "$TH/.local/share/fonts/HackNerdFont-Regular.ttf"
            out="$(HOME="$TH" bash "$ROOT/scripts/nerd-font-download.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "skip message" "echo \"\$out\" | grep -q 'already installed'"
            assertEquals 1 "$(ls -1 "$TH/.local/share/fonts" | wc -l)"   # nothing new installed
            rm -rf "$TH"
        }
        test_nerdfont_missing_curl_fails_cleanly() {
            # no curl on PATH and no font installed -> clean error, exit 1
            # (absolute bash: the interpreter must be found with PATH broken)
            TH="$(mktemp -d)"
            BASH_ABS="$(command -v bash)"
            out="$(HOME="$TH" PATH=/nonexistent "$BASH_ABS" "$ROOT/scripts/nerd-font-download.sh" 2>&1)"
            assertEquals 1 "$?"
            assertTrue "curl error message" "echo \"\$out\" | grep -q 'curl is required'"
            rm -rf "$TH"
        }
        test_nerdfont_windows_idempotent_skip() {
            # fake git-bash (MINGW) + the Mono TTF already in the per-user font
            # dir AND registered (reg stub query succeeds) -> skip, no download
            FAKEBIN="$(mktemp -d)"; TH="$(mktemp -d)"
            printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$FAKEBIN/uname"
            mkdir -p "$TH/loc/Microsoft/Windows/Fonts"
            printf 'fake' > "$TH/loc/Microsoft/Windows/Fonts/HackNerdFontMono-Regular.ttf"
            cat > "$FAKEBIN/reg" <<'EOS'
#!/bin/sh
printf '%s %s\n' "${MSYS_NO_PATHCONV:-unset}" "$*" >> "$NERD_REGLOG"
EOS
            chmod +x "$FAKEBIN/uname" "$FAKEBIN/reg"
            out="$(HOME="$TH" LOCALAPPDATA="$TH/loc" NERD_REGLOG="$TH/reg.log" \
                PATH="$FAKEBIN:/usr/bin:/bin" bash "$ROOT/scripts/nerd-font-download.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "skip message" "echo \"\$out\" | grep -q 'already installed'"
            assertEquals 1 "$(ls -1 "$TH/loc/Microsoft/Windows/Fonts" | wc -l)"   # nothing new
            assertTrue "query ran with path conversion off" "grep -q '^1 query' '$TH/reg.log'"
            rm -rf "$FAKEBIN" "$TH"
        }
        test_nerdfont_windows_installs_and_registers() {
            # fake curl drops a fixture ttf, fake reg records the registry args:
            # the Mono font must land in the per-user dir and be registered via HKCU
            FAKEBIN="$(mktemp -d)"; TH="$(mktemp -d)"
            printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$FAKEBIN/uname"
            FIXTURE="$TH/fake.ttf"; printf 'FAKE-TTF-DATA' > "$FIXTURE"
            cat > "$FAKEBIN/curl" <<'EOS'
#!/bin/sh
[ -n "${NERD_CURLLOG:-}" ] && printf 'called\n' >> "$NERD_CURLLOG"
while [ $# -gt 0 ]; do
    if [ "$1" = "-o" ]; then cp "$NERD_FIXTURE" "$2"; shift 2; else shift; fi
done
EOS
            cat > "$FAKEBIN/reg" <<'EOS'
#!/bin/sh
printf '%s %s\n' "${MSYS_NO_PATHCONV:-unset}" "$*" >> "$NERD_REGLOG"
EOS
            chmod +x "$FAKEBIN/uname" "$FAKEBIN/curl" "$FAKEBIN/reg"
            out="$(HOME="$TH" LOCALAPPDATA="$TH/loc" NERD_FIXTURE="$FIXTURE" NERD_REGLOG="$TH/reg.log" \
                PATH="$FAKEBIN:/usr/bin:/bin" bash "$ROOT/scripts/nerd-font-download.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "font file created" "grep -q FAKE-TTF-DATA '$TH/loc/Microsoft/Windows/Fonts/HackNerdFontMono-Regular.ttf'"
            assertTrue "registered with the standard font value name" "grep -q 'Hack Nerd Font Mono Regular (TrueType)' '$TH/reg.log'"
            assertTrue "HKCU Fonts key used" "grep -q 'CurrentVersion' '$TH/reg.log'"
            assertTrue "add ran with path conversion off" "grep -q '^1 add' '$TH/reg.log'"
            rm -rf "$FAKEBIN" "$TH"
        }
        test_nerdfont_windows_partial_install_self_heals() {
            # file present but NOT registered (reg stub query fails): the
            # script must re-register WITHOUT re-downloading
            FAKEBIN="$(mktemp -d)"; TH="$(mktemp -d)"
            printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$FAKEBIN/uname"
            mkdir -p "$TH/loc/Microsoft/Windows/Fonts"
            printf 'fake-original' > "$TH/loc/Microsoft/Windows/Fonts/HackNerdFontMono-Regular.ttf"
            cat > "$FAKEBIN/curl" <<'EOS'
#!/bin/sh
[ -n "${NERD_CURLLOG:-}" ] && printf 'called\n' >> "$NERD_CURLLOG"
while [ $# -gt 0 ]; do
    if [ "$1" = "-o" ]; then cp "$NERD_FIXTURE" "$2"; shift 2; else shift; fi
done
EOS
            cat > "$FAKEBIN/reg" <<'EOS'
#!/bin/sh
printf '%s %s\n' "${MSYS_NO_PATHCONV:-unset}" "$*" >> "$NERD_REGLOG"
case "$1" in query) [ -n "${NERD_REG_QUERY_FAILS:-}" ] && exit 1 ;; esac
EOS
            chmod +x "$FAKEBIN/uname" "$FAKEBIN/curl" "$FAKEBIN/reg"
            out="$(HOME="$TH" LOCALAPPDATA="$TH/loc" NERD_REGLOG="$TH/reg.log" NERD_REG_QUERY_FAILS=1 NERD_CURLLOG="$TH/curl.log" \
                PATH="$FAKEBIN:/usr/bin:/bin" bash "$ROOT/scripts/nerd-font-download.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "re-registered" "grep -q '^1 add' '$TH/reg.log'"
            assertTrue "no download attempt" "[ ! -e '$TH/curl.log' ]"
            assertEquals "fake-original" "$(cat "$TH/loc/Microsoft/Windows/Fonts/HackNerdFontMono-Regular.ttf")"   # file untouched
            rm -rf "$FAKEBIN" "$TH"
        }
        # --- deps lib: compare helpers + parsers ------------------------------------
        . "$ROOT/scripts/deps-lib.sh"
        test_deps_is_newer() {
            assertTrue  "patch bump"   "deps_is_newer 0.10.1 0.10.0"
            assertTrue  "minor bump"   "deps_is_newer 0.11.0 0.10.9"
            assertTrue  "v prefix"     "deps_is_newer v0.41.0 v0.40.3"
            assertFalse "equal"        "deps_is_newer 0.10.0 0.10.0"
            assertFalse "older"        "deps_is_newer 0.9.4 0.10.0"
            assertFalse "empty latest" "deps_is_newer '' 0.10.0"
        }
        test_deps_sha_matches() {
            assertTrue  "short pin prefix of full sha" "deps_sha_matches fca0d61abcdef0123 fca0d61"
            assertTrue  "exact"     "deps_sha_matches fca0d61 fca0d61"
            assertFalse "different" "deps_sha_matches 9f8e7d6 fca0d61"
            assertFalse "empty sha" "deps_sha_matches '' fca0d61"
        }
        test_deps_max_version() {
            # string sort would pick v0.9.9; numeric compare must pick v0.41.0
            out="$(printf 'v0.40.3\nv0.9.9\nv0.41.0\nv0.40.10\n' | deps_max_version)"
            assertEquals "v0.41.0" "$out"
        }
        test_deps_parse_apt_upgradable() {
            out="$(printf 'Listing...\nnvim/jammy-updates 2:0.6.7-3 amd64 [upgradable from: 2:0.6.7-2]\nbat/jammy-updates 0.6.2-1 amd64 [upgradable from: 0.6.1-1]\n' | deps_parse_apt_upgradable)"
            assertEquals 2 "$(printf '%s\n' "$out" | wc -l)"
            assertTrue "nvim parsed"  "printf '%s\n' \"\$out\" | grep -q $'nvim\t2:0.6.7-2\t2:0.6.7-3'"
            assertTrue "bat parsed"   "printf '%s\n' \"\$out\" | grep -q $'bat\t0.6.1-1\t0.6.2-1'"
        }
        test_deps_versions_single_source_of_truth() {
            # the installers must read the pins from the lib, not carry their own
            assertFalse "install.sh has no hardcoded tmux-powerline pin" "grep -q 'TMUX_POWERLINE_PIN=' '$ROOT/install.sh'"
            assertFalse "install-pi.sh has no hardcoded tmux-powerline pin" "grep -q 'TMUX_POWERLINE_PIN=' '$ROOT/install-pi.sh'"
            assertFalse "nerd-font script has no hardcoded release tag" "grep -q 'v3.2.1' '$ROOT/scripts/nerd-font-download.sh'"
        }

        test_deps_font_present_darwin_without_fontconfig() {
            # macOS has no fc-list by default: the ~/Library/Fonts check must
            # catch the font nerd-font-download.sh installs there (PATH without
            # /usr/bin keeps the host's fc-list out of the picture)
            TH="$(mktemp -d)"
            FAKEBIN="$(mktemp -d)"
            printf '#!/bin/sh\necho Darwin\n' > "$FAKEBIN/uname"
            chmod +x "$FAKEBIN/uname"
            mkdir -p "$TH/Library/Fonts"
            printf 'fake' > "$TH/Library/Fonts/HackNerdFont-Regular.ttf"
            out="$(PATH="$FAKEBIN:/bin" HOME="$TH" bash -c \
                ". '$ROOT/scripts/deps-lib.sh'; deps_font_present && echo present || echo absent" 2>&1)"
            assertEquals "present" "$out"
            rm -rf "$TH" "$FAKEBIN"
        }

        test_deps_font_present_windows_posix_and_backslash_localappdata() {
            # git-bash LOCALAPPDATA is 'C:\...': backslashes break glob
            # patterns (escape chars) - the $HOME POSIX form must win (this
            # exact bug kept the windows CI smoke check red for days)
            TH="$(mktemp -d)"
            FAKEBIN="$(mktemp -d)"
            printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$FAKEBIN/uname"
            chmod +x "$FAKEBIN/uname"
            mkdir -p "$TH/AppData/Local/Microsoft/Windows/Fonts"
            printf 'fake' > "$TH/AppData/Local/Microsoft/Windows/Fonts/HackNerdFontMono-Regular.ttf"
            out="$(PATH="$FAKEBIN:/bin" HOME="$TH" LOCALAPPDATA='C:\Users\x\AppData\Local' bash -c \
                ". '$ROOT/scripts/deps-lib.sh'; deps_font_present && echo present || echo absent" 2>&1)"
            assertEquals "present" "$out"
            rm -rf "$TH" "$FAKEBIN"
        }

        # --- deps-check: fixture remotes + stubbed curl/npm (no real network) ---------
        # bare file:// repos stand in for github; a stub curl answers the release
        # API; a stub npm answers view/ls. CI-runner-safe (AGENTS.md trap 21).
        # NB: assertions must read pins from deps-versions.sh (dep_pin), never
        # hardcode them - the weekly deps PR bumps that file and these tests
        # run ON that PR (trap 30)
        dep_pin() { awk -F'"' -v v="$1" '$0 ~ "^"v"=" {print $2; exit}' "$ROOT/scripts/deps-versions.sh"; }
        DC_FIX=""; DC_BIN=""
        dc_setup() {
            DC_FIX="$(mktemp -d)"; DC_BIN="$(mktemp -d)"
            git init -q --bare -b main "$DC_FIX/tp.git"
            git clone -q "$DC_FIX/tp.git" "$DC_FIX/tp" 2>/dev/null
            git -C "$DC_FIX/tp" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c1
            git -C "$DC_FIX/tp" push -q origin HEAD 2>/dev/null
            git init -q --bare -b main "$DC_FIX/nvm.git"
            git clone -q "$DC_FIX/nvm.git" "$DC_FIX/nvm" 2>/dev/null
            git -C "$DC_FIX/nvm" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c1
            git -C "$DC_FIX/nvm" tag v0.40.3 && git -C "$DC_FIX/nvm" tag v0.41.0
            git -C "$DC_FIX/nvm" tag v9.9.9   # always newer than any real pin
            git -C "$DC_FIX/nvm" push -q origin HEAD --tags 2>/dev/null
            git init -q --bare -b main "$DC_FIX/shunit2.git"
            git clone -q "$DC_FIX/shunit2.git" "$DC_FIX/shunit2" 2>/dev/null
            git -C "$DC_FIX/shunit2" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c1
            git -C "$DC_FIX/shunit2" tag v2.1.6
            git -C "$DC_FIX/shunit2" tag v9.9.9   # always newer than any real pin
            git -C "$DC_FIX/shunit2" push -q origin HEAD --tags 2>/dev/null
            # zoxide: a sentinel newer than any plausible pin; nerd-font: the
            # CURRENT pin (interpolated) so the row status is deterministic ok
            local nf_pin
            nf_pin="$(dep_pin NF_VERSION)"
            cat > "$DC_BIN/curl" <<EOS
#!/bin/sh
case "\$*" in
    *ajeetdsouza/zoxide*)   echo '{"tag_name": "v9.9.9"}' ;;
    *ryanoasis/nerd-fonts*) echo '{"tag_name": "${nf_pin}"}' ;;
    *) exit 1 ;;
esac
EOS
            cat > "$DC_BIN/npm" <<'EOS'
#!/bin/sh
[ "$1" = "view" ] || exit 0
case "$2" in
    turbo-git)     echo 2.2.5 ;;
    diff-so-fancy) echo 1.4.4 ;;
esac
EOS
            chmod +x "$DC_BIN/curl" "$DC_BIN/npm"
        }
        dc_teardown() {
            [ -n "$DC_FIX" ] && rm -rf "$DC_FIX"
            [ -n "$DC_BIN" ] && rm -rf "$DC_BIN"
        }
        dc_run() {
            # NVM_DIR pointed at nothing: the fixtures must exercise the PATH
            # npm stub, never the real nvm installation of the host machine
            HOME="$DC_FIX/home" PATH="$DC_BIN:$PATH" NVM_DIR="$DC_FIX/home/.nvm-absent" \
                DOTFILES_TMUX_POWERLINE_REPO="file://$DC_FIX/tp.git" \
                DOTFILES_NVM_REPO_URL="file://$DC_FIX/nvm.git" \
                DOTFILES_SHUNIT2_REPO_URL="file://$DC_FIX/shunit2.git" \
                bash "$ROOT/scripts/deps-check.sh" "$@" 2>&1
        }
        dc_machine_state_behind() {
            # fake machine state: tmux-powerline checkout NOT at the pin,
            # old turbo-git installed, diff-so-fancy absent
            mkdir -p "$DC_FIX/home/.tmux/tmux-powerline"
            git -C "$DC_FIX/home/.tmux/tmux-powerline" init -q
            git -C "$DC_FIX/home/.tmux/tmux-powerline" -c user.email=t@t -c user.name=t commit -q --allow-empty -m local
            cat > "$DC_BIN/npm" <<'EOS'
#!/bin/sh
case "$1" in
    view) case "$2" in turbo-git) echo 2.2.5 ;; diff-so-fancy) echo 1.4.4 ;; esac ;;
    ls)   printf '%s\n' '├── turbo-git@2.2.4' ;;
    *)    exit 0 ;;
esac
EOS
            chmod +x "$DC_BIN/npm"
        }
        test_deps_check_default_reports_outdated_pins() {
            dc_setup
            out="$(dc_run --machine)"; code=$?
            assertEquals "exit 10 on pin updates" 10 "$code"
            # tmux-powerline is on DEPS_HOLD: reported as held, never outdated
            assertTrue "tmux-powerline held" "printf '%s\n' \"\$out\" | grep -q $'^T1\\ttmux-powerline\\t.*held$'"
            assertTrue "zoxide outdated"  "printf '%s\n' \"\$out\" | grep -q $'^T1\\tzoxide\\t$(dep_pin ZOXIDE_VERSION)\\tv9.9.9\\t-\\toutdated$'"
            assertTrue "nvm outdated"     "printf '%s\n' \"\$out\" | grep -q $'^T1\\tnvm\\t$(dep_pin NVM_VERSION)\\tv9.9.9\\t-\\toutdated$'"
            assertTrue "nerd-font ok"     "printf '%s\n' \"\$out\" | grep -q $'^T1\\tnerd-font\\t$(dep_pin NF_VERSION)\\t$(dep_pin NF_VERSION)\\t-\\tok$'"
            assertTrue "shunit2 outdated" "printf '%s\\n' \"\$out\" | grep -q $'^T1\\tshunit2\\t$(dep_pin SHUNIT2_VERSION)\\tv9.9.9\\t-\\toutdated$'"
            assertTrue "npm latest info"  "printf '%s\\n' \"\$out\" | grep -q $'^T2\\tturbo-git\\t-\\t2.2.5\\t-\\tinfo$'"
            dc_teardown
        }
        test_deps_held_dep_never_counts_or_bumps() {
            # a held dep must not flip the exit code on its own and must not
            # appear in the bump script's report actions
            . "$ROOT/scripts/deps-versions.sh"   # provides DEPS_HOLD
            assertTrue "held helper matches" "deps_dep_held tmux-powerline"
            assertFalse "held helper non-member" "deps_dep_held zoxide"
            TH="$(mktemp -d)"
            printf 'T1\ttmux-powerline\tfca0d61\tdeadbeef\t-\theld\n' > "$TH/report.txt"
            out="$(PATH=/usr/bin:/bin DEPS_CURL_FAIL=none bash -c ". '$ROOT/scripts/deps-bump-pr.sh' '$TH/report.txt' --dry-run" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "held row not bumped" "echo \"\$out\" | grep -q 'no pin changes to make'"
            rm -rf "$TH"
        }
        test_deps_check_local_reports_drift_and_behind() {
            dc_setup
            dc_machine_state_behind
            out="$(dc_run --local --machine)"; code=$?
            assertEquals "exit 10 on local updates" 10 "$code"
            # held: even a local drift on a held dep is never actionable
            assertTrue "tmux-powerline held (never drift)" "printf '%s\n' \"\$out\" | grep -q $'^T1\\ttmux-powerline\\t.*held$'"
            assertTrue "turbo-git behind"       "printf '%s\n' \"\$out\" | grep -q $'^T2\\tturbo-git\\t2.2.4\\t2.2.5\\t-\\tbehind$'"
            assertTrue "diff-so-fancy missing"  "printf '%s\\n' \"\$out\" | grep -q $'^T2\\tdiff-so-fancy\\t-\\t1.4.4\\t-\\tmissing$'"
            # NB: fzf's status is machine-dependent (a distro fzf with working
            # bindings is "ok" by design) - autoenv is asserted instead
            assertTrue "autoenv missing"        "printf '%s\\n' \"\$out\" | grep -q $'^T2\\tautoenv\\t.*missing$'"
            dc_teardown
        }
        test_deps_check_human_table_mentions_apply_hint() {
            dc_setup
            out="$(dc_run)"; code=$?
            assertEquals 10 "$code"
            assertTrue "pinned section" "echo \"\$out\" | grep -q '== pinned dependencies'"
            assertTrue "apply hint"     "echo \"\$out\" | grep -q 'dotfiles-update'"
            dc_teardown
        }
        test_deps_check_windows_scope_is_limited() {
            # fake git-bash: only the font and the npm globals are managed on
            # windows - tmux/zoxide/nvm/fzf/autoenv rows must never appear
            # (offering to install them on windows would be wrong)
            dc_setup
            printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$DC_BIN/uname"
            # no fontconfig on windows: the stub forces the per-user font dir
            # branch (empty LOCALAPPDATA -> no font -> drift, deterministic)
            printf '#!/bin/sh\nexit 1\n' > "$DC_BIN/fc-list"
            chmod +x "$DC_BIN/uname" "$DC_BIN/fc-list"
            out="$(dc_run --local --machine)"; code=$?
            assertEquals "exit 10: font drift counted" 10 "$code"
            assertFalse "no tmux-powerline row" "printf '%s\n' \"\$out\" | grep -q 'tmux-powerline'"
            assertFalse "no zoxide row"         "printf '%s\n' \"\$out\" | grep -q $'^T1\\tzoxide'"
            assertFalse "no nvm row"            "printf '%s\n' \"\$out\" | grep -q $'^T1\\tnvm'"
            assertFalse "no fzf/autoenv rows"   "printf '%s\n' \"\$out\" | grep -q $'^T2\\t\\(fzf\\|autoenv\\)'"
            assertTrue "font still checked"     "printf '%s\n' \"\$out\" | grep -q $'^T1\\tnerd-font\\t.*drift$'"
            assertTrue "npm still checked"      "printf '%s\n' \"\$out\" | grep -q $'^T2\\tturbo-git'"
            dc_teardown
        }

        # --- deps-apply: plan, dry-run, confirmation gate -------------------------------
        # DOTFILES_DEPS_REPORT_FILE injects the check result: apply tests are
        # fully offline and deterministic (the check itself is tested above)
        DA_REPORT=""; DA_HOME=""; DA_BIN=""
        da_setup() { # optional report content as $1
            DA_REPORT="$(mktemp /tmp/da-report-XXXXXX)"; DA_HOME="$(mktemp -d)"; DA_BIN="$(mktemp -d)"
            if [ -n "${1:-}" ]; then
                printf '%s\n' "$1" > "$DA_REPORT"
            else
                printf 'T1\ttmux-powerline\tfca0d61\t1a2b3c4\t9f8e7d6\tdrift\n' > "$DA_REPORT"
                printf 'T1\tzoxide\t0.10.0\t0.11.1\t-\tok\n' >> "$DA_REPORT"
                printf 'T2\tturbo-git\t2.2.4\t2.2.5\t-\tbehind\n' >> "$DA_REPORT"
                printf 'T2\tdiff-so-fancy\t-\t1.4.4\t-\tmissing\n' >> "$DA_REPORT"
            fi
            # stub npm: records invocations, never touches a registry
            cat > "$DA_BIN/npm" <<'EOS'
#!/bin/sh
[ -n "${DA_NPM_LOG:-}" ] && printf '%s\n' "$*" >> "$DA_NPM_LOG"
exit 0
EOS
            chmod +x "$DA_BIN/npm"
        }
        da_teardown() {
            [ -n "$DA_REPORT" ] && rm -f "$DA_REPORT"
            [ -n "$DA_HOME" ] && rm -rf "$DA_HOME"
            [ -n "$DA_BIN" ] && rm -rf "$DA_BIN"
            unset DA_MODE DA_DRY DA_TTY 2>/dev/null
        }
        da_run() {
            DOTFILES_DEPS_REPORT_FILE="$DA_REPORT" HOME="$DA_HOME" PATH="$DA_BIN:$PATH" \
                NVM_DIR="$DA_HOME/.nvm-absent" \
                DA_NPM_LOG="$DA_HOME/npm-ran" DOTFILES_DEPS_TTY="${DA_TTY:-1}" \
                DOTFILES_UPDATE_MODE="${DA_MODE:-prompt}" DOTFILES_INSTALL_DRY_RUN="${DA_DRY:-0}" \
                bash "$ROOT/scripts/deps-apply.sh" "$@" 2>&1
        }
        test_deps_apply_dry_run_prints_plan_without_executing() {
            da_setup
            DA_MODE=auto DA_DRY=1
            out="$(da_run --post-update)"; code=$?
            da_teardown
            assertEquals 0 "$code"
            assertTrue "plan header"      "echo \"\$out\" | grep -q 'dependency updates available'"
            assertTrue "informs the plan" "echo \"\$out\" | grep -q 'tmux-powerline: apply pin fca0d61'"
            assertTrue "npm plan line"    "echo \"\$out\" | grep -q 'turbo-git: 2.2.4 -> 2.2.5'"
            assertTrue "missing pkg line" "echo \"\$out\" | grep -q 'diff-so-fancy: not installed'"
            assertTrue "dry-run markers"  "echo \"\$out\" | grep -q '\\[dry-run\\]'"
            assertFalse "nothing executed" "[ -e '$DA_HOME/npm-ran' ]"
            da_teardown
        }
        test_deps_apply_without_tty_only_reminds() {
            da_setup
            DA_TTY=0
            out="$(da_run </dev/null)"; code=$?
            unset DA_TTY
            assertEquals 0 "$code"
            assertTrue "reminder to update" "echo \"\$out\" | grep -q 'run: dotfiles-update'"
            assertFalse "nothing executed"  "[ -e '$DA_HOME/npm-ran' ]"
            da_teardown
        }
        test_deps_apply_yes_executes_the_plan() {
            # npm-only report: the T1 drift path would clone from the real
            # tmux-powerline repo - offline tests stay off that path
            da_setup 'T2	turbo-git	2.2.4	2.2.5	-	behind
T2	diff-so-fancy	-	1.4.4	-	missing'
            out="$(da_run --yes)"; code=$?
            assertEquals 0 "$code"
            assertTrue "npm install ran (behind)"  "grep -q 'install -g turbo-git' '$DA_HOME/npm-ran'"
            assertTrue "npm install ran (missing)" "grep -q 'install -g diff-so-fancy' '$DA_HOME/npm-ran'"
            assertTrue "summary is green" "echo \"\$out\" | grep -q 'Everything Done'"
            da_teardown
        }
        test_deps_apply_all_current_is_silent() {
            da_setup 'T1	zoxide	0.10.0	0.11.1	-	ok
T2	turbo-git	2.2.5	2.2.5	-	ok'
            out="$(da_run --yes)"; code=$?
            assertEquals 0 "$code"
            assertTrue "all current message" "echo \"\$out\" | grep -q 'all dependencies current'"
            assertFalse "no npm run happened" "[ -e '$DA_HOME/npm-ran' ]"
            da_teardown
        }

        # --- deps-bump-pr: dry run edits nothing ---------------------------------------
        # shared stub: HEAD/release curl that 404s only for $DEPS_CURL_FAIL
        bump_curl_stub() {
            cat > "$1/curl" <<'EOS'
#!/bin/sh
case "$*" in
    *"${DEPS_CURL_FAIL:-__none__}"*) printf '404' ;;
    *) printf '200' ;;
esac
EOS
            chmod +x "$1/curl"
        }
        test_deps_url_exists() {
            TH="$(mktemp -d)"
            bump_curl_stub "$TH"
            out="$(PATH="$TH:/usr/bin:/bin" DEPS_CURL_FAIL='/x' bash -c ". '$ROOT/scripts/deps-lib.sh'; deps_url_exists https://example.com/x && echo yes || echo no" 2>&1)"
            assertEquals "no" "$out"
            out="$(PATH="$TH:/usr/bin:/bin" bash -c ". '$ROOT/scripts/deps-lib.sh'; deps_url_exists https://example.com/x && echo yes || echo no" 2>&1)"
            assertEquals "yes" "$out"
            rm -rf "$TH"
        }
        test_deps_artifacts_exist_gates_every_os() {
            TH="$(mktemp -d)"
            bump_curl_stub "$TH"
            # one OS artifact 404 -> the whole version must be rejected
            out="$(PATH="$TH:/usr/bin:/bin" DEPS_CURL_FAIL=aarch64-apple-darwin bash -c ". '$ROOT/scripts/deps-lib.sh'; deps_artifacts_exist zoxide v0.11.1 && echo all || echo missing" 2>&1)"
            assertEquals "missing" "$out"
            out="$(PATH="$TH:/usr/bin:/bin" bash -c ". '$ROOT/scripts/deps-lib.sh'; deps_artifacts_exist nerd-font v3.5.1 && echo all || echo missing" 2>&1)"
            assertEquals "all" "$out"
            # nerd-font: linux/osx zip AND the windows TTF (old OR new layout)
            out="$(PATH="$TH:/usr/bin:/bin" DEPS_CURL_FAIL='Regular/HackNerdFontMono' bash -c ". '$ROOT/scripts/deps-lib.sh'; deps_artifacts_exist nerd-font v3.5.1 && echo all || echo missing" 2>&1)"
            assertEquals "all" "$out"   # flat v3.3+ layout accepted
            out="$(PATH="$TH:/usr/bin:/bin" DEPS_CURL_FAIL=HackNerdFontMono-Regular.ttf bash -c ". '$ROOT/scripts/deps-lib.sh'; deps_artifacts_exist nerd-font v3.5.1 && echo all || echo missing" 2>&1)"
            assertEquals "missing" "$out"
            rm -rf "$TH"
        }
        test_nerdfont_windows_falls_back_to_flat_layout() {
            # v3.3+ moved the TTFs out of patched-fonts/<font>/Regular/: the
            # stub fails the old URL and succeeds on the flat one
            FAKEBIN="$(mktemp -d)"; TH="$(mktemp -d)"
            printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$FAKEBIN/uname"
            FIXTURE="$TH/fake.ttf"; printf 'FAKE-FLAT-TTF' > "$FIXTURE"
            cat > "$FAKEBIN/curl" <<'EOS'
#!/bin/sh
case "$*" in
    *"/Regular/"*) exit 1 ;;          # old layout gone in new releases
    *"-o"*) while [ $# -gt 0 ]; do [ "$1" = "-o" ] && cp "$NERD_FIXTURE" "$2" && shift 2 || shift; done ;;
    *) exit 1 ;;
esac
EOS
            cat > "$FAKEBIN/reg" <<'EOS'
#!/bin/sh
exit 0
EOS
            chmod +x "$FAKEBIN/uname" "$FAKEBIN/curl" "$FAKEBIN/reg"
            out="$(HOME="$TH" LOCALAPPDATA="$TH/loc" NERD_FIXTURE="$FIXTURE" \
                PATH="$FAKEBIN:/usr/bin:/bin" bash "$ROOT/scripts/nerd-font-download.sh" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "flat layout downloaded" "grep -q FAKE-FLAT-TTF '$TH/loc/Microsoft/Windows/Fonts/HackNerdFontMono-Regular.ttf'"
            rm -rf "$FAKEBIN" "$TH"
        }
        test_deps_bump_pr_dry_run() {
            FX="$(mktemp -d)"; BIN="$(mktemp -d)"
            bump_curl_stub "$BIN"   # artifact HEAD checks: never real network
            cp "$ROOT/scripts/deps-versions.sh" "$FX/deps-versions.sh"
            # report built from the CURRENT pins: on the weekly PR they are
            # already bumped, so literals would break (trap 30)
            printf 'T1\tzoxide\t%s\tv9.9.9\t-\toutdated\n' "$(dep_pin ZOXIDE_VERSION)" > "$FX/report.txt"
            printf 'T1\tnvm\t%s\tv9.9.9\t-\toutdated\n' "$(dep_pin NVM_VERSION)" >> "$FX/report.txt"
            printf 'T1\tnerd-font\t%s\t%s\t-\tok\n' "$(dep_pin NF_VERSION)" "$(dep_pin NF_VERSION)" >> "$FX/report.txt"
            printf 'T2\tturbo-git\t-\t2.2.5\t-\tinfo\n' >> "$FX/report.txt"
            out="$(PATH="$BIN:/usr/bin:/bin" DOTFILES_BUMP_VERSIONS="$FX/deps-versions.sh" bash "$ROOT/scripts/deps-bump-pr.sh" "$FX/report.txt" --dry-run 2>&1)"
            assertEquals 0 "$?"
            assertTrue "commit message uses the turbo [TAG] convention" "echo \"\$out\" | grep -q '^\\[MOD\\] deps: bump 2 pin(s) (weekly check)$'"
            assertTrue "zoxide bump listed"  "echo \"\$out\" | grep -q 'ZOXIDE_VERSION: $(dep_pin ZOXIDE_VERSION) -> 9.9.9'"
            assertTrue "nvm bump listed"     "echo \"\$out\" | grep -q 'NVM_VERSION: $(dep_pin NVM_VERSION) -> v9.9.9'"
            assertTrue "pr body table"       "echo \"\$out\" | grep -q '| dependency | pinned | latest |'"
            assertTrue "floating notes"      "echo \"\$out\" | grep -q 'turbo-git'"
            assertTrue "pin file untouched"  "grep -q 'ZOXIDE_VERSION=\"$(dep_pin ZOXIDE_VERSION)\"' '$FX/deps-versions.sh'"
            rm -rf "$FX" "$BIN"
        }
        test_deps_bump_pr_skips_incomplete_releases() {
            # a release missing one OS artifact must NOT be pinned: the dep is
            # skipped (pin kept), the rest of the report still bumps
            FX="$(mktemp -d)"; BIN="$(mktemp -d)"
            bump_curl_stub "$BIN"
            cp "$ROOT/scripts/deps-versions.sh" "$FX/deps-versions.sh"
            printf 'T1\tzoxide\t%s\tv9.9.9\t-\toutdated\n' "$(dep_pin ZOXIDE_VERSION)" > "$FX/report.txt"
            printf 'T1\tnvm\t%s\tv9.9.9\t-\toutdated\n' "$(dep_pin NVM_VERSION)" >> "$FX/report.txt"
            out="$(PATH="$BIN:/usr/bin:/bin" DEPS_CURL_FAIL=aarch64-apple-darwin \
                DOTFILES_BUMP_VERSIONS="$FX/deps-versions.sh" \
                bash "$ROOT/scripts/deps-bump-pr.sh" "$FX/report.txt" --dry-run 2>&1)"
            assertEquals 0 "$?"
            assertTrue "commit message counts only applied bumps" "echo \"\$out\" | grep -q '^\\[MOD\\] deps: bump 1 pin(s) (weekly check)$'"
            assertTrue "zoxide skipped"   "echo \"\$out\" | grep -q 'zoxide.*SKIPPED'"
            assertTrue "nvm still bumped" "echo \"\$out\" | grep -q 'NVM_VERSION: $(dep_pin NVM_VERSION) -> v9.9.9'"
            assertTrue "zoxide pin kept"  "grep -q 'ZOXIDE_VERSION=\"$(dep_pin ZOXIDE_VERSION)\"' '$FX/deps-versions.sh'"
            assertTrue "pr body notes it" "echo \"\$out\" | grep -q 'Skipped bumps'"
            rm -rf "$FX" "$BIN"
        }

        # --- doctor: pin drift comes from the lib, not a hardcoded sha -------------------
        test_doctor_flags_tmux_powerline_pin_drift() {
            au_setup
            mkdir -p "$AU_FIX/home/.tmux/tmux-powerline"
            git -C "$AU_FIX/home/.tmux/tmux-powerline" init -q
            git -C "$AU_FIX/home/.tmux/tmux-powerline" -c user.email=t@t -c user.name=t commit -q --allow-empty -m fake
            # read the pin at test time: the weekly PR bumps it (trap 30)
            pin="$(dep_pin TMUX_POWERLINE_PIN)"
            out="$(HOME="$AU_FIX/home" bash "$ROOT/scripts/doctor.sh" 2>&1)"
            assertTrue "drift warning mentions the pin" "echo \"\$out\" | grep -q 'drifted from pin $pin'"
            au_teardown
        }
        # --- tmux-powerline.local (extra bar segments) --------------------------------
        test_tmux_powerline_local_appends_segments() {
            # requires the powerline framework (skipped on machines without it)
            if [ ! -d "$HOME/.tmux/tmux-powerline" ]; then
                startSkipping
            fi
            TH="$(mktemp -d)"
            printf 'TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS+=("uptime 235 136")\n' > "$TH/.tmux-powerline.local"
            out="$(bash -c "
                . '$HOME/.tmux/tmux-powerline/config/helpers.sh' 2>/dev/null
                . '$HOME/.tmux/tmux-powerline/config/paths.sh' 2>/dev/null
                . '$HOME/.tmux/tmux-powerline/config/defaults.sh' 2>/dev/null
                export TMUX_POWERLINE_DIR_USER_THEMES='$ROOT'
                TMUX_POWERLINE_THEME='tmux-bar-sam-theme'
                HOME='$TH'
                . '$ROOT/tmux-bar-sam-theme.sh'
                printf '%s\n' \"\${TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS[@]}\"
            " 2>&1)"
            assertTrue "uptime segment appended" "echo \"\$out\" | grep -q '^uptime 235 136'"
            assertTrue "standard segments still present" "echo \"\$out\" | grep -q 'chip-temperature 129 7'"
            endSkipping
            rm -rf "$TH"
        }
        # --- chip-temperature segment --------------------------------------------------
        # segments are sourced and run_segment() is called by the framework -
        # tests must follow the same pattern
        test_chip_temp_smctemp_darwin() {
            # fake darwin toolchain: uname says Darwin, smctemp reports 64.2
            FAKEBIN="$(mktemp -d)"
            printf '#!/bin/sh\necho Darwin\n' > "$FAKEBIN/uname"
            printf '#!/bin/sh\necho 64.2\n' > "$FAKEBIN/smctemp"
            chmod +x "$FAKEBIN"/*
            out="$(PATH="$FAKEBIN:/usr/bin:/bin" bash -c ". '$ROOT/segments/chip-temperature.sh'; run_segment" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "darwin chip temp" "echo \"\$out\" | grep -q '64.2°C'"
            rm -rf "$FAKEBIN"
        }
        test_chip_temp_old_smctemp_fallback() {
            # smctemp v0.1: -f is an unknown option and the usage/error goes
            # to STDOUT (not stderr) - the segment must fall back to plain -c
            FAKEBIN="$(mktemp -d)"
            printf '#!/bin/sh\necho Darwin\n' > "$FAKEBIN/uname"
            cat > "$FAKEBIN/smctemp" <<'EOS'
#!/bin/sh
case "$1" in
    -f) echo "smctemp: invalid option -- 'f'" ;;
    *)  echo 64.2 ;;
esac
EOS
            chmod +x "$FAKEBIN"/*
            out="$(PATH="$FAKEBIN:/usr/bin:/bin" bash -c ". '$ROOT/segments/chip-temperature.sh'; run_segment" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "fallback to plain -c" "echo \"\$out\" | grep -q '64.2°C'"
            assertFalse "usage text not rendered" "echo \"\$out\" | grep -q 'invalid option'"
            rm -rf "$FAKEBIN"
        }
        test_chip_temp_garbage_output_dropped() {
            # any non-numeric output (even without an explicit failure) must
            # never reach the bar - return 1 = the framework's drop contract
            FAKEBIN="$(mktemp -d)"
            printf '#!/bin/sh\necho Darwin\n' > "$FAKEBIN/uname"
            printf '#!/bin/sh\necho "not a temperature"\n' > "$FAKEBIN/smctemp"
            chmod +x "$FAKEBIN"/*
            out="$(PATH="$FAKEBIN:/usr/bin:/bin" bash -c ". '$ROOT/segments/chip-temperature.sh'; run_segment" 2>&1)"
            assertEquals 1 "$?"
            assertEquals "" "$out"
            rm -rf "$FAKEBIN"
        }
        test_chip_temp_sensors_linux() {
            # real uname (Linux) + fake sensors output -> package temp parsed
            FAKEBIN="$(mktemp -d)"
            printf '#!/bin/sh\necho "Package id 0: +50.0°C  (high = +52.0°C)"\n' > "$FAKEBIN/sensors"
            chmod +x "$FAKEBIN/sensors"
            out="$(PATH="$FAKEBIN:/usr/bin:/bin" bash -c ". '$ROOT/segments/chip-temperature.sh'; run_segment" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "linux chip temp" "echo \"\$out\" | grep -q '50.0°C'"
            rm -rf "$FAKEBIN"
        }
        test_gpu_temp_hidden_without_nvidia() {
            # no nvidia-smi -> empty output (segment auto-drops on macs);
            # return 1 = the framework's "no output" contract
            out="$(PATH="/nonexistent" "$(command -v bash)" -c ". '$ROOT/segments/gpu-temp.sh'; run_segment" 2>&1)"
            assertEquals 1 "$?"
            assertEquals "" "$out"
        }
        # --- os-icon segment (byobu-style logo) -----------------------------------------
        test_os_icon_ubuntu_uses_theme_colors() {
            # ubuntu carries no markup: the theme entry ("os-icon 235 255 ...")
            # colors it - output is byobu's " u " logo + trailing space
            out="$(bash -c ". '$ROOT/segments/os-icon.sh'; run_segment" 2>&1)"
            assertEquals 0 "$?"
                        assertTrue "ubuntu orange chip + tight u" "echo \"\$out\" | grep -q 'fg=colour255,bg=colour202][[:space:]]*u[[:space:]]*'"

        }
        test_os_icon_debian_matches_byobu_colors() {
            TH="$(mktemp -d)"
            printf 'NAME="Debian GNU/Linux 12"\n' > "$TH/os-release"
            out="$(DOTFILES_OS_RELEASE="$TH/os-release" bash -c ". '$ROOT/segments/os-icon.sh'; run_segment" 2>&1)"
            assertEquals 0 "$?"
            assertTrue "debian red chip + tight @" "echo \"\$out\" | grep -q 'fg=white,bg=red][[:space:]]*@[[:space:]]*'"
            rm -rf "$TH"
        }
        test_os_icon_darwin_apple_logo() {
            # Hack NF has no U+F8FF (byobu's apple char) - the segment uses the
            # NF apple glyph U+F179 on the standard orange chip instead
            FAKEBIN="$(mktemp -d)"
            printf '#!/bin/sh\necho Darwin\n' > "$FAKEBIN/uname"
            chmod +x "$FAKEBIN"/*
            out="$(PATH="$FAKEBIN:/usr/bin:/bin" bash -c ". '$ROOT/segments/os-icon.sh'; run_segment" 2>&1)"
            assertEquals 0 "$?"
            local apple_glyph expected
            apple_glyph="$(printf '\uf179')"
            expected="bg=colour235][[:space:]]*$apple_glyph[[:space:]]*"
            assertTrue "orange chip with NF apple glyph" "echo \"\$out\" | grep -q '$expected'"
            rm -rf "$FAKEBIN"
        }
        test_theme_has_os_icon_before_hostname() {
            theme="$ROOT/tmux-bar-sam-theme.sh"
            os_line="$(grep -n '"os-icon 235 255 ' "$theme" | cut -d: -f1)"
            host_line="$(grep -n '"hostname 148 234"' "$theme" | cut -d: -f1)"
            assertTrue "os-icon precedes hostname in the left bar" "[ -n '$os_line' ] && [ -n '$host_line' ] && [ '$os_line' -lt '$host_line' ]"
        }
        . "$SHUNIT2"
    )
    [ $? -eq 0 ] || FAILED=1
else
    echo "  [skip] shunit2 unavailable (offline?) - unit tests skipped"
fi

echo "==> 4. install.sh dry-run (exercises the sh -> bash re-exec guard)"
DRY_OUT="$(DOTFILES_INSTALL_DRY_RUN=1 sh "$ROOT/install.sh" 2>&1)"
DRY_CODE=$?
if printf '%s' "$DRY_OUT" | grep -q "detected OS:" && [ "$DRY_CODE" -eq 0 ]; then
    echo "  [ok]   dry-run completed under sh dispatch"
    printf '%s\n' "$DRY_OUT" | sed 's/^/     /'
else
    echo "  [FAIL] dry-run failed (exit $DRY_CODE)"
    printf '%s\n' "$DRY_OUT" | sed 's/^/     /'
    FAILED=1
fi

echo
if [ "$FAILED" -eq 0 ]; then
    echo "ALL TESTS PASSED"
else
    echo "TESTS FAILED"
fi
exit "$FAILED"
