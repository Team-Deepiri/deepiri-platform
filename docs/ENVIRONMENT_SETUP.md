# Deepiri — Environment Setup

> **Source of truth.** If the Discord setup pinned message and this file ever disagree, this file wins. Update this file and the Discord message together.

---

## Prerequisites

### Windows

1. **WSL2** — Windows Subsystem for Linux (run all dev work inside WSL2, not native Windows)
   - [Install WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) — open PowerShell as Administrator and run:
     ```powershell
     wsl --install
     ```
   - Restart your machine after install. Default distro is Ubuntu.

2. **Docker** — install Docker GPG key and Docker Engine through WSL2 (not Docker Desktop)
   ```bash
   # Inside WSL2 Ubuntu terminal:
   sudo apt-get update
   sudo apt-get install ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
     -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc

   echo \
     "deb [arch=$(dpkg --print-architecture) \
     signed-by=/etc/apt/keyrings/docker.asc] \
     https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

   sudo apt-get update
   sudo apt-get install docker-ce docker-ce-cli containerd.io \
     docker-buildx-plugin docker-compose-plugin

   # Allow running docker without sudo
   sudo usermod -aG docker $USER
   newgrp docker
   ```
   Verify: `docker run hello-world`

3. **Python 3.11+**
   ```bash
   sudo apt-get install python3 python3-pip python3-venv
   python3 --version
   ```

4. **Git**
   ```bash
   sudo apt-get install git
   git --version
   ```

5. **Node.js 20+** (via nvm — recommended)
   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
   source ~/.bashrc
   nvm install 20
   nvm use 20
   node --version
   ```

---

### macOS

1. **Homebrew** — package manager for macOS
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
   Follow the post-install instructions to add Homebrew to your `PATH`.

2. **Docker Desktop**
   ```bash
   brew install --cask docker
   ```
   Open the Docker app and let it finish setup. Verify: `docker run hello-world`

3. **Python 3.11+**
   ```bash
   brew install python
   python3 --version
   ```

4. **Git**
   ```bash
   brew install git
   git --version
   ```

5. **Node.js 20+** (via nvm — recommended)
   ```bash
   brew install nvm
   # Follow the brew post-install instructions to add nvm to your shell profile, then:
   nvm install 20
   nvm use 20
   node --version
   ```

---

## SSH Key Setup & GitHub

You need an SSH key to push/pull from GitHub without entering a password every time.

### Generate the key

**WSL2 (Windows) or macOS Terminal:**
```bash
ssh-keygen -t ed25519 -C "your_github_email@example.com"
```
- Press Enter to accept the default file location (`~/.ssh/id_ed25519`)
- Set a passphrase (recommended) or press Enter to skip

### Add the key to ssh-agent
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Add the public key to GitHub
```bash
cat ~/.ssh/id_ed25519.pub
```
Copy the output, then:
1. Go to [GitHub → Settings → SSH and GPG keys](https://github.com/settings/keys)
2. Click **New SSH key**
3. Give it a name (e.g. `WSL2 Ubuntu` or `MacBook Pro`)
4. Paste the key and save

### Verify the connection
```bash
ssh -T git@github.com
# Expected: Hi <your-username>! You've successfully authenticated...
```

### Configure Git identity (required before your first commit)
```bash
git config --global user.name "Your Name"
git config --global user.email "your_github_email@example.com"
```

---

## Cloning the Deepiri Platform

```bash
git clone git@github.com:deepiri/<repo-name>.git
cd <repo-name>
```

> Replace `<repo-name>` with the actual repository name. Ask in Discord `#dev-setup` if you're unsure which repo to start with.

---

## Verifying Your Setup

Run this checklist after following the steps above:

```bash
docker --version          # Docker 24+
python3 --version         # Python 3.11+
node --version            # Node 20+
git --version             # Git 2.40+
ssh -T git@github.com     # Authenticated successfully
```

All five should return a version or success message. If anything fails, check the **Troubleshooting** section below or ask in `#dev-setup`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `docker: permission denied` | Run `sudo usermod -aG docker $USER` then `newgrp docker` |
| `ssh: connect to host github.com port 22` | Try `ssh -T -p 443 git@ssh.github.com` — your network may block port 22 |
| `nvm: command not found` | Restart your terminal or run `source ~/.bashrc` / `source ~/.zshrc` |
| Python not found | Use `python3` explicitly, or `sudo apt install python-is-python3` (WSL2) |
| Homebrew not in PATH (Mac) | Follow the instructions printed at the end of the Homebrew install script |

For platform-specific issues, see [`docs/troubleshooting/TROUBLESHOOTING.md`](./troubleshooting/TROUBLESHOOTING.md).

---

*Last updated: 2026-05-08 · Maintainer: @deepiri/platform-eng*
