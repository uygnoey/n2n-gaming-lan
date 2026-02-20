# Architecture.md - GameLink Dashboard

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  AWS Lightsail (sim.vpn.m-club.or.kr / 43.203.192.81)              │
│                                                                     │
│  ┌──────────────────┐     UDP 5645      ┌────────────────────────┐ │
│  │  n2n supernode    │ ◄──(localhost)──► │  Next.js App (:3000)   │ │
│  │  :7654 (UDP)      │                   │                        │ │
│  │  :5645 (mgmt)     │                   │  GET /api/peers        │ │
│  └────────┬─────────┘                   │    → UDP query          │ │
│           │                              │    → JSON response      │ │
│           │ UDP (P2P mesh)               │                        │ │
│           │                              │  page.js (dashboard)   │ │
│           │                              │    → 5s polling         │ │
│           │                              │    → peer table         │ │
└───────────┼──────────────────────────────┴────────────────────────┘ │
            │                                         ▲               │
            │                                         │ TCP 3000      │
            ▼                                         │               │
┌───────────────────────┐                   ┌─────────┴─────────┐
│  Windows Edge Clients │                   │  Web Browser       │
│  (GameLink.exe)       │                   │  (관리자/회원)     │
│                       │                   │                    │
│  10.0.0.1  (회원#1)   │                   │  실시간 피어 모니터│
│  10.0.0.100(회원#100) │                   └────────────────────┘
│  10.0.2.37 (회원#545) │
│  ...                  │
└───────────────────────┘
```

## Data Flow

### 1. Peer Registration (VPN 연결)
```
GameLink.exe → edge.exe → supernode(:7654/UDP)
                          supernode 내부 edge 테이블에 등록
```

### 2. Dashboard Query (피어 조회)
```
Browser ──HTTP GET──► Next.js /api/peers
                          │
                          ▼
                     Node.js dgram
                          │
                     UDP "r 1 edges\n"
                          │
                          ▼
                     supernode :5645
                          │
                     JSON responses (multi-line)
                          │
                          ▼
                     Parse _type:"row" only
                          │
                          ▼
                     HTTP JSON response
                          │
Browser ◄─────────────────┘
```

### 3. Auto Refresh (자동 갱신)
```
Browser: setInterval(fetch('/api/peers'), 5000)
         → state update
         → re-render table
```

## Component Architecture

```
app/layout.js          ── Root HTML, Google Fonts 로드
 └── app/page.js       ── Dashboard (client component)
      ├── Stats Cards   ── 접속자수, 전체 피어, 커뮤니티, 상태
      ├── Search/Filter ── 검색, 자동갱신 토글
      └── Peers Table   ── 피어 목록 (상태, 회원번호, IP, 이름...)

app/api/peers/route.js ── API Route (server-side)
      └── querySupernode() ── UDP 소켓으로 supernode 쿼리
```

## n2n Supernode Management Protocol

### Connection
- **Transport**: UDP (NOT TCP)
- **Address**: 127.0.0.1:5645
- **Encoding**: UTF-8

### Request Format
```
r <tag> <command>\n
```
- `<tag>`: 임의 정수 (응답 매칭용, 보통 1)
- `<command>`: edges, supernodes, communities 등

### Response Format
응답은 여러 UDP 패킷으로 나뉘어 올 수 있음. 각 패킷은 독립 JSON 한 줄.

```json
{"_tag":"1","_type":"begin","cmd":"edges"}
{"_tag":"1","_type":"row","community":"MCK_LAN","ip4addr":"10.0.2.37/16",...}
{"_tag":"1","_type":"row","community":"MCK_LAN","ip4addr":"10.0.0.100/16",...}
{"_tag":"1","_type":"end","cmd":"edges"}
```

**_type 종류:**
| _type | 의미 | 처리 |
|-------|------|------|
| begin | 응답 시작 | 무시 |
| row   | 실제 데이터 | 파싱하여 사용 |
| end   | 응답 종료 | 무시 |

### Edge Row Fields
| Field | Type | 설명 | 예시 |
|-------|------|------|------|
| community | string | VPN 커뮤니티 | "MCK_LAN" |
| ip4addr | string | VPN IP/mask | "10.0.2.37/16" |
| macaddr | string | 가상 MAC | "00:FF:DA:9F:A3:A8" |
| sockaddr | string | 공인IP:포트 | "14.37.5.120:60838" |
| proto | string | 프로토콜 | "UDP" |
| desc | string | edge 설명 (hostname) | "yeongyu" |
| last_seen | number | Unix timestamp | 1771333828 |

### UDP Timeout Strategy
```
Send query → Start 3s global timeout
On each packet received → Reset 500ms idle timer
If 500ms no more packets → Done (resolve)
If 3s total → Force done (resolve with what we have)
```

## IP Address Scheme

### VPN Subnet
- **Network**: 10.0.0.0/16 (255.255.0.0)
- **Range**: 10.0.0.1 ~ 10.0.255.254
- **Capacity**: 65,024 addresses

### Member ID ↔ IP Conversion
```
Forward (ID → IP):
  octet3 = floor((memberID - 1) / 254)
  octet4 = (memberID - 1) % 254 + 1
  IP = 10.0.{octet3}.{octet4}

Reverse (IP → ID):
  memberID = octet3 * 254 + octet4
```

### Examples
| Member ID | VPN IP | Calculation |
|-----------|--------|-------------|
| 1 | 10.0.0.1 | (0/254=0, 0%254+1=1) |
| 254 | 10.0.0.254 | (253/254=0, 253%254+1=254) |
| 255 | 10.0.1.1 | (254/254=1, 254%254+1=1) |
| 545 | 10.0.2.37 | (544/254=2, 544%254+1=37) |

## Deployment

### Server Environment
```
OS:       Amazon Linux 2023
Instance: Lightsail $5/month (Seoul ap-northeast-2)
IP:       43.203.192.81
DNS:      sim.vpn.m-club.or.kr (Gabia A record)
User:     ec2-user
```

### Port Map
| Port | Protocol | Service | Access |
|------|----------|---------|--------|
| 7654 | UDP | n2n supernode | Public (Lightsail FW open) |
| 5645 | UDP | supernode mgmt | localhost only |
| 3000 | TCP | Next.js dashboard | Public (Lightsail FW 열어야 함) |
| 22   | TCP | SSH | Public |

### Process Management
```bash
# supernode (이미 실행 중)
sudo systemctl status n2n-supernode

# dashboard
sudo systemctl start gamelink-web
sudo systemctl stop gamelink-web
sudo systemctl restart gamelink-web
sudo journalctl -u gamelink-web -f
```

### Build & Deploy
```bash
# standalone 빌드 (next.config.js: output: 'standalone')
npm run build

# 실행 (.next/standalone/server.js)
NODE_ENV=production PORT=3000 HOSTNAME=0.0.0.0 \
  node .next/standalone/server.js
```

## Security Considerations

- `/api/peers` 는 현재 인증 없음 (필요 시 Basic Auth 또는 API key 추가)
- supernode management port (5645)는 localhost only — 외부에서 직접 접근 불가
- 공인 IP가 피어 테이블에 노출됨 — 내부 관리용으로만 사용 권장
- 필요 시 nginx reverse proxy + htpasswd 로 접근 제한 가능

## Future Enhancements (Optional)
- [ ] 인증 (Basic Auth 또는 로그인)
- [ ] 피어 히스토리 (접속/해제 로그)
- [ ] 네트워크 토폴로지 시각화 (D3.js)
- [ ] 피어 간 latency 표시
- [ ] 모바일 반응형 레이아웃
- [ ] 서버 리소스 모니터링 (CPU, RAM, bandwidth)
