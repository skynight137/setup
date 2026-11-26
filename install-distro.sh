#!/usr/bin/env bash
# install-distro.sh — Phase Ubuntu: zsh + oh-my-zsh + powerlevel10k + plugins + uv.
#
# Run INSIDE proot-distro ubuntu as root. Idempotent; safe to re-run.
#
# Usage (from inside the distro):
#   /data/data/com.termux/files/home/setup/install-distro.sh
#   /data/data/com.termux/files/home/setup/install-distro.sh --no-uv
#
# Or from Termux (one command, runs the same script inside the distro):
#   proot-distro login ubuntu -- /data/data/com.termux/files/home/setup/install-distro.sh
#
# What it does:
#   1. Fixes apt sources to the complete set (all components + all pockets,
#      correct mirror for the arch) — the proot image ships a minimal list.
#   2. apt install curl zsh git ca-certificates.
#   3. Installs oh-my-zsh unattended (RUNZSH=no: no interactive zsh spawned,
#      no mid-script `exit` needed) and makes zsh root's default shell.
#   4. Clones the powerlevel10k theme + 4 plugins.
#   5. Restores distro/.bashrc, distro/.p10k.zsh, distro/.zshrc to /root/.
#   6. Installs uv (default on; the dotfiles source ~/.local/bin/env).
#   7. Prints the re-login command to get zsh + powerlevel10k.
set -euo pipefail

WITH_UV=1
for arg in "$@"; do
    case "$arg" in
        --no-uv) WITH_UV=0 ;;
        -h|--help)
            sed -n '2,20p' "${BASH_SOURCE[0]:-$0}"
            exit 0
            ;;
    esac
done

# Repo dir = the dir this script lives in. From inside the distro the Termux
# home path is reachable, so the repo's distro/ files are right next to it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DISTRO_DIR="$SCRIPT_DIR/distro"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root inside the distro (proot-distro login ubuntu)." >&2
    exit 1
fi
for f in .bashrc .p10k.zsh .zshrc; do
    [ -f "$DISTRO_DIR/$f" ] || { echo "Missing $DISTRO_DIR/$f" >&2; exit 1; }
done

# fix_apt_sources — the proot-distro Ubuntu image ships a minimal apt source
# list (often only `main`, sometimes the wrong mirror for the arch), so apt
# is missing packages. Rewrite it to the complete set: all components
# (main restricted universe multiverse) and all pockets (release, -updates,
# -security, -backports), on the right mirror for the arch. Handles both
# formats: deb822 (/etc/apt/sources.list.d/ubuntu.sources, Ubuntu 24.04+)
# and one-line (/etc/apt/sources.list). Originals are backed up to *.bak.
fix_apt_sources() {
    local codename arch mirror components
    codename="$(. /etc/os-release 2>/dev/null; printf '%s' "${VERSION_CODENAME:-}")"
    if [ -z "$codename" ] && command -v lsb_release >/dev/null 2>&1; then
        codename="$(lsb_release -cs 2>/dev/null || true)"
    fi
    if [ -z "$codename" ]; then
        echo "WARNING: could not detect Ubuntu codename, leaving apt sources alone." >&2
        return 0
    fi
    arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    case "$arch" in
        arm64|armhf) mirror="http://ports.ubuntu.com/ubuntu-ports/" ;;
        *) mirror="http://archive.ubuntu.com/ubuntu/" ;;
    esac
    components="main restricted universe multiverse"
    echo "== apt sources: $codename ($arch) via $mirror =="
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak 2>/dev/null || true
        {
            echo "Types: deb"
            echo "URIs: $mirror"
            echo "Suites: $codename $codename-updates $codename-security $codename-backports"
            echo "Components: $components"
            if [ -f /usr/share/keyrings/ubuntu-archive-keyring.gpg ]; then
                echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
            fi
        } > /etc/apt/sources.list.d/ubuntu.sources
        # A stale one-line list next to the deb822 file would duplicate
        # every source; back it up and neutralise it.
        if [ -s /etc/apt/sources.list ]; then
            cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
            printf '# managed by install-distro.sh; see ubuntu.sources\n' > /etc/apt/sources.list
        fi
    else
        [ -f /etc/apt/sources.list ] && cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
        {
            for pocket in "" "-updates" "-security" "-backports"; do
                echo "deb $mirror $codename$pocket $components"
            done
        } > /etc/apt/sources.list
    fi
}
fix_apt_sources

echo "== apt base =="
apt update -y
apt install -y curl zsh git ca-certificates

echo "== oh-my-zsh =="
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    # RUNZSH=no: install without spawning an interactive zsh, so the script
    # keeps running instead of needing a manual `exit` like the README.
    RUNZSH=no sh -c "$(curl -fsSL https://install.ohmyz.sh/)"
else
    echo "oh-my-zsh already installed."
fi

# Make zsh root's default shell (the installer already tries this; this is
# the fallback so a re-login lands in zsh even if the installer skipped it).
if [ "$(basename "${SHELL:-/bin/bash}")" != "zsh" ]; then
    chsh -s "$(command -v zsh)" || true
fi

echo "== powerlevel10k theme =="
THEME_DIR="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$THEME_DIR" ]; then
    git clone --depth=1 --filter=blob:none https://github.com/romkatv/powerlevel10k.git "$THEME_DIR"
else
    echo "powerlevel10k already present."
fi

echo "== plugins =="
for spec in \
    "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting" \
    "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions" \
    "zsh-fzf-history-search https://github.com/joshskidmore/zsh-fzf-history-search" \
    "zsh-autocomplete https://github.com/marlonrichert/zsh-autocomplete" ; do
    name="${spec%% *}"
    url="${spec#* }"
    dest="$HOME/.oh-my-zsh/custom/plugins/$name"
    if [ ! -d "$dest" ]; then
        git clone --depth=1 --filter=blob:none "$url" "$dest"
    else
        echo "$name already present."
    fi
done

echo "== restore config =="
cp "$DISTRO_DIR/.bashrc" "$HOME/.bashrc"
cp "$DISTRO_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
cp "$DISTRO_DIR/.zshrc" "$HOME/.zshrc"

if [ "$WITH_UV" -eq 1 ]; then
    echo "== uv =="
    if ! command -v uv >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        echo "uv already installed."
    fi
fi

echo ""
echo "Done. Exit and re-login to get zsh + powerlevel10k:"
echo "  exit"
echo "  proot-distro login ubuntu"
