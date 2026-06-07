#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y zsh git curl ca-certificates gnupg net-tools telnet wget rsync htop python3 apt-transport-https

# Install Oh My Zsh
echo "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="gentoo"/' "$HOME/.zshrc"
sed -i 's/^plugins=(.*)/plugins=(git kubectl history)/' "$HOME/.zshrc"
sudo chsh -s $(which zsh) $(whoami)

# Install SSH keys
install_key() {
    local key="$1"
    [ -z "$key" ] && return
    mkdir -p "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    if ! grep -Fxq "$key" "$HOME/.ssh/authorized_keys"; then
        echo "$key" >> "$HOME/.ssh/authorized_keys"
    fi
}

if [ -n "$SSH_PUBKEYS_JSON" ]; then
    echo "Adding SSH public keys..."
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

if [ -d "$HOME/.ssh" ]; then
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/authorized_keys"
    chown -R $(whoami):$(whoami) "$HOME/.ssh"
fi

# Disable swap (required by Kubernetes)
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/\bswap\b/d' /etc/fstab

# Kernel modules required by containerd/Kubernetes
echo "Configuring kernel modules..."
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl for Kubernetes networking
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Install containerd from Debian's own repos (no third-party repo needed)
echo "Installing containerd..."
sudo apt-get install -y containerd

# Configure containerd with systemd cgroup driver (required for kubeadm)
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Install kubeadm, kubelet, kubectl
echo "Installing Kubernetes v${KUBERNETES_VERSION}..."
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key" | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet

# Install Node Exporter
echo "Installing Node Exporter v${NODE_EXPORTER_VERSION}..."
NODE_EXPORTER_FILENAME="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"
NODE_EXPORTER_TARBALL="${NODE_EXPORTER_FILENAME}.tar.gz"
wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_TARBALL}" \
    -O /tmp/"$NODE_EXPORTER_TARBALL"
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

echo "Kubernetes control plane template provisioning complete."
