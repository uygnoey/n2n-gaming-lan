# SKILL.md - GameLink Development Guide

## 코딩 컨벤션

### 파일 구조
- Next.js 14 App Router 사용 (`app/` 디렉토리)
- API Routes: `app/api/[endpoint]/route.js`
- Pages: `app/page.js` (client component)
- Layout: `app/layout.js` (server component)

### JavaScript / React
- ES6+ 문법 사용
- React Hooks (`useState`, `useEffect`, `useCallback`)
- `'use client'` 지시어는 page.js 최상단에만
- API route는 서버 컴포넌트 (default)
- 타입스크립트 미사용 (순수 JS)

### 스타일링
- **CSS-in-JS (inline styles)** — Tailwind, CSS Modules 사용하지 않음
- `style` 객체를 컴포넌트 하단에 `const styles = {}` 로 분리
- 색상값은 hex 사용 (`#06b6d4`, `rgba(...)`)
- CSS 변수 사용 안 함 — 직접 값 입력

### 네이밍
```
파일명:      kebab-case (route.js, page.js)
컴포넌트:    PascalCase (Dashboard, PeerTable)
함수:        camelCase (fetchPeers, ipToMemberId)
상수:        UPPER_SNAKE (SUPERNODE_HOST, TIMEOUT_MS)
CSS 스타일:  camelCase (styles.statCard, styles.tableWrap)
```

## 핵심 유틸리티 함수

### IP ↔ 회원번호 변환
```javascript
// IP → 회원번호
function ipToMemberId(ip) {
  const parts = ip.replace(/\/\d+/, '').split('.').map(Number);
  if (parts.length !== 4 || parts[0] !== 10) return '?';
  return parts[2] * 254 + parts[3];
}

// 회원번호 → IP
function memberIdToIp(id) {
  const t = id - 1;
  return `10.0.${Math.floor(t / 254)}.${t % 254 + 1}`;
}
```

### 시간 표시
```javascript
function timeAgo(unixTimestamp) {
  const diff = Math.floor(Date.now() / 1000 - unixTimestamp);
  if (diff < 10) return '방금';
  if (diff < 60) return `${diff}초 전`;
  if (diff < 3600) return `${Math.floor(diff / 60)}분 전`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}시간 전`;
  return `${Math.floor(diff / 86400)}일 전`;
}
```

### 피어 상태 판정
```javascript
function statusInfo(lastSeenTimestamp) {
  const diff = Date.now() / 1000 - lastSeenTimestamp;
  if (diff < 30)  return { color: '#22c55e', label: '온라인' };
  if (diff < 120) return { color: '#eab308', label: '대기' };
  return { color: '#ef4444', label: '오프라인' };
}
```

## UDP 통신 패턴

### supernode management API 쿼리
```javascript
import dgram from 'dgram';

function querySupernode(command) {
  return new Promise((resolve, reject) => {
    const client = dgram.createSocket('udp4');
    const results = [];
    let timer;

    client.on('message', (msg) => {
      const line = msg.toString().trim();
      if (!line) return;
      try {
        const obj = JSON.parse(line);
        results.push(obj);
      } catch {}

      // idle timer: 패킷 간 500ms 이상 간격이면 완료로 판단
      clearTimeout(timer);
      timer = setTimeout(() => { client.close(); resolve(results); }, 500);
    });

    client.on('error', (err) => { client.close(); reject(err); });

    // 전체 타임아웃 3초
    timer = setTimeout(() => { client.close(); resolve(results); }, 3000);

    client.send(Buffer.from(command + '\n'), 5645, '127.0.0.1');
  });
}
```

**주의사항:**
- UDP는 패킷 순서 보장 안 됨 — 하지만 localhost라 실질적으로 순서 보장
- 각 패킷이 독립 JSON — 줄 단위 파싱
- `_type: "row"` 만 유효 데이터, `begin`/`end`는 무시
- 소켓은 반드시 `client.close()` 해야 함 (메모리 누수 방지)

## API Route 패턴

### GET 핸들러
```javascript
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    const data = await querySupernode('r 1 edges');
    const peers = data.filter(r => r._type === 'row').map(r => ({
      community: r.community || '',
      ip4addr: r.ip4addr || '',
      macaddr: r.macaddr || '',
      sockaddr: r.sockaddr || '',
      proto: r.proto || 'UDP',
      desc: r.desc || '',
      last_seen: r.last_seen || 0,
    }));

    return NextResponse.json({ ok: true, peers, peer_count: peers.length });
  } catch (err) {
    return NextResponse.json({ ok: false, error: err.message, peers: [] }, { status: 500 });
  }
}
```

## 프론트엔드 패턴

### Polling
```javascript
// 5초 간격 자동 갱신
useEffect(() => {
  if (!autoRefresh) return;
  const t = setInterval(fetchPeers, 5000);
  return () => clearInterval(t);
}, [autoRefresh]);
```

### 실시간 "time ago" 업데이트
```javascript
// 1초마다 리렌더 트리거 (last_seen 기준 시간 경과 표시용)
const [, setTick] = useState(0);
useEffect(() => {
  const t = setInterval(() => setTick(n => n + 1), 1000);
  return () => clearInterval(t);
}, []);
```

## 디자인 시스템

### Color Palette
```
Background:    #0a0a0f (darkest), #111827 (dark), #1e293b (medium)
Surface:       rgba(255,255,255,0.02~0.05)
Border:        rgba(255,255,255,0.03~0.10)
Text Primary:  #e2e8f0
Text Secondary:#94a3b8
Text Muted:    #64748b
Text Faint:    #475569

Cyan:          #06b6d4 (primary, VPN IP 강조)
Purple:        #8b5cf6 (accent, 회원번호 배지)
Green:         #22c55e (온라인)
Yellow:        #eab308 (대기)
Red:           #ef4444 (오프라인/에러)
```

### Typography
```
Font Family: 'JetBrains Mono', 'SF Mono', 'Fira Code', monospace
Title:       28px, weight 800
Stat Number: 28px, weight 800
Table Body:  12-14px, weight 400-600
Label:       11px, uppercase, letter-spacing 1.5px
Badge:       11-13px, weight 700
```

### Component Patterns
```
Card:       background rgba(255,255,255,0.03)
            border 1px solid rgba(255,255,255,0.06)
            border-radius 12px
            padding 20px 18px

Table:      border-radius 14px (wrapper)
            header: border-bottom, uppercase labels
            row: hover rgba(255,255,255,0.03)

Badge:      padding 3px 10px
            border-radius 6px
            colored background at 12% opacity

Status Dot: width/height 9px, border-radius 50%
            box-shadow 0 0 8px {color}60
```

## 배포 체크리스트

### next.config.js
```javascript
const nextConfig = { output: 'standalone' };
```
`standalone` 필수 — systemd에서 `.next/standalone/server.js` 직접 실행

### systemd service
```ini
[Service]
ExecStart=/usr/bin/node /opt/gamelink-web/.next/standalone/server.js
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOSTNAME=0.0.0.0
```

### Lightsail 방화벽
TCP 3000 인바운드 허용 필요 (또는 nginx → 80/443 리버스 프록시)

## 트러블슈팅

### "dgram is not defined"
→ API route가 클라이언트에서 실행되고 있음
→ `'use client'` 가 API route에 있으면 안 됨
→ API route는 서버 컴포넌트여야 함

### UDP 응답 비어있음
→ supernode management port 확인: `sudo ss -ulnp | grep 5645`
→ supernode 서비스 확인: `sudo systemctl status n2n-supernode`
→ management port 옵션 확인: `-t 5645`

### standalone 빌드 에러
→ `npm run build` 후 `.next/standalone/` 디렉토리 존재 확인
→ `public/`, `.next/static/` 을 `.next/standalone/` 에 복사 필요:
```bash
cp -r public .next/standalone/
cp -r .next/static .next/standalone/.next/
```

### 한국어 깨짐
→ layout.js에 `<html lang="ko">` 확인
→ `Content-Type: application/json; charset=utf-8` 자동 (NextResponse)
