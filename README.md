# Termux + proot-distro Ubuntu setup

Two-phase setup: Termux style + Ubuntu (proot-distro) with zsh, oh-my-zsh,
powerlevel10k and plugins. The config files live in this repo (branch `termux`),
the installers copy them from the local checkout — no curl from another repo.

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

One command, end to end (it prompts before the Ubuntu phase):

```
curl -fsSL https://raw.githubusercontent.com/skynight137/setup/refs/heads/termux/install-termux.sh | bash
```

Or clone first, then run:

```
pkg install -y git
git clone --branch termux --single-branch https://github.com/skynight137/setup.git ~/setup
~/setup/install-termux.sh            # prompts to run the Ubuntu phase
~/setup/install-termux.sh --auto     # also run the Ubuntu phase, no prompt
~/setup/install-termux.sh --no-distro  # Termux phase only
```

What `install-termux.sh` does:

1. Clones this repo to `~/setup` (skipped when run from inside the repo).
2. `termux-setup-storage` (Android storage permission dialog).
3. Copies `.termux/` to `~/.termux/` and runs `termux-reload-settings`.
4. Installs `proot-distro` and the `ubuntu` distro (skipped if present).
5. Runs the Ubuntu phase inside the distro, or prints the command to do it manually.

## Ubuntu phase (manual)

After the Termux phase, from Termux:

```
proot-distro login ubuntu -- /data/data/com.termux/files/home/setup/install-distro.sh
```

Or log in first, then run it inside:

```
proot-distro login ubuntu
/data/data/com.termux/files/home/setup/install-distro.sh
/data/data/com.termux/files/home/setup/install-distro.sh --no-uv   # skip uv
```

What `install-distro.sh` does (all inside the distro, as root):

1. `apt update && apt install curl zsh git ca-certificates`.
2. Installs oh-my-zsh unattended (`RUNZSH=no`, so no interactive zsh is spawned
   and no mid-script `exit` is needed) and makes zsh root's default shell.
3. Clones powerlevel10k + 4 plugins
   (zsh-syntax-highlighting, zsh-autosuggestions, zsh-fzf-history-search,
   zsh-autocomplete).
4. Restores `distro/.bashrc`, `distro/.p10k.zsh`, `distro/.zshrc` to `/root/`.
5. Installs uv (the dotfiles source `~/.local/bin/env`; skip with `--no-uv`).
6. Prints the re-login command.

Then re-login to get zsh + powerlevel10k:

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
cp distro/.p10k.zsh ~/.p10k.zsh
cp distro/.zshrc ~/.zshrc
cp distro/.bashrc ~/.bashrc
```

Install uv package manager (optional):

```
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Re-login to Ubuntu:

```
exit
proot-distro login ubuntu
```
