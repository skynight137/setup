# SSH & GitHub Authentication

> Sandbox note: loose files directly under `$HOME` are wiped on restart. `~/workspace` is the persistent project mount — store secrets there, not directly in `$HOME`.

## 1. Generate SSH key

```bash
mkdir -p ~/workspace/.local/.ssh

ssh-keygen -t ed25519 -C "103868701+skynight137@users.noreply.github.com" \
  -f ~/workspace/.local/.ssh/id_ed25519 -N "your-real-passphrase-here"
```

## 2. Fix permissions

```bash
chmod 700 ~/workspace/.local/.ssh
chmod 600 ~/workspace/.local/.ssh/id_ed25519
chmod 644 ~/workspace/.local/.ssh/id_ed25519.pub
```

## 3. Symlink `~/.ssh` to the persistent path

```bash
rm -rf ~/.ssh
ln -sfn ~/workspace/.local/.ssh ~/.ssh
```

Add this `rm -rf ~/.ssh` + `ln -sfn` step to your startup script — `~/.ssh` resets with `$HOME`, so it needs to be re-linked every restart.

## 4. Add public key to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```
[GitHub → Settings → SSH and GPG keys → New SSH key](https://github.com/settings/keys)

## 5. (Optional) ssh-agent — avoid re-typing passphrase every push/pull

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

## 6. Test connection

```bash
ssh -T git@github.com
```
Expect: `Hi username! You've successfully authenticated...`
First time only, it'll ask to confirm the host key — type `yes`.

## 7. Point repo at SSH

```bash
git remote set-url origin git@github.com:username/repo.git
git fetch
```

---

## 8. Same key on multiple PCs

**Recommended: generate a separate key per PC**, add each public key to GitHub separately (labeled per device). If one PC is lost, revoke just that key.

**If you specifically want to reuse the same key pair on PC2:**

```bash
# PC1 — archive the real key files (-h dereferences the ~/.ssh symlink)
tar -czhf ssh-backup.tar.gz -C ~/workspace/.local .ssh
tar -tvf ssh-backup.tar.gz   # confirm id_ed25519 / .pub are listed, not a symlink entry
```

Transfer via `scp` or an encrypted USB — never email/chat.

```bash
# PC2 — extract and re-link
mkdir -p ~/workspace/.local
tar -xzf ssh-backup.tar.gz -C ~/workspace/.local
chmod 700 ~/workspace/.local/.ssh
chmod 600 ~/workspace/.local/.ssh/id_ed25519
chmod 644 ~/workspace/.local/.ssh/id_ed25519.pub
rm -rf ~/.ssh
ln -sfn ~/workspace/.local/.ssh ~/.ssh
ssh -T git@github.com
```

Trade-off: one shared key means one compromised PC = revoke on both, and no per-device audit trail.

---

## 9. Where secrets actually live

| Method | File | Risk |
|---|---|---|
| Token in remote URL | `.git/config` | ❌ plaintext, easy leak |
| `credential.helper store` | `~/.git-credentials` | ❌ plaintext |
| SSH key + passphrase | `~/.ssh/id_ed25519` | ✅ encrypted at rest |
| SSH key, no passphrase | `~/.ssh/id_ed25519` | ⚠️ file itself = full access |

Minimum hygiene regardless of method: `chmod 600` the secret file, scope tokens narrowly, set expiration where possible, never sync the file to untrusted storage.
 
