#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Update repositories and install prerequisites
echo "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y zsh git curl ca-certificates gnupg net-tools telnet wget rsync htop

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

echo "Installation complete."
