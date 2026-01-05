## Overview

This repsitory contains Packer configuration to build VM templates for my homelab. Basically installing these tools:
- Docker Engine
- Oh My Zsh
- Some useful tools such as telnet, net-tools, htop, etc.

## How to build

1. Make sure you already have API token and secret from Proxmox VE
2. Copy `example.pkrvars.hcl` to `vars.auto.pkrvars.hcl`
3. Fill the variables in `vars.auto.pkrvars.hcl`
4. Run `packer build proxmox-ubuntu.pkr.hcl`
5. The template will be available in the Proxmox VE

> [!IMPORTANT]
> If you want to run this on your own Proxmox server, make sure to change the `proxmox_api_url`, `ssh_host`, `ssh_private_key_file`, and the ipconfig configuration to match your environment.