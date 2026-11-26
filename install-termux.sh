#!/usr/bin/env bash
# install-termux.sh — Phase Termux: Termux style + proot-distro Ubuntu.
#
# Run in Termux. Idempotent; safe to re-run.
#
# Usage:
#   ./install-termux.sh              Termux phase only: prepare proot-distro ubuntu
#   ./install-termux.sh --zip FILE   Unpack a local repo zip to ~/setup, then install
#
# This script ONLY does the Termux phase. It does not run the Ubuntu
# phase. After it finishes, log into the distro first, then run
# install-distro.sh from inside it:
#   proot-distro login ubuntu
#   /data/data/com.termux/files/home/setup/install-distro.sh
# Do NOT run it one-shot (proot-distro login ubuntu -- <script>): zsh
# is not fully set up in that context, so the zsh steps are not accepted.
#
# The repo is public. The simplest install is the one-command bootstrap
# (see below), which clones the repo — git is installed first if missing.
# A shared zip still works too. The normal way to install from the zip:
#   1. Copy the zip to Termux home, e.g. ~/setup-termux.zip
#   2. Unpack it:  unzip ~/setup-termux.zip   (creates ~/setup-termux/)
#   3. Run the installer from inside the unpacked dir:
#         ~/setup-termux/install-termux.sh
#   The script uses the files next to it, so the unpacked dir name does not
#   matter. Alternatively, let the script do the unpack for you:
#         ./install-termux.sh --zip ~/setup-termux.zip
#   (unpacks to ~/setup, then continues with the install).
#
# With git access, clone first instead:
#   git clone --branch termux --single-branch https://github.com/skynight137/setup.git ~/setup
#   ~/setup/install-termux.sh
#
# Bootstrap (no repo yet):
#   curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install-termux.sh | bash
#
# How the repo is obtained (in order):
#   1. --zip FILE: unpack that local zip to ~/setup.
#   2. Run from inside a checkout/unpacked dir: use the files next to it.
#   3. git clone (the repo is public).
#   4. If none of those work: the script stops and tells you to copy the
#      shared zip to Termux home and unpack it, or pass it with --zip.
#
# What it does:
#   1. Obtains this repo (checkout, unpacked zip, or clone).
#   2. termux-setup-storage (Android storage permission dialog).
#   3. Copies .termux/{termux.properties,colors.properties,font.ttf} to ~/.termux/
#      and reloads Termux settings.
#   4. Installs proot-distro and the ubuntu distro (skipped if already present).
#   5. Prints the command to run install-distro.sh inside the distro.
# Clean look: fail fast on error. Repair is a separate step — if the
# install fails, the error is visible and the run stops, instead of
# continuing into a half-installed state.
set -euo pipefail

REPO_URL="https://github.com/skynight137/setup.git"
REPO_BRANCH="termux"
REPO_DIR_DEFAULT="$HOME/setup"

ZIP_SRC=""
for arg in "$@"; do
    case "$arg" in
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

# Unpack a local repo zip into $2 (target dir). The zip extracts to a single
# top-level dir (e.g. setup-termux/); that dir's contents become the target.
install_from_zip() {
    local zipfile="$1" target="$2" tmpdir top
    [ -f "$zipfile" ] || { echo "zip not found: $zipfile" >&2; return 1; }
    tmpdir="$(mktemp -d)"
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

# Resolve the repo dir: --zip wins, then a checkout/unpacked dir this script
# lives in, then git clone (the repo is public, so clone works from a fresh
# Termux once git is installed — the installer installs it if missing).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -n "$ZIP_SRC" ]; then
    REPO_DIR="$REPO_DIR_DEFAULT"
    install_from_zip "$ZIP_SRC" "$REPO_DIR" || exit 1
elif [ -d "$SCRIPT_DIR/.termux" ] && [ -d "$SCRIPT_DIR/distro" ]; then
    REPO_DIR="$SCRIPT_DIR"
else
    REPO_DIR="$REPO_DIR_DEFAULT"
    # Fresh Termux has no git. Install it before any clone/pull, otherwise
    # the curl-piped bootstrap fails with "git: command not found".
    # stdin is /dev/null: when run as `curl ... | bash`, a pkg install
    # reading stdin would eat the rest of the piped script.
    if ! command -v git >/dev/null 2>&1; then
        echo "== git not found, installing =="
        pkg install -y git </dev/null || { pkg update -y </dev/null; pkg install -y git </dev/null; }
        command -v git >/dev/null 2>&1 || { echo "ERROR: git is required but could not be installed." >&2; exit 1; }
    fi
    if [ -d "$REPO_DIR/.git" ]; then
        echo "== Repo already at $REPO_DIR, pulling latest =="
        git -C "$REPO_DIR" pull --ff-only || true
    elif git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$REPO_DIR"; then
        echo "== Cloned $REPO_URL (branch $REPO_BRANCH) to $REPO_DIR =="
    else
        echo "ERROR: could not obtain the repo (git clone failed)." >&2
        echo "Check your connection, or copy the shared zip to Termux home, unpack it, then run the installer from inside:" >&2
        echo "  unzip ~/setup-termux.zip" >&2
        echo "  ~/setup-termux/install-termux.sh" >&2
        echo "or pass the zip directly:" >&2
        echo "  $0 --zip ~/setup-termux.zip" >&2
        exit 1
    fi
fi

echo "== Termux storage permission =="
# termux-setup-storage runs here in the installer — it can be forced
# without a manual step. It shows the Android permission dialog; allow
# it and the ~/storage symlinks are created. Retry once in case the
# dialog is slow to appear.
if [ -d "$HOME/storage" ]; then
    echo "Storage already set up."
else
    termux-setup-storage || true
    sleep 2
    if [ ! -d "$HOME/storage" ]; then
        termux-setup-storage || true
        sleep 2
    fi
    if [ -d "$HOME/storage" ]; then
        echo "Storage permission granted."
    else
        echo "WARNING: storage permission was not granted (dialog not allowed)."
        echo "Continuing anyway — storage is only needed for file access (e.g. copying from Downloads), not for the install itself."
    fi
fi

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
echo "Done (Termux phase). Now log into the distro first, then run the Ubuntu phase from inside it:"
echo "  proot-distro login ubuntu"
echo "  $DISTRO_SCRIPT"
echo "(Do not run it one-shot with 'proot-distro login ubuntu -- <script>' — zsh is not fully set up in that context.)"
