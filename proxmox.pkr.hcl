variable "proxmox_api_url" {
  type    = string
  default = "https://100.106.66.38:8006/api2/json"
}

variable "proxmox_token_id" {
  type      = string
  sensitive = true
}

variable "proxmox_secret" {
  type      = string
  sensitive = true
}

variable "debian_clone_vm_id" {
  type    = number
  default = 9001
}

# Ubuntu 26.04 (Resolute) cloud-image base VM, default cloud-init user `ubuntu`
variable "ubuntu_clone_vm_id" {
  type    = number
  default = 9000
}


variable "proxmox_node" {
  type    = string
  default = "phoenix"
}

variable "node_exporter_version" {
  type    = string
  default = "1.7.0"
}

variable "kubernetes_version" {
  type    = string
  default = "1.32"
}

variable "k3s_version" {
  type    = string
  default = ""
}

# Support multiple SSH public keys using `ssh_public_keys` (list of strings)
# Example:
# ssh_public_keys = [ file("/home/you/.ssh/id_rsa.pub"), "ssh-ed25519 AAAA... user@host" ]

# New: support multiple SSH public keys. Use HCL list of strings, e.g.
# ssh_public_keys = [ file("/home/you/.ssh/id_rsa.pub"), "ssh-ed25519 AAAA... user@host" ]
variable "ssh_public_keys" {
  type    = list(string)
  default = []
}


packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-clone" "gp-debian-trixie-podman" {
  // Proxmox API settings
  proxmox_url              = "${var.proxmox_api_url}"
  node                     = "${var.proxmox_node}"
  insecure_skip_tls_verify = true
  username                 = "${var.proxmox_token_id}"
  token                    = "${var.proxmox_secret}"
  clone_vm_id              = "${var.debian_clone_vm_id}"

  // Template settings
  template_name        = "debian-trixie-podman"
  template_description = "General Purpose Debian 13 (Trixie). Installed with Podman (rootless, daemonless), Oh My Zsh, and some useful tools."
  tags                 = "packer-managed;debian"
  # disks block removed; disk size must be set in the source VM/template
  // VM resources
  cores        = 2
  memory       = 2048
  ssh_username = "debian"
  // Using static IP on purpose
  ssh_host             = "192.168.100.111"
  ssh_private_key_file = "~/.ssh/id_rsa"
  os                   = "l26"
  // Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"
  scsi_controller         = "virtio-scsi-pci"


  // Network Adapters
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }

  // Network Configuration
  nameserver = "1.1.1.1"
  ipconfig {
    ip      = "192.168.100.111/24"
    gateway = "192.168.100.1"
  }
}

build {
  name    = "gp-debian-trixie-podman"
  sources = ["source.proxmox-clone.gp-debian-trixie-podman"]
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }
  provisioner "shell" {
    script = "scripts/debian-podman.sh"
    environment_vars = [
      "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
      # Pass the HCL list as a JSON string for readability and robustness
      "SSH_PUBKEYS_JSON=${jsonencode(var.ssh_public_keys)}"
    ]
  }
}

source "proxmox-clone" "gp-debian-trixie-k3s-server" {
  // Proxmox API settings
  proxmox_url              = "${var.proxmox_api_url}"
  node                     = "${var.proxmox_node}"
  insecure_skip_tls_verify = true
  username                 = "${var.proxmox_token_id}"
  token                    = "${var.proxmox_secret}"
  clone_vm_id              = "${var.debian_clone_vm_id}"

  // Template settings
  template_name        = "debian-trixie-k3s-server"
  template_description = "Debian 13 (Trixie) with k3s (server, service disabled), Oh My Zsh, and Node Exporter."
  tags                 = "packer-managed;debian;k3s"
  # disks block removed; disk size must be set in the source VM/template
  // VM resources
  cores        = 2
  memory       = 2048
  ssh_username = "debian"
  // Using static IP on purpose
  ssh_host             = "192.168.100.112"
  ssh_private_key_file = "~/.ssh/id_rsa"
  os                   = "l26"
  // Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"
  scsi_controller         = "virtio-scsi-pci"

  // Network Adapters
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }

  // Network Configuration
  nameserver = "1.1.1.1"
  ipconfig {
    ip      = "192.168.100.112/24"
    gateway = "192.168.100.1"
  }
}

build {
  name    = "gp-debian-trixie-k3s-server"
  sources = ["source.proxmox-clone.gp-debian-trixie-k3s-server"]
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }
  provisioner "shell" {
    script = "scripts/debian-k3s-server.sh"
    environment_vars = [
      "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
      "K3S_VERSION=${var.k3s_version}",
      # Pass the HCL list as a JSON string for readability and robustness
      "SSH_PUBKEYS_JSON=${jsonencode(var.ssh_public_keys)}"
    ]
  }
}

source "proxmox-clone" "gp-debian-trixie-k3s-agent" {
  // Proxmox API settings
  proxmox_url              = "${var.proxmox_api_url}"
  node                     = "${var.proxmox_node}"
  insecure_skip_tls_verify = true
  username                 = "${var.proxmox_token_id}"
  token                    = "${var.proxmox_secret}"
  clone_vm_id              = "${var.debian_clone_vm_id}"

  // Template settings
  template_name        = "debian-trixie-k3s-agent"
  template_description = "Debian 13 (Trixie) with k3s (agent, service disabled), Oh My Zsh, and Node Exporter."
  tags                 = "packer-managed;debian;k3s"
  # disks block removed; disk size must be set in the source VM/template
  // VM resources
  cores        = 2
  memory       = 2048
  ssh_username = "debian"
  // Using static IP on purpose
  ssh_host             = "192.168.100.113"
  ssh_private_key_file = "~/.ssh/id_rsa"
  os                   = "l26"
  // Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"
  scsi_controller         = "virtio-scsi-pci"

  // Network Adapters
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }

  // Network Configuration
  nameserver = "1.1.1.1"
  ipconfig {
    ip      = "192.168.100.113/24"
    gateway = "192.168.100.1"
  }
}

build {
  name    = "gp-debian-trixie-k3s-agent"
  sources = ["source.proxmox-clone.gp-debian-trixie-k3s-agent"]
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }
  provisioner "shell" {
    script = "scripts/debian-k3s-agent.sh"
    environment_vars = [
      "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
      "K3S_VERSION=${var.k3s_version}",
      # Pass the HCL list as a JSON string for readability and robustness
      "SSH_PUBKEYS_JSON=${jsonencode(var.ssh_public_keys)}"
    ]
  }
}
source "proxmox-clone" "gp-ubuntu-resolute-docker" {
  // Proxmox API settings
  proxmox_url              = "${var.proxmox_api_url}"
  node                     = "${var.proxmox_node}"
  insecure_skip_tls_verify = true
  username                 = "${var.proxmox_token_id}"
  token                    = "${var.proxmox_secret}"
  clone_vm_id              = "${var.ubuntu_clone_vm_id}"
  // Full clone of the 20G cloud-image disk takes longer than the 60s default
  task_timeout = "10m"

  // Template settings
  template_name        = "ubuntu-resolute-docker"
  template_description = "General Purpose Ubuntu 26.04 (Resolute). Installed with Docker CE, Oh My Zsh, Node Exporter, and some useful tools."
  tags                 = "packer-managed;ubuntu;docker"
  # disks block removed; disk size must be set in the source VM/template
  // VM resources
  cores        = 2
  memory       = 2048
  ssh_username = "ubuntu"
  // Using static IP on purpose
  ssh_host             = "192.168.100.114"
  ssh_private_key_file = "~/.ssh/id_rsa"
  os                   = "l26"
  // Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"
  scsi_controller         = "virtio-scsi-pci"

  // Network Adapters
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }

  // Network Configuration
  nameserver = "1.1.1.1"
  ipconfig {
    ip      = "192.168.100.114/24"
    gateway = "192.168.100.1"
  }
}

build {
  name    = "gp-ubuntu-resolute-docker"
  sources = ["source.proxmox-clone.gp-ubuntu-resolute-docker"]
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }
  provisioner "shell" {
    script = "scripts/ubuntu-docker.sh"
    environment_vars = [
      "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
      # Pass the HCL list as a JSON string for readability and robustness
      "SSH_PUBKEYS_JSON=${jsonencode(var.ssh_public_keys)}"
    ]
  }
}
