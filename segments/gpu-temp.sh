# Print gpu temp.
# Linux only via nvidia-smi (first GPU): on macOS (Apple Silicon) the cpu/gpu
# sensors are combined - the chip-temperature segment covers the whole chip,
# so this segment renders nothing on macs.

icon=" "


run_segment() {
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
