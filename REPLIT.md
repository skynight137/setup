# Generate ssh key
```bash
ssh-keygen -t ed25519 -C "103868701+skynight137@users.noreply.github.com"
```

# Fix permissions (SSH is picky about this) 
```bash
chmod 700 /home/runner/.ssh
chmod 600 /home/runner/.ssh/id_ed25519
chmod 644 /home/runner/.ssh/id_ed25519.pub
```

# Start ssh-agent and add the key
```bash
eval "$(ssh-agent -s)"
ssh-add /home/runner/.ssh/id_ed25519
```

# Copy the public key 
```bash
cat /home/runner/.ssh/id_ed25519.pub
```

# Add to Github 
[GitHub → Settings → SSH and GPG keys → New SSH key](https://github.com/settings/keys)

# Test the connection
```bash
ssh -T git@github.com
```
>You should see: "Hi username! You've successfully authenticated..."

# Point your repo at SSH instead of HTTPS
```bash
cd $HOME/workspace
git remote add origin git@github.com:username/repo.git
git remote -v
git fetch
```
