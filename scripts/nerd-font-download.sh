#!/usr/bin/env bash
# Install a patched Nerd Font (needed by the tmux powerline bar icons).
# Usage: nerd-font-download.sh [FontName] [Version]
#   FontName: any release asset of github.com/ryanoasis/nerd-fonts, e.g.
#             Hack, DroidSansMono, FiraCode, JetBrainsMono
#   Version:  a nerd-fonts release tag (default: v3.2.1)
# Default: Hack - the font this dotfiles setup standardizes on; install the
# SAME font on every machine you connect from (the bar separators render at
# the size of the terminal's font, so mismatched fonts look different).
# Idempotent: skips when the font already sits in the user font directory.

set -u

FONT_NAME="${1:-Hack}"
NF_VERSION="${2:-v3.2.1}"
URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/${FONT_NAME}.zip"

PLATFORM="$(uname -s)"
case "$PLATFORM" in
    Darwin)
        FONT_DIR="$HOME/Library/Fonts"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # per-user font dir (Windows 10 1809+): no admin rights needed
        FONT_DIR="${LOCALAPPDATA:-$HOME/AppData/Local}/Microsoft/Windows/Fonts"
        ;;
    *)
        FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
        ;;
esac

# the linux/osx zip flow installs every variant, so ANY match means installed;
# windows installs a single Mono TTF and must fall through to its own check
case "$PLATFORM" in
    MINGW*|MSYS*|CYGWIN*) : ;;
    *)
        if compgen -G "$FONT_DIR/*${FONT_NAME}*" >/dev/null 2>&1 \
            || compgen -G "$HOME/.fonts/*${FONT_NAME}*" >/dev/null 2>&1; then
            echo "==> $FONT_NAME nerd font already installed - skip"
            exit 0
        fi
        ;;
esac

command -v curl >/dev/null 2>&1 || { echo "curl is required. Please install it first."; exit 1; }

# --- windows: single-file per-user install ----------------------------------------
# The zip flow below needs unzip (not shipped by every Git for Windows); the
# single Mono Regular TTF matches the font the server machines standardize on
# (the bar separators must render at the same size from every terminal), and
# registering it under HKCU makes it visible to Windows Terminal without
# admin rights.
case "$PLATFORM" in
    MINGW*|MSYS*|CYGWIN*)
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/raw/${NF_VERSION}/patched-fonts/${FONT_NAME}/Regular/${FONT_NAME}NerdFontMono-Regular.ttf"
        FONT_FILE="$FONT_DIR/${FONT_NAME}NerdFontMono-Regular.ttf"
        FONT_REG_KEY='HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        FONT_REG_NAME="${FONT_NAME} Nerd Font Mono Regular (TrueType)"
        # reg.exe is a native Windows binary: git-bash mangles /flag arguments
        # into POSIX paths ("Invalid syntax") unless conversion is disabled
        reg_cmd() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' reg "$@"; }

        # idempotent only when BOTH the file and the registry entry exist -
        # a partial install (file without registration) must self-heal
        if [ -f "$FONT_FILE" ] \
            && reg_cmd query "$FONT_REG_KEY" /v "$FONT_REG_NAME" >/dev/null 2>&1; then
            echo "==> $FONT_NAME Nerd Font Mono already installed and registered - skip"
            exit 0
        fi

        if [ ! -f "$FONT_FILE" ]; then
            echo "==> downloading $FONT_NAME Nerd Font Mono Regular ($NF_VERSION) - per-user install"
            echo "    $FONT_URL"
            mkdir -p "$FONT_DIR"
            if ! curl -fL --progress-bar -o "$FONT_FILE" "$FONT_URL"; then
                echo "download failed - check the font name and release tag at:"
                echo "  https://www.nerdfonts.com/font-downloads"
                rm -f "$FONT_FILE"
                exit 1
            fi
        fi
        FONT_FILE_WIN="$(cygpath -w "$FONT_FILE" 2>/dev/null || printf '%s' "$FONT_FILE")"
        echo "==> registering the font for the current user (HKCU Fonts)"
        if reg_cmd add "$FONT_REG_KEY" /v "$FONT_REG_NAME" /t REG_SZ /d "$FONT_FILE_WIN" /f; then
            echo "==> done: $FONT_NAME Nerd Font Mono installed in $FONT_DIR"
        else
            echo "    [warn] registry registration unavailable - if Windows Terminal"
            echo "           does not list the font, install it manually (double-click):"
            echo "           $FONT_FILE_WIN"
        fi
        echo "    set it as the terminal font (profile: git-bash (dotfiles)), then restart WT"
        exit 0
        ;;
esac

command -v unzip >/dev/null 2>&1 || { echo "unzip is required. Please install it first (apt install unzip / brew install unzip)."; exit 1; }

TMP_ZIP="$(mktemp /tmp/nerd-font-XXXXXX.zip)"
trap 'rm -f "$TMP_ZIP"' EXIT

echo "==> downloading $FONT_NAME ($NF_VERSION)"
echo "    $URL"
if ! curl -fL --progress-bar -o "$TMP_ZIP" "$URL"; then
    echo "download failed - check the font name and release tag at:"
    echo "  https://www.nerdfonts.com/font-downloads"
    exit 1
fi

mkdir -p "$FONT_DIR"
if ! unzip -o -q "$TMP_ZIP" -d "$FONT_DIR"; then
    echo "unzip failed - the downloaded file may be corrupt"
    exit 1
fi

if command -v fc-cache >/dev/null 2>&1; then
    echo "==> refreshing font cache"
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1
fi

echo "==> done: $FONT_NAME installed in $FONT_DIR"
echo "    select it as your terminal font, then restart the terminal"
