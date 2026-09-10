# Default Theme

if patched_font_in_use; then
	TMUX_POWERLINE_SEPARATOR_LEFT_BOLD=""
	TMUX_POWERLINE_SEPARATOR_LEFT_THIN=""
	TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD=""
	TMUX_POWERLINE_SEPARATOR_RIGHT_THIN=""
else
	TMUX_POWERLINE_SEPARATOR_LEFT_BOLD="◀"
	TMUX_POWERLINE_SEPARATOR_LEFT_THIN="❮"
	TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD="▶"
	TMUX_POWERLINE_SEPARATOR_RIGHT_THIN="❯"
fi

TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR:-'235'}
TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR=${TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR:-'255'}

TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_LEFTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD}
TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR=${TMUX_POWERLINE_DEFAULT_RIGHTSIDE_SEPARATOR:-$TMUX_POWERLINE_SEPARATOR_LEFT_BOLD}


# Format: segment_name background_color foreground_color [non_default_separator]

if [ -z $TMUX_POWERLINE_LEFT_STATUS_SEGMENTS ]; then
	TMUX_POWERLINE_LEFT_STATUS_SEGMENTS=(
		#"tmux_session_info 148 234" \
		#"hostname 33 0" \
		"os-icon 235 255 - - - both_disable separator_disable" \
		"hostname 148 234" \
		#"ifstat 30 255" \
		#"ifstat_sys 30 255" \
        #"wifi 33 255"\
		"lan_ip 24 255" \
		"now_playing 234 37" \
		#"wan_ip 24 255" \
		#"vcs_branch 29 88" \
		#"vcs_compare 60 255" \
		#"vcs_staged 64 255" \
		#"vcs_modified 9 255" \
		#"vcs_others 245 0" \
		# needs a re-work (mac notification counts)
		#"macos_notification_count2 28 255" \
		"new_window 12 233" \
		"new_split 13 235" \
	)
fi

if [ -z $TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS ]; then
	TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS=(
		#"earthquake 3 0" \
		#"pwd 89 211" \
		#"mailcount 9 255" \
		#"cpu 240 136" \
		#"load 237 167" \
		#"tmux_mem_cpu_load 234 136" \
		#"macos_notification_count 197 255" \
		"close_pane 1 255" \
		"chip-temperature 129 7" \
		# renders only where nvidia-smi exists; re-add locally via ~/.tmux-powerline.local
		#"gpu-temp 160 7" \
		"battery 7 160" \
		"weather 57 255" \
		#"rainbarf 0 ${TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR}" \
		#"xkb_layout 125 117" \
		"date_day 235 131" \
		"date 235 130 ${TMUX_POWERLINE_SEPARATOR_LEFT_THIN}" \
		"time 235 136 ${TMUX_POWERLINE_SEPARATOR_LEFT_THIN}" \
		#"utc_time 235 136 ${TMUX_POWERLINE_SEPARATOR_LEFT_THIN}" \
	)
fi

# machine-local extra segments (never committed) - sourced AFTER the arrays
# above, so it can append or prepend without touching this file:
#   TMUX_POWERLINE_LEFT_STATUS_SEGMENTS+=("my_segment 12 233")          # append left
#   TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS+=("uptime 235 136")            # append right
#   TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS=("new 1 255" "${TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS[@]}")  # prepend
# segment scripts must exist in ~/dotfiles/segments/ (or the stock segments dir)
if [ -f "$HOME/.tmux-powerline.local" ]; then
    source "$HOME/.tmux-powerline.local"
fi
