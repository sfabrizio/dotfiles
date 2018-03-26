#!/bin/bash
function get_os_name {
    os_name='unknown'
    unamestr=`uname`
    if [[ "$unamestr" == 'Linux' ]]; then
       os_name='linux'
       if command -v dnf >/dev/null 2>&1; then
          os_name+=' fedora'
       fi
       if command -v apt >/dev/null 2>&1; then
          os_name+=' ubuntu'
       fi
    elif [[ "$unamestr" == 'Darwin' ]]; then
       os_name='osx'
    elif [[ "$unamestr" == 'Linux raspberrypi' ]]; then
       os_name='raspy'
    fi
    echo $os_name
}
