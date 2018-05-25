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

# install package for any OS
npm_packages=('turbo-git')

if ! isNodeJs ; then
    echo "install node js adn them install the require packages by running:"
    echo "'npm i -g ${npm_packages[@]}'"
else
    npm install -g "${npm_packages[@]}"
fi

echo "Creating backup of your previus config files."
cp ~/.gitconfig ~/.gitconfig.bak > /dev/null
cp ~/.vimrc ~/.vimrc.bak > /dev/null
cp ~/.bashrc ~/.bashrc.bak > /dev/null

#creating folders
cd ~/
mkdir -p dotfiles
mkdir -p workspace

echo "Coping new configuration files.."
echo "[include] path = ~/dotfiles/gitconfig" > ~/.gitconfig
echo "source ~/dotfiles/vimrc" > ~/.vimrc
echo "source ~/dotfiles/bashrc" > ~/.bashrc
source ~/.bashrc

echo "Everything Done."