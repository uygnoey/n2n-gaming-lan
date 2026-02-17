# GameLink - P2P Gaming LAN

🌐 [한국어](README.md)

An automated gaming LAN setup tool using n2n P2P VPN.
A single install script handles everything from VPN connection to the system tray app.

## Architecture

```
[Client PC]                        [Supernode Server]
 ┌──────────────┐                 ┌──────────────┐
 │ GameLink.exe │                 │  supernode    │
 │ edge.exe     │── UDP P2P ────▶│  (UDP 7654)   │
 │ TAP Driver   │                 └──────────────┘
 │ VPN IP       │                        ▲
 │ 10.0.x.x     │                        │
 └──────────────┘                        │
                                         │
[Client PC]                              │
 ┌──────────────┐                        │
 │ GameLink.exe │── UDP P2P ─────────────┘
 │ edge.exe     │
 │ VPN IP       │
 │ 10.0.x.x     │
 └──────────────┘
```

Clients discover each other through the supernode, then communicate **directly via P2P**.

---

## ⚠️ Prerequisites: Supernode Server

A **supernode server must be set up first** before installing clients.
The supernode acts as a broker that helps clients find each other.

> See **[SERVER_SETUP_EN.md](SERVER_SETUP_EN.md)** for server setup instructions.

---

## Client Installation (Windows)

### Requirements

- Windows 10 / 11 (64-bit)
- Administrator privileges
- .NET Framework 4.x (pre-installed)
- Internet connection

### Quick Start

**1. Prepare Configuration**

Copy `env.ini.example` to `env.ini` and fill in the actual values.

```powershell
Copy-Item env.ini.example env.ini
notepad env.ini
```

`env.ini` contents:
```ini
[Settings]
SuperNode=your.supernode.com:7654
Community=YOUR_COMMUNITY
EncryptKey=YourSecretKey123
```

> All clients must use the **same Community and EncryptKey** values.

**2. Run the Install Script**

Open PowerShell as **Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\install_edge.ps1
```

Enter your **member ID** during installation to get an auto-assigned VPN IP.

### What the Install Script Does

1. Creates `C:\n2n` directory
2. Installs n2n edge.exe binary (local → auto-download from GitHub)
3. Installs TAP network driver
4. Adds Windows Firewall UDP rules
5. Takes member ID input → generates config.ini + compiles GameLink.exe

---

## Usage

### Installed Files

The following files are created in `C:\n2n`:

| File | Description |
|------|-------------|
| `GameLink.exe` | System tray app (double-click to run) |
| `config.ini` | VPN config file (editable with Notepad) |
| `edge.exe` | n2n VPN engine |

### How to Use GameLink.exe

- **Double-click** → Auto VPN connect + system tray
- **Tray left-click** → Real-time log window
- **Tray right-click** → Menu
  - Connect / Reconnect / Disconnect
  - View log
  - Open config.ini
  - Exit

### Tray Icon Status

| Color | Status |
|-------|--------|
| ⚪ Gray | Idle / Disconnected |
| 🟡 Yellow | Connecting |
| 🟢 Green | Connected |
| 🔴 Red | Connection lost / Error |

---

## IP Assignment

VPN IPs are automatically calculated from member IDs (1~65024).

```
VPN IP = 10.0.{octet3}.{octet4}

octet3 = (memberID - 1) / 254  (floor)
octet4 = (memberID - 1) % 254 + 1
```

| Member ID | VPN IP |
|-----------|--------|
| 1 | 10.0.0.1 |
| 27 | 10.0.0.27 |
| 254 | 10.0.0.254 |
| 255 | 10.0.1.1 |
| 300 | 10.0.1.46 |
| 1024 | 10.0.4.3 |

You can change your IP by editing `MemberID` in `C:\n2n\config.ini`.

---

## config.ini Example

```ini
[VPN]
; GameLink config file

; Supernode address (do not change)
SuperNode=your.supernode.com:7654

; Community name (do not change)
Community=MY_COMMUNITY

; Encryption key (do not change)
Key=YourSecretKey123

; Your member ID (edit here if entered incorrectly)
MemberID=27
```

---

## Manual edge.exe Installation

If auto-download fails:

1. Visit [lucktu/n2n Windows builds](https://github.com/lucktu/n2n/tree/master/Windows)
2. Download a `.zip` file containing `v3` and `x64` in the filename
3. Copy `edge.exe` from the zip to the script folder
4. Re-run the script

---

## Troubleshooting

| Symptom | Solution |
|---------|----------|
| GameLink.exe won't start | Right-click → Run as administrator |
| Tray icon is red | Check server status, verify internet connection |
| Can't see other PCs | Ensure both sides use the same Community and Key |
| TAP driver error | Reboot PC and retry |
