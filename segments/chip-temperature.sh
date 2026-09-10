# Print the cpu/chip temperature.
# macOS: smctemp (works on Apple Silicon + Intel; M-series sensors are combined
#        cpu/gpu, so this is THE temperature segment on macs)
# Linux: lm-sensors (Intel "Package id 0" or AMD "Tdie")

icon=" "

# smctemp_temp <args...>: run smctemp and print the temperature ONLY when the
# output is a bare number - old versions print their usage/error to stdout
smctemp_temp() {
    local out
    out=$(smctemp "$@" 2>/dev/null | head -n 1)
    case "$out" in
        ''|*[!0-9.]*) return 1 ;;
    esac
    printf '%s\n' "$out"
}


run_segment() {
    if [ "$(uname)" = "Darwin" ]; then
        local temp
        command -v smctemp >/dev/null 2>&1 || return 1
        # -f (fail-soft) stabilizes reads on M2 macs but only exists on
        # smctemp >= 0.2: older versions print their usage/error to STDOUT,
        # so the output must be validated as a bare number before use
        temp=$(smctemp_temp -c -f) || temp=$(smctemp_temp -c) || return 1
        [ "$temp" != "0" ] || return 1
        echo -e "$icon ${temp}°C"
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
