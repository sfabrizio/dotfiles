
echo "Creating backup of your previus config files."
cp ~/.gitconfig ~/.gitconfig.bak
cp ~/.vimrc ~/.vimrc.bak
cp ~/.zshrc ~/.zshrc.bak

echo "Coping new files.."
echo "[include] \npath = ~/dotfiles/gitconfig" > ~/.gitconfig
echo "source ~/dotfiles/vimrc" > ~/.vimrc
echo "source ~/dotfiles/zshrc" > ~/.zshrc
mkdir -p ~/.vim/colors
cp ~/dotfiles/vim/monokai.vim ~/.vim/colors/  
source ~/.zshrc

echo "Everything Done."
