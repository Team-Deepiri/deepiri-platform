#!/bin/bash

# ======================================================
# Docker + Buildx + Compose installation script for WSL
# ======================================================

set -e

echo "==> Updating apt and installing dependencies..."
# Continue even if some repositories fail (e.g., ROS repository)
sudo apt update || true
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "==> Setting up Docker's official GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "==> Verifying Docker GPG key fingerprint..."
# Official Docker GPG key fingerprint: 9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88
EXPECTED_FP="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
if command -v gpg >/dev/null 2>&1; then
    KEY_FINGERPRINT=$(sudo gpg --show-keys --with-fingerprint /etc/apt/keyrings/docker.asc 2>/dev/null | \
        grep -A1 "^pub" | grep -i "fingerprint" | sed 's/.*fingerprint = //' | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    if [ "$KEY_FINGERPRINT" = "$EXPECTED_FP" ]; then
        echo "✅ Docker GPG key fingerprint verified"
    else
        echo "⚠️  Warning: GPG key fingerprint verification failed or could not be read"
        echo "   Expected: $EXPECTED_FP"
        echo "   Got: ${KEY_FINGERPRINT:-not found}"
        echo "   Continuing anyway (key downloaded from official Docker source)..."
    fi
else
    echo "⚠️  gpg not found, skipping fingerprint verification"
    echo "   Key downloaded from official Docker source: https://download.docker.com/linux/ubuntu/gpg"
fi

echo "==> Adding Docker repository..."
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Continue even if some repositories fail (e.g., ROS repository)
sudo apt update || true

echo "==> Installing Docker Engine, CLI, Buildx, and Compose..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Adding current user to Docker group..."
sudo addgroup docker || true  # in case the group exists
sudo usermod -aG docker $USER

echo "==> Configuring DNS for better container connectivity..."
RESOLV_CONF="/etc/resolv.conf"
if ! grep -q "1.1.1.1" $RESOLV_CONF; then
    sudo cp $RESOLV_CONF "${RESOLV_CONF}.bak"
    echo -e "nameserver 1.1.1.1" | sudo tee $RESOLV_CONF > /dev/null
    echo "Backed up original resolv.conf to ${RESOLV_CONF}.bak"
fi

echo "==> Setting WSL to use systemd and prevent resolv.conf regen..."
WSL_CONF="/etc/wsl.conf"
if ! grep -q "\[boot\]" $WSL_CONF; then
    sudo bash -c "cat >> $WSL_CONF <<EOL
[boot]
systemd=true

[network]
generateResolvConf=false
EOL"
fi

echo ""
echo "==> Installation complete!"
echo ""
echo "⚠️  IMPORTANT: You need to restart WSL2 for changes to take effect:"
echo "   1. Close this terminal"
echo "   2. In Windows PowerShell (as Administrator), run: wsl --shutdown"
echo "   3. Restart your WSL2 terminal"
echo ""
echo "After restarting, verify installation with:"
echo "   docker version"
echo "   docker buildx version"
echo "   docker ps"
echo ""

