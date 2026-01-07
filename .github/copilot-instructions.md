# Copilot / AI Agent Instructions for this repository

## Quick summary
- This repo builds a Proxmox VM template using Packer HCL (`proxmox-ubuntu.pkr.hcl`) and provisions it with `scripts/provision.sh`.
- Main flow: provide Proxmox credentials via `example.pkrvars.hcl` → copy to `variables.auto.pkrvars.hcl` and fill secrets → run `packer build proxmox-ubuntu.pkr.hcl`.

## Big picture / architecture
- Single Packer HCL source: `source "proxmox-clone" "gp-ubuntu-server-24-04"` clones an existing Proxmox VM (`clone_vm_id`) and converts it to a template named `gp-ubuntu-server-24-04`.
- Cloud-init is used to finish initial boot; the build waits for `/var/lib/cloud/instance/boot-finished` before running `scripts/provision.sh`.
- Provisioning installs Docker, Oh My Zsh, and common utilities; it uses the official Docker apt repository and `systemd` to enable Docker.

## Key files to reference
- `proxmox-ubuntu.pkr.hcl` — source and build configuration (network, cloud-init, clone id, ssh settings).
- `scripts/provision.sh` — the provisioning script run inside the VM (package installs, Docker setup, zsh config).
- `example.pkrvars.hcl` — template for required variables (token id, secret, API URL).
- `variables.auto.pkrvars.hcl` — environment-specific variables (do NOT commit secrets to VCS).
- `README.md` — contains build steps and some important notes about changing IPs and tokens.

## Developer workflows & helpful commands
- Build the template (after filling `variables.auto.pkrvars.hcl`):
  - packer build proxmox-ubuntu.pkr.hcl
- Debugging / verbose log:
  - PACKER_LOG=1 PACKER_LOG_PATH=packer.log packer build -debug proxmox-ubuntu.pkr.hcl
- Common issues to check when a build fails:
  - Ensure `proxmox_api_url`, `proxmox_token_id`, and `proxmox_secret` are correct and the token has appropriate privileges.
  - Verify `clone_vm_id` refers to an existing VM/template on the target Proxmox node.
  - Confirm SSH key file (`ssh_private_key_file`) exists and matches the image's authorized keys.
  - If cloud-init never finishes, check network (`ipconfig`) and cloud-init logs inside the VM.

## Project-specific conventions & gotchas
- Static IPs are used by design: `ssh_host` and `ipconfig.ip` are set in the source; change them only if you understand the target network.
- The Packer config declares a required plugin (`github.com/hashicorp/proxmox`) — ensure Packer can install/load it.
- Provision scripts use `sudo` and `$(whoami)`; they assume a standard user account (`ubuntu`). When editing `scripts/provision.sh`, preserve `set -e` and `DEBIAN_FRONTEND=noninteractive`.
- Secrets: never commit `variables.auto.pkrvars.hcl` with real tokens; use `example.pkrvars.hcl` as the safe template.

## Specific examples (when asked to make changes)
- Change template name: edit `template_name` in `proxmox-ubuntu.pkr.hcl` under the `source` block.
- Change static IP: update `ssh_host` and `ipconfig.ip` in the same source block.
- Change packages installed: update `scripts/provision.sh` (the apt `install -y ...` line) and test by running the script inside a debug VM.

## Integration & external dependencies
- Proxmox VE API (configured with `proxmox_api_url`, token id and secret).
- Docker apt repository and the Oh My Zsh install script (external network access required during provisioning).
- Packer plugin: `github.com/hashicorp/proxmox` (ensure compatibility with the local Packer version).

## Safe defaults & tips for AI edits
- Do not add or leak secrets into the repo. If a task requires creating or showing a token, return an instruction to use `example.pkrvars.hcl` and to update local `variables.auto.pkrvars.hcl` instead of committing secrets.
- Validate any network or node-specific changes with a short checklist: update `proxmox_api_url`, `proxmox_node`, `ipconfig`, and `ssh_private_key_file`.
- When editing provisioning steps, keep changes idempotent so repeated runs do not fail (check for existence before install as `provision.sh` already does for Oh My Zsh).

---
If anything here is unclear or if you want more examples for common edits (e.g., how to add another package or change the cloned source VM), tell me which area to expand. ✅
