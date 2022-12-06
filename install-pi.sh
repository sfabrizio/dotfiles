if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Please install it first."
    exit 1;
fi

cd ~
if [ ! -d "dotfiles" ] ; then
    git clone git://github.com/sfabrizio/dotfiles.git dotfiles
fi



bash -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

if ! [ -d ~/.nvm ]; then
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.4/install.sh | bash
fi

echo "Creating backup of your previus config files."
cp ~/.gitconfig ~/.gitconfig.bak > /dev/null
cp ~/.vimrc ~/.vimrc.bak > /dev/null
cp ~/.zshrc ~/.zshrc.bak > /dev/null
cp ~/.tmux.conf ~/.tmux.conf.bak > /dev/null

#creating folders
cd ~/
mkdir -p dotfiles
mkdir -p workspace
mkdir -p .tmux
mkdir -p .autoenv
mkdir -p .config/nvim

#creating symbolic links
ln -s env .env

echo "Coping new configuration files.."
echo "[include] path = ~/dotfiles/gitconfig" > ~/.gitconfig
echo "source ~/dotfiles/vimrc" > ~/.vimrc
echo "source ~/.vimrc" > ~/.config/nvim/init.vim
echo "source ~/dotfiles/zshrc" > ~/.zshrc
echo "source ~/dotfiles/tmux.conf" > ~/.tmux.conf
echo "source ~/dotfiles/tmux-powerlinerc" > ~/.tmux-powerlinerc

source ~/.zshrc
echo "cloning git repos..."
cd ~/workspace
if [ ! -d "ozono-zsh-theme" ] ; then
    git clone https://github.com/sfabrizio/ozono-zsh-theme
fi


echo "Everything Done."
