#!/usr/bin/env bash
# install.sh — Termux + proot-distro Ubuntu, single script.
#
# Run in Termux. Idempotent; safe to re-run.
#
# Usage:
#   ./install.sh              Full setup: Termux phase + Distro phase
#   ./install.sh --zip FILE   Unpack a local repo zip to ~/setup, then install
#
# This is the ONLY installer. It does both phases in one run:
#   Phase Termux (in Termux): storage, Termux style, proot-distro ubuntu.
#   Phase Distro (inside proot-distro ubuntu, run automatically): apt
#     sources fix, base packages, oh-my-zsh, powerlevel10k theme,
#     zsh-autocomplete plugin, config restore.
#
# Plugins: zsh-syntax-highlighting and zsh-autosuggestions ship with zsh
# (apt packages) — installed via apt and bridged into oh-my-zsh, not
# cloned. Only marlonrichert/zsh-autocomplete is cloned.
# zsh-fzf-history-search is not installed (small help, not recommended).
#
# The repo is public. The simplest install is the one-command bootstrap
# (see below), which clones the repo — git is installed first if missing.
# A shared zip still works too. The normal way to install from the zip:
#   1. Copy the zip to Termux home, e.g. ~/setup-termux.zip
#   2. Unpack it:  unzip ~/setup-termux.zip   (creates ~/setup-termux/)
#   3. Run the installer from inside the unpacked dir:
#         ~/setup-termux/install.sh
#   The script uses the files next to it, so the unpacked dir name does not
#   matter. Alternatively, let the script do the unpack for you:
#         ./install.sh --zip ~/setup-termux.zip
#   (unpacks to ~/setup, then continues with the install).
#
# With git access, clone first instead:
#   git clone --branch termux --single-branch https://github.com/skynight137/setup.git ~/setup
#   ~/setup/install.sh
#
# Bootstrap (no repo yet):
#   curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install.sh | bash
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
#   5. Runs the Distro phase inside proot-distro ubuntu (apt sources fix,
#      base packages, oh-my-zsh, powerlevel10k, zsh-autocomplete, config
#      restore). The Distro phase is a script this installer writes into
#      the distro rootfs and runs via `proot-distro login ubuntu` — it is
#      NOT a separate file in the repo.
#   6. Prints the next step: log in (zsh is now root's default shell).
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
        echo "  ~/setup-termux/install.sh" >&2
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
pkg update -y </dev/null || echo "(pkg update failed, continuing with cached lists)"
pkg install -y proot-distro </dev/null
if proot-distro list 2>/dev/null | grep -qw ubuntu; then
    echo "ubuntu distro already installed, skipping."
else
    proot-distro install ubuntu
fi

# ---- Phase Distro (inside proot-distro ubuntu) ----
# The Distro phase runs as root inside the ubuntu distro. It is written
# here, into the distro rootfs, and executed via `proot-distro login` —
# one script, no separate distro installer file. The script file is
# removed after the run (trap), success or failure.
echo "== Distro phase (inside proot-distro ubuntu) =="
DISTRO_ROOT="${PREFIX:-/data/data/com.termux/files/usr}/var/lib/proot-distro/installed-rootfs/ubuntu"
[ -d "$DISTRO_ROOT" ] || { echo "ERROR: ubuntu rootfs not found at $DISTRO_ROOT" >&2; exit 1; }
DISTRO_SCRIPT="$DISTRO_ROOT/root/.setup-distro.sh"
trap 'rm -f "$DISTRO_SCRIPT"' EXIT
cat > "$DISTRO_SCRIPT" <<'DISTRO_EOF'
#!/usr/bin/env bash
# Distro phase — runs as root inside proot-distro ubuntu.
# Generated by install.sh (single script). Idempotent; safe to re-run.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
REPO_DIR="@REPO_DIR@"

echo "== Fix apt sources (first, before oh-my-zsh) =="
# The proot image ships a minimal apt source list (often only main,
# sometimes the wrong mirror for the arch), so apt is missing packages.
# Rewrite to the complete set (all components, all pockets) on the right
# mirror for the arch. Handles both deb822 and one-line formats.
# Originals are backed up to *.bak (only if no backup exists yet).
codename="$(. /etc/os-release; printf '%s' "$VERSION_CODENAME")"
arch="$(dpkg --print-architecture)"
case "$arch" in
  arm64|armhf) mirror="http://ports.ubuntu.com/ubuntu-ports/" ;;
  *) mirror="http://archive.ubuntu.com/ubuntu/" ;;
esac
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  [ -f /etc/apt/sources.list.d/ubuntu.sources.bak ] || cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
  {
    echo "Types: deb"
    echo "URIs: $mirror"
    echo "Suites: $codename $codename-updates $codename-security $codename-backports"
    echo "Components: main restricted universe multiverse"
    [ -f /usr/share/keyrings/ubuntu-archive-keyring.gpg ] && echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
  } > /etc/apt/sources.list.d/ubuntu.sources
  [ -s /etc/apt/sources.list ] && { [ -f /etc/apt/sources.list.bak ] || cp /etc/apt/sources.list /etc/apt/sources.list.bak; printf '# managed by setup; see ubuntu.sources\n' > /etc/apt/sources.list; }
else
  [ -f /etc/apt/sources.list.bak ] || cp /etc/apt/sources.list /etc/apt/sources.list.bak
  for p in "" "-updates" "-security" "-backports"; do
    echo "deb $mirror $codename$p main restricted universe multiverse"
  done > /etc/apt/sources.list
fi

echo "== Base packages =="
apt update -y
apt install -y curl zsh git ca-certificates
# zsh-syntax-highlighting + zsh-autosuggestions ship with zsh (apt
# packages). Install them so oh-my-zsh can load them via the bridge
# files below. Not fatal if the packages are unavailable — the other
# plugins still work, and the bridge step warns instead of failing.
apt install -y zsh-syntax-highlighting zsh-autosuggestions || echo "WARNING: could not apt-install zsh-syntax-highlighting/zsh-autosuggestions; those two plugins will not load."

echo "== Oh-My-Zsh =="
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no sh -c "$(curl -fsSL https://install.ohmyz.sh/)"
else
  echo "oh-my-zsh already installed, skipping."
fi
chsh -s "$(command -v zsh)"

# ensure_clone <url> <dest> — clone unless dest is already a healthy
# clone (a .git dir). A plain `[ -d ]` check is not enough: a directory
# left by an interrupted/partial clone looks "present" but is broken.
# Retried up to 3 times; the clone output is NOT silenced.
ensure_clone() {
  local url="$1" dest="$2" i
  if [ -d "$dest/.git" ]; then
    echo "Already present: $dest"
    return 0
  fi
  rm -rf "$dest"
  for i in 1 2 3; do
    if git clone --depth=1 --filter=blob:none "$url" "$dest"; then
      return 0
    fi
    echo "Clone failed (attempt $i/3), retrying..." >&2
    rm -rf "$dest"
    sleep 2
  done
  echo "ERROR: could not clone $url" >&2
  return 1
}

echo "== Theme: powerlevel10k =="
ensure_clone https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"

echo "== Plugin: zsh-autocomplete (the only cloned plugin) =="
ensure_clone https://github.com/marlonrichert/zsh-autocomplete.git "$HOME/.oh-my-zsh/custom/plugins/zsh-autocomplete"

echo "== Bridge apt-provided plugins into oh-my-zsh =="
# The apt packages install to /usr/share, where oh-my-zsh never looks.
# Each bridge is a small .plugin.zsh that sources the apt file, so the
# file's own path (and its highlighters dir) resolves correctly.
bridge_plugin() {
  local name="$1" aptfile="$2" dir
  dir="$HOME/.oh-my-zsh/custom/plugins/$name"
  if [ -f "$aptfile" ]; then
    mkdir -p "$dir"
    printf '# Provided by the %s apt package (ships with zsh).\nsource %s\n' "$name" "$aptfile" > "$dir/$name.plugin.zsh"
    echo "Bridged $name from $aptfile"
  else
    echo "WARNING: $aptfile not found — $name will not load." >&2
  fi
}
bridge_plugin zsh-syntax-highlighting /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
bridge_plugin zsh-autosuggestions /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

echo "== Restore config =="
# Termux home is visible inside proot at the same absolute path, so the
# repo dir resolved in Termux works here too.
cp "$REPO_DIR/distro/.p10k.zsh" "$HOME/.p10k.zsh"
cp "$REPO_DIR/distro/.zshrc" "$HOME/.zshrc"
cp "$REPO_DIR/distro/.bashrc" "$HOME/.bashrc"

echo "== Clear completion cache =="
# A stale ~/.zcompdump from an earlier broken run keeps failing to find
# completion functions even after the plugins are healed.
rm -f "$HOME/.zcompdump*"

echo "Distro phase done."
DISTRO_EOF
sed -i "s|@REPO_DIR@|$REPO_DIR|g" "$DISTRO_SCRIPT"
chmod +x "$DISTRO_SCRIPT"
proot-distro login ubuntu -- bash /root/.setup-distro.sh

echo ""
echo "Done. Log in (zsh is now root's default shell):"
echo "  proot-distro login ubuntu"
