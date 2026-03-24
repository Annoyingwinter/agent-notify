
# agent-notify installer for Windows
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$hookDir = Join-Path $env:USERPROFILE ".agent-hooks"
$npmBin = Join-Path $env:APPDATA "npm"

Write-Host "=== agent-notify installer ===" -ForegroundColor Cyan
Write-Host ""

# 1. Create hook directory
if (-not (Test-Path $hookDir)) {
    New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
    Write-Host "[+] Created $hookDir" -ForegroundColor Green
} else {
    Write-Host "[=] $hookDir already exists" -ForegroundColor Yellow
}

# 2. Copy scripts
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = @("agent-notify.ps1", "wpf-popup.ps1", "enable-toast.ps1")

foreach ($f in $files) {
    $src = Join-Path $scriptDir $f
    $dst = Join-Path $hookDir $f
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "[+] Installed $f -> $hookDir" -ForegroundColor Green
    } else {
        Write-Host "[-] Missing $f, skipped" -ForegroundColor Red
    }
}

# 3. Install agent-notify.cmd to npm global bin (on PATH)
$cmdSrc = Join-Path $scriptDir "agent-notify.cmd"
if (Test-Path $cmdSrc) {
    if (-not (Test-Path $npmBin)) {
        New-Item -ItemType Directory -Path $npmBin -Force | Out-Null
    }
    Copy-Item $cmdSrc (Join-Path $npmBin "agent-notify.cmd") -Force
    Write-Host "[+] Installed agent-notify.cmd -> $npmBin" -ForegroundColor Green
} else {
    Write-Host "[-] agent-notify.cmd not found, skipped" -ForegroundColor Red
}

# 4. Enable Windows toast notifications for PowerShell
Write-Host ""
Write-Host "Enabling Windows toast notifications..." -ForegroundColor Cyan
$toastScript = Join-Path $hookDir "enable-toast.ps1"
if (Test-Path $toastScript) {
    & $toastScript
}

# 5. Show Claude Code hook config
Write-Host ""
Write-Host "=== Setup complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Add this to your Claude Code settings.json hooks section:" -ForegroundColor Cyan
Write-Host @'

"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "cmd /c agent-notify.cmd claude complete",
        "timeout": 5000
      }
    ]
  }
],
"Notification": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "cmd /c agent-notify.cmd claude attention",
        "timeout": 5000
      }
    ]
  }
]
'@

Write-Host ""
Write-Host "Test it: echo test | agent-notify.cmd claude complete" -ForegroundColor Yellow
