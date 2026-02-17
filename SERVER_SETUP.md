# 슈퍼노드 서버 설정

슈퍼노드는 클라이언트들이 서로를 찾을 수 있도록 중개하는 서버입니다.
Linux 환경에서 설정하며, 클라이언트 설치 전에 먼저 구축되어 있어야 합니다.

---

## 방법 1: Docker (권장)

```bash
docker run -d \
  --name n2n-supernode \
  --restart always \
  -p 7654:7654/udp \
  supermock/supernode:latest \
  supernode -p 7654 -f
```

컨테이너 상태 확인:
```bash
docker logs n2n-supernode
```

---

## 방법 2: 직접 설치

### Ubuntu / Debian

```bash
# n2n 빌드 의존성 설치
sudo apt update
sudo apt install -y build-essential cmake libssl-dev

# n2n 소스 빌드
git clone https://github.com/ntop/n2n.git
cd n2n
cmake -B build
cmake --build build
sudo cmake --install build

# supernode 실행
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

## systemd 서비스 등록

슈퍼노드를 시스템 서비스로 등록하면 서버 재시작 시 자동 실행됩니다.

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

## 방화벽 포트 개방

```bash
# UFW (Ubuntu)
sudo ufw allow 7654/udp

# firewalld (CentOS)
sudo firewall-cmd --permanent --add-port=7654/udp
sudo firewall-cmd --reload
```
