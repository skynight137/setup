#!/usr/bin/env bash
# install-termux.sh — Phase Termux: Termux style + proot-distro Ubuntu.
#
# Run in Termux. Idempotent; safe to re-run.
#
# Usage:
#   ./install-termux.sh              Termux phase, then ask to run the Ubuntu phase
#   ./install-termux.sh --auto       Termux phase + run the Ubuntu phase automatically
#   ./install-termux.sh --no-distro  Termux phase only, never touch the distro
#   ./install-termux.sh --zip FILE   Use a repo zip (local file) instead of git clone
#   ./install-termux.sh --zip URL    Use a repo zip (download URL) instead of git clone
#
# Bootstrap (no clone yet):
#   curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install-termux.sh | bash
#
# How the repo is obtained (in order):
#   1. --zip FILE/URL: unpack that zip to ~/setup.
#   2. Run from inside a checkout: use the local files.
#   3. git clone (repo must be public, or git must be authenticated).
#   4. If the clone fails (e.g. repo is private): download the branch zip
#      from GitHub (works once the repo is public) and unpack it.
#   5. If that also fails: the script stops and tells you to make the repo
#      public, or pass a local zip with --zip.
#
# What it does:
#   1. Obtains this repo at ~/setup (clone, local checkout, or zip).
#   2. termux-setup-storage (Android storage permission dialog).
#   3. Copies .termux/{termux.properties,colors.properties,font.ttf} to ~/.termux/
#      and reloads Termux settings.
#   4. Installs proot-distro and the ubuntu distro (skipped if already present).
#   5. Runs the Ubuntu phase (install-distro.sh) inside the distro, or prints
#      the command to run it manually.
set -euo pipefail

REPO_URL="https://github.com/skynight137/setup.git"
REPO_BRANCH="termux"
REPO_ZIP_URL="https://github.com/skynight137/setup/archive/refs/heads/termux.zip"
REPO_DIR_DEFAULT="$HOME/setup"

AUTO=0
NO_DISTRO=0
ZIP_SRC=""
for arg in "$@"; do
    case "$arg" in
        --auto|-y|--yes) AUTO=1 ;;
        --no-distro) NO_DISTRO=1 ;;
        --zip) ZIP_PENDING=1 ;;
        --zip=*) ZIP_SRC="${arg#--zip=}" ;;
        -h|--help)
            sed -n '2,20p' "${BASH_SOURCE[0]:-$0}"
            exit 0
            ;;
        *)
            if [ "${ZIP_PENDING:-0}" -eq 1 ]; then
                ZIP_SRC="$arg"
                ZIP_PENDING=0
            fi
            ;;
    esac
done

# Unpack a repo zip (local file or URL) into $1 (target dir). GitHub branch
# zips extract to a single top-level dir named setup-<branch>; that dir's
# contents become the target dir.
install_from_zip() {
    local src="$1" target="$2" zipfile tmpdir top
    tmpdir="$(mktemp -d)"
    if [ -f "$src" ]; then
        zipfile="$src"
    else
        zipfile="$tmpdir/repo.zip"
        echo "== Downloading repo zip: $src =="
        curl -fsSL -o "$zipfile" "$src" || { echo "zip download failed: $src" >&2; rm -rf "$tmpdir"; return 1; }
    fi
    command -v unzip >/dev/null 2>&1 || pkg install -y unzip
    unzip -q -o "$zipfile" -d "$tmpdir" || { echo "unzip failed: $zipfile" >&2; rm -rf "$tmpdir"; return 1; }
    top="$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -1)"
    [ -n "$top" ] || { echo "zip has no top-level dir" >&2; rm -rf "$tmpdir"; return 1; }
    rm -rf "$target"
    mkdir -p "$(dirname "$target")"
    mv "$top" "$target"
    rm -rf "$tmpdir"
    echo "== Repo unpacked to $target =="
}

# Resolve the repo dir: --zip wins, then a checkout this script lives in,
# then git clone, then the GitHub branch zip as fallback.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -n "$ZIP_SRC" ]; then
    REPO_DIR="$REPO_DIR_DEFAULT"
    install_from_zip "$ZIP_SRC" "$REPO_DIR" || exit 1
elif [ -d "$SCRIPT_DIR/.termux" ] && [ -d "$SCRIPT_DIR/distro" ]; then
    REPO_DIR="$SCRIPT_DIR"
else
    REPO_DIR="$REPO_DIR_DEFAULT"
    if [ -d "$REPO_DIR/.git" ]; then
        echo "== Repo already at $REPO_DIR, pulling latest =="
        git -C "$REPO_DIR" pull --ff-only || true
    elif git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$REPO_DIR" 2>/dev/null; then
        echo "== Cloned $REPO_URL (branch $REPO_BRANCH) to $REPO_DIR =="
    else
        echo "== git clone failed (repo may be private) — trying the branch zip =="
        if ! install_from_zip "$REPO_ZIP_URL" "$REPO_DIR"; then
            echo "ERROR: could not obtain the repo." >&2
            echo "Make the repo public and re-run, or pass a local zip:" >&2
            echo "  $0 --zip /path/to/setup-termux.zip" >&2
            exit 1
        fi
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
