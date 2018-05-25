#!/bin/bash
echo -e "\e[36m"
echo -e '-- Multi Git -- Insert one git command, run it on many repos';
echo -e "\e[0m"

if test ${#} -eq 0; then
    git
    exit 0;
fi

pathsFile=~/.dotfiles/multi-git/paths.txt

if ! [ -f $pathsFile ] ; then
    echo "Path file doesn't exit, you can create one on: $pathsFile"
    echo "or You can autogenerate them by running: `mg-init` cmd."
fi

branchesToPull=()
while read -r line
do
    branchesToPull+=("$line")
done < "$pathsFile"


for branchPath in "${branchesToPull[@]}"
do
  echo -e "\n\e[36m"
  echo -e "Running \"git $@\" on \"${branchPath}\" \e[0m";
  echo -e "(`pwd`)\n"
  echo "${branchPath}\.git\\"
  git --git-dir "${branchPath}\.git" --work-tree="${branchPath}" --no-pager $@
done
