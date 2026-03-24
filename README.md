<div align="center">

**[English](README.md)** | **[中文](README_CN.md)**

# agent-notify

### Stop watching your terminal. Start **vibe coding**.

Windows desktop notifications for AI coding agents.<br>
Get a sound + popup the instant your agent finishes — so you can tab away and actually be productive.

<br>

<table>
<tr>
<td align="center"><strong>Task Complete</strong></td>
<td align="center"><strong>Needs Attention</strong></td>
<td align="center"><strong>Error</strong></td>
</tr>
<tr>
<td align="center">

```diff
+ ✓ Claude Code: Finished
+ Build complete
```

</td>
<td align="center">

```fix
? Claude Code: Needs Attention
Test requires confirmation
```

</td>
<td align="center">

```diff
- ! Claude Code: Failed
- Build failed with 3 errors
```

</td>
</tr>
<tr>
<td align="center">Green card + 2x chime</td>
<td align="center">Yellow card + 3x alert</td>
<td align="center">Red card + 2x alarm</td>
</tr>
</table>

<br>

**Works with** &nbsp; Claude Code &nbsp;|&nbsp; Codex CLI &nbsp;|&nbsp; Any agent that can run a shell command

---

</div>

## The Problem

You're vibe coding with Claude Code or Codex. You send a prompt. Then you wait... and wait... staring at the terminal, not sure when it's done. You could be browsing, studying, or touching grass — but instead you're glued to a blinking cursor.

**agent-notify** fixes this. One install, and you'll never miss a completion again.

## Features

| Feature | Description |
|---------|-------------|
| **WPF Popup** | Beautiful styled card, top-right corner, fade-in/out animation, auto-dismiss after 6s, click to close |
| **System Sounds** | Distinct audio cues for complete / attention / error — hear it even when minimized |
| **Smart Routing** | Auto-detects event type from message content (errors, questions, completions) |
| **JSON Parsing** | Reads structured payloads from stdin for rich notification messages |
| **Detached Process** | Popup runs in a separate process — never blocks or gets killed by hook timeouts |
| **Multi-layer Fallback** | WPF popup → Windows Toast → Legacy Balloon — something will always show |
| **Zero Dependencies** | Pure PowerShell + built-in .NET. No npm, no Python, no installs beyond Windows itself |

## Quick Start

### 1. Install

```powershell
git clone https://github.com/Annoyingwinter/agent-notify.git
cd agent-notify
powershell -ExecutionPolicy Bypass -File install.ps1
```

This copies scripts to `%USERPROFILE%\.agent-hooks\` and puts `agent-notify.cmd` on your PATH.

### 2. Configure Claude Code

Add to your `~/.claude/settings.json` → `hooks` section:

```jsonc
{
  "hooks": {
    // Notify when Claude finishes a response
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
    // Notify when Claude needs your attention
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

### 3. Done!

Tab away. The popup will find you.

## Usage

```bash
# Task finished
echo '{"message":"Build complete"}' | agent-notify.cmd claude complete

# Needs attention
echo '{"message":"Approve this PR?"}' | agent-notify.cmd claude attention

# Error
echo '{"message":"Build failed"}' | agent-notify.cmd claude error

# No message (still shows popup + sound)
agent-notify.cmd claude complete
```

## How It Works

```
Claude Code finishes
        │
        ▼
   Stop hook fires
        │
        ▼
  agent-notify.cmd          ← entry point (batch file)
        │
        ▼
  agent-notify.ps1          ← main logic: parse event, play sound
        │
        ├──► wpf-popup.ps1  ← detached process: WPF popup window
        │
        └──► Toast API      ← Windows notification center (backup)
```

Key design decisions:
- **Detached popup process** — The WPF popup runs in its own `powershell.exe` process via `Start-Process` + `-EncodedCommand`. This means the parent script returns instantly (< 100ms), so it never hits the Claude Code hook timeout (typically 3-5s). The popup lives independently for its full 6-second display.
- **Smart event detection** — If you pass `auto` as the event type, it scans the message for keywords like "error", "failed", "approve", "confirm" to automatically choose the right notification style.
- **UTF-8 encoding** — Properly handles CJK characters in notification messages by forcing UTF-8 on stdin/stdout.

## Notification Styles

<table>
<tr><th>Event</th><th>Popup Style</th><th>Sound</th><th>Auto-detected keywords</th></tr>
<tr>
<td><code>complete</code></td>
<td>Green card, ✓ badge</td>
<td>2× system asterisk</td>
<td><em>(default)</em></td>
</tr>
<tr>
<td><code>attention</code></td>
<td>Yellow card, ? badge</td>
<td>3× system hand</td>
<td>approve, confirm, permission, question, review, <code>?</code></td>
</tr>
<tr>
<td><code>error</code></td>
<td>Red card, ! badge</td>
<td>2× system hand</td>
<td>error, failed, failure, exception, fatal, denied</td>
</tr>
</table>

## Project Structure

```
agent-notify/
├── agent-notify.cmd      # Entry point (batch wrapper)
├── agent-notify.ps1      # Core logic: event routing, sound, dispatch
├── wpf-popup.ps1         # WPF popup window (detached process)
├── enable-toast.ps1      # Enables Windows toast for PowerShell
├── install.ps1           # One-click installer
├── LICENSE               # MIT
└── README.md
```

## Codex CLI Setup

```jsonc
// In your Codex CLI config, add a post-completion hook:
{
  "hooks": {
    "post-completion": "agent-notify.cmd codex complete"
  }
}
```

## Requirements

- **Windows 10 / 11**
- **PowerShell 5.1+** (pre-installed on all modern Windows)
- **.NET Framework** (pre-installed, provides WPF)

No external dependencies. No npm. No Python. Just Windows.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| No popup appears | Run `enable-toast.ps1` to register PowerShell as notification source |
| Sound works but no popup | Check if `wpf-popup.ps1` exists in `%USERPROFILE%\.agent-hooks\` |
| Popup appears but garbled text | Encoding issue — the script sets UTF-8 automatically, re-run `install.ps1` |
| Hook timeout kills notification | Ensure you're on the latest version — popup now runs as detached process |

## Contributing

PRs welcome! Some ideas:

- [ ] macOS support (AppleScript / terminal-notifier)
- [ ] Linux support (notify-send / libnotify)
- [ ] Custom notification sounds
- [ ] Notification history / log viewer
- [ ] Integration with more agents (Cursor, Windsurf, Aider, etc.)

## License

[MIT](LICENSE) — do whatever you want with it.

---

<div align="center">
<br>
<strong>Built because staring at terminals is not vibe coding.</strong>
<br><br>
</div>
