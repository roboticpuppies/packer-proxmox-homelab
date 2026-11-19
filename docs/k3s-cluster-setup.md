# K3s Cluster Setup

How to launch a k3s cluster from Proxmox templates built by this repo.

## Prerequisites

- `debian-trixie-k3s-server` template built (`make k3s`)
- `debian-trixie-k3s-agent` template built (`make k3s-agent`)

## 1. Start the Server

Clone `debian-trixie-k3s-server` in Proxmox, then SSH into the new VM.

```bash
# Create config (single-node or first server in HA)
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml <<EOF
cluster-init: true
tls-san:
  - <SERVER_IP>
write-kubeconfig-mode: "0644"
EOF

# Start k3s
sudo systemctl enable --now k3s
```

Verify:

```bash
kubectl get nodes
```

## 2. Get the Join Token

On the server:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Save this token for agent and additional server joins.

## 3. Join an Agent

Clone `debian-trixie-k3s-agent` in Proxmox, then SSH into the new VM.

```bash
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml <<EOF
server: https://<SERVER_IP>:6443
token: <NODE_TOKEN>
EOF

sudo systemctl enable --now k3s-agent
```

Verify from the server:

```bash
kubectl get nodes
```

Repeat for each additional agent node.

## 4. Join Additional Servers (HA)

Clone another `debian-trixie-k3s-server` and SSH in.

```bash
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml <<EOF
server: https://<FIRST_SERVER_IP>:6443
token: <NODE_TOKEN>
tls-san:
  - <THIS_SERVER_IP>
write-kubeconfig-mode: "0644"
EOF

sudo systemctl enable --now k3s
```

HA requires an odd number of servers (3, 5, etc.) for etcd quorum.

## Useful Commands

```bash
# Check cluster status
kubectl get nodes -o wide

# Check k3s service logs
journalctl -u k3s -f          # server
journalctl -u k3s-agent -f    # agent

# Get kubeconfig (copy to local machine)
cat /etc/rancher/k3s/k3s.yaml
```

Replace `server: https://127.0.0.1:6443` in the kubeconfig with the server's actual IP when using remotely.
