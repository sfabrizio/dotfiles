# Clickable segment: horizontal split (top/bottom panes, like byobu Shift-F2).
# Click targeting needs tmux >= 3.3 (user status ranges + mouse_status_range).
# On older tmux it renders the same but the whole-bar default click applies.

run_segment() {
    local v icon
    v=$(tmux display -p '#{version}' 2>/dev/null)
    if patched_font_in_use; then
        # nerd font: fa-align-justify (stacked rows = horizontal split)
        icon="  "
    else
        icon=" - "
    fi
    case "$v" in
        3.[3-9]*|4.*|4)
            # wrap in a user range; closed with norange so the hit area stays on the icon
            echo "#[range=user|newsplit]${icon}#[norange]"
            ;;
        *)
            echo "$icon"
            ;;
    esac
    return 0
}
