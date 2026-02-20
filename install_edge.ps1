#Requires -RunAsAdministrator
#=============================================================================
# n2n Edge 자동 설치 스크립트 - GameLink - P2P Gaming LAN
# 관리자 권한 PowerShell에서 실행:
#   Set-ExecutionPolicy Bypass -Scope Process -Force; .\install_edge.ps1
#=============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$N2N_DIR = "C:\n2n"
$SUPERNODE = "sim.vpn.m-club.or.kr:7654"
$COMMUNITY = "MCK_LAN"
$ENCRYPT_KEY = "MCK2026!@#"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  GameLink - P2P Gaming LAN - n2n VPN 설치"         -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

#-----------------------------------------------------------------------------
# 1. 설치 디렉토리 생성
#-----------------------------------------------------------------------------
Write-Host "[1/5] 설치 디렉토리 생성..." -ForegroundColor Yellow
if (-not (Test-Path $N2N_DIR)) {
    New-Item -ItemType Directory -Path $N2N_DIR -Force | Out-Null
}
Write-Host "  → $N2N_DIR 준비됨" -ForegroundColor Green

#-----------------------------------------------------------------------------
# 2. edge.exe 설치
#-----------------------------------------------------------------------------
Write-Host "[2/5] n2n v3 Windows 바이너리 설치..." -ForegroundColor Yellow

$edgeExe = "$N2N_DIR\edge.exe"
$downloaded = $false
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- 방법 1: 스크립트 폴더에 edge.exe가 있으면 바로 복사 ---
$localEdge = Join-Path $scriptDir "edge.exe"
if (Test-Path $localEdge) {
    Write-Host "  → edge.exe 발견! 복사 중..." -ForegroundColor Green
    Copy-Item -Path $localEdge -Destination $edgeExe -Force
    $downloaded = $true
}

# --- 방법 2: 스크립트 폴더에 n2n zip이 있으면 해제 ---
if (-not $downloaded) {
    $localZips = Get-ChildItem -Path $scriptDir -Filter "*.zip" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "n2n" }
    if ($localZips) {
        $zipFile = $localZips[0].FullName
        Write-Host "  → $($localZips[0].Name) 발견! 압축 해제 중..." -ForegroundColor Green
        $tempDir = "$N2N_DIR\_temp"
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
        $foundEdge = Get-ChildItem -Path $tempDir -Recurse -Filter "edge.exe" | Select-Object -First 1
        if ($foundEdge) {
            Copy-Item -Path $foundEdge.FullName -Destination $edgeExe -Force
            $downloaded = $true
        }
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- 방법 3: GitHub lucktu/n2n Windows 폴더에서 v3 x64 자동 다운로드 ---
if (-not $downloaded) {
    Write-Host "  GitHub에서 n2n v3 Windows 바이너리 검색 중..." -ForegroundColor Gray
    try {
        # GitHub에서 Windows 폴더 파일 목록 가져오기
        $apiUrl = "https://api.github.com/repos/lucktu/n2n/contents/Windows"
        $files = Invoke-RestMethod -Uri $apiUrl -Headers @{"User-Agent"="GameLink-installer"} -TimeoutSec 15

        # v3 + x64 zip 파일 찾기 (최신순 정렬)
        $target = $files | Where-Object {
            $_.name -match "\.zip$" -and
            $_.name -match "v\.?3" -and
            $_.name -match "(x64|w64|x86_64)"
        } | Sort-Object name -Descending | Select-Object -First 1

        # x64 매치 없으면 v3 zip 전체에서 검색
        if (-not $target) {
            $target = $files | Where-Object {
                $_.name -match "\.zip$" -and $_.name -match "v\.?3"
            } | Sort-Object name -Descending | Select-Object -First 1
        }

        if ($target) {
            $dlFile = "$N2N_DIR\$($target.name)"
            Write-Host "  → 다운로드: $($target.name)" -ForegroundColor Green
            Invoke-WebRequest -Uri $target.download_url -OutFile $dlFile -UseBasicParsing

            $tempDir = "$N2N_DIR\_temp"
            Expand-Archive -Path $dlFile -DestinationPath $tempDir -Force
            $foundEdge = Get-ChildItem -Path $tempDir -Recurse -Filter "edge.exe" | Select-Object -First 1
            if ($foundEdge) {
                Copy-Item -Path $foundEdge.FullName -Destination $edgeExe -Force
                $downloaded = $true
                Write-Host "  → edge.exe 설치 완료!" -ForegroundColor Green
            }
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $dlFile -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "  [!] v3 Windows 빌드를 찾지 못했습니다" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [!] GitHub 다운로드 실패: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- 이미 C:\n2n\edge.exe가 있으면 OK ---
if (-not $downloaded -and (Test-Path $edgeExe)) {
    Write-Host "  → 기존 edge.exe 확인됨" -ForegroundColor Green
    $downloaded = $true
}

# --- 실패 시 수동 안내 ---
if (-not $downloaded) {
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Red
    Write-Host "  [!] 자동 다운로드 실패!" -ForegroundColor Red
    Write-Host "  ================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  수동 다운로드 방법:" -ForegroundColor White
    Write-Host "  1. 아래 링크 접속" -ForegroundColor White
    Write-Host "     https://github.com/lucktu/n2n/tree/master/Windows" -ForegroundColor Cyan
    Write-Host "  2. 파일명에 v3, x64 가 포함된 .zip 다운로드" -ForegroundColor White
    Write-Host "  3. zip 안의 edge.exe를 이 스크립트 폴더에 넣기" -ForegroundColor White
    Write-Host "  4. 이 스크립트 다시 실행" -ForegroundColor White
    Write-Host ""
    Read-Host "  Enter를 눌러 종료"
    exit 1
}

Write-Host "  → edge.exe 확인됨: $edgeExe" -ForegroundColor Green

#-----------------------------------------------------------------------------
# 3. TAP 네트워크 드라이버 설치
#-----------------------------------------------------------------------------
Write-Host "[3/5] TAP 네트워크 드라이버 확인..." -ForegroundColor Yellow

$tapAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*TAP*" }

if (-not $tapAdapter) {
    Write-Host "  TAP 드라이버 설치 중..." -ForegroundColor Yellow
    $tapUrl = "https://build.openvpn.net/downloads/releases/tap-windows-9.24.7-I601-Win10.exe"
    $tapInstaller = "$N2N_DIR\tap-installer.exe"
    try {
        Invoke-WebRequest -Uri $tapUrl -OutFile $tapInstaller -UseBasicParsing
        Start-Process -FilePath $tapInstaller -ArgumentList "/S" -Wait
        Start-Sleep -Seconds 3
        $tapAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*TAP*" }
        if ($tapAdapter) {
            Write-Host "  → TAP 드라이버 설치 완료!" -ForegroundColor Green
        } else {
            Write-Host "  → TAP 설치됨 (재부팅 필요할 수 있음)" -ForegroundColor Yellow
        }
        Remove-Item -Path $tapInstaller -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  [!] TAP 자동 설치 실패. 수동 설치:" -ForegroundColor Red
        Write-Host "      https://openvpn.net/community-downloads/" -ForegroundColor Cyan
    }
} else {
    Write-Host "  → TAP 드라이버 확인됨: $($tapAdapter.Name)" -ForegroundColor Green
}

#-----------------------------------------------------------------------------
# 4. 방화벽 규칙
#-----------------------------------------------------------------------------
Write-Host "[4/5] Windows 방화벽 규칙 설정..." -ForegroundColor Yellow
try {
    # 기존 규칙 정리
    Remove-NetFirewallRule -DisplayName "n2n Edge VPN*" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "GameLink VPN*" -ErrorAction SilentlyContinue

    # edge.exe UDP 허용
    New-NetFirewallRule -DisplayName "n2n Edge VPN" -Direction Inbound -Protocol UDP -Action Allow -Description "GameLink - P2P Gaming LAN" | Out-Null
    New-NetFirewallRule -DisplayName "n2n Edge VPN (Out)" -Direction Outbound -Protocol UDP -Action Allow -Description "GameLink - P2P Gaming LAN" | Out-Null

    # VPN 서브넷 전체 허용 (10.0.0.0/16)
    New-NetFirewallRule -DisplayName "GameLink VPN In" -Direction Inbound -RemoteAddress 10.0.0.0/16 -Action Allow -Description "GameLink VPN subnet" | Out-Null
    New-NetFirewallRule -DisplayName "GameLink VPN Out" -Direction Outbound -RemoteAddress 10.0.0.0/16 -Action Allow -Description "GameLink VPN subnet" | Out-Null

    Write-Host "  → 방화벽 규칙 추가됨 (edge UDP + VPN 서브넷)" -ForegroundColor Green
} catch {
    Write-Host "  [!] 방화벽 규칙 추가 실패" -ForegroundColor Yellow
}

# TAP 어댑터를 Private 네트워크로 변경 (LAN 검색 + ping 허용)
try {
    $tapProfile = Get-NetConnectionProfile -InterfaceAlias "로컬 영역 연결" -ErrorAction SilentlyContinue
    if ($tapProfile -and $tapProfile.NetworkCategory -ne "Private") {
        Set-NetConnectionProfile -InterfaceAlias "로컬 영역 연결" -NetworkCategory Private
        Write-Host "  → TAP 어댑터 네트워크 → Private 변경됨" -ForegroundColor Green
    } elseif ($tapProfile) {
        Write-Host "  → TAP 어댑터 이미 Private" -ForegroundColor Green
    }
} catch {
    Write-Host "  [!] TAP 네트워크 프로필 변경은 VPN 연결 후 수동 설정 필요" -ForegroundColor Yellow
    Write-Host "      Set-NetConnectionProfile -InterfaceAlias '로컬 영역 연결' -NetworkCategory Private" -ForegroundColor Gray
}

#-----------------------------------------------------------------------------
# 5. 회원번호 입력 & 배치 파일 생성
#-----------------------------------------------------------------------------
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  회원 고유번호 입력"                  -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  회원번호에 따라 VPN IP가 자동 계산됩니다:" -ForegroundColor Gray
Write-Host "  번호 27   → IP 10.0.0.27" -ForegroundColor Gray
Write-Host "  번호 254  → IP 10.0.0.254" -ForegroundColor Gray
Write-Host "  번호 300  → IP 10.0.1.46" -ForegroundColor Gray
Write-Host "  번호 1024 → IP 10.0.4.3" -ForegroundColor Gray
Write-Host ""

do {
    $memberInput = Read-Host "  회원 고유번호를 입력하세요"
    $MEMBER_ID = 0
    if ([int]::TryParse($memberInput, [ref]$MEMBER_ID) -and $MEMBER_ID -ge 1 -and $MEMBER_ID -le 65024) {
        $octet3 = [math]::Floor(($MEMBER_ID - 1) / 254)
        $octet4 = (($MEMBER_ID - 1) % 254) + 1
        $myIP = "10.0.$octet3.$octet4"
        Write-Host ""
        Write-Host "  회원번호: $MEMBER_ID → VPN IP: $myIP" -ForegroundColor Green
        Write-Host ""
        $confirm = Read-Host "  맞으면 Enter, 다시 입력하려면 N"
        if ($confirm -eq "" -or $confirm -eq "Y" -or $confirm -eq "y") { break }
    } else {
        Write-Host "  [!] 1 ~ 65024 사이 숫자를 입력하세요" -ForegroundColor Red
    }
} while ($true)

Write-Host "[5/5] 설정 파일 및 트레이 앱 생성..." -ForegroundColor Yellow

# --- config.ini 생성 ---
$configIni = @"
[VPN]
; GameLink 설정 파일
; 메모장으로 수정 가능합니다

; 슈퍼노드 주소 (변경 금지)
SuperNode=$SUPERNODE

; 커뮤니티 이름 (변경 금지)
Community=$COMMUNITY

; 암호화 키 (변경 금지)
Key=$ENCRYPT_KEY

; 본인 회원 고유번호 (잘못 입력했으면 여기서 수정)
MemberID=$MEMBER_ID
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$N2N_DIR\config.ini", $configIni, $utf8NoBom)
Write-Host "  → config.ini 생성됨" -ForegroundColor Green

# --- GameLink.exe 시스템 트레이 앱 (C#) ---
$trayAppCs = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Security.Principal;
using System.Threading;
using System.Windows.Forms;
using System.Collections.Generic;

class GameLinkTray : Form {
    private NotifyIcon trayIcon;
    private ContextMenuStrip trayMenu;
    private ToolStripMenuItem statusItem;
    private RichTextBox logBox;
    private Process edgeProcess;
    private string edgePath, community, key, supernode, myIp, baseDir;
    private int memberId;
    private bool connected = false;

    static Dictionary<string,string> ReadIni(string path) {
        var dict = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        if (!File.Exists(path)) return dict;
        foreach (var raw in File.ReadAllLines(path)) {
            string line = raw.Trim();
            if (line.Length == 0 || line[0] == ';' || line[0] == '#' || line[0] == '[') continue;
            int eq = line.IndexOf('=');
            if (eq > 0) dict[line.Substring(0, eq).Trim()] = line.Substring(eq + 1).Trim();
        }
        return dict;
    }
    static string Ini(Dictionary<string,string> d, string k, string def = "") {
        string v; return d.TryGetValue(k, out v) ? v : def;
    }

    public GameLinkTray() {
        baseDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
        string iniPath = Path.Combine(baseDir, "config.ini");
        edgePath = Path.Combine(baseDir, "edge.exe");

        if (!File.Exists(iniPath)) {
            MessageBox.Show("config.ini 를 찾을 수 없습니다!\n" + iniPath, "GameLink", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Environment.Exit(1);
        }
        if (!File.Exists(edgePath)) {
            MessageBox.Show("edge.exe 를 찾을 수 없습니다!\n" + edgePath, "GameLink", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Environment.Exit(1);
        }

        var cfg = ReadIni(iniPath);
        supernode = Ini(cfg, "SuperNode", "sim.vpn.m-club.or.kr:7654");
        community = Ini(cfg, "Community", "MCK_LAN");
        key       = Ini(cfg, "Key", "");
        int.TryParse(Ini(cfg, "MemberID", "0"), out memberId);

        if (memberId <= 0) {
            MessageBox.Show("config.ini 의 MemberID 값이 잘못되었습니다.", "GameLink", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Environment.Exit(1);
        }

        int t = memberId - 1;
        myIp = "10.0." + (t / 254) + "." + (t % 254 + 1);

        // 로그 창 설정
        this.Text = "GameLink 로그 - " + myIp;
        this.Size = new Size(700, 420);
        this.StartPosition = FormStartPosition.CenterScreen;
        this.FormBorderStyle = FormBorderStyle.SizableToolWindow;
        this.ShowInTaskbar = false;

        logBox = new RichTextBox();
        logBox.Dock = DockStyle.Fill;
        logBox.ReadOnly = true;
        logBox.BackColor = Color.FromArgb(30, 30, 30);
        logBox.ForeColor = Color.FromArgb(180, 255, 180);
        logBox.Font = new Font("Consolas", 9.5f);
        logBox.BorderStyle = BorderStyle.None;
        this.Controls.Add(logBox);

        // 닫기 → 숨김 (종료 시에는 진짜 닫기)
        this.FormClosing += (s, e) => { if (!exiting) { e.Cancel = true; this.Hide(); } };

        // 트레이 메뉴
        trayMenu = new ContextMenuStrip();
        statusItem = new ToolStripMenuItem("GameLink");
        statusItem.Enabled = false;
        trayMenu.Items.Add(statusItem);
        trayMenu.Items.Add(new ToolStripSeparator());
        trayMenu.Items.Add("연결 (Connect)", null, (s, e) => Connect());
        trayMenu.Items.Add("재연결 (Reconnect)", null, (s, e) => Reconnect());
        trayMenu.Items.Add("연결 해제 (Disconnect)", null, (s, e) => Disconnect());
        trayMenu.Items.Add(new ToolStripSeparator());
        trayMenu.Items.Add("로그 보기", null, (s, e) => ShowLog());
        trayMenu.Items.Add("config.ini 열기", null, (s, e) => {
            try { Process.Start("notepad.exe", Path.Combine(baseDir, "config.ini")); } catch {}
        });
        trayMenu.Items.Add(new ToolStripSeparator());
        trayMenu.Items.Add("종료 (Exit)", null, (s, e) => ExitApp());

        // 트레이 아이콘
        trayIcon = new NotifyIcon();
        trayIcon.ContextMenuStrip = trayMenu;
        trayIcon.Visible = true;
        trayIcon.MouseClick += (s, e) => { if (e.Button == MouseButtons.Left) ShowLog(); };
        SetTrayStatus("대기", Color.Gray);

        // 자동 연결
        Connect();
    }

    private Icon MakeIcon(Color c) {
        var bmp = new Bitmap(16, 16);
        using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            using (var brush = new SolidBrush(c))
                g.FillEllipse(brush, 2, 2, 12, 12);
            using (var pen = new Pen(Color.FromArgb(60, 0, 0, 0), 1))
                g.DrawEllipse(pen, 2, 2, 12, 12);
        }
        IntPtr hIcon = bmp.GetHicon();
        Icon icon = (Icon)Icon.FromHandle(hIcon).Clone();
        DestroyIcon(hIcon);
        return icon;
    }
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    static extern bool DestroyIcon(IntPtr handle);

    private void SetTrayStatus(string status, Color color) {
        trayIcon.Icon = MakeIcon(color);
        trayIcon.Text = "GameLink - " + status;
        statusItem.Text = myIp + " (" + status + ")";
    }

    private void Log(string msg) {
        if (logBox.InvokeRequired) {
            try { logBox.BeginInvoke(new Action(() => Log(msg))); } catch {}
            return;
        }
        string time = DateTime.Now.ToString("HH:mm:ss");
        logBox.AppendText("[" + time + "] " + msg + "\n");
        logBox.ScrollToCaret();

        // supernode 연결 성공 감지
        if (msg.Contains("[OK] edge") && msg.Contains("supernode")) {
            SetTrayStatus("연결됨 " + myIp, Color.LimeGreen);
            trayIcon.ShowBalloonTip(3000, "GameLink", "VPN 연결 성공!\nIP: " + myIp, ToolTipIcon.Info);
            // TAP 어댑터를 Private 네트워크로 변경 (ping/LAN 허용)
            try {
                var ps = new ProcessStartInfo {
                    FileName = "powershell",
                    Arguments = "-NoProfile -Command \"Set-NetConnectionProfile -InterfaceAlias '로컬 영역 연결' -NetworkCategory Private\"",
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                Process.Start(ps);
            } catch {}
        }
        // supernode 응답 없음 감지
        if (msg.Contains("WARNING: supernode not responding")) {
            SetTrayStatus("연결 시도 중...", Color.Orange);
        }
    }

    private void Connect() {
        if (connected && edgeProcess != null && !edgeProcess.HasExited) {
            Log("이미 연결되어 있습니다. 재연결하려면 우클릭 → 재연결");
            return;
        }

        // 기존 edge 프로세스 정리
        try {
            var kill = new ProcessStartInfo {
                FileName = "taskkill",
                Arguments = "/F /IM edge.exe",
                UseShellExecute = false,
                CreateNoWindow = true
            };
            var kp = Process.Start(kill);
            kp.WaitForExit(3000);
        } catch {}
        Thread.Sleep(500);

        Log("=========================================");
        Log("  GameLink - P2P Gaming LAN");
        Log("=========================================");
        Log("  서버:      " + supernode);
        Log("  커뮤니티:  " + community);
        Log("  회원번호:  " + memberId);
        Log("  VPN IP:    " + myIp);
        Log("");
        Log("연결 시작...");
        SetTrayStatus("연결 중...", Color.Yellow);

        try {
            var psi = new ProcessStartInfo {
                FileName = edgePath,
                Arguments = string.Format("-c {0} -k {1} -a {2}/16 -l {3} -A3 -b", community, key, myIp, supernode),
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardOutputEncoding = System.Text.Encoding.Default,
                StandardErrorEncoding = System.Text.Encoding.Default
            };

            edgeProcess = new Process();
            edgeProcess.StartInfo = psi;
            edgeProcess.OutputDataReceived += (s, e) => { if (!string.IsNullOrWhiteSpace(e.Data)) Log(e.Data); };
            edgeProcess.ErrorDataReceived  += (s, e) => { if (!string.IsNullOrWhiteSpace(e.Data)) Log(e.Data); };
            edgeProcess.EnableRaisingEvents = true;
            edgeProcess.Exited += (s, e) => {
                connected = false;
                try { SetTrayStatus("연결 끊김", Color.Red); } catch {}
                Log("edge.exe 가 종료되었습니다.");
            };

            edgeProcess.Start();
            edgeProcess.BeginOutputReadLine();
            edgeProcess.BeginErrorReadLine();
            connected = true;
        } catch (Exception ex) {
            Log("[실패] " + ex.Message);
            SetTrayStatus("오류", Color.Red);
        }
    }

    private void Disconnect() {
        // 1. 관리 중인 프로세스 종료
        try {
            if (edgeProcess != null && !edgeProcess.HasExited) {
                edgeProcess.Kill();
                edgeProcess.WaitForExit(3000);
            }
        } catch {}
        edgeProcess = null;

        // 2. taskkill로 확실하게 종료 (관리자 권한)
        try {
            var kill = new ProcessStartInfo {
                FileName = "taskkill",
                Arguments = "/F /IM edge.exe",
                UseShellExecute = false,
                CreateNoWindow = true
            };
            var p = Process.Start(kill);
            p.WaitForExit(3000);
        } catch {}

        connected = false;
        SetTrayStatus("연결 해제", Color.Gray);
        Log("VPN 연결이 해제되었습니다.");
    }

    private void Reconnect() {
        Log("재연결 중...");
        Disconnect();
        Thread.Sleep(1000);
        Connect();
    }

    private void ShowLog() {
        this.Show();
        this.WindowState = FormWindowState.Normal;
        this.BringToFront();
        this.Activate();
    }

    private bool exiting = false;

    private void ExitApp() {
        exiting = true;
        Disconnect();
        trayIcon.Visible = false;
        trayIcon.Dispose();
        Environment.Exit(0);
    }

    protected override void OnLoad(EventArgs e) {
        base.OnLoad(e);
        this.Hide();
    }

    [STAThread]
    static void Main() {
        if (!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) {
            MessageBox.Show("관리자 권한으로 실행해주세요!\n\n우클릭 → 관리자 권한으로 실행", "GameLink", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }
        bool created;
        var mutex = new Mutex(true, "GameLink_TRAY_MUTEX", out created);
        if (!created) {
            MessageBox.Show("GameLink 가 이미 실행 중입니다.\n시스템 트레이를 확인하세요.", "GameLink", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new GameLinkTray());
        GC.KeepAlive(mutex);
    }
}
'@

# UAC 관리자 권한 manifest
$manifest = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
'@

$manifestFile = "$N2N_DIR\app.manifest"
[System.IO.File]::WriteAllText($manifestFile, $manifest, $utf8NoBom)

# C# 컴파일
$cscPath = Join-Path ([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) "csc.exe"
if (-not (Test-Path $cscPath)) {
    $cscPath = Get-ChildItem "C:\Windows\Microsoft.NET\Framework64\v4*\csc.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}

if ($cscPath -and (Test-Path $cscPath)) {
    Write-Host "  컴파일러: $cscPath" -ForegroundColor Gray

    $csFile = "$N2N_DIR\GameLink.cs"
    $exeFile = "$N2N_DIR\GameLink.exe"
    [System.IO.File]::WriteAllText($csFile, $trayAppCs, $utf8NoBom)

    $result = & $cscPath /nologo /target:winexe /out:$exeFile /optimize+ /win32manifest:$manifestFile /r:System.Windows.Forms.dll /r:System.Drawing.dll $csFile 2>&1
    if (Test-Path $exeFile) {
        Write-Host "  → GameLink.exe 생성 완료" -ForegroundColor Green
    } else {
        Write-Host "  [!] GameLink.exe 컴파일 실패:" -ForegroundColor Red
        Write-Host "  $result" -ForegroundColor Red
    }
    Remove-Item $csFile -Force -ErrorAction SilentlyContinue
    Remove-Item $manifestFile -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "  [!] C# 컴파일러를 찾을 수 없습니다" -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  설치 완료!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [C:\n2n 폴더 구조]" -ForegroundColor Yellow
Write-Host "    GameLink.exe   ← 더블클릭으로 실행 (시스템 트레이 앱)" -ForegroundColor White
Write-Host "    config.ini    ← 설정 파일 (메모장으로 수정 가능)" -ForegroundColor White
Write-Host "    edge.exe      ← n2n 엔진" -ForegroundColor Gray
Write-Host ""
Write-Host "  [사용법]" -ForegroundColor Yellow
Write-Host "    GameLink.exe 더블클릭 → 자동 연결 + 시스템 트레이" -ForegroundColor White
Write-Host "    트레이 좌클릭  → 로그 창" -ForegroundColor White
Write-Host "    트레이 우클릭  → 연결/재연결/해제/종료" -ForegroundColor White
Write-Host ""
Write-Host "  [내 설정]" -ForegroundColor Yellow
Write-Host "  회원번호: $MEMBER_ID" -ForegroundColor White
Write-Host "  VPN IP:   $myIP" -ForegroundColor White
Write-Host "  설정 변경: C:\n2n\config.ini 메모장으로 열어서 수정" -ForegroundColor Gray
Write-Host ""
Read-Host "Enter를 눌러 종료"
