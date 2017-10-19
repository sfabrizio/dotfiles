# Print wifi info.

osxCommand='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I'
icon=" "


run_segment() {

    if echo -n `$osxCommand` | grep -q "AirPort: Off"; then
        echo -e $icon "Off"
        exit 0;
    fi

    echo -n "$icon"
    echo -e "$( $osxCommand \
             | awk '/ SSID/ {print substr($0, index($0, $2))}'\
             | sed 's/SSID:/No_connection/g'\
             | tr -d '[:blank:]' \
            )"
	exit 0
}

