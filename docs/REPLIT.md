# REPLIT x GITHUB

## Generate ssh key
```bash
# save to project path avoid $HOME reset
mkdir -p ~/workspace/.local/.ssh

# symlink
ln -sfn ~/workspace/.local/.ssh ~/.ssh

# generate key
ssh-keygen -t ed25519 -C "103868701+skynight137@users.noreply.github.com" -f ~/workspace/.local/.ssh/id_ed25519 -N "passphrase"


```

## Fix permissions
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

## Start ssh-agent and add the key
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

## Copy the public key 
```bash
cat ~/.ssh/id_ed25519.pub
```

## Add to Github
[GitHub → Settings → SSH and GPG keys → New SSH key](https://github.com/settings/keys)

## Test the connection
```bash
ssh -T git@github.com
```
> [!IMPORTANT]
> **You should see:** "Hi username! You've successfully authenticated..."

## Point your repo at SSH instead of HTTPS
```bash
git remote add origin git@github.com:username/repo.git
git remote -v
git fetch
```
 
