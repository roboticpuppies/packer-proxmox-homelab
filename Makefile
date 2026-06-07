.PHONY: all podman base validate fmt

all: podman base

podman:
	packer build -only="gp-debian-trixie-podman.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

base:
	packer build -only="gp-ubuntu-server-24-04-base.*" --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

validate:
	packer validate --var-file=variables.auto.pkrvars.hcl proxmox.pkr.hcl

fmt:
	packer fmt proxmox.pkr.hcl
