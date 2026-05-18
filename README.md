# Chrome Auto Connect

[![npm version](https://img.shields.io/npm/v/chrome-auto-connect.svg)](https://www.npmjs.com/package/chrome-auto-connect)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/x99wang/chrome-auto-connect/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)
[![Node.js](https://img.shields.io/badge/Node.js-22.x-339933.svg)](https://nodejs.org/)
[![Chrome DevTools](https://img.shields.io/badge/Chrome%20DevTools-CLI-4285F4.svg)](https://github.com/ChromeDevTools/chrome-devtools-mcp)
[![AppleScript](https://img.shields.io/badge/AppleScript-supported-9966CC.svg)](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/introduction/ASLR_intro.html)

自动连接已运行的 Chrome 浏览器，并处理"允许调试"弹窗。

## 功能

1. 检查环境依赖（Node.js + chrome-devtools CLI）
2. 自动运行点击允许脚本
3. 获取 WebSocket 连接地址
4. 检查页面状态（URL 可访问性 + list_pages 卡住风险）
5. 输出检查结果和连接建议
6. 自动连接 Chrome DevTools CLI

## 安装

### 方式一：全局安装（推荐）

```bash
npm install -g chrome-auto-connect
```

### 方式二：使用 npx

```bash
npx chrome-auto-connect
```

### 方式三：从源码安装

```bash
# 克隆项目
git clone https://github.com/x99wang/chrome-auto-connect.git

# 进入项目目录
cd chrome-auto-connect

# 安装依赖
npm install

# 链接到全局
npm link
```

## 使用方法

```bash
# 检查状态
chrome-auto-connect status

# 自动连接
chrome-auto-connect start

# 检测并点击「允许」
chrome-auto-connect allow

# 同步模式
chrome-auto-connect allow --sync

# 设置超时
chrome-auto-connect allow --timeout 5

# JSON 输出
chrome-auto-connect status --json

# 调试模式
chrome-auto-connect status --debug
```

> **重要：MCP 环境 vs 原生 CLI**
>
> 本工具常用于 Agent 自动化工作流。在 Chrome DevTools 生态中有两种连接方式：
>
> - **原生 CLI**（`chrome-devtools` 命令）：本工具已自动处理，无需额外配置。
> - **MCP 服务端**（`chrome-devtools-mcp`）：如果通过 MCP 使用 Chrome DevTools，**务必在 MCP 配置中添加 `--auto-connect` 参数**。否则 MCP 会忽略已运行的 Chrome 会话，强制打开一个新的浏览器实例，导致本工具的自动连接失效。
>
> ```json
> // MCP 配置示例（如 .claude/settings.json 或 mcp.json）
> {
>   "mcpServers": {
>     "chrome-devtools": {
>       "command": "npx",
>       "args": ["chrome-devtools-mcp", "--auto-connect"]
>     }
>   }
> }
> ```

## 命令

| 命令 | 说明 |
|------|------|
| `status` | 检查环境、页面状态（问题页面仅作 warning 不阻断），输出连接命令 |
| `start` | 自动连接 Chrome DevTools CLI |
| `allow` | 检测并点击「允许」按钮 |

## 选项

| 选项 | 说明 |
|------|------|
| `--debug` | 显示详细调试信息 |
| `--json` | 输出 JSON 格式 |
| `--sync` | 同步模式（仅 allow 命令） |
| `--timeout <sec>` | 设置超时时间（默认 2 秒） |
| `-h, --help` | 显示帮助信息 |
| `-v, --version` | 显示版本号 |

## 前置条件

1. macOS 系统
2. 已安装 Google Chrome
3. 已安装 Node.js (>=22.0.0)
4. 已安装 chrome-devtools CLI
5. Chrome 已开启远程调试
6. **辅助功能权限**（重要）：
   - 系统设置 → 隐私与安全性 → 辅助功能
   - 需要为以下应用添加权限：
     - **终端**（Terminal.app）- 如果直接运行脚本
     - **iTerm2** - 如果使用 iTerm2
     - **Node.js** - 如果通过 `npx` 或 `npm` 运行
   - 添加方式：点击 `+` 按钮，选择对应的应用程序

## 文件结构

```
chrome-auto-connect/
├── src/                           # Node.js 源码
│   └── cli.js                     # CLI 入口文件
├── scripts/                       # 脚本目录
│   ├── chrome-auto-connect.sh     # 主脚本 (status / start / allow)
│   ├── check-pages.js             # CDP 页面检查
│   ├── allow-clicker.sh           # 弹窗监听
│   └── allow-clicker.applescript  # 弹窗检测 (AppleScript)
├── docs/                          # 文档目录
├── package.json                   # npm 包配置
├── SKILL.md                       # Claude Code 技能文件
├── README.md
└── LICENSE
```

## 依赖

- [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) - Chrome DevTools CLI 工具
- [Node.js](https://nodejs.org/) - JavaScript 运行时（>=22.0.0）
- [AppleScript](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/introduction/ASLR_intro.html) - macOS 自动化脚本
- [ws](https://github.com/websockets/ws) - WebSocket 客户端库

## 常见问题

### 为什么 status 报告"发现问题页面"但工具仍能连接？

`chrome://`、`chrome-extension://` 等内部页面可能在某些情况下导致 `list_pages` 卡住，但这并非必然。工具会以 warning 形式报告，**不会阻断连接**。如果连接后 `list_pages` 正常，可以忽略这些 warning。

### status 和 start 有什么区别？

- **status**：诊断命令，检查环境、WS 端点、页面状态，输出连接建议。不会修改任何状态。
- **start**：直接连接 Chrome DevTools CLI 并执行 `list_pages`，自动处理弹窗。适合日常开发使用。

### 弹窗没有被自动点击怎么办？

1. 检查辅助功能权限：系统设置 → 隐私与安全性 → 辅助功能，确保终端（或 iTerm2）已授权
2. 使用 `chrome-auto-connect allow --sync` 手动触发一次点击
3. 增加超时：`chrome-auto-connect allow --timeout 10`

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=x99wang/chrome-auto-connect&type=Date)](https://star-history.com/#x99wang/chrome-auto-connect&Date)

## 许可证

[MIT License](LICENSE)
