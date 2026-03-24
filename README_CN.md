<div align="center">

**[English](README.md)** | **[中文](README_CN.md)**

# agent-notify

### 别再盯着终端傻等了。

这是一个给 AI 编程助手用的 Windows 桌面通知工具。  
当任务完成、需要你关注、或者出错时，立即弹窗并播放提示音。

**支持** Claude Code | Codex CLI | 任何能执行 shell 命令的 AI 工具

</div>

## 这个仓库现在是什么

这个仓库提供一套共用的 Windows 通知脚本：

- `agent-notify.cmd`
- `agent-notify.ps1`
- `wpf-popup.ps1`

脚本本身是共用的，区别只在“谁来调用它”：

- 之前那个 hook 示例是给 **Claude Code** 用的
- 这次新增并标注清楚的是 **Codex CLI** 的配置方式

## 功能

| 功能 | 说明 |
|------|------|
| WPF 弹窗 | 屏幕右上角卡片弹窗，自动关闭，点击可手动关闭 |
| 红黄绿状态 | 绿色完成，黄色关注，红色错误 |
| 系统提示音 | 完成 / 关注 / 错误三种不同声音 |
| 智能路由 | `auto` 模式下根据消息内容自动判断状态 |
| JSON 解析 | 支持从 stdin 读取结构化消息 |
| 多级降级 | WPF 弹窗 -> Windows Toast -> 气泡通知 |
| 零依赖 | 纯 PowerShell + Windows/.NET 自带能力 |

## 安装

```powershell
git clone https://github.com/Annoyingwinter/agent-notify.git
cd agent-notify
powershell -ExecutionPolicy Bypass -File install.ps1
```

安装后脚本会被复制到 `%USERPROFILE%\.agent-hooks\`，并提供 `agent-notify.cmd` 入口。

## Agent 配置

### Claude Code

这是仓库里之前的配置方式。Claude 在 `~/.claude/settings.json` 里通过 hooks 调用通知脚本。

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

见：[`examples/claude-settings.json`](examples/claude-settings.json)

### Codex CLI

这是这次补进去并明确标注的配置方式。Codex 在 `~/.codex/config.toml` 里通过 `notify` 调用同一套脚本。

```toml
notify = ["agent-notify.cmd", "codex", "auto"]

[tui]
notifications = true
notification_method = "auto"
```

这样 Codex CLI 在发出通知事件时就会调用这套 Windows hook，并把来源标记为 `codex`。

见：[`examples/codex-config.toml`](examples/codex-config.toml)

## 用法

```powershell
# Claude Code：完成
echo '{"message":"构建完成"}' | agent-notify.cmd claude complete

# Claude Code：需要关注
echo '{"message":"请确认这个 PR"}' | agent-notify.cmd claude attention

# Claude Code：错误
echo '{"message":"构建失败"}' | agent-notify.cmd claude error

# Codex CLI：自动根据 payload 判断状态
echo '{"message":"构建完成","status":"complete"}' | agent-notify.cmd codex auto
echo '{"message":"需要确认？","status":"attention"}' | agent-notify.cmd codex auto
echo '{"message":"测试失败","status":"error"}' | agent-notify.cmd codex auto
```

## 工作方式

```text
Claude Code hook
或
Codex CLI notify 回调
        |
        v
agent-notify.cmd
        |
        v
agent-notify.ps1
        |
        +--> wpf-popup.ps1
        +--> Windows Toast
        +--> 气泡通知兜底
```

关键点：

- Claude Code 和 Codex CLI 共用同一套脚本
- `source` 参数决定弹窗标题是 `claude` 还是 `codex`
- `event` 可以显式传 `complete / attention / error`，也可以传 `auto`
- 右上角 WPF 弹窗是主显示层

## 通知样式

| 事件 | 颜色 | 标记 | 声音 |
|------|------|------|------|
| `complete` | 绿色 | `✓` | 2 次系统提示音 |
| `attention` | 黄色 | `?` | 3 次系统警示音 |
| `error` | 红色 | `!` | 2 次系统警示音 |

## 项目结构

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

## 系统要求

- Windows 10 / 11
- PowerShell 5.1+
- .NET Framework / WPF 支持

## 常见问题

| 问题 | 处理方式 |
|------|----------|
| 有声音但没弹窗 | 检查 `%USERPROFILE%\.agent-hooks\wpf-popup.ps1` 是否存在 |
| 改了 Codex 配置后还是没弹 | 重启 Codex CLI，让它重新加载 `config.toml` |
| Toast 没出现 | WPF 是主弹窗，Toast 只是补充 |
| 中文乱码 | 重新执行 `install.ps1`，脚本默认强制 UTF-8 |

## 开源协议

[MIT](LICENSE)
