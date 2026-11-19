> [!NOTE]
> I'm using AI to help me write the code and troubleshoot errors. At the same time I was learning Packer and agentic IDE.

## Overview

This repository contains Packer configuration to build VM templates for my homelab:
- `debian-trixie-podman` — Debian 13 with Podman (rootless/daemonless), Oh My Zsh, Node Exporter
- `debian-trixie-k3s-server` — Debian 13 with k3s (server, service disabled), Oh My Zsh, Node Exporter
- `debian-trixie-k3s-agent` — Debian 13 with k3s (agent, service disabled), Oh My Zsh, Node Exporter
- `ubuntu-resolute-docker` — Ubuntu 26.04 with Docker CE, Oh My Zsh, Node Exporter

## How to build

1. Make sure you already have an API token and secret from Proxmox VE.
2. Copy `example.pkrvars.hcl` to `variables.auto.pkrvars.hcl`.
3. Fill the variables in `variables.auto.pkrvars.hcl` (`proxmox_token_id`, `proxmox_secret`, `ssh_public_keys`, e.g. `ssh_public_keys = [ file("/home/you/.ssh/id_rsa.pub") ]`). The build passes the list as a JSON array internally for readability and robustness.
4. Build with `make podman`, `make k3s`, `make k3s-agent`, `make ubuntu-docker`, or `make all`.
5. The resulting template will be available in Proxmox VE.

> [!IMPORTANT]
> Each template clones a source VM (`clone_vm_id` variables, defaults 9001 for Debian, 9000 for Ubuntu) and SSHes to a **static IP** during the build (`192.168.100.111/.112/.113/.114`). If you run this on your own Proxmox server, make sure to change `proxmox_api_url`, `proxmox_node`, the `*_clone_vm_id` variables, `ssh_host`, `ssh_private_key_file`, and the `ipconfig` blocks in `proxmox.pkr.hcl` to match your environment, and make sure the source VMs exist on the target node.

## Setting up a k3s cluster

The k3s templates install the `k3s` binary with the systemd service **disabled** (`INSTALL_K3S_SKIP_ENABLE=true`), so every clone boots clean with no cluster state. You configure and enable the service after cloning.

### 1. Create the server node

1. In Proxmox, clone the `debian-trixie-k3s-server` template to a new VM (give it its own VM ID and IP — don't reuse the build-time static IP `192.168.100.112` for a long-lived node, or change it via cloud-init).
2. SSH in and start k3s:
   ```bash
   sudo systemctl enable --now k3s
   ```
3. (Optional, for HA / multiple servers later) Before or right after first start, set `cluster-init: true` in `/etc/rancher/k3s/config.yaml` and restart:
   ```bash
   echo "cluster-init: true" | sudo tee -a /etc/rancher/k3s/config.yaml
   sudo systemctl restart k3s
   ```
4. Get the kubeconfig for `kubectl`:
   ```bash
   sudo cat /etc/rancher/k3s/k3s.yaml
   ```
   Copy this to your workstation's `~/.kube/config`, replacing `server: https://127.0.0.1:6443` with `https://<server-ip>:6443`.
5. Get the join token (needed for agents/additional servers):
   ```bash
   sudo cat /var/lib/rancher/k3s/server/node-token
   ```

### 2. Add an agent/worker node

1. Clone the `debian-trixie-k3s-agent` template to a new VM (own VM ID and IP).
2. SSH in and write `/etc/rancher/k3s/config.yaml`:
   ```yaml
   server: https://<server-ip>:6443
   token: <TOKEN from step 1.5>
   ```
3. Enable and start the agent:
   ```bash
   sudo systemctl enable --now k3s-agent
   ```
4. From the server (or your workstation with kubeconfig set up), confirm the node joined:
   ```bash
   kubectl get nodes
   ```

Repeat step 2 for each additional worker. Use the same `debian-trixie-k3s-agent` clone steps for every worker — only the VM ID/IP differ.
