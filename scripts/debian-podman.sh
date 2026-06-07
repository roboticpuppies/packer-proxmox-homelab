#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y zsh git curl ca-certificates gnupg net-tools telnet wget rsync htop python3 uidmap

# Install Podman (daemonless, rootless container runtime)
echo "Installing Podman..."
sudo apt-get install -y podman podman-compose podman-docker

# Configure rootless Podman subuid/subgid for the current user
CURRENT_USER=$(whoami)
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$CURRENT_USER" || true

# Install Oh My Zsh
echo "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh is already installed."
fi

# Configure Zsh
echo "Configuring Zsh..."
sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="gentoo"/' "$HOME/.zshrc"
sed -i 's/^plugins=(.*)/plugins=(git docker docker-compose podman history)/' "$HOME/.zshrc"
echo 'alias docker=podman' >> "$HOME/.zshrc"

# Change default shell to zsh for the current user
echo "Changing default shell to zsh..."
sudo chsh -s $(which zsh) $(whoami)

# Install one SSH public key (idempotent)
install_key() {
    local key="$1"
    [ -z "$key" ] && return
    mkdir -p "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    if ! grep -Fxq "$key" "$HOME/.ssh/authorized_keys"; then
        echo "$key" >> "$HOME/.ssh/authorized_keys"
    fi
}

# Support multiple keys via SSH_PUBKEYS_JSON (JSON array)
if [ -n "$SSH_PUBKEYS_JSON" ]; then
    echo "Adding provided SSH public keys from JSON array to authorized_keys..."
    echo "$SSH_PUBKEYS_JSON" | python3 -c '
import sys, json
try:
    keys = json.load(sys.stdin)
except Exception:
    keys = []
for k in keys:
    if k:
        print(k)
' | while IFS= read -r k; do
        install_key "$k"
    done
fi

# Ensure correct permissions and ownership
if [ -d "$HOME/.ssh" ]; then
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/authorized_keys"
    chown -R $(whoami):$(whoami) "$HOME/.ssh"
fi

# Install Node Exporter
echo "Installing Node Exporter v${NODE_EXPORTER_VERSION}..."
NODE_EXPORTER_FILENAME="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"
NODE_EXPORTER_TARBALL="${NODE_EXPORTER_FILENAME}.tar.gz"
NODE_EXPORTER_DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_TARBALL}"

wget "$NODE_EXPORTER_DOWNLOAD_URL" -O /tmp/"$NODE_EXPORTER_TARBALL"
sudo tar -xvf /tmp/"$NODE_EXPORTER_TARBALL" -C /usr/local/bin --strip-components=1 "$NODE_EXPORTER_FILENAME"/node_exporter

sudo bash -c 'cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'

sudo useradd -rs /bin/false node_exporter || true
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo "Installation complete."
