# dotfiles demo — re-render from the repo root:  vhs assets/demo.tape
# needs: vhs (charmbracelet, PIN v0.9.0 — 0.12's in-process encoder silently
# produces no output on this box), ttyd, ffmpeg, Hack Nerd Font
# (scripts/nerd-font-download.sh). vhs spawns the shell with NO_RCS; the demo
# goes straight into tmux, whose inner zsh loads the real rc files itself.
# The tmux session uses an ISOLATED socket (-L demo) and is killed first -
# never attach the live server from a tape (leaks the user's screen).

Output assets/demo.gif

Set Shell zsh
Set FontFamily "Hack Nerd Font"
Set FontSize 14
Set Width 1080
Set Height 680
Set Padding 16
Set BorderRadius 10
Set WindowBar Rings
Set Theme "Dracula"
Set TypingSpeed 55ms
Set PlaybackSpeed 1.05

Hide
Type "tmux -L demo kill-server 2>/dev/null; cd ~/dotfiles" Enter
Type "clear" Enter
Type "tmux -L demo new -s demo" Enter
Sleep 3500ms
Show

# -- real vim + NERDTree on a real dotfiles segment (full width) ------------------
Type "vim ~/dotfiles/segments/gpu-temp.sh" Enter
Sleep 2500ms
Type ":NERDTree" Enter
Sleep 2500ms
Type "j"
Sleep 400ms
Type "j"
Sleep 400ms
Type "j"
Sleep 500ms
Type ":q" Enter
Sleep 1000ms
Type "/temp" Enter
Sleep 1000ms
Type ":q!" Enter
Sleep 1000ms

# -- vertical split: htop stays alive on the left, work on the right ---------------
Ctrl+T
Type "%"
Sleep 800ms
Ctrl+T
Left
Sleep 300ms
Type "htop" Enter
Sleep 3000ms
Ctrl+T
Right
Sleep 300ms

# -- turbo log (now with convention titles), bat, ripgrep --------------------------
Type "git l" Enter
Sleep 3000ms
Type "bat --color=always --style=numbers ~/dotfiles/scripts/turbo-colors.sh | head -12" Enter
Sleep 2500ms
Type "rg -n --color=always Nerd ~/dotfiles/vimrc | head -6" Enter
Sleep 2200ms

# -- horizontal split: dotfiles-doctor below ---------------------------------------
Ctrl+T
Type '"'
Sleep 800ms
Type "dotfiles-doctor | tail -8" Enter
Sleep 5000ms
Type "echo  github.com/sfabrizio/dotfiles" Enter
Sleep 1500ms

# -- end on htop + the bar: kill everything else from htop's pane ------------------
Ctrl+T
Left
Sleep 400ms
Ctrl+T
Type ":kill-pane -a" Enter
Sleep 2500ms
