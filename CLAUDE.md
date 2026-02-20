# CLAUDE.md - GameLink Dashboard

## Project Overview
GameLink은 n2n P2P VPN 네트워크의 접속자(peer) 상태를 실시간 모니터링하는 웹 대시보드다.
AWS Lightsail 서버에서 동작하는 n2n supernode의 management API(UDP)를 통해 피어 정보를 수집하고,
Next.js 웹앱으로 시각화한다.

## Tech Stack
- **Framework**: Next.js 14 (App Router)
- **Runtime**: Node.js 20+
- **Styling**: CSS-in-JS (inline styles) - 별도 CSS 프레임워크 없음
- **Font**: JetBrains Mono (Google Fonts CDN)
- **Deploy**: AWS Lightsail (Amazon Linux 2023), systemd service
- **Data Source**: n2n supernode management API (UDP 5645, localhost only)

## Architecture
`docs/Architecture.md` 참고

## Key Commands
```bash
npm install          # 의존성 설치
npm run dev          # 개발 서버 (localhost:3000)
npm run build        # 프로덕션 빌드
npm run start        # 프로덕션 실행
./deploy.sh          # 서버 배포 (systemd 등록)
```

## Project Structure
```
gamelink-web/
├── CLAUDE.md                    # 이 파일
├── docs/
│   ├── Architecture.md          # 아키텍처 문서
│   └── SKILL.md                 # 스킬/컨벤션 가이드
├── app/
│   ├── layout.js                # Root layout (HTML, fonts)
│   ├── page.js                  # 메인 대시보드 (client component)
│   └── api/
│       └── peers/
│           └── route.js         # GET /api/peers - supernode UDP 쿼리
├── package.json
├── next.config.js               # output: 'standalone'
├── deploy.sh                    # 배포 스크립트
└── .gitignore
```

## Critical Context

### n2n Supernode Management API
- **프로토콜**: UDP (NOT TCP)
- **주소**: 127.0.0.1:5645 (localhost only, 외부 노출 안 됨)
- **쿼리 형식**: `r <tag> <command>\n` 을 UDP로 전송
- **응답**: JSON 줄 단위 (여러 줄, 각각 독립 JSON)
- **주요 명령어**:
  - `r 1 edges` → 연결된 edge(피어) 목록
  - `r 1 supernodes` → supernode 정보
- **응답 예시** (edges):
```json
{"_tag":"1","_type":"begin","cmd":"edges"}
{"_tag":"1","_type":"row","community":"MCK_LAN","ip4addr":"10.0.2.37/16","macaddr":"00:FF:DA:9F:A3:A8","sockaddr":"14.37.5.120:60838","proto":"UDP","desc":"yeongyu","last_seen":1771333828}
{"_tag":"1","_type":"end","cmd":"edges"}
```
- **중요**: `_type: "row"` 만 실제 데이터. `begin`/`end`는 무시해야 함

### IP ↔ 회원번호 매핑
```
VPN IP = 10.0.{(memberID-1) / 254}.{(memberID-1) % 254 + 1}
역변환: memberID = octet3 * 254 + octet4
```
예: 회원번호 545 → 10.0.2.37, 회원번호 1 → 10.0.0.1

### 서버 환경
- **OS**: Amazon Linux 2023 (Lightsail $5/month, Seoul region)
- **IP**: 43.203.192.81
- **DNS**: sim.vpn.m-club.or.kr
- **n2n supernode**: UDP 7654 (main), UDP 5645 (management)
- **대시보드**: TCP 3000 (Next.js)
- **사용자**: ec2-user

### VPN 네트워크 설정
- **Community**: MCK_LAN
- **Encryption**: AES-CBC (-A3)
- **Subnet**: 10.0.0.0/16
- **Supernode version**: v3.0.0

## Design Guidelines
- **테마**: 다크 모드 전용 (배경 #0a0a0f ~ #111827)
- **색상 팔레트**:
  - Primary: #06b6d4 (cyan)
  - Accent: #8b5cf6 (purple)
  - Success/Online: #22c55e (green)
  - Warning/Idle: #eab308 (yellow)
  - Error/Offline: #ef4444 (red)
  - Text: #e2e8f0 / #94a3b8 / #64748b / #475569
- **폰트**: JetBrains Mono (모노스페이스, 터미널 느낌)
- **분위기**: 네트워크 모니터링 터미널 / 사이버펑크

## Peer Status Rules
| 조건 | 상태 | 색상 |
|------|------|------|
| last_seen < 30초 | 온라인 | #22c55e |
| last_seen < 120초 | 대기 | #eab308 |
| last_seen >= 120초 | 오프라인 | #ef4444 |

## API Endpoints

### GET /api/peers
supernode에서 현재 연결된 피어 목록 조회.

**Response:**
```json
{
  "ok": true,
  "timestamp": 1771333828,
  "peer_count": 5,
  "peers": [
    {
      "community": "MCK_LAN",
      "ip4addr": "10.0.2.37/16",
      "macaddr": "00:FF:DA:9F:A3:A8",
      "sockaddr": "14.37.5.120:60838",
      "proto": "UDP",
      "desc": "yeongyu",
      "last_seen": 1771333828
    }
  ]
}
```

## Do's and Don'ts

### Do
- UDP 소켓은 매 요청마다 생성/해제 (connection pool 불필요)
- `_type: "row"` 만 파싱
- IP 주소에서 `/16` 서브넷 제거 후 표시
- 5초 간격 자동 갱신 (클라이언트 polling)
- `output: 'standalone'` 빌드 (systemd에서 단독 실행)

### Don't
- TCP로 management API 접근하지 마라 (UDP only)
- 외부에서 5645 포트 접근 불가 — API route는 서버 로컬에서만 동작
- SSE나 WebSocket 불필요 — 단순 polling으로 충분
- `dgram` 모듈은 Node.js built-in이므로 별도 설치 불필요 (package.json에 넣어도 무시됨)
