echo "Fixing Permission on scripts folder"
chmod -R +x scripts

echo "Creating backup of your previus config files."
cp ~/.gitconfig ~/.gitconfig.bak
cp ~/.vimrc ~/.vimrc.bak
cp ~/.zshrc ~/.zshrc.bak
cp ~/.tmux.conf ~/.tmux.conf.bak

echo "creating folders"
cd ~/
mkdir -p dotfiles
mkdir -p workspace
mkdir -p .tmux
mkdir -p .autoenv

echo "creating symbolic links"
ln -s env .env

echo "cloning git repo"
cd ~
git clone git://github.com/sfabrizio/dotfiles.git
cd ~/workspace
git clone https://github.com/sfabrizio/ozono-zsh-theme
cd ~/.tmux
git clone https://github.com/erikw/tmux-powerline.git
cd ~/.autoenv
git clone git://github.com/kennethreitz/autoenv.git

echo "Coping new configuration files.."
echo "[include] path = ~/dotfiles/gitconfig" > ~/.gitconfig
echo "source ~/dotfiles/vimrc" > ~/.vimrc
echo "source ~/dotfiles/zshrc" > ~/.zshrc
echo "source ~/dotfiles/tmux.conf" > ~/.tmux.conf

source ~/.zshrc

echo "Everything Done."
