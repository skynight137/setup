#!/usr/bin/env bash
# install-termux.sh — Phase Termux: Termux style + proot-distro Ubuntu.
#
# Run in Termux. Idempotent; safe to re-run.
#
# Usage:
#   ./install-termux.sh              Termux phase, then ask to run the Ubuntu phase
#   ./install-termux.sh --auto       Termux phase + run the Ubuntu phase automatically
#   ./install-termux.sh --no-distro  Termux phase only, never touch the distro
#   ./install-termux.sh --zip FILE   Unpack a local repo zip to ~/setup, then install
#
# The repo is private, so there is no download from GitHub. The repo is
# shared as a zip file. The normal way to install from the zip:
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
# Bootstrap (no repo yet, repo must be public for this to work):
#   curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install-termux.sh | bash
#
# How the repo is obtained (in order):
#   1. --zip FILE: unpack that local zip to ~/setup.
#   2. Run from inside a checkout/unpacked dir: use the files next to it.
#   3. git clone (needs access to the private repo, or the repo made public).
#   4. If none of those work: the script stops and tells you to copy the
#      shared zip to Termux home and unpack it, or pass it with --zip.
#
# What it does:
#   1. Obtains this repo (checkout, unpacked zip, or clone).
#   2. termux-setup-storage (Android storage permission dialog).
#   3. Copies .termux/{termux.properties,colors.properties,font.ttf} to ~/.termux/
#      and reloads Termux settings.
#   4. Installs proot-distro and the ubuntu distro (skipped if already present).
#   5. Runs the Ubuntu phase (install-distro.sh) inside the distro, or prints
#      the command to run it manually.
# No `set -euo pipefail` here, deliberately. Same reason as install-distro.sh:
# a manual run has no issues; the installer must behave the same way — visible
# output, no silent abort. `set -e` killed the script on the first transient
# failure while output redirected to /dev/null hid where and why it died.

REPO_URL="https://github.com/skynight137/setup.git"
REPO_BRANCH="termux"
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
# lives in, then git clone. No download from GitHub — the repo is private
# and is shared as a zip file.
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
    elif git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$REPO_DIR"; then
        echo "== Cloned $REPO_URL (branch $REPO_BRANCH) to $REPO_DIR =="
    else
        echo "ERROR: could not obtain the repo (git clone failed)." >&2
        echo "The repo is private — copy the shared zip to Termux home, unpack it, then run the installer from inside:" >&2
        echo "  unzip ~/setup-termux.zip" >&2
        echo "  ~/setup-termux/install-termux.sh" >&2
        echo "or pass the zip directly:" >&2
        echo "  $0 --zip ~/setup-termux.zip" >&2
        exit 1
    fi
fi

echo "== Termux storage permission =="
# NOTE: termux-setup-storage needs a foreground terminal to show the
# Android permission dialog. Run from inside a script it often fails
# silently (no dialog appears), while running it manually works. So try
# it here, verify it actually worked, and if not, tell the user to run
# it manually instead of silently continuing without storage access.
if [ -d "$HOME/storage" ]; then
    echo "Storage already set up."
else
    termux-setup-storage || true
    sleep 2
    if [ -d "$HOME/storage" ]; then
        echo "Storage permission granted."
    else
        echo "WARNING: the storage permission dialog did not appear (or was not allowed)."
        echo "Run it manually in Termux, allow the storage permission, then re-run this installer:"
        echo "  termux-setup-storage"
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
