#!/usr/bin/env bash
# install-termux.sh — Phase Termux: Termux style + proot-distro Ubuntu.
#
# Run in Termux. Idempotent; safe to re-run.
#
# Usage:
#   ./install-termux.sh              Termux phase, then ask to run the Ubuntu phase
#   ./install-termux.sh --auto       Termux phase + run the Ubuntu phase automatically
#   ./install-termux.sh --no-distro  Termux phase only, never touch the distro
#
# Bootstrap (no clone yet):
#   curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install-termux.sh | bash
#
# What it does:
#   1. Clones this repo to ~/setup (skipped when run from inside the repo).
#   2. termux-setup-storage (Android storage permission dialog).
#   3. Copies .termux/{termux.properties,colors.properties,font.ttf} to ~/.termux/
#      and reloads Termux settings.
#   4. Installs proot-distro and the ubuntu distro (skipped if already present).
#   5. Runs the Ubuntu phase (install-distro.sh) inside the distro, or prints
#      the command to run it manually.
set -euo pipefail

REPO_URL="https://github.com/skynight137/setup.git"
REPO_BRANCH="termux"
REPO_DIR_DEFAULT="$HOME/setup"

AUTO=0
NO_DISTRO=0
for arg in "$@"; do
    case "$arg" in
        --auto|-y|--yes) AUTO=1 ;;
        --no-distro) NO_DISTRO=1 ;;
        -h|--help)
            sed -n '2,20p' "${BASH_SOURCE[0]:-$0}"
            exit 0
            ;;
    esac
done

# Resolve the repo dir: use the checkout this script lives in when it has
# the payload dirs, otherwise clone to ~/setup.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -d "$SCRIPT_DIR/.termux" ] && [ -d "$SCRIPT_DIR/distro" ]; then
    REPO_DIR="$SCRIPT_DIR"
else
    REPO_DIR="$REPO_DIR_DEFAULT"
    if [ ! -d "$REPO_DIR/.git" ]; then
        echo "== Cloning $REPO_URL (branch $REPO_BRANCH) to $REPO_DIR =="
        git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$REPO_DIR"
    else
        echo "== Repo already at $REPO_DIR, pulling latest =="
        git -C "$REPO_DIR" pull --ff-only || true
    fi
fi

echo "== Termux storage permission =="
termux-setup-storage || true
echo "(If Android shows a storage permission dialog, allow it.)"

echo "== Termux style =="
mkdir -p "$HOME/.termux"
cp "$REPO_DIR/.termux/termux.properties" "$HOME/.termux/termux.properties"
cp "$REPO_DIR/.termux/colors.properties" "$HOME/.termux/colors.properties"
cp "$REPO_DIR/.termux/font.ttf" "$HOME/.termux/font.ttf"
termux-reload-settings || true

echo "== proot-distro ubuntu =="
pkg update -y || echo "(pkg update failed, continuing with cached lists)"
pkg install -y proot-distro
if proot-distro list 2>/dev/null | grep -qw ubuntu; then
    echo "ubuntu distro already installed, skipping."
else
    proot-distro install ubuntu
fi

DISTRO_SCRIPT="$REPO_DIR/install-distro.sh"
chmod +x "$DISTRO_SCRIPT" 2>/dev/null || true

echo ""
echo "== Phase Ubuntu =="
echo "Run inside the distro with:"
echo "  proot-distro login ubuntu -- $DISTRO_SCRIPT"
echo "or manually:"
echo "  proot-distro login ubuntu"
echo "  $DISTRO_SCRIPT"

if [ "$NO_DISTRO" -eq 0 ]; then
    RUN_DISTRO=0
    if [ "$AUTO" -eq 1 ]; then
        RUN_DISTRO=1
    elif [ -t 0 ]; then
        read -r -p "Run the Ubuntu setup now? [y/N] " ans
        case "$ans" in
            [yY]*) RUN_DISTRO=1 ;;
        esac
    fi
    if [ "$RUN_DISTRO" -eq 1 ]; then
        echo "== Running Ubuntu phase inside the distro =="
        proot-distro login ubuntu -- "$DISTRO_SCRIPT"
    fi
fi

echo ""
echo "Done (Termux phase). Re-login to the distro to get zsh + powerlevel10k."
