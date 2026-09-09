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
    curl -fsSL "https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/shunit2/shunit2-2.1.6.tgz" \
        | tar zx -C /tmp 2>/dev/null || true
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
