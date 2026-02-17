# Supernode Server Setup

The supernode is a broker server that helps clients discover each other.
It runs on Linux and must be set up before installing clients.

---

## Method 1: Docker (Recommended)

```bash
docker run -d \
  --name n2n-supernode \
  --restart always \
  -p 7654:7654/udp \
  supermock/supernode:latest \
  supernode -p 7654 -f
```

Check container status:
```bash
docker logs n2n-supernode
```

---

## Method 2: Build from Source

### Ubuntu / Debian

```bash
# Install build dependencies
sudo apt update
sudo apt install -y build-essential cmake libssl-dev

# Build n2n from source
git clone https://github.com/ntop/n2n.git
cd n2n
cmake -B build
cmake --build build
sudo cmake --install build

# Run supernode
sudo supernode -p 7654 -f
```

### CentOS / RHEL

```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y cmake openssl-devel

git clone https://github.com/ntop/n2n.git
cd n2n
cmake -B build
cmake --build build
sudo cmake --install build

sudo supernode -p 7654 -f
```

---

## Register as systemd Service

Register the supernode as a system service for auto-start on boot.

```bash
sudo tee /etc/systemd/system/n2n-supernode.service << 'EOF'
[Unit]
Description=n2n Supernode
After=network.target

[Service]
ExecStart=/usr/local/sbin/supernode -p 7654 -f
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now n2n-supernode
```

---

## Open Firewall Port

```bash
# UFW (Ubuntu)
sudo ufw allow 7654/udp

# firewalld (CentOS)
sudo firewall-cmd --permanent --add-port=7654/udp
sudo firewall-cmd --reload
```
