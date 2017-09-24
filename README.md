# Sam’s dotfiles

This is my personal dotfiles. I created it from scratch. You are free to use it if you want.. But I recommend you create your own dotfiles.. It's a learning journey and It's fun! You can do exactly what you want or you can just take the inpiration for another dotfiles and make it in your own way.

![my shell prompt & my vim](https://raw.githubusercontent.com/sfabrizio/dotfiles/master/screenshots/preview2.png)

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
  - [nodeJs](https://nodejs.org/en/)
  - [turbo-git](https://github.com/labs-js/turbo-git)
  - and  It will copy all the dotfiles doing first a backup of your current ones.


# Features

> This dotfile is more friendly for work with JS enviroments. But I use it with other lenguages too and It's fine.

## ZSH
- custom zsh theme: [ozono](https://github.com/sfabrizio/ozono-zsh-theme)
- [ozono](https://github.com/sfabrizio/ozono-zsh-theme): switch the icon according OS: linux, mac, rasbian, etc.
- [ozono](https://github.com/sfabrizio/ozono-zsh-theme): show node js version only on js projects.
- auto switch node js version enviroment only when it’s necessary. Using Autoenv

## VIM

This configuration work with the regular vim but I'm usin nvim instead.

- code higliting: js, jsx, html,css, scss, etc. linting.
- auto ident js code.
- nerd tree, vim icons, etc.
- eslint_d for faster linting.

## git

- custom shorts alias & turbo git alias
- colors improvements
- global gitconfig & global gitignore

## tmux

- easy shorcuts thanks to byobu
- beter colors, match with ozono theme
- tmux powerline bar

## TODO:
- ~~install script: install autoenv~~
- ~~install script: should install oh-my-zsh~~
- ~~one command for install all the dependencies OSX~~
- auto updates on dotfiles
- install nvim on script install
- vim: create plugin for auto fix eslint warnning.
- implement autoenv global file
- autocheck new node js version on new session start
- autocheck updates of nvim.
- tmux-bar: create custom segments.
- tmux-bar: show spotify playing song and change it from the bar.

<p align="center">
  <a href="https://github.com/labs-js/turbo-git/blob/develop/README.md"><img src="https://img.shields.io/badge/Turbo_Commit-on-3DD1F2.svg" alt="Turbo Commit: On"/></a>
</p>
