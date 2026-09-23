# dotfiles demo — re-render from the repo root:  vhs assets/demo.tape
# needs: vhs (charmbracelet, PIN v0.9.0 — 0.12's in-process encoder silently
# produces no output on this box), ttyd, ffmpeg, Hack Nerd Font
# (scripts/nerd-font-download.sh). vhs spawns the shell with NO_RCS; the demo
# goes straight into tmux, whose inner zsh loads the real rc files itself.
# The tmux session uses an ISOLATED socket (-L demo) - never attach the live
# server from a tape (leaks the user's screen into the render).

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
Set TypingSpeed 35ms
Set PlaybackSpeed 1.3

Hide
Type "tmux -L demo kill-server 2>/dev/null; cd ~/dotfiles" Enter
Type "clear" Enter
Type "tmux -L demo new -s demo" Enter
Sleep 3000ms
Show

# -- split panes: htop stays alive on the left while we work on the right --------
Ctrl+T
Type "%"
Sleep 400ms
Ctrl+T
Left
Sleep 200ms
Type "htop" Enter
Sleep 2500ms

# -- real vim on a real dotfiles segment ------------------------------------------
Ctrl+T
Right
Sleep 250ms
Type "vim ~/dotfiles/segments/gpu-temp.sh" Enter
Sleep 2000ms
Type "/temp" Enter
Sleep 800ms
Type ":q!" Enter
Sleep 600ms

# -- turbo log (colorful) + bat ---------------------------------------------------
Type "git l" Enter
Sleep 2500ms
Type "bat --style=numbers ~/dotfiles/alias | head -14" Enter
Sleep 1800ms

# -- tmux layouts cycle ------------------------------------------------------------
Ctrl+T
Type " "
Sleep 800ms
Ctrl+T
Type " "
Sleep 800ms

# -- sign off, then close the work pane - demo ends on htop + the bar -------------
Type "echo  github.com/sfabrizio/dotfiles" Enter
Sleep 1200ms
Ctrl+T
Type "x"
Sleep 600ms
Type "y"
Sleep 2000ms
