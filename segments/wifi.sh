# Print wifi info.

icon=" "


run_segment() {
    if [ "$(uname)" = "Darwin" ]; then
        __run_osx
    else
        __run_linux
    fi
    exit $?
}

__run_osx() {
    osxCommand='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I'

    if echo -n `$osxCommand` | grep -q "AirPort: Off"; then
        echo -e $icon "Off"
        return 0
    fi

    echo -n "$icon"
    echo -e "$( $osxCommand \
             | awk '/ SSID/ {print substr($0, index($0, $2))}'\
             | sed 's/SSID:/No_connection/g'\
             | tr -d '[:blank:]' \
            )"
    return 0
}

__run_linux() {
    local iface ssid
    iface=$(awk 'NR>2 && $1!~/Inter-/ {gsub(":", "", $1); print $1; exit}' /proc/net/wireless 2>/dev/null)
    [ -z "$iface" ] && return 1

    ssid=""
    if command -v nmcli >/dev/null 2>&1; then
        ssid=$(nmcli -t -f GENERAL.CONNECTION device show "$iface" 2>/dev/null | cut -d: -f2-)
    fi
    if [ -z "$ssid" ] || [ "$ssid" = "--" ]; then
        ssid="$iface"
    fi

    echo -e "$icon $ssid"
    return 0
}

