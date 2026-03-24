$ErrorActionPreference = "Stop"

# Register Windows PowerShell as a toast notification source
$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows PowerShell"
if (-not (Test-Path $key)) {
    New-Item -Path $key -Force | Out-Null
    Write-Host "Created notification key for PowerShell"
}
New-ItemProperty -Path $key -Name "Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $key -Name "ShowBanner" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $key -Name "ShowInActionCenter" -Value 1 -PropertyType DWord -Force | Out-Null
Write-Host "PowerShell toast notifications ENABLED"

# Verify
$check = Get-ItemProperty $key
Write-Host "  Enabled: $($check.Enabled)"
Write-Host "  ShowBanner: $($check.ShowBanner)"
Write-Host "  ShowInActionCenter: $($check.ShowInActionCenter)"

# Check global notification center policy
$policyKey = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
if (Test-Path $policyKey) {
    $val = Get-ItemProperty $policyKey -Name "DisableNotificationCenter" -ErrorAction SilentlyContinue
    if ($val -and $val.DisableNotificationCenter -eq 1) {
        New-ItemProperty -Path $policyKey -Name "DisableNotificationCenter" -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Host "Re-enabled notification center (was disabled by policy)"
    } else {
        Write-Host "Notification center policy: OK"
    }
} else {
    Write-Host "Notification center policy: not set (OK)"
}

Write-Host "`nDone! Toast notifications should now work."
