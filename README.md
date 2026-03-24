<div align="center">

**[English](README.md)** | **[中文](README_CN.md)**

# agent-notify

### Stop watching your terminal. Start vibe coding.

Windows desktop notifications for AI coding agents.  
Get a sound + popup when your agent finishes, needs attention, or fails.

**Works with** Claude Code | Codex CLI | any agent that can run a shell command

</div>

## What This Repo Contains

This repo ships one shared Windows notification hook:

- `agent-notify.cmd`
- `agent-notify.ps1`
- `wpf-popup.ps1`

The scripts are shared across agents. What changes is the caller:

- The previous hook example in this repo is for **Claude Code**
- The new notify example in this repo is for **Codex CLI**

## Features

| Feature | Description |
|---------|-------------|
| WPF popup | Top-right popup card, auto-dismiss, click to close |
| Status colors | Green = complete, yellow = attention, red = error |
| System sounds | Distinct audio cues for complete / attention / error |
| Smart routing | `auto` mode classifies messages by content |
| JSON parsing | Reads structured payloads from stdin |
| Fallback chain | WPF popup -> Windows Toast -> balloon fallback |
| Zero dependencies | Pure PowerShell + built-in Windows/.NET |

## Install

```powershell
git clone https://github.com/Annoyingwinter/agent-notify.git
cd agent-notify
powershell -ExecutionPolicy Bypass -File install.ps1
```

This copies the scripts to `%USERPROFILE%\.agent-hooks\` and installs `agent-notify.cmd` into `%APPDATA%\npm`.

If `%APPDATA%\npm` is missing from your user `PATH`, the installer adds it for you. After reopening your terminal, `agent-notify.cmd` should work from anywhere.

For portable open-source setups, keep agent configs like this:

- Use `agent-notify.cmd` directly
- Do not hardcode an absolute local path

## Agent Setup

### Claude Code

This is the older example. Claude calls the hook from `~/.claude/settings.json`.

```jsonc
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

See: [`examples/claude-settings.json`](examples/claude-settings.json)

### Codex CLI

This is the new example. Codex calls the hook from `~/.codex/config.toml`.

```toml
notify = ["agent-notify.cmd", "codex", "auto"]

[tui]
notifications = true
notification_method = "auto"
```

This tells Codex CLI to invoke the same Windows notification hook and label the popup as a Codex CLI event.

See: [`examples/codex-config.toml`](examples/codex-config.toml)

## Usage

```powershell
# Claude Code: task finished
echo '{"message":"Build complete"}' | agent-notify.cmd claude complete

# Claude Code: needs attention
echo '{"message":"Approve this PR?"}' | agent-notify.cmd claude attention

# Claude Code: error
echo '{"message":"Build failed"}' | agent-notify.cmd claude error

# Codex CLI: auto-route from payload
echo '{"message":"Build complete","status":"complete"}' | agent-notify.cmd codex auto
echo '{"message":"Need confirmation?","status":"attention"}' | agent-notify.cmd codex auto
echo '{"message":"Tests failed","status":"error"}' | agent-notify.cmd codex auto
```

## How It Works

```text
Claude Code hook
or
Codex CLI notify callback
        |
        v
agent-notify.cmd
        |
        v
agent-notify.ps1
        |
        +--> wpf-popup.ps1
        +--> Windows Toast
        +--> balloon fallback
```

Key points:

- The same scripts support both Claude Code and Codex CLI
- The `source` argument controls whether the notification is labeled `claude` or `codex`
- The `event` argument can be explicit (`complete`, `attention`, `error`) or `auto`
- The WPF popup is the primary visible UI and uses top-right status cards

## Notification Styles

| Event | Color | Badge | Sound |
|-------|-------|-------|-------|
| `complete` | Green | `✓` | 2x system asterisk |
| `attention` | Yellow | `?` | 3x system hand |
| `error` | Red | `!` | 2x system hand |

## Project Structure

```text
agent-notify/
├── agent-notify.cmd
├── agent-notify.ps1
├── wpf-popup.ps1
├── enable-toast.ps1
├── install.ps1
├── examples/
│   ├── claude-settings.json
│   └── codex-config.toml
├── LICENSE
├── README.md
└── README_CN.md
```

## Requirements

- Windows 10 / 11
- PowerShell 5.1+
- .NET Framework / WPF support

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Sound works but no popup | Check `%USERPROFILE%\.agent-hooks\wpf-popup.ps1` |
| No Codex popup after editing config | Restart Codex CLI so it reloads `config.toml` |
| `agent-notify.cmd` is not found | Reopen the terminal so the updated user `PATH` is loaded |
| No visible Toast | WPF popup is primary; Toast is only fallback/secondary |
| Garbled text | Re-run `install.ps1`; scripts force UTF-8 |

## License

[MIT](LICENSE)
