#!/usr/bin/env bash
# CI helper for .github/workflows/deps-check.yml: turn a deps-check --machine
# report into a pin bump commit + PR against the default branch.
#
# Usage: deps-bump-pr.sh <report-file> [--dry-run]
#   --dry-run prints the intended bumps + PR body without touching git (tests).
#
# Only Tier 1 "outdated" lines change scripts/deps-versions.sh; Tier 2 "info"
# lines are listed in the PR body as floating deps (applied locally by
# dotfiles-update, never pinned here). Binary/font releases (zoxide,
# nerd-font) additionally get their per-OS artifacts verified via HEAD
# requests BEFORE the bump is offered - one pin serves every OS, so an
# upstream release with a missing platform artifact must not be pinned.
set -euo pipefail

REPORT="${1:?usage: deps-bump-pr.sh <report-file> [--dry-run]}"
DRY=0
if [ "${2:-}" = "--dry-run" ]; then
    DRY=1
fi

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/deps-lib.sh
. "$SELF_DIR/deps-lib.sh"

VERSIONS_FILE="${DOTFILES_BUMP_VERSIONS:-scripts/deps-versions.sh}"
BRANCH="chore/deps-bump"
TITLE="chore(deps): weekly dependency bump"

bump_var_for() {
    case "$1" in
        tmux-powerline) echo "TMUX_POWERLINE_PIN" ;;
        zoxide)         echo "ZOXIDE_VERSION" ;;
        nvm)            echo "NVM_VERSION" ;;
        nerd-font)      echo "NF_VERSION" ;;
        shunit2)        echo "SHUNIT2_VERSION" ;;
        *)              echo "" ;;
    esac
}

BODY="$(mktemp /tmp/deps-pr-body-XXXXXX.md)"
trap 'rm -f "$BODY"' EXIT

{
    echo "## Weekly dependency check"
    echo
    echo "| dependency | pinned | latest | status |"
    echo "| --- | --- | --- | --- |"
} > "$BODY"

T2_NOTES=""
SKIPPED_NOTES=""
CHANGED=0
while IFS=$'\t' read -r kind name a b c status; do
    [ -n "${kind:-}" ] || continue
    if [ "$kind" = "T1" ]; then
        printf '| %s | %s | %s | %s |\n' "$name" "$a" "$b" "$status" >> "$BODY"
        if [ "$status" != "outdated" ]; then
            continue
        fi
        var="$(bump_var_for "$name")"
        if [ -z "$var" ]; then
            continue
        fi
        case "$name" in
            tmux-powerline) new="$b" ;;   # short sha, keep as-is
            zoxide)         new="${b#v}" ;;  # pin carries no v prefix
            *)              new="$b" ;;
        esac
        cur="$(awk -F'"' -v v="$var" '$0 ~ "^"v"=" {print $2; exit}' "$VERSIONS_FILE")"
        if [ -n "$cur" ] && [ "$cur" != "$new" ]; then
            # one pin = one version for every OS: verify the release actually
            # has artifacts for all of them before offering the bump (HEAD only)
            case "$name" in
                zoxide|nerd-font)
                    if ! deps_artifacts_exist "$name" "$new"; then
                        echo "skip $name $new: release artifacts missing (or unreachable) for some OS" >&2
                        SKIPPED_NOTES="${SKIPPED_NOTES}- \`${name}\` ${new}: bump SKIPPED - release artifacts missing (or unreachable) for some OS; pin stays at \`${cur}\`
"
                        continue
                    fi
                    ;;
            esac
            echo "$var: $cur -> $new"
            echo "- $name: $cur -> $new" >> "$BODY"
            CHANGED=1
            if [ "$DRY" -eq 0 ]; then
                sed -i "s|^${var}=.*|${var}=\"${new}\"|" "$VERSIONS_FILE"
            fi
        fi
    elif [ "$kind" = "T2" ] && [ "$status" = "info" ]; then
        T2_NOTES="${T2_NOTES}- \`${name}\` latest: ${b} (floating - applied locally by dotfiles-update)
"
    fi
done < "$REPORT"

if [ -n "$SKIPPED_NOTES" ]; then
    {
        echo
        echo "### Skipped bumps (upstream release incomplete)"
        printf '%s' "$SKIPPED_NOTES"
    } >> "$BODY"
fi

if [ -n "$T2_NOTES" ]; then
    {
        echo
        echo "### Floating dependencies (no pin; updated on your machines)"
        printf '%s' "$T2_NOTES"
    } >> "$BODY"
fi

cat >> "$BODY" <<'EOF'
## After merging
Run `dotfiles-update` on your machines and confirm the dependency prompt: it
re-clones / re-downloads whatever drifted from the new pins and separately
offers to upgrade OS packages (apt/brew).

tmux-powerline bumps deserve a diff review before merging: upstream master
restructured its config system once before and silently ignores
~/.tmux-powerlinerc + user themes/segments when it does.
EOF

if [ "$CHANGED" -eq 0 ]; then
    echo "no pin changes to make"
    exit 0
fi

if [ "$DRY" -eq 1 ]; then
    echo "--- PR body ---"
    cat "$BODY"
    exit 0
fi

cd "$(git rev-parse --show-toplevel)"
git config user.email "deps-bot@users.noreply.github.com"
git config user.name "deps-bot"
git checkout -q -b "$BRANCH"
git add "$VERSIONS_FILE"
git commit -q -m "$TITLE"
git push -qf origin "$BRANCH"
if gh pr view "$BRANCH" --json number >/dev/null 2>&1; then
    gh pr edit "$BRANCH" --title "$TITLE" --body-file "$BODY"
else
    gh pr create --title "$TITLE" --body-file "$BODY" --head "$BRANCH"
fi
echo "pin-bump PR is up on branch $BRANCH"
