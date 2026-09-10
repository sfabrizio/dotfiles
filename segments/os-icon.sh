# Print the OS logo, matching byobu's default status bar (icon + colors).
# Distro detection mirrors byobu's get_distro (/etc/os-release NAME, then
# /etc/issue), colors mirror byobu's logo table (color BACK FORE).
#
# The theme entry disables spacing + separator ("both_disable" +
# "separator_disable"): this segment is self-contained - it draws its own
# trailing separator wedge (fg = chip bg, bg = hostname's colour148) so the
# transition stays correct on every OS.

run_segment() {
    local distro fg bg glyph
    if [ "$(uname -s)" = "Darwin" ]; then
        distro="darwin"
    elif [ -r "${DOTFILES_OS_RELEASE:-/etc/os-release}" ]; then
        distro=$(DOTFILES_OS_RELEASE="${DOTFILES_OS_RELEASE:-/etc/os-release}" bash -c '. "$0" && echo "$NAME"' "${DOTFILES_OS_RELEASE:-/etc/os-release}" 2>/dev/null)
    elif [ -r /etc/issue ]; then
        read -r distro _ < /etc/issue
    fi
    distro=$(printf '%s' "$distro" | tr '[:upper:]' '[:lower:]')

    case "$distro" in
        *raspbian*)         fg="colour15";      bg="colour125";  glyph="@" ;;
        *ubuntu*)           fg="colour255";     bg="colour202";  glyph="u" ;;
        *debian*)           fg="white";         bg="red";        glyph="@" ;;
        *fedora*)           fg="white";         bg="blue";       glyph="f" ;;
        *arch*)             fg="white";         bg="blue";       glyph="A" ;;
        *centos*)           fg="magenta";       bg="white";      glyph="※" ;;
        *gentoo*)           fg="white";         bg="cyan";       glyph=">" ;;
        *mint*)             fg="white";         bg="green";      glyph="lm" ;;
        *red\ hat*|*rhel*)  fg="black";         bg="brightred";  glyph="RH" ;;
        *suse*)             fg="green";         bg="brightwhite"; glyph="SUSE" ;;
        *mac*|*darwin*)     fg="colour255";     bg="colour235";  glyph="" ;;
        *)                  fg="brightwhite";   bg="blue";       glyph="〣" ;;
    esac

    # spacing: 2 before, 3 after the glyph (separator disabled in the theme)
    printf '#[fg=%s,bg=%s] %s  ' "$fg" "$bg" "$glyph"
    return 0
}
