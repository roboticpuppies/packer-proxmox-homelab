#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Update repositories and install prerequisites
echo "Installing prerequisites..."
sudo apt-get update
# Ensure python3 is available for parsing JSON arrays of SSH keys
sudo apt-get install -y zsh git curl ca-certificates gnupg net-tools telnet wget rsync htop python3

# Install Docker
echo "Installing Docker..."
# Add Docker's official GPG key:
sudo install -m 0755 -d /etc/apt/keyrings
if [ -f /etc/apt/keyrings/docker.gpg ]; then
    sudo rm /etc/apt/keyrings/docker.gpg
fi
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker service and add user to docker group
sudo systemctl enable docker
sudo usermod -aG docker $(whoami)

# Install Oh My Zsh
echo "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh is already installed."
fi

# Configure Zsh
echo "Configuring Zsh..."
# Set theme to gentoo
sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="gentoo"/' "$HOME/.zshrc"
# Set plugins
sed -i 's/^plugins=(.*)/plugins=(git docker docker-compose history)/' "$HOME/.zshrc"

# Change default shell to zsh for the current user
echo "Changing default shell to zsh..."
sudo chsh -s $(which zsh) $(whoami)

# Install one SSH public key (idempotent)
install_key() {
    local key="$1"
    [ -z "$key" ] && return
    mkdir -p "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    # Only add the key if it's not already present
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

# Ensure correct permissions and ownership if we created or modified keys
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

# Create node_exporter systemd service
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

# Create node_exporter user and group
sudo useradd -rs /bin/false node_exporter || true

# Reload systemd, enable and start node_exporter
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo "Installation complete."
