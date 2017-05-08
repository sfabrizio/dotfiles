echo "Fixing Permission on scripts folder"
chmod -R +x scripts

echo "Creating backup of your previus config files."
cp ~/.gitconfig ~/.gitconfig.bak
cp ~/.vimrc ~/.vimrc.bak
cp ~/.zshrc ~/.zshrc.bak
cp ~/.tmux.conf ~/.tmux.conf.bak

echo "creating folders"
cd ~/
mkdir -p workspace
mkdir -p .tmux
mkdir -p .autoenv

echo "cloning git repos on workspace folder"
git clone https://github.com/sfabrizio/ozono-zsh-theme ~/workspace
git clone https://github.com/erikw/tmux-powerline.git ~/.tmux
git clone git://github.com/kennethreitz/autoenv.git ~/.autoenv

echo "Coping new configuration files.."
echo "[include] path = ~/dotfiles/gitconfig" > ~/.gitconfig
echo "source ~/dotfiles/vimrc" > ~/.vimrc
echo "source ~/dotfiles/zshrc" > ~/.zshrc
echo "source ~/dotfiles/tmux.conf" > ~/.tmux.conf

source ~/.zshrc

echo "Everything Done."
