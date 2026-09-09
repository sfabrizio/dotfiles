#!/usr/bin/env bash
# Print "true" when version1 is strictly LOWER than version2, else "false".
# Numeric comparison across major.minor.patch; a leading "v" is tolerated.
# (The old implementation only compared the minor component and exited the
# calling shell; kept the original function name for compatibility.)

checkIsLowerVerion() {
    local v1="${1#v}" v2="${2#v}"
    local v1_parts v2_parts
    v1_parts=(${v1//./ })
    v2_parts=(${v2//./ })
    local i a b
    for i in 0 1 2; do
        a="${v1_parts[i]:-0}"
        b="${v2_parts[i]:-0}"
        # tolerate suffixes like "10-rc1" -> "10"
        a="${a%%[!0-9]*}"
        b="${b%%[!0-9]*}"
        a="${a:-0}"
        b="${b:-0}"
        if [ "$a" -lt "$b" ]; then
            echo true
            return 0
        fi
        if [ "$a" -gt "$b" ]; then
            echo false
            return 0
        fi
    done
    echo false
    return 0
}
