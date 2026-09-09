# Clickable segment: closes the current pane (like byobu F6 / tmux kill-pane).
# First click arms it: the segment then shows confirm (y) and cancel (n) icons;
# confirm kills the pane, cancel (or a 10s timeout set by the status-click
# binding in tmux.conf) returns it to the plain cross. Click targeting needs
# tmux >= 3.3 (user status ranges + mouse_status_range); icons are padded so
# the whole segment chip is the click target. On older tmux it renders the
# same but the whole-bar default click applies.

run_segment() {
    local v armed
    v=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[a-z]?')
    armed=$(tmux show -gv @close_pane_confirm 2>/dev/null)
    if patched_font_in_use; then
        # nerd font: fa-times (close/cancel), fa-check (confirm)
        close="    "
        check="    "
        cancel="    "
    else
        close="  x  "
        check="  y  "
        cancel="  n  "
    fi
    case "$v" in
        3.[3-9]*|4.*|4)
            if [ "$armed" = "1" ]; then
                # two-icon confirm/cancel space; each icon gets its own click
                # range, padded so the whole half-chip is the target; the bare
                # space between the ranges is a neutral no-action gap
                echo "#[range=user|closeconfirm]${check}#[norange] #[range=user|closecancel]${cancel}#[norange]"
            else
                # wrap in a user range; closed with norange. the icon is padded
                # so the click target is the whole chip, not just the glyph
                echo "#[range=user|closepane]${close}#[norange]"
            fi
            ;;
        *)
            if [ "$armed" = "1" ]; then
                echo "${check}${cancel}"
            else
                echo "$close"
            fi
            ;;
    esac
    return 0
}
