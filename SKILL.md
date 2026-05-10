# Chrome Auto Connect Skill

## 概述

Chrome Auto Connect 是一个自动化工具，用于连接已运行的 Chrome 浏览器并处理"允许调试"弹窗。该技能可用于智能体自动化 Chrome DevTools 连接流程。

## 功能

- 自动检测并点击 Chrome 的"允许调试"弹窗
- 检查页面状态，识别可能导致 `list_pages` 卡住的页面
- 自动连接 Chrome DevTools CLI
- 支持 JSON 输出和调试模式

## 使用场景

当智能体需要连接到已运行的 Chrome 浏览器进行自动化操作时，可以使用此技能：

1. **连接前检查**：使用 `status` 命令检查环境和页面状态
2. **自动连接**：使用 `start` 命令自动连接 Chrome DevTools CLI
3. **弹窗处理**：使用 `allow` 命令自动点击"允许调试"弹窗

## 命令参考

### 检查状态

```bash
chrome-auto-connect status [--json] [--debug]
```

**返回值：**
- 无问题页面：`{"status":"ok","problems":[],"wsEndpoint":"ws://..."}`
- 有问题页面：`{"status":"error","problems":[...],"wsEndpoint":"ws://..."}`

### 自动连接

```bash
chrome-auto-connect start [--json] [--debug]
```

**功能：**
1. 检查环境依赖
2. 获取 WebSocket 连接地址
3. 后台启动点击允许脚本
4. 检查页面状态
5. 自动连接 Chrome DevTools CLI

### 检测并点击「允许」

```bash
chrome-auto-connect allow [--sync] [--json] [--debug] [--timeout <sec>]
```

**参数：**
- `--sync`：同步模式，等待结果返回
- `--json`：JSON 格式输出
- `--debug`：显示调试信息
- `--timeout <sec>`：设置超时时间（默认 2 秒）

**返回值（同步模式）：**
- 成功点击：`{"status":"ok","result":"clicked","message":"成功点击「允许」按钮"}`
- 超时：`{"status":"ok","result":"timeout","message":"未检测到弹窗（超时）"}`
- Chrome 未运行：`{"status":"error","result":"no_chrome","message":"Chrome 未运行"}`

## 智能体集成示例

### 示例 1：连接前检查

```bash
# 检查是否有问题页面
result=$(chrome-auto-connect status --json)

# 解析结果
if echo "$result" | grep -q '"status":"ok"'; then
    echo "可以安全连接"
    # 获取 WebSocket 地址
    ws_endpoint=$(echo "$result" | grep -o '"wsEndpoint":"[^"]*"' | cut -d'"' -f4)
else
    echo "发现问题页面，需要处理"
    # 获取问题页面列表
    problems=$(echo "$result" | grep -o '"problems":\[.*\]')
fi
```

### 示例 2：自动连接

```bash
# 自动连接 Chrome DevTools CLI
chrome-auto-connect start --json
```

### 示例 3：异步点击允许

```bash
# 后台启动点击允许脚本
chrome-auto-connect allow --timeout 5

# 继续执行其他操作
echo "点击允许脚本已在后台运行"
```

### 示例 4：同步点击允许

```bash
# 同步等待点击结果
result=$(chrome-auto-connect allow --sync --timeout 10 --json)

# 解析结果
if echo "$result" | grep -q '"result":"clicked"'; then
    echo "成功点击允许按钮"
else
    echo "未检测到弹窗或点击失败"
fi
```

## 错误处理

### 常见错误

1. **Node.js 未安装**
   ```json
   {"level":"error","message":"Node.js 未安装","install":"https://nodejs.org/"}
   ```

2. **chrome-devtools CLI 未安装**
   ```json
   {"level":"error","message":"chrome-devtools CLI 未安装","install":"npm install -g chrome-devtools-mcp@latest","github":"https://github.com/ChromeDevTools/chrome-devtools-mcp"}
   ```

3. **Chrome 未运行**
   ```json
   {"status":"error","result":"no_chrome","message":"Chrome 未运行"}
   ```

4. **WebSocket 连接失败**
   ```json
   {"level":"error","message":"WebSocket 连接失败: ..."}
   ```

### 错误处理建议

1. **环境检查失败**：根据错误信息安装相应的依赖
2. **Chrome 未运行**：启动 Chrome 浏览器
3. **WebSocket 连接失败**：检查 Chrome 是否开启了远程调试
4. **超时**：增加 `--timeout` 参数的值

## 注意事项

1. **macOS 限制**：该工具仅支持 macOS 系统
2. **辅助功能权限**：需要授予以下应用辅助功能权限（系统设置 → 隐私与安全性 → 辅助功能）：
   - 终端（Terminal.app）- 直接运行脚本时
   - iTerm2 - 使用 iTerm2 时
   - Node.js - 通过 `npx` 或 `npm` 运行时
3. **Chrome 远程调试**：需要在 Chrome 中开启远程调试
4. **会话管理**：`start` 命令只负责连接，会话关闭需要使用 `chrome-devtools stop`

## 相关链接

- [Chrome DevTools CLI](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [Node.js](https://nodejs.org/)
- [AppleScript 文档](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/introduction/ASLR_intro.html)
