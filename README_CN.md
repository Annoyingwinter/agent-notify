<div align="center">

**[English](README.md)** | **[中文](README_CN.md)**

# agent-notify

### 别盯着终端了，去做你该做的事。

AI 编程助手的 Windows 桌面通知工具。<br>
代码生成完毕的瞬间，弹窗 + 声音提醒你回来 —— 再也不用傻等了。

<br>

<table>
<tr>
<td align="center"><strong>任务完成</strong></td>
<td align="center"><strong>需要关注</strong></td>
<td align="center"><strong>出错了</strong></td>
</tr>
<tr>
<td align="center">

```diff
+ ✓ Claude Code: Finished
+ 构建完成
```

</td>
<td align="center">

```fix
? Claude Code: Needs Attention
测试需要你确认
```

</td>
<td align="center">

```diff
- ! Claude Code: Failed
- 构建失败，3 个错误
```

</td>
</tr>
<tr>
<td align="center">绿色卡片 + 两声提示音</td>
<td align="center">黄色卡片 + 三声警示音</td>
<td align="center">红色卡片 + 两声警报音</td>
</tr>
</table>

<br>

**支持** &nbsp; Claude Code &nbsp;|&nbsp; Codex CLI &nbsp;|&nbsp; 任何能跑 shell 命令的 AI 工具

---

</div>

## 痛点

你在用 Claude Code 或 Codex 写代码。发了一条 prompt，然后就开始等……盯着终端，不知道什么时候才生成完。你本可以去刷手机、看文档、甚至摸鱼 —— 但你被光标钉在了屏幕前。

**agent-notify** 解决这个问题。装一次，从此不再错过任何一次完成。

## 功能特性

| 功能 | 说明 |
|------|------|
| **WPF 弹窗** | 精致的卡片式弹窗，右上角弹出，淡入淡出动画，6 秒自动消失，点击关闭 |
| **系统提示音** | 完成 / 需要关注 / 出错，三种不同声音 —— 最小化也能听到 |
| **智能识别** | 自动从消息内容判断事件类型（错误、提问、完成） |
| **JSON 解析** | 支持从 stdin 读取结构化 JSON 消息 |
| **独立进程** | 弹窗在独立进程中运行 —— 不会被 hook 超时杀掉 |
| **多级降级** | WPF 弹窗 → Windows Toast → 系统托盘气泡 —— 总有一个能弹出来 |
| **零依赖** | 纯 PowerShell + 内置 .NET，不需要 npm、Python，Windows 自带就够 |

## 快速开始

### 1. 安装

```powershell
git clone https://github.com/Annoyingwinter/agent-notify.git
cd agent-notify
powershell -ExecutionPolicy Bypass -File install.ps1
```

脚本会把文件安装到 `%USERPROFILE%\.agent-hooks\`，并把 `agent-notify.cmd` 放到 PATH 上。

### 2. 配置 Claude Code

在 `~/.claude/settings.json` 的 `hooks` 部分添加：

```jsonc
{
  "hooks": {
    // Claude 回复完毕时通知
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
    // Claude 需要你关注时通知
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

### 3. 搞定！

切到别的窗口去吧，弹窗会来找你的。

## 用法

```bash
# 任务完成
echo '{"message":"构建完成"}' | agent-notify.cmd claude complete

# 需要关注
echo '{"message":"这个 PR 需要你确认"}' | agent-notify.cmd claude attention

# 出错
echo '{"message":"构建失败"}' | agent-notify.cmd claude error

# 不传消息也行（照样弹窗 + 声音）
agent-notify.cmd claude complete
```

## 工作原理

```
Claude Code 回复完毕
        │
        ▼
   Stop hook 触发
        │
        ▼
  agent-notify.cmd          ← 入口（批处理文件）
        │
        ▼
  agent-notify.ps1          ← 核心逻辑：解析事件、播放声音
        │
        ├──► wpf-popup.ps1  ← 独立进程：WPF 弹窗
        │
        └──► Toast API      ← Windows 通知中心（备用）
```

关键设计：
- **独立弹窗进程** —— WPF 弹窗通过 `Start-Process` + `-EncodedCommand` 在独立的 `powershell.exe` 中运行。父进程 < 100ms 内返回，不会触发 Claude Code 的 hook 超时（通常 3-5 秒）。弹窗独立存活 6 秒。
- **智能事件识别** —— 传入 `auto` 作为事件类型时，自动扫描消息中的关键词（如 "error"、"failed"、"approve"、"confirm"）来选择通知样式。
- **UTF-8 编码** —— 强制 stdin/stdout 使用 UTF-8，正确显示中文消息。

## 通知样式

<table>
<tr><th>事件</th><th>弹窗样式</th><th>声音</th><th>自动识别关键词</th></tr>
<tr>
<td><code>complete</code></td>
<td>绿色卡片，✓ 徽标</td>
<td>2× 系统提示音</td>
<td><em>（默认）</em></td>
</tr>
<tr>
<td><code>attention</code></td>
<td>黄色卡片，? 徽标</td>
<td>3× 系统警示音</td>
<td>approve, confirm, permission, question, review, <code>?</code></td>
</tr>
<tr>
<td><code>error</code></td>
<td>红色卡片，! 徽标</td>
<td>2× 系统警报音</td>
<td>error, failed, failure, exception, fatal, denied</td>
</tr>
</table>

## 项目结构

```
agent-notify/
├── agent-notify.cmd      # 入口（批处理包装器）
├── agent-notify.ps1      # 核心逻辑：事件路由、声音、分发
├── wpf-popup.ps1         # WPF 弹窗（独立进程）
├── enable-toast.ps1      # 启用 PowerShell 的 Windows 通知
├── install.ps1           # 一键安装脚本
├── LICENSE               # MIT 开源协议
└── README.md
```

## Codex CLI 配置

```jsonc
// 在 Codex CLI 配置中添加完成后 hook：
{
  "hooks": {
    "post-completion": "agent-notify.cmd codex complete"
  }
}
```

## 系统要求

- **Windows 10 / 11**
- **PowerShell 5.1+**（Windows 自带）
- **.NET Framework**（Windows 自带，提供 WPF）

不需要任何外部依赖。不需要 npm。不需要 Python。Windows 自带的就够了。

## 常见问题

| 问题 | 解决方案 |
|------|----------|
| 看不到弹窗 | 运行 `enable-toast.ps1` 注册 PowerShell 为通知源 |
| 有声音但没弹窗 | 检查 `%USERPROFILE%\.agent-hooks\` 下是否有 `wpf-popup.ps1` |
| 弹窗出现但中文乱码 | 编码问题 —— 重新运行 `install.ps1` 即可修复 |
| hook 超时导致通知消失 | 更新到最新版 —— 弹窗现在在独立进程中运行 |

## 参与贡献

欢迎 PR！以下是一些计划中的功能：

- [ ] macOS 支持（AppleScript / terminal-notifier）
- [ ] Linux 支持（notify-send / libnotify）
- [ ] 自定义通知声音
- [ ] 通知历史 / 日志查看器
- [ ] 更多 AI 工具集成（Cursor、Windsurf、Aider 等）

## 开源协议

[MIT](LICENSE) —— 随便用。

---

<div align="center">
<br>
<strong>写这个工具，是因为盯着终端发呆不叫 vibe coding。</strong>
<br><br>
</div>
