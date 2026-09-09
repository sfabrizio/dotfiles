#!/usr/bin/env bash
# Print a normalized OS identifier for the installers:
#   "osx" | "windows" | "raspy" | "linux" | "linux fedora" | "linux ubuntu"
#
# Note: `uname -s` never returns "Linux raspberrypi" (the old check here was
# dead code) - pi detection uses /etc/os-release and the device-tree instead.

get_os_name() {
    local uname_str
    uname_str="$(uname -s)"
    case "$uname_str" in
        Darwin)
            echo 'osx'
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo 'windows'
            ;;
        Linux)
            if grep -qiE 'raspbian|raspberry' /etc/os-release 2>/dev/null \
                || [ -f /etc/rpi-issue ] \
                || grep -qis 'raspberry' /proc/device-tree/model 2>/dev/null; then
                echo 'raspy'
            elif command -v dnf >/dev/null 2>&1; then
                echo 'linux fedora'
            elif command -v apt >/dev/null 2>&1; then
                echo 'linux ubuntu'
            else
                echo 'linux'
            fi
            ;;
        *)
            echo 'unknown'
            ;;
    esac
}
