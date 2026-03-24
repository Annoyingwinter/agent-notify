# agent-notify

Windows desktop notifications for AI coding agents (Claude Code, Codex CLI, etc).

Get a **sound + popup notification** when your AI agent finishes generating code, so you can tab away and do other things while waiting.

![notification preview](docs/preview.png)

## Features

- **WPF popup** — styled card with fade-in/out animation, appears top-right, auto-dismisses after 6s
- **System sound** — different sounds for complete/attention/error events
- **Windows Toast** — falls back to native toast notification (if enabled)
- **Balloon fallback** — if all else fails, uses legacy system tray balloon
- **Event types** — `complete` (green), `attention` (yellow), `error` (red)
- **Works with any agent** — Claude Code, Codex CLI, or any tool that can run a shell command

## Install

```powershell
git clone https://github.com/YOUR_USERNAME/agent-notify.git
cd agent-notify
powershell -ExecutionPolicy Bypass -File install.ps1
```

This installs the scripts to `%USERPROFILE%\.agent-hooks\` and puts `agent-notify.cmd` on your PATH.

## Claude Code Setup

Add to your `~/.claude/settings.json`:

```json
{
  "hooks": {
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
  }
}
```

## Usage

```bash
# Basic - task finished
echo '{"message":"Build complete"}' | agent-notify.cmd claude complete

# Needs attention
echo '{"message":"Test failed"}' | agent-notify.cmd claude attention

# Error
echo '{"message":"Build failed"}' | agent-notify.cmd claude error

# No message
agent-notify.cmd claude complete
```

## Event Types

| Event | Color | Sound | Use Case |
|-------|-------|-------|----------|
| `complete` | Green | 2x asterisk | Task finished |
| `attention` | Yellow | 3x hand | Needs user input |
| `error` | Red | 2x hand | Task failed |

## Files

| File | Description |
|------|-------------|
| `agent-notify.cmd` | Entry point, calls the PS1 script |
| `agent-notify.ps1` | Main notification logic (sound, routing, dispatch) |
| `wpf-popup.ps1` | WPF popup window (spawned as detached process) |
| `enable-toast.ps1` | Enables Windows toast notifications for PowerShell |
| `install.ps1` | One-click installer |

## Requirements

- Windows 10/11
- PowerShell 5.1+ (built-in)
- .NET Framework (built-in, for WPF)

## How It Works

1. Claude Code fires a `Stop` hook when it finishes a response
2. The hook runs `agent-notify.cmd`
3. `agent-notify.ps1` parses the event, plays a sound, and launches `wpf-popup.ps1` as a **detached process**
4. The popup appears top-right with a fade-in animation, auto-dismisses after 6 seconds
5. The parent process returns immediately so it doesn't block the hook timeout

## License

MIT
