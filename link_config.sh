
echo "Creating backup of your gitconfig.."
mv ~/.gitconfig ~/.gitconfig.bak
echo "Done."
echo "[include] \npath = ~/dotfiles/gitconfig" > ~/.gitconfig
