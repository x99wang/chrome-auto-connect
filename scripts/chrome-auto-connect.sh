#!/bin/bash
# chrome-auto-connect.sh
# Chrome DevTools CLI 连接工具
# 版本: 1.0.0
# 用法: 
#   ./chrome-auto-connect.sh status [--debug] [--json] [--timeout <seconds>]
#   ./chrome-auto-connect.sh start [--debug] [--json] [--timeout <seconds>]
#   ./chrome-auto-connect.sh allow [--debug] [--json] [--sync] [--timeout <seconds>]

VERSION="1.0.0"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCHER_SCRIPT="$SCRIPT_DIR/allow-clicker.sh"
CHECK_PAGES_SCRIPT="$SCRIPT_DIR/check-pages.js"
DEVTOOLS_PORT_FILE="$HOME/Library/Application Support/Google/Chrome/DevToolsActivePort"

# 解析参数
COMMAND=""
DEBUG_MODE=false
JSON_MODE=false
SYNC_MODE=false
TIMEOUT=""

show_help() {
    echo "Chrome DevTools CLI 连接工具 v$VERSION"
    echo ""
    echo "用法:"
    echo "  ./chrome-auto-connect.sh <command> [options]"
    echo ""
    echo "命令:"
    echo "  status  检查环境、页面状态，输出连接命令"
    echo "  start   自动连接 Chrome DevTools CLI"
    echo "  allow   检测并点击「允许」按钮"
    echo ""
    echo "选项:"
    echo "  --debug           显示详细调试信息"
    echo "  --json            输出 JSON 格式"
    echo "  --sync            同步模式（仅 allow 命令）"
    echo "  --timeout <sec>   设置超时时间（默认 2 秒）"
    echo "  -h, --help        显示帮助信息"
    echo "  -v, --version     显示版本号"
    echo ""
    echo "示例:"
    echo "  ./chrome-auto-connect.sh status                检查状态"
    echo "  ./chrome-auto-connect.sh start --json          以 JSON 格式连接"
    echo "  ./chrome-auto-connect.sh allow --sync          同步检测并点击「允许」"
    echo "  ./chrome-auto-connect.sh allow --timeout 5     设置 5 秒超时"
}

show_version() {
    echo "chrome-cli v$VERSION"
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        status|start|allow)
            COMMAND="$1"
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --json)
            JSON_MODE=true
            shift
            ;;
        --sync)
            SYNC_MODE=true
            shift
            ;;
        --timeout)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                TIMEOUT="$2"
                shift 2
            else
                echo "错误: --timeout 需要一个数字参数" >&2
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        *)
            echo "未知参数: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# 如果没有指定命令，显示帮助
if [ -z "$COMMAND" ]; then
    show_help
    exit 0
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    if [ "$JSON_MODE" = true ]; then
        echo "{\"level\":\"info\",\"message\":\"$1\"}"
    else
        echo -e "${GREEN}[INFO]${NC} $1"
    fi
}

log_warn() {
    if [ "$JSON_MODE" = true ]; then
        echo "{\"level\":\"warn\",\"message\":\"$1\"}"
    else
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    if [ "$JSON_MODE" = true ]; then
        echo "{\"level\":\"error\",\"message\":\"$1\"}"
    else
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

log_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        if [ "$JSON_MODE" = true ]; then
            echo "{\"level\":\"debug\",\"message\":\"$1\"}" >&2
        else
            echo -e "${YELLOW}[DEBUG]${NC} $1" >&2
        fi
    fi
}

# 检查环境依赖
check_environment() {
    log_info "检查环境依赖..."
    
    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        if [ "$JSON_MODE" = true ]; then
            echo "{\"level\":\"error\",\"message\":\"Node.js 未安装\",\"install\":\"https://nodejs.org/\"}"
        else
            log_error "Node.js 未安装"
            echo ""
            echo "请安装 Node.js："
            echo "  - 官网下载：https://nodejs.org/"
            echo "  - macOS (Homebrew): brew install node"
            echo "  - Ubuntu/Debian: sudo apt install nodejs"
        fi
        exit 1
    fi
    log_info "Node.js 已安装: $(node --version)"
    
    # 检查 chrome-devtools CLI
    if ! command -v chrome-devtools &> /dev/null; then
        if [ "$JSON_MODE" = true ]; then
            echo "{\"level\":\"error\",\"message\":\"chrome-devtools CLI 未安装\",\"install\":\"npm install -g chrome-devtools-mcp@latest\",\"github\":\"https://github.com/ChromeDevTools/chrome-devtools-mcp\"}"
        else
            log_error "chrome-devtools CLI 未安装"
            echo ""
            echo "请安装 chrome-devtools CLI："
            echo "  npm install -g chrome-devtools-mcp@latest"
            echo ""
            echo "GitHub 仓库："
            echo "  https://github.com/ChromeDevTools/chrome-devtools-mcp"
        fi
        exit 1
    fi
    log_info "chrome-devtools CLI 已安装"
}

# 后台启动点击允许脚本
run_click_allow_watcher_in_background() {
    log_info "后台启动点击允许脚本..."
    log_debug "点击允许脚本路径: $WATCHER_SCRIPT"
    
    if [ ! -f "$WATCHER_SCRIPT" ]; then
        log_warn "点击允许脚本不存在: $WATCHER_SCRIPT"
        return
    fi
    
    if [ ! -x "$WATCHER_SCRIPT" ]; then
        chmod +x "$WATCHER_SCRIPT"
    fi
    
    # 构造参数
    local watcher_args=""
    if [ "$DEBUG_MODE" = true ]; then
        watcher_args="$watcher_args --debug"
    fi
    if [ "$JSON_MODE" = true ]; then
        watcher_args="$watcher_args --json"
    fi
    if [ -n "$TIMEOUT" ]; then
        watcher_args="$watcher_args --timeout $TIMEOUT"
    fi
    
    # 后台运行脚本
    log_debug "启动点击允许脚本（后台）... 参数: $watcher_args"
    "$WATCHER_SCRIPT" $watcher_args &
    CLICK_ALLOW_PID=$!
    log_debug "点击允许脚本 PID: $CLICK_ALLOW_PID"
}

# 等待点击允许脚本完成
wait_for_click_allow_watcher() {
    if [ -z "$CLICK_ALLOW_PID" ]; then
        log_debug "没有运行中的点击允许脚本"
        return
    fi
    
    log_info "等待点击允许脚本完成..."
    
    # 等待脚本完成（最多 15 秒）
    local timeout=15
    local elapsed=0
    while kill -0 $CLICK_ALLOW_PID 2>/dev/null && [ $elapsed -lt $timeout ]; do
        sleep 1
        elapsed=$((elapsed + 1))
        log_debug "等待点击允许脚本... ($elapsed/$timeout)"
    done
    
    # 如果还在运行，终止它
    if kill -0 $CLICK_ALLOW_PID 2>/dev/null; then
        kill $CLICK_ALLOW_PID 2>/dev/null
        log_warn "点击允许脚本超时，已终止"
        CLICK_ALLOW_RESULT="timeout"
        return 1
    fi
    
    # 获取退出码
    wait $CLICK_ALLOW_PID
    local exit_code=$?
    
    case $exit_code in
        0)
            log_info "点击允许脚本完成：成功点击「允许」按钮"
            CLICK_ALLOW_RESULT="clicked"
            ;;
        1)
            log_info "点击允许脚本完成：未检测到弹窗（超时）"
            CLICK_ALLOW_RESULT="timeout"
            ;;
        2)
            log_warn "点击允许脚本完成：Chrome 未运行"
            CLICK_ALLOW_RESULT="no_chrome"
            ;;
        3)
            log_error "点击允许脚本完成：检测异常"
            CLICK_ALLOW_RESULT="error"
            ;;
        *)
            log_warn "点击允许脚本完成：未知退出码 ($exit_code)"
            CLICK_ALLOW_RESULT="unknown"
            ;;
    esac
    
    return $exit_code
}

# 获取 WebSocket 连接地址
get_ws_endpoint() {
    log_info "获取 WebSocket 连接地址..."
    log_debug "DevToolsActivePort 文件路径: $DEVTOOLS_PORT_FILE"
    
    if [ ! -f "$DEVTOOLS_PORT_FILE" ]; then
        log_error "DevToolsActivePort 文件不存在"
        echo "请确保 Chrome 已开启远程调试："
        echo "1. 打开 chrome://inspect/#remote-debugging"
        echo "2. 按提示允许调试连接"
        exit 1
    fi
    
    # 读取端口号和 WebSocket 路径
    local port=$(sed -n '1p' "$DEVTOOLS_PORT_FILE")
    local ws_path=$(sed -n '2p' "$DEVTOOLS_PORT_FILE")
    
    log_debug "读取到端口: $port"
    log_debug "读取到路径: $ws_path"
    
    if [ -z "$port" ] || [ -z "$ws_path" ]; then
        log_error "无法读取 DevToolsActivePort 文件内容"
        exit 1
    fi
    
    # 构造 WebSocket endpoint
    WS_ENDPOINT="ws://127.0.0.1:${port}${ws_path}"
    log_info "WebSocket endpoint: $WS_ENDPOINT"
}

# 检查页面状态
check_pages() {
    log_info "检查页面状态..."
    log_debug "页面检查脚本路径: $CHECK_PAGES_SCRIPT"
    
    if [ ! -f "$CHECK_PAGES_SCRIPT" ]; then
        log_error "页面检查脚本不存在: $CHECK_PAGES_SCRIPT"
        return 1
    fi
    
    # 构造 Node.js 脚本参数
    local node_args="$CHECK_PAGES_SCRIPT $WS_ENDPOINT"
    if [ "$DEBUG_MODE" = true ]; then
        node_args="$node_args --debug"
    fi
    log_debug "运行命令: node $node_args"
    
    # 运行页面检查脚本（禁用 set -e 以捕获错误）
    # 注意：只捕获 stdout，stderr 直接输出到终端
    local result
    local exit_code=0
    result=$(node $node_args) || exit_code=$?
    
    log_debug "Node.js 脚本退出码: $exit_code"
    
    if [ $exit_code -ne 0 ]; then
        log_error "页面检查失败: $result"
        return 1
    fi
    
    # 解析结果
    if echo "$result" | grep -q "NO_PROBLEMS"; then
        if [ "$JSON_MODE" = true ]; then
            echo "{\"status\":\"ok\",\"problems\":[],\"wsEndpoint\":\"$WS_ENDPOINT\"}"
        else
            log_info "未发现问题页面"
            echo ""
            echo "可以安全连接 Chrome DevTools CLI："
            echo "chrome-devtools start --wsEndpoint \"$WS_ENDPOINT\""
            echo ""
            echo "注意：连接后如果出现「允许远程调试」弹窗，脚本会自动点击允许。"
        fi
        return 0
    elif echo "$result" | grep -q "PROBLEMS_FOUND"; then
        # 提取问题页面 JSON
        local json=$(echo "$result" | sed -n '/PROBLEMS_FOUND/,/^$/p' | tail -n +2)
        
        if [ "$JSON_MODE" = true ]; then
            echo "{\"status\":\"error\",\"problems\":$json,\"wsEndpoint\":\"$WS_ENDPOINT\"}"
        else
            log_warn "发现问题页面"
            echo ""
            echo "检查完成，发现以下问题页面："
            echo ""
            
            # 解析并显示问题页面
            echo "$json" | node -e "
                const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
                data.forEach((page, index) => {
                    console.log(\`\${index + 1}. \${page.url}\`);
                    console.log(\`   - 标题: \${page.title}\`);
                    console.log(\`   - 问题: \${page.issue}\`);
                    console.log('');
                });
            "
            
            echo "建议关闭这些页面后再连接。"
        fi
        return 1
    else
        log_error "未知的检查结果: $result"
        return 1
    fi
}

# status 命令：检查状态
cmd_status() {
    if [ "$JSON_MODE" = false ]; then
        echo "Chrome DevTools CLI 状态检查"
        echo "=========================="
        echo ""
    fi
    
    # 1. 检查环境
    check_environment
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 2. 获取 WebSocket 连接地址
    get_ws_endpoint
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 3. 后台启动点击允许脚本（等待可能的弹窗）
    log_debug "后台启动点击允许脚本..."
    run_click_allow_watcher_in_background
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 4. 检查页面状态（会建立 WS 连接，可能触发允许弹窗）
    check_pages
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 5. 等待点击允许脚本完成
    wait_for_click_allow_watcher
    
    # 6. 输出最终结果
    if [ "$JSON_MODE" = true ]; then
        echo "{\"status\":\"ok\",\"wsEndpoint\":\"$WS_ENDPOINT\",\"clickAllow\":\"$CLICK_ALLOW_RESULT\"}"
    fi
}

# start 命令：连接 Chrome DevTools CLI
cmd_start() {
    if [ "$JSON_MODE" = false ]; then
        echo "连接 Chrome DevTools CLI"
        echo "========================"
        echo ""
    fi
    
    # 1. 检查环境
    check_environment
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 2. 获取 WebSocket 连接地址
    get_ws_endpoint
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 3. 后台启动点击允许脚本（等待可能的弹窗）
    log_debug "后台启动点击允许脚本..."
    run_click_allow_watcher_in_background
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 4. 检查页面状态（会建立 WS 连接，可能触发允许弹窗）
    check_pages
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 5. 等待点击允许脚本完成
    wait_for_click_allow_watcher
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 6. 关闭 check_pages 创建的连接
    log_info "关闭 check_pages 创建的连接..."
    chrome-devtools stop 2>/dev/null || true
    if [ "$JSON_MODE" = false ]; then
        echo ""
    fi
    
    # 7. 连接 Chrome DevTools CLI
    if [ "$JSON_MODE" = true ]; then
        echo "{\"status\":\"connecting\",\"wsEndpoint\":\"$WS_ENDPOINT\",\"clickAllow\":\"$CLICK_ALLOW_RESULT\",\"note\":\"本脚本只负责连接并自动点击允许按钮，会话关闭请使用 chrome-devtools stop\"}"
    else
        log_info "正在连接 Chrome DevTools CLI..."
        echo "执行命令: chrome-devtools start --wsEndpoint \"$WS_ENDPOINT\""
        echo ""
        echo "注意：本脚本只负责连接并自动点击「允许」按钮。"
        echo "会话关闭请使用原生命令：chrome-devtools stop"
        echo ""
    fi
    
    # 执行连接命令
    chrome-devtools start --wsEndpoint "$WS_ENDPOINT"
    
    # 8. 后台启动点击允许脚本（list_pages 会触发允许弹窗）
    log_info "后台启动点击允许脚本..."
    
    # 使用 nohup 启动，使其完全独立于父进程
    local watcher_args=""
    if [ "$DEBUG_MODE" = true ]; then
        watcher_args="$watcher_args --debug"
    fi
    if [ -n "$TIMEOUT" ]; then
        watcher_args="$watcher_args --timeout $TIMEOUT"
    fi
    
    nohup "$WATCHER_SCRIPT" $watcher_args > /tmp/allow-clicker-listpages.log 2>&1 &
    CLICK_ALLOW_PID=$!
    log_debug "点击允许脚本 PID: $CLICK_ALLOW_PID"
    
    # 等待点击脚本完全启动
    sleep 1
    
    # 9. 调用原生 list_pages
    log_info "调用原生 list_pages..."
    chrome-devtools list_pages
    
    # 10. 等待点击允许脚本完成
    wait_for_click_allow_watcher
}

# allow 命令：检测并点击「允许」
cmd_allow() {
    if [ "$JSON_MODE" = false ]; then
        echo "检测并点击「允许」按钮"
        echo "=========================="
        echo ""
    fi
    
    # 构造参数
    local watcher_args=""
    if [ "$DEBUG_MODE" = true ]; then
        watcher_args="$watcher_args --debug"
    fi
    if [ "$JSON_MODE" = true ]; then
        watcher_args="$watcher_args --json"
    fi
    if [ -n "$TIMEOUT" ]; then
        watcher_args="$watcher_args --timeout $TIMEOUT"
    fi
    
    log_debug "点击允许脚本路径: $WATCHER_SCRIPT"
    log_debug "参数: $watcher_args"
    
    if [ ! -f "$WATCHER_SCRIPT" ]; then
        if [ "$JSON_MODE" = true ]; then
            echo "{\"status\":\"error\",\"message\":\"点击允许脚本不存在: $WATCHER_SCRIPT\"}"
        else
            log_error "点击允许脚本不存在: $WATCHER_SCRIPT"
        fi
        return 1
    fi
    
    if [ ! -x "$WATCHER_SCRIPT" ]; then
        chmod +x "$WATCHER_SCRIPT"
    fi
    
    # 同步模式
    if [ "$SYNC_MODE" = true ]; then
        log_debug "同步模式运行..."
        "$WATCHER_SCRIPT" $watcher_args
        local exit_code=$?
        
        case $exit_code in
            0)
                if [ "$JSON_MODE" = true ]; then
                    echo "{\"status\":\"ok\",\"result\":\"clicked\",\"message\":\"成功点击「允许」按钮\"}"
                else
                    log_info "成功点击「允许」按钮"
                fi
                ;;
            1)
                if [ "$JSON_MODE" = true ]; then
                    echo "{\"status\":\"ok\",\"result\":\"timeout\",\"message\":\"未检测到弹窗（超时）\"}"
                else
                    log_info "未检测到弹窗（超时）"
                fi
                ;;
            2)
                if [ "$JSON_MODE" = true ]; then
                    echo "{\"status\":\"error\",\"result\":\"no_chrome\",\"message\":\"Chrome 未运行\"}"
                else
                    log_warn "Chrome 未运行"
                fi
                ;;
            3)
                if [ "$JSON_MODE" = true ]; then
                    echo "{\"status\":\"error\",\"result\":\"error\",\"message\":\"检测异常\"}"
                else
                    log_error "检测异常"
                fi
                ;;
            *)
                if [ "$JSON_MODE" = true ]; then
                    echo "{\"status\":\"error\",\"result\":\"unknown\",\"message\":\"未知退出码: $exit_code\"}"
                else
                    log_warn "未知退出码: $exit_code"
                fi
                ;;
        esac
        
        return $exit_code
    fi
    
    # 异步模式（默认）
    log_debug "异步模式运行..."
    "$WATCHER_SCRIPT" $watcher_args &
    local pid=$!
    
    if [ "$JSON_MODE" = true ]; then
        echo "{\"status\":\"ok\",\"pid\":$pid,\"message\":\"点击允许脚本已在后台启动\"}"
    else
        log_info "点击允许脚本已在后台启动 (PID: $pid)"
    fi
    
    return 0
}

# 主函数
main() {
    case "$COMMAND" in
        status)
            cmd_status
            ;;
        start)
            cmd_start
            ;;
        allow)
            cmd_allow
            ;;
    esac
}

# 运行主函数
main
