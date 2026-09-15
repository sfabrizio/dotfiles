#!/usr/bin/env bash
# Single source of truth for the dependencies this dotfiles setup pins.
# Sourced by: install.sh, install-pi.sh, scripts/nerd-font-download.sh,
# scripts/deps-check.sh, scripts/deps-apply.sh, scripts/doctor.sh.
#
# The weekly CI workflow (.github/workflows/deps-check.yml) compares these
# pins against upstream and opens a "chore(deps): weekly dependency bump" PR
# that edits THIS file. Machines pick the new pins up via dotfiles-update,
# whose follow-up (scripts/deps-apply.sh) re-installs whatever drifted.
#
# Tiers:
#   Tier 1 - pinned here (a bump = edit this file):
#     TMUX_POWERLINE_PIN, ZOXIDE_VERSION, NVM_VERSION, NF_VERSION,
#     SHUNIT2_VERSION
#   Tier 2 - floating, tracked not pinned (the local check compares installed
#     vs upstream; dotfiles-update re-runs the install command when behind):
#     NPM_PACKAGES, fzf, autoenv. oh-my-zsh keeps its own updater.
#   OS packages (apt/brew) are never pinned: doctor checks version minimums,
#     the deps check offers upgrades.
#
# The DOTFILES_* env overrides on the repo URLs exist for offline tests
# (file:// fixture remotes); never set them outside test fixtures.
#
# ADDING A NEW DEPENDENCY? Read AGENTS.md -> "adding a new dependency" first:
# classify the dep (pinned git / release binary / npm global / floating clone
# / OS package), then touch ONLY the columns this file owns. The three
# responsibilities stay separate:
#   - this file: WHAT version (one pin serves every OS)
#   - deps-lib.sh install fns: WHICH artifact for the machine at apply time
#   - deps_artifacts_exist (deps-lib.sh): proof the release has every OS's
#     artifact BEFORE a bump is offered (release deps MUST register there)

# --- Tier 1 pins -----------------------------------------------------------------
# tmux-powerline commit this dotfiles config is tested against: newer master
# restructured its config system (lib/rcfile.sh gone) and silently ignores
# ~/.tmux-powerlinerc + user themes/segments
TMUX_POWERLINE_PIN="fca0d61"
ZOXIDE_VERSION="0.10.0"
NVM_VERSION="v0.40.3"
NF_VERSION="v3.2.1"          # nerd-fonts release tag (see NF_FONT)
NF_FONT="Hack"               # the font this setup standardizes on
SHUNIT2_VERSION="v2.1.6"     # test-only dependency (fetched on demand by test.sh)

# --- upstream locations ------------------------------------------------------------
TMUX_POWERLINE_REPO="${DOTFILES_TMUX_POWERLINE_REPO:-https://github.com/erikw/tmux-powerline.git}"
NVM_REPO_URL="${DOTFILES_NVM_REPO_URL:-https://github.com/nvm-sh/nvm.git}"
SHUNIT2_REPO_URL="${DOTFILES_SHUNIT2_REPO_URL:-https://github.com/kward/shunit2.git}"
FZF_REPO_URL="${DOTFILES_FZF_REPO_URL:-https://github.com/junegunn/fzf.git}"
AUTOENV_REPO_URL="${DOTFILES_AUTOENV_REPO_URL:-https://github.com/hyperupcall/autoenv.git}"
ZOXIDE_REPO="${DOTFILES_ZOXIDE_REPO:-ajeetdsouza/zoxide}"
NF_REPO="${DOTFILES_NF_REPO:-ryanoasis/nerd-fonts}"
GH_API_BASE="${DOTFILES_GH_API_BASE:-https://api.github.com}"

# --- Tier 2: floating npm globals ----------------------------------------------------
NPM_PACKAGES=(turbo-git diff-so-fancy)

# --- OS packages the dotfiles rely on (apt/brew-managed, never pinned) ---------------
OS_PKGS_UBUNTU=(curl wget git zsh tmux byobu neovim htop fzf ripgrep bat jq unzip)
OS_PKGS_PI=(curl wget git zsh tmux byobu htop fzf ripgrep jq unzip)
OS_PKGS_BREW=(byobu tmux neovim git-extras htop node bat smctemp)
