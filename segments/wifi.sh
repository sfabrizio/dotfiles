# Print wifi info.

run_segment() {
    echo -n " "
    echo -e "$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I \
            | awk '/ SSID/ {print substr($0, index($0, $2))}'\
            | sed 's/SSID:/No Connection/g'\
            | tr -d '[:blank:]')"
	exit 0
}

