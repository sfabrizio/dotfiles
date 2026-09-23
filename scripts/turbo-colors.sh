# turbo-commit tag colors - the exact palette of turbo-git
# (turbo-git-config lib/configs/turbo.json):
#   [ADD]=green [FIX]=yellow [MOD]=blue [DEL]=red [REF]=cyan [BRK]=magenta
# Sourced lib (not executed), like semver.sh/get_os_name.sh. turbo_colorize
# reads `git log --oneline` lines on stdin and colors from the [TAG] to the
# end of the line (the hash stays plain), matching turbo-log's behavior.
# Colors are emitted only when stdout is a terminal, when
# DOTFILES_TURBO_COLORS=1 forces them (tests, pagers), and never with
# NO_COLOR set.

turbo_colorize() {
    if [ -z "${NO_COLOR:-}" ] && { [ -t 1 ] || [ "${DOTFILES_TURBO_COLORS:-0}" = "1" ]; }; then
        local esc reset line hash rest code
        esc="$(printf '\033')"
        reset="${esc}[0m"
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                *" "*)
                    hash="${line%% *}"
                    rest="${line#* }"
                    code=""
                    case "$rest" in
                        "[ADD]"*) code=32 ;;  # green
                        "[FIX]"*) code=33 ;;  # yellow
                        "[MOD]"*) code=34 ;;  # blue
                        "[DEL]"*) code=31 ;;  # red
                        "[REF]"*) code=36 ;;  # cyan
                        "[BRK]"*) code=35 ;;  # magenta
                    esac
                    if [ -n "$code" ]; then
                        printf '%s %s%s%s%s\n' "$hash" "${esc}[${code}m" "$rest" "$reset"
                    else
                        printf '%s\n' "$line"
                    fi
                    ;;
                *)
                    printf '%s\n' "$line"
                    ;;
            esac
        done
    else
        cat
    fi
}
