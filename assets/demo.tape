# dotfiles demo — re-render from the repo root:  vhs assets/demo.tape
# needs: vhs (charmbracelet, PIN v0.9.0 — 0.12's in-process encoder silently
# produces no output on this box), ttyd, ffmpeg, Hack Nerd Font
# (scripts/nerd-font-download.sh). vhs spawns the shell with NO_RCS; the demo
# goes straight into tmux, whose inner zsh loads the real rc files itself.
# The tmux session uses an ISOLATED socket (-L demo) and is killed first -
# never attach the live server from a tape (leaks the user's screen).
# Keep the commands plain and the pacing uneven - it should read like a
# human at a terminal, not a script exercising flags.

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
Set PlaybackSpeed 1.0

Hide
Type "tmux -L demo kill-server 2>/dev/null; cd ~/dotfiles" Enter
Type "clear" Enter
Type "tmux -L demo new -s demo" Enter
Sleep 3500ms
Show

# -- vim + NERDTree on a real dotfiles segment (full width) -----------------------
Type "vim segments/gpu-temp.sh" Enter
Sleep 2500ms
Type ":NERDTree" Enter
Sleep 2500ms
Type "j"
Sleep 500ms
Type "j"
Sleep 700ms
Type "j"
Sleep 600ms
Type ":q" Enter
Sleep 1200ms
Type "/temp" Enter
Sleep 1100ms
Type ":q!" Enter
Sleep 1200ms

# -- vertical split: turbo log on the left -----------------------------------------
Ctrl+T
Type "%"
Sleep 900ms
Ctrl+T
Left
Sleep 400ms
Type "git l" Enter
Sleep 3000ms
Ctrl+T
Right
Sleep 500ms

# -- bat with its pager, then a quick search ---------------------------------------
Type "bat README.md" Enter
Sleep 2800ms
Type "q"
Sleep 1200ms
Type "rg nerd" Enter
Sleep 2500ms

# -- horizontal split: the health check ---------------------------------------------
Ctrl+T
Type '"'
Sleep 900ms
Type "dotfiles-doctor" Enter
Sleep 6000ms
Type "echo  github.com/sfabrizio/dotfiles" Enter
Sleep 1800ms

# -- close the doctor pane the human way - end on two panes + the bar ---------------
Ctrl+T
Type "x"
Sleep 700ms
Type "y"
Sleep 2500ms
