# Print cpu temp.

icon=" "


run_segment() {
    if [ "$(uname)" = "Darwin" ]; then
        local temp
        temp=$(~/dotfiles/externals/osx-cpu-temp/osx-cpu-temp 2>/dev/null)
        [ -z "$temp" ] && return 1
        echo -e "$icon $temp"
        return 0
    fi

    # Linux via lm-sensors: Intel "Package id 0" or AMD "Tdie"
    if command -v sensors >/dev/null 2>&1; then
        local temp
        temp=$(sensors 2>/dev/null | awk '/Package id 0|Tdie/ {for (i=1; i<=NF; i++) if ($i ~ /^\+[0-9.]+°C$/) {gsub(/[+°C]/, "", $i); print $i; exit}}')
        [ -n "$temp" ] || return 1
        echo -e "$icon ${temp}°C"
        return 0
    fi

    return 1
}

