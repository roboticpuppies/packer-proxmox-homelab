# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Packer config that builds Proxmox VM templates for a homelab. It clones an existing Proxmox VM, provisions it via shell script, and converts it to a reusable template.

Current templates:
- `debian-trixie-podman` — Debian 13 (Trixie) with Podman (rootless/daemonless), Oh My Zsh, Node Exporter
- `ubuntu-2404-base` — Ubuntu 24.04 LTS with Oh My Zsh, Node Exporter (no container runtime)
- `debian-trixie-k8s-control-plane` — Debian 13 (Trixie) with containerd, kubeadm, kubelet, kubectl, Node Exporter

## Commands

```bash
# Build specific template
make podman   # debian-trixie-podman
make base     # ubuntu-2404-base
make all      # both of the above

# Build directly
packer build -only="gp-debian-trixie-podman.*" proxmox.pkr.hcl

# Verbose / debug build
PACKER_LOG=1 PACKER_LOG_PATH=packer.log packer build -debug proxmox.pkr.hcl

# Validate config without building
packer validate proxmox.pkr.hcl

# Format HCL
packer fmt proxmox.pkr.hcl
```

There are no tests. Verification = a successful `packer build` producing the template on the Proxmox node.

## Architecture

Two-file build pipeline:

1. **`proxmox.pkr.hcl`** — source `"proxmox-clone"` blocks plus `build` blocks (one per template).
   - Uses the `github.com/hashicorp/proxmox` plugin (`proxmox-clone` builder), NOT an ISO install. It clones `clone_vm_id` (default `9000`) on node `proxmox_node`.
   - VM uses a **static IP** (`ssh_host` and `ipconfig.ip` must match, default `192.168.100.111/24`). Packer SSHes to this fixed address during the build.
   - Each `build` has two provisioners: (a) inline wait loop on `/var/lib/cloud/instance/boot-finished` so cloud-init finishes first, then (b) the relevant shell script.

2. **`scripts/debian-podman.sh`** — runs inside the Debian Trixie cloned VM. Installs Podman (rootless, via `podman podman-compose podman-docker`), configures subuid/subgid for rootless containers, Oh My Zsh (theme `gentoo`, plugins `git docker docker-compose history`), common utils, and Node Exporter (systemd service). Sets default shell to zsh. SSH username: `debian`.

3. **`scripts/ubuntu-base.sh`** — runs inside the Ubuntu 24.04 cloned VM. Installs Oh My Zsh, common utils, and Node Exporter. No container runtime. SSH username: `ubuntu`.

4. **`scripts/debian-k8s-control-plane.sh`** — runs inside the Debian Trixie cloned VM. Installs containerd (from Debian's own repos), kubeadm, kubelet, kubectl (from pkgs.k8s.io), and Node Exporter. SSH username: `debian`.

### Variable passing convention

The HCL→script boundary uses `environment_vars` in the build block:
- `NODE_EXPORTER_VERSION` — plain string.
- `SSH_PUBKEYS_JSON` — `var.ssh_public_keys` (an HCL `list(string)`) passed through `jsonencode()`. Scripts parse it with an inline `python3` snippet, so `python3` is installed before that step runs. When adding new list/complex variables to a script, follow this JSON-encode-then-parse pattern rather than space-joining.

## Conventions & gotchas

- **Secrets**: `variables.auto.pkrvars.hcl` holds the real Proxmox `proxmox_token_id`, `proxmox_secret`, and `ssh_public_keys`. It is gitignored (`*.auto.pkrvars.hcl`) and must never be committed. `example.pkrvars.hcl` is the committed safe template. Do not print or echo the contents of the real vars file.
- **Static IPs are intentional.** Changing `ssh_host` / `ipconfig.ip` requires matching the target network — change both together.
- **Idempotency**: Scripts run with `set -e` and `DEBIAN_FRONTEND=noninteractive`. Existing steps guard against re-runs (Oh My Zsh dir check, `grep -Fxq` before appending SSH keys, `useradd ... || true`). Preserve these when editing.
- **SSH usernames differ by OS**: Debian cloud images use `debian`; Ubuntu cloud images use `ubuntu`. Each source block sets `ssh_username` accordingly.
- The cloned source VM (`clone_vm_id`) must already exist on the node, with the disk sized correctly — there is no `disks` block; disk size comes from the source VM.
- External network access is required during provisioning (Oh My Zsh installer, Node Exporter GitHub release, Podman from Debian repos).

## Common edits

- Add a package → edit the `apt-get install -y ...` line in the relevant script under `scripts/`.
- Change template identity → `template_name` / `tags` / `template_description` in the `source` block.
- Change Node Exporter version → `node_exporter_version` variable default.
