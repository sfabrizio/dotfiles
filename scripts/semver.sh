#!/bin/bash

#This script is an adaptation from: https://gist.github.com/maxrimue/ca69ee78081645e1ef62

function checkIsLowerVerion {
    # Assume we have two semantic versions that we want to compare:
    version1=$1
    version2=$2

    # First, we replace the dots by blank spaces, like this:

    version1=${version1//./ }
    version2=${version2//./ }

    # If you have a "v" in front of your versions, you can get rid of it like this:

    version1=${version1//v/}
    version2=${version2//v/}

    # Now we have "0 12 0" and "1 15 5"
    # So, we just need to extract each number like this:

    patch1=$(echo $version1 | awk '{print $3}')
    minor1=$(echo $version1 | awk '{print $2}')
    major1=$(echo $version1 | awk '{print $1}')

    patch2=$(echo $version2 | awk '{print $3}')
    minor2=$(echo $version2 | awk '{print $2}')
    major2=$(echo $version2 | awk '{print $1}')

    # And now, we can simply compare the variables, like:

    [ $major1 -eq $major2 ] && [ $minor1 -lt $minor2 ] && echo "true" && exit 0;
    echo "false" && exit 0;
}