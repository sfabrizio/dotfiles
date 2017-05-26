#!/bin/bash
function get_os_name {
    platform='unknown'
    unamestr=`uname`
    if [[ "$unamestr" == 'Linux' ]]; then
       platform='linux'
    elif [[ "$unamestr" == 'Darwin' ]]; then
       platform='mac'
    elif [[ "$unamestr" == 'Linux raspberrypi' ]]; then
       platform='raspy'
    fi
    return platform
}
