# Termux + proot-distro Ubuntu setup

Two-phase setup: Termux style + Ubuntu (proot-distro) with zsh, oh-my-zsh,
powerlevel10k and plugins. The config files live in this repo (branch `termux`),
the installers copy them from the local checkout — no curl from another repo.

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
  install-distro.sh     # Phase Ubuntu (run inside proot-distro ubuntu)
```

## Quick start (fresh Termux)

Two steps, split on purpose. `install-termux.sh` only prepares the
proot distro in Termux; `install-distro.sh` runs separately inside it.

Step 1 — Termux phase (one command):

```
curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install-termux.sh | bash
```

The installer installs git first if it is missing, then clones the repo
and runs the Termux phase (storage permission, Termux style, proot-distro
ubuntu install).

Step 2 — Ubuntu phase (inside the distro):

Log into the distro first, then run the installer from inside it:

```
proot-distro login ubuntu
/data/data/com.termux/files/home/setup/install-distro.sh
```

Do NOT run it one-shot (`proot-distro login ubuntu -- <script>`):
zsh is not fully set up in that context, so the zsh steps are not
accepted and the install fails the same way every time. When zsh is
run inside an interactive zsh session, everything works.

That copies the 3 config files to /root/, then prints the 4 plugin
clone commands for you to run manually.

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

Then run the Ubuntu phase inside the distro (see Step 2 above).

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
5. Prints the command to run `install-distro.sh` inside the distro.
   (It does not run the Ubuntu phase itself — that is a separate step.)

## Ubuntu phase (manual)

After the Termux phase, log into the distro first, then run it inside:

```
proot-distro login ubuntu
/data/data/com.termux/files/home/setup/install-distro.sh
```

Do NOT run it one-shot (`proot-distro login ubuntu -- <script>`):
zsh is not fully set up in that context, so the zsh steps are not
accepted.

What `install-distro.sh` does (all inside the distro, as root):

1. Fixes apt sources to the complete set — the proot image ships a minimal
   list (often only `main`, sometimes the wrong mirror for the arch), so apt
   is missing packages. It rewrites the sources to all components
   (`main restricted universe multiverse`) and all pockets (release,
   `-updates`, `-security`, `-backports`), on the right mirror for the arch
   (`ports.ubuntu.com` for arm64/armhf, `archive.ubuntu.com` otherwise).
   Handles both the deb822 format (`/etc/apt/sources.list.d/ubuntu.sources`,
   Ubuntu 24.04+) and the one-line format (`/etc/apt/sources.list`).
   Originals are backed up to `*.bak`.
2. `apt update && apt install curl zsh git ca-certificates`.
3. Installs oh-my-zsh unattended (`RUNZSH=no`, so no interactive zsh is spawned
   and no mid-script `exit` is needed) and makes zsh root's default shell.
4. Clones the powerlevel10k theme.
5. Restores `distro/.bashrc`, `distro/.p10k.zsh`, `distro/.zshrc` to `/root/`
   (from `/data/data/com.termux/files/home/setup/distro`), then removes
   `~/.zcompdump*` so the next zsh start regenerates a fresh cache.
6. Prints the 4 plugin clone commands for you to run manually, then the
   re-login command. (uv is not installed — not part of this setup.)

Then run the 4 plugin commands it prints, and re-login to get zsh + powerlevel10k:

```
exit
proot-distro login ubuntu
```

Both scripts are idempotent — safe to re-run; installed pieces are skipped.

## Manual steps (reference)

The installers above are the same steps, automated. For reference, or when
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

### Phase Ubuntu

```
root@localhost:~# pwd
/root
```

Install Oh-My-Zsh:

```
apt update -y && apt install -y curl zsh git
sh -c "$(curl -fsSL https://install.ohmyz.sh/)"
exit
```

Download themes:

```
git clone --depth=1 --filter=blob:none https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
```

Download plugins:

```
git clone --depth=1 --filter=blob:none https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone --depth=1 --filter=blob:none https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth=1 --filter=blob:none https://github.com/joshskidmore/zsh-fzf-history-search ~/.oh-my-zsh/custom/plugins/zsh-fzf-history-search
git clone --depth=1 --filter=blob:none https://github.com/marlonrichert/zsh-autocomplete ~/.oh-my-zsh/custom/plugins/zsh-autocomplete
```

Restore config (files are in this repo under `distro/`):

```
cp /data/data/com.termux/files/home/setup/distro/.p10k.zsh ~/.p10k.zsh
cp /data/data/com.termux/files/home/setup/distro/.zshrc ~/.zshrc
cp /data/data/com.termux/files/home/setup/distro/.bashrc ~/.bashrc
```

Re-login to Ubuntu:

```
exit
proot-distro login ubuntu
```
