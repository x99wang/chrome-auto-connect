# chrome-devtools CLI 连接已打开 Chrome 浏览器完整指南

基于对 `chrome-devtools-mcp` 源码分析和实际测试的总结。

---

## 一、结论

**chrome-devtools CLI 可以连接到已运行的 Chrome 浏览器并进行操作。**

唯一需要注意的是 `list_pages` 命令会卡住（Puppeteer 的 `browser.pages()` bug），但可以通过 `browser.targets()` 或原始 CDP 协议绕过。

---

## 二、连接方法

### 前提条件

Chrome 需要开启远程调试：
1. 打开 `chrome://inspect/#remote-debugging`
2. 按提示允许调试连接

开启后，Chrome 会在用户数据目录写入 `DevToolsActivePort` 文件。

### DevToolsActivePort 文件位置

| 平台    | 路径                                                        |
| ------- | ----------------------------------------------------------- |
| macOS   | `~/Library/Application Support/Google/Chrome/DevToolsActivePort` |
| Linux   | `~/.config/google-chrome/DevToolsActivePort`                    |
| Windows | `%LOCALAPPDATA%\Google\Chrome\User Data\DevToolsActivePort`     |

文件内容格式：
```
9222
/devtools/browser/e4b52b16-4fc4-468b-b75a-58fed4a6de0f
```
第一行是端口号，第二行是 WebSocket 路径。

### 连接步骤

```bash
# 1. 读取 WebSocket endpoint
cat ~/Library/Application\ Support/Google/Chrome/DevToolsActivePort

# 2. 启动 daemon（用实际读到的值替换）
chrome-devtools start --wsEndpoint "ws://127.0.0.1:9222/devtools/browser/e4b52b16-4fc4-468b-b75a-58fed4a6de0f"

# 3. 执行操作
chrome-devtools take_screenshot
chrome-devtools navigate_page --url https://example.com
chrome-devtools evaluate_script --function "() => document.title"
```

---

## 三、已知问题：list_pages 卡住

### 现象

```bash
chrome-devtools list_pages
# 超时，无响应
```

### 原因

Puppeteer 的 `browser.pages()` 在 Chrome 144+ 自动调试模式下会卡住。这是 Puppeteer 的兼容性问题，不是 Chrome 的问题。

### 验证测试

| 测试项                              | 结果                   |
| ----------------------------------- | ---------------------- |
| CDP `Target.getTargets`             | 正常，返回所有 tab     |
| Puppeteer `browser.version()`       | 正常                   |
| Puppeteer `browser.newPage()`       | 正常                   |
| Puppeteer `browser.targets()`       | 正常                   |
| Puppeteer `browser.pages()`         | 卡死                   |
| Raw WebSocket CDP 创建 target       | 正常                   |

### 绕过方案

用原始 CDP 协议获取页面列表：

```bash
node -e "
const WebSocket = require('ws');
const ws = new WebSocket('ws://127.0.0.1:9222/devtools/browser/YOUR-ID');
ws.on('open', () => {
  ws.send(JSON.stringify({id: 1, method: 'Target.getTargets'}));
});
ws.on('message', (data) => {
  const msg = JSON.parse(data.toString());
  if (msg.id) {
    const pages = msg.result.targetInfos.filter(t => t.type === 'page');
    pages.forEach(p => console.log(p.title, '-', p.url));
    ws.close();
  }
});
setTimeout(() => process.exit(0), 5000);
"
```

或用 Puppeteer 的 `browser.targets()`：

```bash
node -e "
const p = require('puppeteer');
p.connect({browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser/YOUR-ID'})
  .then(b => {
    const pages = b.targets().filter(t => t.type() === 'page');
    pages.forEach(t => console.log(t.url()));
    b.disconnect();
  });
"
```

---

## 四、其他连接方式的问题

| 方式               | 状态 | 问题                                        |
| ------------------ | ---- | ------------------------------------------- |
| `--autoConnect`    | 不可用 | CLI 的 yargs 配置问题，参数被拒绝           |
| `--browserUrl`     | 不可用 | Chrome 144+ 的 HTTP API 返回 404            |
| `--wsEndpoint`     | 可用   | 需手动从 DevToolsActivePort 读取 endpoint   |
| MCP `--auto-connect` | 可用   | 但走 MCP 协议，不是 CLI                     |

### --autoConnect 失败原因分析

`autoConnect` 定义在 `cliOptions` 中（`chrome-devtools-mcp-cli-options.ts:11-23`），`startCliOptions` 是 `cliOptions` 的拷贝（`chrome-devtools.ts:42-44`），`autoConnect` 没有被删除。但 yargs strict 模式仍然拒绝它。

可能原因：
- `autoConnect` 的 `coerce` 函数在值为 falsy 时返回 `undefined` 而不是 `false`
- `autoConnect` 声明了 `conflicts: ['isolated', 'executablePath']`，而 `start` 命令默认设置 `isolated = true`

### --browserUrl 失败原因

Chrome 144+ 的自动调试模式不暴露传统的 HTTP `/json/version` 端点：

```bash
curl -v http://127.0.0.1:9222/json/version
# HTTP/1.1 404 Not Found
```

但 WebSocket 端口是正常监听的（`lsof -i :9222` 能看到 Chrome 进程）。

---

## 五、Daemon 架构

```
chrome-devtools list_pages
  → CLI 连接 daemon socket
    → daemon 收到命令
      → mcpClient.callTool({ name: 'list_pages' })
        → MCP server 处理工具调用
          → getContext() → ensureBrowserConnected({ wsEndpoint })
            → puppeteer.connect({ browserWSEndpoint: ... })
              → 连接到 Chrome
```

CLI 超时：60 秒（`daemon/client.ts:95`）。

Daemon 默认带 `--headless` 和 `--isolated` 参数（`chrome-devtools.ts:99-104`），但不影响连接逻辑。

---

## 六、Chrome 版本信息

测试环境：
- Chrome 147.0.7727.138
- macOS
- Node.js v22.12.0
- Puppeteer（chrome-devtools-mcp 内置版本）

---

## 七、常用命令参考

```bash
# 启动 daemon
chrome-devtools start --wsEndpoint "ws://..."

# 查看 daemon 状态
chrome-devtools status

# 停止 daemon
chrome-devtools stop

# 截图
chrome-devtools take_screenshot [--filePath /tmp/test.png]

# 导航
chrome-devtools navigate_page --url https://example.com

# 执行 JS
chrome-devtools evaluate_script --function "() => document.title"

# 获取页面快照（a11y tree）
chrome-devtools take_snapshot

# 网络请求
chrome-devtools list_network_requests

# 新建 tab
chrome-devtools new_page https://example.com
```

---

## 八、源码关键文件

| 文件                                    | 作用                       |
| --------------------------------------- | -------------------------- |
| `src/browser.ts:46-134`                 | ensureBrowserConnected     |
| `src/index.ts:190-238`                  | getContext 路由逻辑        |
| `src/bin/chrome-devtools.ts:40-109`     | CLI start 命令定义        |
| `src/bin/chrome-devtools-mcp-cli-options.ts:11-23` | autoConnect 选项定义 |
| `src/daemon/daemon.ts`                  | daemon 进程实现           |
| `src/daemon/client.ts:95`               | CLI 超时设置（60s）      |
| `src/daemon/utils.ts`                   | socket 路径、PID 文件等  |
