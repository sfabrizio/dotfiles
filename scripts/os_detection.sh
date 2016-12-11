platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
   platform='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
   platform='mac'
elif [[ "$unamestr" == 'Linux raspberrypi' ]]; then
   platform='raspy'
fi
echo $platform
