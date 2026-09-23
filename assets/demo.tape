# dotfiles demo — re-render from the repo root:  vhs assets/demo.tape
# needs: vhs (charmbracelet, PIN v0.9.0 — 0.12's in-process encoder silently
# produces no output on this box), ttyd, ffmpeg, Hack Nerd Font
# (scripts/nerd-font-download.sh). vhs spawns the shell with NO_RCS, so the
# tape sources ~/.zshrc itself to load the real dotfiles environment.

Output assets/demo.gif

Set Shell zsh
Set FontFamily "Hack Nerd Font"
Set FontSize 14
Set Width 1000
Set Height 640
Set Padding 20
Set BorderRadius 10
Set WindowBar Rings
Set Theme "Dracula"
Set TypingSpeed 40ms
Set PlaybackSpeed 1.25

Hide
Type "cd ~/dotfiles" Enter
Type "source ~/.zshrc" Enter
Sleep 800ms
Type "clear" Enter
Sleep 300ms
Show

# -- 1) startup speed ----------------------------------------------------------
Type "echo ' instant startup - nvm, autoenv and tools load lazily'" Enter
Sleep 250ms
Type "bash scripts/startup-check.sh" Enter
Sleep 2300ms

# -- 2) lazy nvm ---------------------------------------------------------------
Type "clear" Enter
Type "echo 'BOLT nvm loads on the first node-family command - not at startup'" Enter
Sleep 250ms
Type "nvm --version" Enter
Sleep 1400ms
Type "time node --version" Enter
Sleep 1400ms
Type "time node --version" Enter
Sleep 1100ms

# -- 3) fzf history (searches the commands typed above) --------------------------
Type "clear" Enter
Type "echo ' fuzzy history with Ctrl-R (fzf)'" Enter
Sleep 250ms
Ctrl+R
Sleep 400ms
Type "startup-check"
Sleep 500ms
Enter
Sleep 300ms
Enter
Sleep 2300ms

# -- 4) bat ----------------------------------------------------------------------
Type "echo ' modern tools: bat, fzf, zoxide, eza are pre-wired'" Enter
Sleep 250ms
Type "bat --style=numbers README.md | head -8" Enter
Sleep 1400ms

# -- 5) the powerline bar (isolated tmux socket, dotfiles tmux.conf) --------------
Type "clear" Enter
Type "echo ' byobu/tmux launch with the clickable powerline bar'" Enter
Sleep 250ms
Type "tmux -L demo new -s demo" Enter
Sleep 2800ms
Type "clear" Enter
Sleep 500ms
Ctrl+T
Type "d"
Sleep 600ms

# -- outro -----------------------------------------------------------------------
Type@20ms "echo   github.com/sfabrizio/dotfiles" Enter
Sleep 400ms
Type@20ms "echo install:  bash install.sh   (or the one-liner in the README)" Enter
Sleep 2000ms
