#!/usr/bin/env bash
# install-distro.sh — Phase Ubuntu: fix apt sources, install zsh + oh-my-zsh,
# powerlevel10k theme, 4 plugins. Minimal and self-contained: it needs no
# local repo files, so it can be run by curl from inside the proot distro.
#
# Run INSIDE an interactive proot-distro login as root:
#   proot-distro login ubuntu
#   curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install-distro.sh | bash
#
# Do NOT run it one-shot (proot-distro login ubuntu -- <script>): zsh
# is not fully set up in that context, so the zsh steps are not accepted
# and the install fails the same way every time. When zsh is run inside
# an interactive zsh session, everything works.
#
# What it does (only these 4 things):
#   1. Fixes apt sources to the complete set (all components + all pockets,
#      correct mirror for the arch) — the proot image ships a minimal list.
#   2. apt install curl zsh git ca-certificates; installs oh-my-zsh
#      unattended (RUNZSH=no: no interactive zsh spawned, no mid-script
#      `exit` needed) and makes zsh root's default shell.
#   3. Clones the powerlevel10k theme.
#   4. Clones the 4 plugins (zsh-syntax-highlighting, zsh-autosuggestions,
#      zsh-fzf-history-search, zsh-autocomplete).
# Each clone is verified healthy (valid git repo + marker file); a directory
# left by an interrupted/partial clone is removed and re-cloned, and the
# clone is retried up to 3 times. The clone output is NOT silenced.
#
# Config files (.bashrc, .p10k.zsh, .zshrc) are NOT copied by this script —
# copy them yourself after (see the README Phase Ubuntu section):
#   cp /data/data/com.termux/files/home/setup/distro/.p10k.zsh ~/.p10k.zsh
#   cp /data/data/com.termux/files/home/setup/distro/.zshrc ~/.zshrc
#   cp /data/data/com.termux/files/home/setup/distro/.bashrc ~/.bashrc
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root inside the distro (proot-distro login ubuntu)." >&2
    exit 1
fi

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

if [ -n "$FAILED_CLONES" ]; then
    echo "" >&2
    echo "ERROR: these clones failed after 3 attempts each:$FAILED_CLONES" >&2
    echo "Re-run this script — it is idempotent and will retry only the failed ones." >&2
    exit 1
fi

echo ""
echo "Done. Now copy the 3 config files:"
echo "  cp /data/data/com.termux/files/home/setup/distro/.p10k.zsh ~/.p10k.zsh"
echo "  cp /data/data/com.termux/files/home/setup/distro/.zshrc ~/.zshrc"
echo "  cp /data/data/com.termux/files/home/setup/distro/.bashrc ~/.bashrc"
echo ""
echo "Then exit and re-login to get zsh + powerlevel10k:"
echo "  exit"
echo "  proot-distro login ubuntu"
