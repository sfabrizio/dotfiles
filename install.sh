#Fixing Permission on scripts folder
chmod -R +x scripts

#detec OS
source ~/dotfiles/scripts/get_os_name.sh
OS_NAME=`get_os_name`

if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Please install it first."
    exit 1;
fi

if [[ "$OS_NAME" == 'osx' ]]; then

    if ! command -v brew >/dev/null 2>&1; then
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi
fi

if ! [ -d $ZSH ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

if ! [ -d ~/.nvm ]; then
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.4/install.sh | bash
fi


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
mkdir -p .config/nvim

echo "creating symbolic links"
ln -s env .env

echo "cloning git repo"
cd ~
git clone git://github.com/sfabrizio/dotfiles.git dotfiles
git clone git://github.com/kennethreitz/autoenv.git .autoenv
cd ~/workspace
git clone https://github.com/sfabrizio/ozono-zsh-theme
cd ~/.tmux
git clone https://github.com/erikw/tmux-powerline.git

echo "Coping new configuration files.."
echo "[include] path = ~/dotfiles/gitconfig" > ~/.gitconfig
echo "source ~/dotfiles/vimrc" > ~/.vimrc
echo "source ~/.vimrc" > ~/.config/nvim/init.vim
echo "source ~/dotfiles/zshrc" > ~/.zshrc
echo "source ~/dotfiles/tmux.conf" > ~/.tmux.conf

source ~/.zshrc

echo "Everything Done."
