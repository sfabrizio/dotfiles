#!/bin/bash
echo -e "\e[36m"
echo -e '-- Multi Git -- Insert one git command, run it on many repos';
echo -e "\e[0m"

if test ${#} -eq 0; then
    git
    exit 0;
fi

command -v configurator >/dev/null 2>&1 || {
    printf "'configurator' it's not installed.  Aborting.";
    printf  "\n\n You can install the last version by running:\n"
    printf  "\t npm install -g git+ssh://git@bitbucket.realtimegaming.com:7999/it/configurator.git#master"
    exit 1;
}

currentPath=$(pwd)
branchesToPull=($(configurator -g pull-branches))

for branchPath in "${branchesToPull[@]}"
do
  cd "$(configurator -g ${branchPath})"
  echo -e "\n\e[36m"
  echo -e "Running \"git $@\" on \"${branchPath}\" \e[0m";
  echo -e "(`pwd`)\n"
  git $@
done

#come back to current branch
cd $currentPath