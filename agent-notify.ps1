param(
    [string]$Source = "generic",
    [string]$Event = "auto"
)

$ErrorActionPreference = "SilentlyContinue"
# Fix Chinese encoding: force UTF-8 for stdin/stdout
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$Script:HookRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:LogPath = Join-Path $Script:HookRoot "agent-notify.log"

function Write-NotifyLog {
    param([string]$Message)

    try {
        $timestamp = (Get-Date).ToString("s")
        Add-Content -Path $Script:LogPath -Value "[$timestamp] $Message" -Encoding UTF8
    } catch {
    }
}

function Get-JsonPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        if ($null -eq $Object) {
            continue
        }

        $property = $Object.PSObject.Properties[$name]
        if ($null -ne $property -and $null -ne $property.Value) {
            return [string]$property.Value
        }
    }

    return $null
}

function ConvertTo-StringValue {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        return $Value
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        foreach ($item in $Value) {
            $candidate = ConvertTo-StringValue -Value $item
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                return $candidate
            }
        }

        return $null
    }

    $props = @(
        "text",
        "message",
        "content",
        "summary",
        "last_assistant_message",
        "last-assistant-message",
        "body",
        "title",
        "status"
    )

    foreach ($name in $props) {
        $property = $Value.PSObject.Properties[$name]
        if ($null -ne $property) {
            $candidate = ConvertTo-StringValue -Value $property.Value
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                return $candidate
            }
        }
    }

    return $null
}

function Parse-NotifyPayload {
    param([string]$PayloadText)

    if ([string]::IsNullOrWhiteSpace($PayloadText)) {
        return [pscustomobject]@{
            Raw       = $null
            Message   = $null
            EventKind = $null
        }
    }

    try {
        $payload = $PayloadText | ConvertFrom-Json
        $message = Get-JsonPropertyValue -Object $payload -Names @(
            "last-assistant-message",
            "last_assistant_message",
            "message",
            "text"
        )

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = ConvertTo-StringValue -Value $payload
        }

        $eventKind = Get-JsonPropertyValue -Object $payload -Names @(
            "event",
            "event_kind",
            "eventKind",
            "notification_type",
            "notificationType",
            "kind",
            "status",
            "level",
            "severity",
            "type"
        )

        return [pscustomobject]@{
            Raw       = $payload
            Message   = $message
            EventKind = $eventKind
        }
    } catch {
        Write-NotifyLog "Failed to parse payload as JSON: $($_.Exception.Message)"
        return [pscustomobject]@{
            Raw       = $null
            Message   = (Normalize-Text -Text $PayloadText -MaxLength 160)
            EventKind = $null
        }
    }
}

function Resolve-EventKind {
    param(
        [string]$RequestedEvent,
        [string]$RequestedSource,
        [string]$MessageText,
        [string]$PayloadEventKind
    )

    if ($RequestedEvent -ne "auto") {
        return $RequestedEvent
    }

    $combinedText = @($PayloadEventKind, $MessageText) -join " "

    if ($combinedText -match "(?i)\b(error|failed|failure|exception|fatal|denied|rejected)\b") {
        return "error"
    }

    if ($RequestedSource -eq "claude") {
        return "attention"
    }

    if ([string]::IsNullOrWhiteSpace($MessageText)) {
        return "complete"
    }

    if ($combinedText -match "(?i)\b(approve|approval|confirm|confirmation|permission|continue|continue\?|question|input required|attention|review|action required)\b|\?$") {
        return "attention"
    }

    return "complete"
}

function Get-SourceLabel {
    param([string]$Name)

    switch ($Name) {
        "codex" { return "Codex CLI" }
        "claude" { return "Claude Code" }
        default { return "Agent CLI" }
    }
}

function Normalize-Text {
    param(
        [string]$Text,
        [int]$MaxLength = 180
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $normalized = ($Text -replace "\s+", " ").Trim()
    if ($normalized.Length -gt $MaxLength) {
        return $normalized.Substring(0, $MaxLength - 3) + "..."
    }

    return $normalized
}

function Get-NotificationTitle {
    param(
        [string]$SourceName,
        [string]$Kind
    )

    $prefix = Get-SourceLabel -Name $SourceName
    $suffix = switch ($Kind) {
        "attention" { "Needs Attention" }
        "error" { "Failed" }
        default { "Finished" }
    }

    return "${prefix}: $suffix"
}

function Escape-ToastText {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    return [System.Security.SecurityElement]::Escape($Text)
}

function ConvertTo-SingleQuotedLiteral {
    param([string]$Text)

    if ($null -eq $Text) {
        return "''"
    }

    return "'" + ($Text -replace "'", "''") + "'"
}

function Play-Sound {
    param([string]$Kind)

    try {
        Add-Type -AssemblyName System.Windows.Extensions
    } catch {
    }

    switch ($Kind) {
        "attention" {
            1..3 | ForEach-Object {
                [System.Media.SystemSounds]::Hand.Play()
                Start-Sleep -Milliseconds 180
            }
        }
        "error" {
            1..2 | ForEach-Object {
                [System.Media.SystemSounds]::Hand.Play()
                Start-Sleep -Milliseconds 260
            }
        }
        "complete" {
            1..2 | ForEach-Object {
                [System.Media.SystemSounds]::Asterisk.Play()
                Start-Sleep -Milliseconds 140
            }
        }
        default {
            [System.Media.SystemSounds]::Asterisk.Play()
        }
    }
}

function Show-Notification {
    param(
        [string]$SourceName,
        [string]$Kind,
        [string]$MessageText
    )

    $title = Get-NotificationTitle -SourceName $SourceName -Kind $Kind
    $body = switch ($Kind) {
        "attention" { "Needs attention or confirmation." }
        "error" { "Task failed or was blocked." }
        "complete" { "Task finished." }
        default { "Status update." }
    }

    $snippet = Normalize-Text -Text $MessageText -MaxLength 160
    if ($snippet) {
        $body = $snippet
    }

    $wpfShown = Show-WpfPopup -Title $title -Body $body -Kind $Kind
    if (-not $wpfShown) {
        Show-BalloonNotification -Title $title -Body $body -Kind $Kind
    }

    Show-ToastNotification -Title $title -Body $body -Kind $Kind | Out-Null
}

function Show-ToastNotification {
    param(
        [string]$Title,
        [string]$Body,
        [string]$Kind
    )

    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null
    } catch {
        Write-NotifyLog "Toast APIs unavailable."
        return $false
    }

    $titleText = Escape-ToastText -Text $Title
    $bodyText = Escape-ToastText -Text $Body
    $scenarioAttr = if ($Kind -eq "attention") { ' scenario="reminder"' } else { "" }
    $xml = @"
<toast$scenarioAttr>
  <visual>
    <binding template="ToastGeneric">
      <text>$titleText</text>
      <text>$bodyText</text>
    </binding>
  </visual>
  <audio silent="true" />
</toast>
"@

    try {
        $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $doc.LoadXml($xml)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($doc)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Windows PowerShell")
        $notifier.Show($toast)
        Write-NotifyLog "Toast notification displayed."
        return $true
    } catch {
        Write-NotifyLog "Toast failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-WpfPopup {
    param(
        [string]$Title,
        [string]$Body,
        [string]$Kind
    )

    $popupScript = Join-Path $Script:HookRoot "wpf-popup.ps1"
    if (-not (Test-Path $popupScript)) {
        Write-NotifyLog "WPF popup helper missing."
        return $false
    }

    try {
        $escapedTitle = $Title -replace "'", "''"
        $escapedBody = $Body -replace "'", "''"
        $escapedKind = $Kind -replace "'", "''"
        $escapedLog = $Script:LogPath -replace "'", "''"
        $escapedScript = $popupScript -replace "'", "''"
        $cmd = "& '$escapedScript' -Title '$escapedTitle' -Body '$escapedBody' -Kind '$escapedKind' -LogPath '$escapedLog'"
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Hidden -EncodedCommand $encoded" -WindowStyle Hidden
        Write-NotifyLog "WPF popup process launched (detached)."
        return $true
    } catch {
        Write-NotifyLog "WPF popup failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-BalloonNotification {
    param(
        [string]$Title,
        [string]$Body,
        [string]$Kind
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    } catch {
        return
    }

    try {
        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $notifyIcon.Icon = switch ($Kind) {
            "attention" { [System.Drawing.SystemIcons]::Warning }
            "error" { [System.Drawing.SystemIcons]::Error }
            default { [System.Drawing.SystemIcons]::Information }
        }
        $notifyIcon.Text = Normalize-Text -Text $title -MaxLength 60
        $notifyIcon.BalloonTipTitle = $title
        $notifyIcon.BalloonTipText = $body
        $notifyIcon.BalloonTipIcon = switch ($Kind) {
            "attention" { [System.Windows.Forms.ToolTipIcon]::Warning }
            "error" { [System.Windows.Forms.ToolTipIcon]::Error }
            default { [System.Windows.Forms.ToolTipIcon]::Info }
        }
        $notifyIcon.Visible = $true
        $notifyIcon.ShowBalloonTip(2500)
        Start-Sleep -Milliseconds 1400
        $notifyIcon.Dispose()
        Write-NotifyLog "Fallback balloon notification displayed."
    } catch {
        Write-NotifyLog "Fallback balloon notification failed."
    }
}

$stdinText = ""
try {
    if ([Console]::IsInputRedirected) {
        $stdinText = [Console]::In.ReadToEnd()
    }
} catch {
}

$payloadInfo = Parse-NotifyPayload -PayloadText $stdinText
$messageText = $payloadInfo.Message
$kind = Resolve-EventKind -RequestedEvent $Event -RequestedSource $Source -MessageText $messageText -PayloadEventKind $payloadInfo.EventKind
Write-NotifyLog "source=$Source event=$Event resolved=$kind message=$([string](Normalize-Text -Text $messageText -MaxLength 100))"
Play-Sound -Kind $kind
Show-Notification -SourceName $Source -Kind $kind -MessageText $messageText
exit 0
