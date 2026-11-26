# Termux + proot-distro Ubuntu setup

One-script setup: Termux style + Ubuntu (proot-distro) with zsh, oh-my-zsh,
powerlevel10k and plugins. The config files live in this repo (branch `termux`).
`install.sh` does both phases in one run — Termux phase, then the Distro
phase inside proot-distro ubuntu automatically. There is no separate
distro installer and no manual Distro steps.

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
  install.sh            # Full setup: Termux phase + Distro phase
```

## Quick start (fresh Termux)

One command, one run — it does the Termux phase, then the Distro phase
inside proot-distro ubuntu automatically:

```
curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install.sh | bash
```

The installer installs git first if it is missing, then clones the repo
and runs both phases. When it finishes, log in (zsh is now root's
default shell):

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
./install.sh
```

Or let the installer unpack the zip for you (unpacks to `~/setup`):

```
./install.sh --zip ~/setup-termux.zip
```

Or, with git access, clone first, then run:

```
pkg install -y git
git clone --branch termux --single-branch https://github.com/skynight137/setup.git ~/setup
~/setup/install.sh
```

The installer obtains the repo in this order: `--zip` first (unpacks a local
zip to `~/setup`), then the local checkout/unpacked dir it runs from, then
`git clone`. If none of those work it stops and tells you to copy the shared zip
to Termux home, unpack it, and run the installer from inside.

What `install.sh` does:

1. Obtains this repo (unpacked zip, local checkout, or clone).
2. `termux-setup-storage` (Android storage permission dialog).
3. Copies `.termux/` to `~/.termux/` and runs `termux-reload-settings`.
4. Installs `proot-distro` and the `ubuntu` distro (skipped if present).
5. Runs the Distro phase inside proot-distro ubuntu (see below). The
   Distro phase is a script this installer writes into the distro
   rootfs and runs via `proot-distro login ubuntu` — not a separate
   file in the repo.

## Phase Distro (in the script)

`install.sh` runs this phase automatically inside proot-distro ubuntu.
No manual steps. What it does, in order:

1. **Fix apt sources first** (before oh-my-zsh). The proot image ships a
   minimal apt source list, so apt is missing packages. Rewrites the
   sources to the complete set (all components `main restricted universe
   multiverse`, all pockets release, `-updates`, `-security`, `-backports`),
   on the right mirror for the arch (`ports.ubuntu.com` for arm64/armhf,
   `archive.ubuntu.com` otherwise). Handles both the deb822 format
   (`/etc/apt/sources.list.d/ubuntu.sources`, Ubuntu 24.04+) and the
   one-line format (`/etc/apt/sources.list`). Originals are backed up
   to `*.bak` (only if no backup exists yet).
2. **Install base packages:** `apt update -y && apt install -y curl zsh git ca-certificates`,
   plus `zsh-syntax-highlighting` and `zsh-autosuggestions` (see Plugins below).
3. **Install Oh-My-Zsh** (`RUNZSH=no` so it does not spawn an interactive
   zsh mid-step), then make zsh root's default shell (`chsh -s`).
4. **Download the theme:** powerlevel10k.
5. **Download the plugins:** only `marlonrichert/zsh-autocomplete` is
   cloned (see Plugins below).
6. **Bridge the apt-provided plugins into oh-my-zsh** (see Plugins below).
7. **Restore config** (files are in this repo under `distro/`):
   `.p10k.zsh`, `.zshrc`, `.bashrc` to `/root/`.
8. **Clear the completion cache** (`rm -f ~/.zcompdump*`) so the next
   zsh start regenerates it fresh.
9. Done — log in with `proot-distro login ubuntu`.

(uv is not installed — not part of this setup.)

## Plugins

The `.zshrc` in this repo loads:
`colorize zsh-syntax-highlighting zsh-autosuggestions zsh-interactive-cd zsh-autocomplete`.

- `colorize`, `zsh-interactive-cd` — oh-my-zsh built-ins, no install needed.
- `zsh-syntax-highlighting`, `zsh-autosuggestions` — ship with zsh (apt
  packages). Installed via apt, then bridged into oh-my-zsh: the
  installer writes a small `.plugin.zsh` for each that sources the apt
  file (`/usr/share/zsh-.../*.zsh`), so oh-my-zsh's `plugins=(...)`
  loads them. Not cloned.
- `zsh-autocomplete` — the only cloned plugin
  (`marlonrichert/zsh-autocomplete`).
- `zsh-fzf-history-search` — not installed (small help, not recommended).

## Manual steps (reference)

`install.sh` is the same steps, automated. For reference, or when
debugging a step by hand:

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

See "Phase Distro (in the script)" above — that section is the Distro
phase (apt sources fix first, then oh-my-zsh, theme, plugins, config
restore). There is no separate reference copy; the two would drift apart.
