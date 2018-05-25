#!/bin/bash
echo -e "\e[36m"
echo -e '-- Multi Git -- Config Paths generator';
echo -e "\e[0m"

command -v configurator >/dev/null 2>&1 || {
    printf "'configurator' it's not installed.  Aborting.";
    printf  "\n\n You can install the last version by running:\n"
    printf  "\t npm install -g git+ssh://git@bitbucket.realtimegaming.com:7999/it/configurator.git#master"
    exit 1;
}

configuratorVersion=$(configurator -V)
source ~/dotfiles/scripts/semver.sh

isConfiguratorLowerVersion=$(checkIsLowerVerion "$configuratorVersion" "1.10.0")

if [ $isConfiguratorLowerVersion == "true" ] ; then
  printf "'configurator v1.10.0' or supperior is required. Please install it.  Aborting.";
  printf  "\t\n npm install -g git+ssh://git@bitbucket.realtimegaming.com:7999/it/configurator.git#v1.10.0"
  exit 1;
fi


branchesToPull=($(configurator -g work-branches))

if [ "${branchesToPull[0]}" == "null" ]; then
  #defaults
  branchesToPull=('gtkjs' 'CasinoRTG' 'ScriptsRTG' 'ContentBuilder')
fi

#create config path if does not exist
mkdir -p ~/.dotfiles/multi-git > /dev/null
#delete previous file
rm -f ~/.dotfiles/multi-git/paths.txt > /dev/null

for branchPath in "${branchesToPull[@]}"
do
  path="$(configurator -g ${branchPath})"
  echo "Writing path on config: $path"
  printf "%s\n" "$path" >> ~/.dotfiles/multi-git/paths.txt
done

echo -e "\e[32m"
echo -e 'Done';
echo -e "\e[0m"
