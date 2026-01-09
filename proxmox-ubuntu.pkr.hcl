variable "proxmox_api_url" {
  type = string
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

variable "clone_vm_id" {
  type = number
  default = 9000
}

variable "proxmox_node" {
  type = string
  default = "phoenix"
}

variable "node_exporter_version" {
  type    = string
  default = "1.7.0"
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

source "proxmox-clone" "gp-ubuntu-server-24-04" {
    // Proxmox API settings
  proxmox_url              = "${var.proxmox_api_url}"
  node                     = "${var.proxmox_node}"
  insecure_skip_tls_verify = true
  username                 = "${var.proxmox_token_id}"
  token                    = "${var.proxmox_secret}"
  clone_vm_id              = "${var.clone_vm_id}"

    // Template settings
  template_name        = "gp-ubuntu-server-24-04"
  template_description = "General Purpose Ubuntu Server 24.04 LTS. Use this server for general purposes. It's installed with Docker Engine, Oh My Zsh, and some useful tools."
  tags                 = "packer-managed;ubuntu;general-purpose"
  # disks block removed; disk size must be set in the source VM/template
    // VM resources
  cores        = 2
  memory       = 2048
  ssh_username = "ubuntu"
    // Using static IP on purpose
  ssh_host             = "10.0.0.111"
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
    ip      = "10.0.0.111/24"
    gateway = "10.0.0.1"
  }
}

build {
  name    = "gp-ubuntu-server-24-04"
  sources = ["source.proxmox-clone.gp-ubuntu-server-24-04"]
  provisioner "shell" {
    inline = [
        "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }
  provisioner "shell" {
    script = "scripts/provision.sh"
    environment_vars = [
      "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
      # Pass the HCL list as a JSON string for readability and robustness
      "SSH_PUBKEYS_JSON=${jsonencode(var.ssh_public_keys)}"
    ]
  }
}