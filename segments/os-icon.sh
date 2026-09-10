# Print the OS logo, matching byobu's default status bar (icon + colors).
# Distro detection mirrors byobu's get_distro (/etc/os-release NAME, then
# /etc/issue), colors mirror byobu's logo table (color BACK FORE).
# The ubuntu entry carries no markup: its colors come from the theme
# ("os-icon 202 255"), so the powerline separators blend into the chip.

run_segment() {
    local distro markup=""
    if [ "$(uname -s)" = "Darwin" ]; then
        distro="darwin"
    elif [ -r "${DOTFILES_OS_RELEASE:-/etc/os-release}" ]; then
        distro=$(. "${DOTFILES_OS_RELEASE:-/etc/os-release}" && echo "$NAME")
    elif [ -r /etc/issue ]; then
        read -r distro _ < /etc/issue
    fi
    distro=$(printf '%s' "$distro" | tr '[:upper:]' '[:lower:]')

    case "$distro" in
        *raspbian*) markup='#[fg=colour15,bg=colour125] @ ' ;;
        *ubuntu*)   printf ' u  '; return 0 ;;   # theme colors: bg colour202, fg colour255
        *debian*)   markup='#[fg=white,bg=red] @ ' ;;
        *fedora*)   markup='#[fg=white,bg=blue] f ' ;;
        *arch*)     markup='#[fg=white,bg=blue] A ' ;;
        *centos*)   markup='#[fg=magenta,bg=white] ※ ' ;;
        *gentoo*)   markup='#[fg=white,bg=cyan] > ' ;;
        *mint*)     markup='#[fg=white,bg=green] lm ' ;;
        *red\ hat*|*rhel*) markup='#[fg=black,bg=brightred] RH ' ;;
        *suse*)     markup='#[fg=green,bg=brightwhite] SUSE ' ;;
        *mac*|*darwin*) markup='#[fg=colour255,bg=colour202]  ' ;;
        *)          markup='#[fg=brightwhite,bg=blue] 〣 ' ;;
    esac
    printf '%s ' "$markup"
    return 0
}
