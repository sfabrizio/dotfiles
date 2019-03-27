if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Please install it first."
    exit 1;
fi

cd ~
git clone git://github.com/sfabrizio/dotfiles.git dotfiles

#detec OS
source ~/dotfiles/scripts/get_os_name.sh
OS_NAME=`get_os_name`

function isNodeJs {
    if command -v node >/dev/null 2>&1; then
        return 0;
    else
        return 1;
    fi
}

if [[ "$OS_NAME" == 'windows' ]]; then
    echo "windows detected running win bash install.."
    sh ~/dotfiles/install-windows.sh
    exit 0;
fi

#OSX install require packages
if [[ "$OS_NAME" == 'osx' ]]; then

    if ! command -v brew >/dev/null 2>&1; then
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi

    if ! command -v byobu >/dev/null 2>&1; then
        echo "installing byobu:"
        brew install byobu
    fi
    if ! isNodeJs ; then
        echo "installing node js:":
        brew install node
    fi
    brew install neovim git-extras htop byobu
    echo "osx-cpu-temp build";
    cd ~/dotfiles/externals/osx-cpu-temp && make && cd ~

fi

# install package for any OS
npm_packages=('turbo-git' 'diff-so-fancy')

if ! isNodeJs ; then
    echo "install node js adn them install the require packages by running:"
    echo "'npm i -g ${npm_packages[@]}'"
else
    npm install -g `${npm_packages[@]}`
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

echo "cloning git repos..."
cd ~
git clone git://github.com/kennethreitz/autoenv.git .autoenv
cd ~/workspace
git clone https://github.com/sfabrizio/ozono-zsh-theme
cd ~/.tmux
git clone https://github.com/erikw/tmux-powerline.git
cd ~/.autoenv
git clone git://github.com/kennethreitz/autoenv.git

echo "Coping new configuration files.."
echo "[include] path = ~/dotfiles/gitconfig" > ~/.gitconfig
echo "source ~/dotfiles/vimrc" > ~/.vimrc
echo "source ~/.vimrc" > ~/.config/nvim/init.vim
echo "source ~/dotfiles/zshrc" > ~/.zshrc
echo "source ~/dotfiles/tmux.conf" > ~/.tmux.conf
echo "source ~/dotfiles/tmux-powerlinerc" > ~/.tmux-powerlinerc

source ~/.zshrc

echo "Everything Done."
