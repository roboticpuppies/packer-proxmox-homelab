# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Packer config that builds a Proxmox VM template for a homelab. It clones an existing Proxmox VM, provisions it via shell script, and converts it to a reusable template.

Current templates:
- `debian-trixie-podman` — Debian 13 (Trixie) with Podman (rootless/daemonless), Oh My Zsh, Node Exporter
- `debian-trixie-k3s-server` — Debian 13 (Trixie) with k3s (server, service installed but disabled), Oh My Zsh, Node Exporter
- `debian-trixie-k3s-agent` — Debian 13 (Trixie) with k3s (agent, service installed but disabled), Oh My Zsh, Node Exporter
- `ubuntu-resolute-docker` — Ubuntu 26.04 (Resolute) with Docker CE, Oh My Zsh, Node Exporter (script `scripts/ubuntu-docker.sh`, clones `ubuntu_clone_vm_id` default `9000`, SSH user `ubuntu`, IP `192.168.100.114/24`)

## Commands

```bash
# Build a template
make podman
make k3s
make k3s-agent
make ubuntu-docker
make all       # all of the above

# Build directly
packer build -only="gp-debian-trixie-podman.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl
packer build -only="gp-debian-trixie-k3s-server.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl
packer build -only="gp-debian-trixie-k3s-agent.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

# Validate config without building
make validate

# Format HCL
make fmt
```

There are no tests. Verification = a successful `packer build` producing the template on the Proxmox node.

## Architecture

Two-file build pipeline, one source/build pair per template:

1. **`proxmox.pkr.hcl`** — a `source "proxmox-clone"` block plus a `build` block per template.
   - Uses the `github.com/hashicorp/proxmox` plugin (`proxmox-clone` builder), NOT an ISO install. Debian templates clone from `debian_clone_vm_id` (default `9001`), the Ubuntu template from `ubuntu_clone_vm_id` (default `9000`), on node `proxmox_node` (default `phoenix`).
   - Each VM uses its own **static IP** (`ssh_host` and `ipconfig.ip` must match: podman `192.168.100.111/24`, k3s server `192.168.100.112/24`, k3s agent `192.168.100.113/24`). Packer SSHes to this fixed address during the build. New templates need a free IP in this scheme.
   - Each `build` block has two provisioners: (a) inline wait loop on `/var/lib/cloud/instance/boot-finished` so cloud-init finishes first, then (b) the template's shell script.

2. **`scripts/debian-podman.sh`** — runs inside the cloned Debian Trixie VM. Installs Podman (rootless, via `podman podman-compose podman-docker`), configures subuid/subgid for rootless containers, Oh My Zsh (theme `gentoo`, plugins `git docker docker-compose podman history`, with `alias docker=podman`), common utils, and Node Exporter (systemd service). Sets default shell to zsh. SSH username: `debian`.

3. **`scripts/debian-k3s-server.sh`** / **`scripts/debian-k3s-agent.sh`** — run inside their cloned Debian Trixie VMs. Install k3s via `get.k3s.io` in `server`/`agent` mode respectively with `INSTALL_K3S_SKIP_ENABLE=true` (binary present but service disabled/stopped, so clones start clean — configure `/etc/rancher/k3s/config.yaml` with `server`/`token` and `systemctl enable --now k3s`/`k3s-agent` on the clone), Oh My Zsh (theme `gentoo`, plugins `git kubectl history`), common utils, and Node Exporter. SSH username: `debian`.

### Variable passing convention

The HCL→script boundary uses `environment_vars` in the build block:
- `NODE_EXPORTER_VERSION` — plain string.
- `K3S_VERSION` (k3s builds only) — plain string; empty default lets `get.k3s.io` install the latest stable channel.
- `SSH_PUBKEYS_JSON` — `var.ssh_public_keys` (an HCL `list(string)`) passed through `jsonencode()`. The script parses it with an inline `python3` snippet, so `python3` is installed before that step runs. When adding new list/complex variables to a script, follow this JSON-encode-then-parse pattern rather than space-joining.

## Conventions & gotchas

- **Secrets**: `variables.auto.pkrvars.hcl` holds the real Proxmox `proxmox_token_id`, `proxmox_secret`, and `ssh_public_keys`. It is gitignored (`*.auto.pkrvars.hcl`) and must never be committed. `example.pkrvars.hcl` is the committed safe template. Do not print or echo the contents of the real vars file.
- **Static IPs are intentional.** Changing `ssh_host` / `ipconfig.ip` requires matching the target network — change both together.
- **Idempotency**: The script runs with `set -e` and `DEBIAN_FRONTEND=noninteractive`. Existing steps guard against re-runs (Oh My Zsh dir check, `grep -Fxq` before appending SSH keys, `useradd ... || true`). Preserve these when editing.
- The cloned source VM (`debian_clone_vm_id` / `ubuntu_clone_vm_id`) must already exist on the node, with the disk sized correctly — there is no `disks` block; disk size comes from the source VM.
- External network access is required during provisioning (Oh My Zsh installer, Node Exporter GitHub release, Podman from Debian repos).

## Common edits

- Add a package → edit the `apt-get install -y ...` line in `scripts/debian-podman.sh`.
- Change template identity → `template_name` / `tags` / `template_description` in the `source` block.
- Change Node Exporter version → `node_exporter_version` variable default.
