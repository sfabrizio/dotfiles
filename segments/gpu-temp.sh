# Print gpu temp.

icon=" "


run_segment() {
    if [ "$(uname)" = "Darwin" ]; then
        local temp
        temp=$(~/dotfiles/externals/osx-cpu-temp/osx-cpu-temp -g 2>/dev/null)
        [ -z "$temp" ] && return 1
        echo -e "$icon $temp"
        return 0
    fi

    # Linux via nvidia-smi (first GPU)
    if command -v nvidia-smi >/dev/null 2>&1; then
        local temp
        temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)
        [ -n "$temp" ] || return 1
        echo -e "$icon ${temp}°C"
        return 0
    fi

    return 1
}

