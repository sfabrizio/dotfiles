[![Build Status](https://travis-ci.org/sfabrizio/dotfiles.svg?branch=master)](https://travis-ci.org/sfabrizio/dotfiles)
# Sam’s dotfiles

This is my personal dotfiles. I created it from scratch. You are free to use it if you want.. But I recommend you create your own dotfiles.. It's a learning journey and It's fun! You can do exactly what you want or you can just take the inpiration for another dotfiles and make it in your own way.

![preview](https://raw.githubusercontent.com/sfabrizio/dotfiles/master/screenshots/preview3.png)

<<<<<<< HEAD
#Preview 

![my shell prompt & my vim](https://raw.githubusercontent.com/sfabrizio/dotfiles/master/screenshots/preview2.png)


# Features

> This dotfile is more friendly for work with JS enviroments. But I use it with other lenguages too and It's fine.

## ZSH
- custom zsh theme: [ozono](https://github.com/sfabrizio/ozono-zsh-theme)
- [ozono](https://github.com/sfabrizio/ozono-zsh-theme): switch the icon according OS: linux, mac, rasbian, etc.
- [ozono](https://github.com/sfabrizio/ozono-zsh-theme): show node js version only on js projects.
- auto switch node js version enviroment only when it’s necessary.
=======
# Install

Sam's dotfiles is installed by running one of the following commands in your terminal. You can install this via the command-line with either curl or wget


**Via curl**

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sfabrizio/dotfiles/master/install.sh)"
```

**Via wget**
```
sh -c "$(wget https://raw.githubusercontent.com/sfabrizio/dotfiles/master/install.sh -O -)"
```

> This will install for you all neccesaty for have it working (this was tested on osx mostly). It will install:
  - [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)
  - [Brew](https://brew.sh/)  (OSX package manager)
  - [byobu](http://byobu.co/)
  - [turbo-git](https://github.com/labs-js/turbo-git)
  - [nodeJs](https://nodejs.org/en/)
  - [NVM](https://github.com/creationix/nvm)
  - [autoenv](https://github.com/kennethreitz/autoenv)
  - [tmux-powerline](https://github.com/erikw/tmux-powerline)
  - and It will copy all the dotfiles for this tools. Creating also a backup of your previus dotfiles.


# Features

## OH-MY-ZSH
- custom zsh theme: [ozono](https://github.com/sfabrizio/ozono-zsh-theme)
- [ozono](https://github.com/sfabrizio/ozono-zsh-theme): switch the icon according OS: linux, mac, rasbian, etc.
- [ozono](https://github.com/sfabrizio/ozono-zsh-theme): show node js version only on js projects.
- auto switch node js version enviroment only when it’s necessary. Using Autoenv

![ozono](https://raw.githubusercontent.com/sfabrizio/dotfiles/master/screenshots/ozono.png)
>>>>>>> cf27af3319ff0b4626832d4ddce31e24e8b7ef33

## VIM

This configuration work with the regular vim but I'm usin nvim instead.

<<<<<<< HEAD
- code higliting: js, jsx, html,css, scss, etc. linting.
- auto ident js code.
- eslint_d for faster linting.

## git

=======
- code higliting: js, jsx, html,css, scss, bash, c, etc. linting.
- auto ident js code.
- nerd tree, vim icons, etc.
- eslint_d for faster linting.

![vim](https://raw.githubusercontent.com/sfabrizio/dotfiles/master/screenshots/vim.png)

## Git

- turbo-git
>>>>>>> cf27af3319ff0b4626832d4ddce31e24e8b7ef33
- custom shorts alias & turbo git alias
- colors improvements
- global gitconfig & global gitignore

<<<<<<< HEAD
## tmux

- easy shorcuts thanks to byobu
- beter colors
- tmux powerline bar

## TODO:
- install script: install autoenv
- vim: create plugin for auto fix eslint warnning.
- implement autoenv global file
- autocheck new node js version on new session start
- autocheck updates on my dotfiles repo & my zsh theme.
- autocheck updates of nvim.
- tmux-bar: create custom segments.
- tmux-bar: show spotify playing song and change it from the bar.
=======
![git](https://raw.githubusercontent.com/sfabrizio/dotfiles/master/screenshots/turbo-git.png)

## TMUX

- easy shorcuts thanks to byobu
- beter colors, match with ozono theme
- custom tmux powerline bar

![tmux](https://raw.githubusercontent.com/sfabrizio/dotfiles/master/screenshots/tmux-bar.png)

## TODO:
- ~~install script: install autoenv~~
- ~~install script: should install oh-my-zsh~~
- ~~one command for install all the dependencies OSX~~
- write unit tests
- tmux-bar: create custom segments.
- ~~tmux-bar: show spotify playing song and change it from the bar.~~
- auto updates on dotfiles
- install nvim on script install
- vim: create plugin for auto fix eslint warnning.
- implement autoenv global file
- autocheck new node js version on new session start
- autocheck updates of nvim.
>>>>>>> cf27af3319ff0b4626832d4ddce31e24e8b7ef33

<p align="center">
  <a href="https://github.com/labs-js/turbo-git/blob/develop/README.md"><img src="https://img.shields.io/badge/Turbo_Commit-on-3DD1F2.svg" alt="Turbo Commit: On"/></a>
</p>
