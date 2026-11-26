#!/usr/bin/env bash
# install-distro.sh — Phase Ubuntu: zsh + oh-my-zsh + powerlevel10k + plugins + uv.
#
# Run INSIDE proot-distro ubuntu as root. Idempotent; safe to re-run.
#
# Usage (from inside the distro):
#   /data/data/com.termux/files/home/setup/install-distro.sh
#   /data/data/com.termux/files/home/setup/install-distro.sh --no-uv
#   /data/data/com.termux/files/home/setup/install-distro.sh --doctor
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
#   4. Clones the powerlevel10k theme + 4 plugins. Each clone is verified
#      healthy (valid git repo + marker file); a directory left by an
#      interrupted/partial clone is removed and re-cloned, so re-running
#      the installer heals a broken plugin instead of skipping it.
#   5. Restores distro/.bashrc, distro/.p10k.zsh, distro/.zshrc to /root/,
#      then removes ~/.zcompdump* so the next zsh start regenerates a
#      fresh completion cache (must come after the plugins + config are
#      in place — a stale cache from an earlier broken run is what made
#      zsh fail to find _autocomplete__unambiguous).
#   6. Installs uv (default on; the dotfiles source ~/.local/bin/env).
#   7. Prints the re-login command to get zsh + powerlevel10k, and a
#      notice to run --doctor if zsh shows completion errors.
#
# --doctor (repair mode, run after zsh is installed): checks .bashrc,
# .p10k.zsh, .zshrc against the repo (restores any that are missing or
# differ), then deletes and re-clones the 4 plugins, then clears
# ~/.zcompdump*. The main install can leave the plugins in a state zsh
# does not like even when the files look complete; deleting and
# re-cloning after zsh has prepared itself is the fix that works.
set -euo pipefail

WITH_UV=1
DOCTOR=0
for arg in "$@"; do
    case "$arg" in
        --no-uv) WITH_UV=0 ;;
        --doctor) DOCTOR=1 ;;
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

# ensure_clone <url> <dest> <marker> — clone the repo to dest, unless dest
# is already a healthy clone (valid git repo + marker file present).
# A plain `[ -d ]` check is not enough: a directory left by an
# interrupted/partial clone looks "present" but is broken, and the old
# script skipped it, leaving the broken plugin in place. This verifies
# health and re-clones when it is not healthy, so re-running the
# installer heals a bad theme/plugin instead of silently keeping it.
# The clone is retried up to 3 times and the marker is verified after
# each attempt, so a transient network failure does not leave a partial
# clone behind. The clone output is NOT silenced — like a manual run,
# you see what git actually did, and a failure is visible, not hidden.
ensure_clone() {
    local url="$1" dest="$2" marker="$3" attempt=0
    if [ -d "$dest/.git" ] && git -C "$dest" rev-parse --git-dir >/dev/null 2>&1 && [ -f "$dest/$marker" ]; then
        echo "$(basename "$dest") already present."
        return 0
    fi
    while [ "$attempt" -lt 3 ]; do
        attempt=$((attempt + 1))
        [ -e "$dest" ] && rm -rf "$dest"
        if git clone --depth=1 --filter=blob:none "$url" "$dest" && [ -f "$dest/$marker" ]; then
            return 0
        fi
        echo "clone of $(basename "$dest") failed or incomplete, retrying ($attempt/3)..." >&2
        sleep 2
    done
    echo "ERROR: failed to clone $url after 3 attempts." >&2
    return 1
}

# --doctor: repair mode, run after zsh is installed. The main install can
# leave the plugins in a state zsh does not like even when the files look
# complete; deleting and re-cloning after zsh has prepared itself is the
# fix that works. Checks the config files, then force re-clones the 4
# plugins, then clears the completion cache.
if [ "$DOCTOR" -eq 1 ]; then
    echo "== doctor: checking config files =="
    for f in .bashrc .p10k.zsh .zshrc; do
        if [ ! -f "$HOME/$f" ]; then
            echo "$f: MISSING — restoring from repo"
            cp "$DISTRO_DIR/$f" "$HOME/$f"
        elif ! cmp -s "$DISTRO_DIR/$f" "$HOME/$f"; then
            echo "$f: DIFFERS from repo — restoring"
            cp "$DISTRO_DIR/$f" "$HOME/$f"
        else
            echo "$f: ok (matches repo)"
        fi
    done
    echo "== doctor: re-cloning 4 plugins =="
    DOCTOR_FAILED=""
    for spec in \
        "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting" \
        "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions" \
        "zsh-fzf-history-search https://github.com/joshskidmore/zsh-fzf-history-search" \
        "zsh-autocomplete https://github.com/marlonrichert/zsh-autocomplete" ; do
        name="${spec%% *}"
        url="${spec#* }"
        dest="$HOME/.oh-my-zsh/custom/plugins/$name"
        rm -rf "$dest"
        ensure_clone "$url" "$dest" "$name.plugin.zsh" || DOCTOR_FAILED="$DOCTOR_FAILED $name"
    done
    echo "== doctor: clearing completion cache =="
    rm -f "$HOME"/.zcompdump*
    if [ -n "$DOCTOR_FAILED" ]; then
        echo "ERROR: these plugins still failed to clone:$DOCTOR_FAILED" >&2
        exit 1
    fi
    echo ""
    echo "Doctor done. Re-login or run: exec zsh"
    exit 0
fi

FAILED_CLONES=""
echo "== powerlevel10k theme =="
ensure_clone https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" "powerlevel10k.zsh-theme" || FAILED_CLONES="$FAILED_CLONES powerlevel10k"

echo "== plugins =="
for spec in \
    "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting" \
    "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions" \
    "zsh-fzf-history-search https://github.com/joshskidmore/zsh-fzf-history-search" \
    "zsh-autocomplete https://github.com/marlonrichert/zsh-autocomplete" ; do
    name="${spec%% *}"
    url="${spec#* }"
    dest="$HOME/.oh-my-zsh/custom/plugins/$name"
    ensure_clone "$url" "$dest" "$name.plugin.zsh" || FAILED_CLONES="$FAILED_CLONES $name"
done

echo "== restore config =="
cp "$DISTRO_DIR/.bashrc" "$HOME/.bashrc"
cp "$DISTRO_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
cp "$DISTRO_DIR/.zshrc" "$HOME/.zshrc"

# ORDER MATTERS: remove the completion cache AFTER the plugins are in
# place AND the config is restored. A ~/.zcompdump generated by an
# earlier run (when a plugin was broken/incomplete) is stale: zsh keeps
# using it and fails to find completion functions like
# _autocomplete__unambiguous even after the plugin is healed. Removing
# it here forces the next zsh start to regenerate a fresh cache with all
# plugins present. This is the stale-cache fix — it is NOT about
# --filter=blob:none (that was correctly reverted; the filter was never
# the problem).
rm -f "$HOME"/.zcompdump*

if [ "$WITH_UV" -eq 1 ]; then
    echo "== uv =="
    if ! command -v uv >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        echo "uv already installed."
    fi
fi

if [ -n "$FAILED_CLONES" ]; then
    echo "" >&2
    echo "ERROR: these clones failed after 3 attempts each:$FAILED_CLONES" >&2
    echo "Re-run this script — it is idempotent and will retry only the failed ones." >&2
    exit 1
fi

echo ""
echo "Done. Exit and re-login to get zsh + powerlevel10k:"
echo "  exit"
echo "  proot-distro login ubuntu"
echo ""
echo "If zsh shows completion errors (e.g. \"command not found: _autocomplete__unambiguous\"), run the doctor:"
echo "  proot-distro login ubuntu -- /data/data/com.termux/files/home/setup/install-distro.sh --doctor"
