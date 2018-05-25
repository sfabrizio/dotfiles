#!/bin/bash
echo -e "\e[36m"
echo -e '-- Multi Git -- Path generator';
echo -e "\e[0m"

command -v configurator >/dev/null 2>&1 || {
    printf "'configurator' it's not installed.  Aborting.";
    printf  "\n\n You can install the last version by running:\n"
    printf  "\t npm install -g git+ssh://git@bitbucket.realtimegaming.com:7999/it/configurator.git#master"
    exit 1;
}

branchesToPull=($(configurator -g work-branches))

#create config path if does not exist
mkdir -p ~/.dotfiles/multi-git > /dev/null
#delete previous file
rm -f ~/.dotfiles/multi-git/paths.txt > /dev/null

for branchPath in "${branchesToPull[@]}"
do
  path="$(configurator -g ${branchPath})"
  echo "Writing path: $path"
  printf "%s\n" "$path" >> ~/.dotfiles/multi-git/paths.txt
done

echo -e "\e[32m"
echo -e 'Done';
echo -e "\e[0m"
