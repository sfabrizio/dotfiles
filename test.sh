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
            # run the updater against the fixture home; stdout+stderr captured
            HOME="$AU_FIX/home" bash "$ROOT/scripts/auto-update.sh" "$@" 2>&1
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
