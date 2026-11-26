# Termux + proot-distro Ubuntu setup

Two-phase setup: Termux style + Ubuntu (proot-distro) with zsh, oh-my-zsh,
powerlevel10k and plugins. The config files live in this repo (branch `termux`).
Only the Termux phase is scripted (`install-termux.sh`); the Distro phase is
manual copy-paste — every automated attempt at the zsh steps failed the same
way while the same steps run manually always work, so there is no
install-distro.sh. The manual steps are in "Phase Distro (manual)" below.

> Note: this repo is **public**. The one-command bootstrap below works
> from a fresh Termux. A shared zip still works too: copy the zip to
> Termux home, unpack it, and run the installer from inside the
> unpacked dir.

## Layout

```
setup/                  # clone target: ~/setup on Termux
  .termux/              # Termux side -> ~/.termux/
    colors.properties
    font.ttf
    termux.properties
  distro/               # Ubuntu side -> /root/
    .bashrc
    .p10k.zsh
    .zshrc
  install-termux.sh     # Phase Termux (run in Termux)
  # Phase Distro is manual copy-paste — see "Phase Distro (manual)" below.
  # There is no install-distro.sh.
```

## Quick start (fresh Termux)

Two steps, split on purpose. `install-termux.sh` only prepares the
proot distro in Termux; the Distro phase is manual copy-paste
(see "Phase Distro (manual)" below).

Step 1 — Termux phase (one command):

```
curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install-termux.sh | bash
```

The installer installs git first if it is missing, then clones the repo
and runs the Termux phase (storage permission, Termux style, proot-distro
ubuntu install).

Step 2 — Distro phase (manual, inside the distro):

Log in, then follow the steps in "Phase Distro (manual)" below:

```
proot-distro login ubuntu
```

Or install from a shared zip. The shared zip lands in Downloads after
you receive it (e.g. via Telegram).

The installer handles storage access itself (`termux-setup-storage` runs
inside it — allow the permission dialog when it appears). Copy the zip to
Termux home, unpack, and run the installer:

```
pwd    # /data/data/com.termux/files/home
cp /storage/emulated/0/Download/setup-termux.zip .
unzip setup-termux.zip
cd setup-termux
./install-termux.sh            # Termux phase only
```

Then the Distro phase, manual (see "Phase Distro (manual)" below).

Or let the installer unpack the zip for you (unpacks to `~/setup`):

```
./install-termux.sh --zip ~/setup-termux.zip
```

Or, with git access, clone first, then run:

```
pkg install -y git
git clone --branch termux --single-branch https://github.com/skynight137/setup.git ~/setup
~/setup/install-termux.sh
```

The installer obtains the repo in this order: `--zip` first (unpacks a local
zip to `~/setup`), then the local checkout/unpacked dir it runs from, then
`git clone`. If none of those work it stops and tells you to copy the shared zip
to Termux home, unpack it, and run the installer from inside.

What `install-termux.sh` does:

1. Obtains this repo (unpacked zip, local checkout, or clone).
2. `termux-setup-storage` (Android storage permission dialog).
3. Copies `.termux/` to `~/.termux/` and runs `termux-reload-settings`.
4. Installs `proot-distro` and the `ubuntu` distro (skipped if present).
5. Prints the next step: the Phase Distro manual steps in this README.
   (It does not run the Distro phase itself — that is manual copy-paste.)

## Phase Distro (manual)

After the Termux phase, log into the distro and run these steps by hand,
in order. There is no installer for this phase: every automated attempt
at the zsh steps failed the same way while the same steps run manually
always work.

```
proot-distro login ubuntu
```

```
root@localhost:~# pwd
/root
```

### 1. Fix apt sources (do this first, before oh-my-zsh)

The proot image ships a minimal apt source list (often only `main`,
sometimes the wrong mirror for the arch), so apt is missing packages.
Paste this whole block — it rewrites the sources to the complete set
(all components `main restricted universe multiverse`, all pockets
release, `-updates`, `-security`, `-backports`), on the right mirror
for the arch (`ports.ubuntu.com` for arm64/armhf, `archive.ubuntu.com`
otherwise). Handles both the deb822 format
(`/etc/apt/sources.list.d/ubuntu.sources`, Ubuntu 24.04+) and the
one-line format (`/etc/apt/sources.list`). Originals are backed up
to `*.bak`.

```
codename="$(. /etc/os-release; printf '%s' "$VERSION_CODENAME")"
arch="$(dpkg --print-architecture)"
case "$arch" in
  arm64|armhf) mirror="http://ports.ubuntu.com/ubuntu-ports/" ;;
  *) mirror="http://archive.ubuntu.com/ubuntu/" ;;
esac
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
  {
    echo "Types: deb"
    echo "URIs: $mirror"
    echo "Suites: $codename $codename-updates $codename-security $codename-backports"
    echo "Components: main restricted universe multiverse"
    [ -f /usr/share/keyrings/ubuntu-archive-keyring.gpg ] && echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg"
  } > /etc/apt/sources.list.d/ubuntu.sources
  [ -s /etc/apt/sources.list ] && { cp /etc/apt/sources.list /etc/apt/sources.list.bak; printf '# managed by setup; see ubuntu.sources\n' > /etc/apt/sources.list; }
else
  cp /etc/apt/sources.list /etc/apt/sources.list.bak
  for p in "" "-updates" "-security" "-backports"; do
    echo "deb $mirror $codename$p main restricted universe multiverse"
  done > /etc/apt/sources.list
fi
```

### 2. Install base packages

```
apt update -y && apt install -y curl zsh git ca-certificates
```

### 3. Install Oh-My-Zsh

`RUNZSH=no` so it does not spawn an interactive zsh mid-step:

```
RUNZSH=no sh -c "$(curl -fsSL https://install.ohmyz.sh/)"
```

Make zsh root's default shell:

```
chsh -s "$(command -v zsh)"
```

### 4. Download the theme

```
git clone --depth=1 --filter=blob:none https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
```

### 5. Download the plugins

```
git clone --depth=1 --filter=blob:none https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone --depth=1 --filter=blob:none https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth=1 --filter=blob:none https://github.com/joshskidmore/zsh-fzf-history-search ~/.oh-my-zsh/custom/plugins/zsh-fzf-history-search
git clone --depth=1 --filter=blob:none https://github.com/marlonrichert/zsh-autocomplete ~/.oh-my-zsh/custom/plugins/zsh-autocomplete
```

### 6. Restore config (files are in this repo under `distro/`)

```
cp /data/data/com.termux/files/home/setup/distro/.p10k.zsh ~/.p10k.zsh
cp /data/data/com.termux/files/home/setup/distro/.zshrc ~/.zshrc
cp /data/data/com.termux/files/home/setup/distro/.bashrc ~/.bashrc
```

Clear the completion cache so the next zsh start regenerates it fresh
(a stale `~/.zcompdump` from an earlier broken run keeps failing to
find completion functions even after the plugins are healed):

```
rm -f ~/.zcompdump*
```

### 7. Re-login to Ubuntu

```
exit
proot-distro login ubuntu
```

(uv is not installed — not part of this setup.)

## Manual steps (reference)

`install-termux.sh` is the same Termux steps, automated. For reference,
or when debugging a step by hand:

### Phase Termux

Install the Termux app:
[Termux Release](https://github.com/termux/termux-app/releases)

```
$ pwd
/data/data/com.termux/files/home
```

Give storage permission:

```
termux-setup-storage
```

Setup Termux style (files are in this repo under `.termux/`):

```
cp .termux/termux.properties ~/.termux/termux.properties
cp .termux/colors.properties ~/.termux/colors.properties
cp .termux/font.ttf ~/.termux/font.ttf
termux-reload-settings
```

Install proot-distro ubuntu:

```
pkg install -y proot-distro
proot-distro install ubuntu
proot-distro login ubuntu
```

### Phase Distro

See "Phase Distro (manual)" above — that section is the manual steps
(apt sources fix first, then oh-my-zsh, theme, plugins, config restore).
There is no separate reference copy; the two would drift apart.
