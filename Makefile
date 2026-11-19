.PHONY: all podman k3s k3s-agent ubuntu-docker validate fmt

all: podman k3s k3s-agent ubuntu-docker

podman:
	packer build -only="gp-debian-trixie-podman.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

k3s:
	packer build -only="gp-debian-trixie-k3s-server.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

k3s-agent:
	packer build -only="gp-debian-trixie-k3s-agent.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

ubuntu-docker:
	packer build -only="gp-ubuntu-resolute-docker.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

validate:
	packer validate --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

fmt:
	packer fmt proxmox.pkr.hcl
