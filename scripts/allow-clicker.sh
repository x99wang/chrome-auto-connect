#!/bin/bash
# allow-clicker.sh
# Chrome 弹窗监听脚本
# 用法: ./allow-clicker.sh [--debug] [--json] [--clear-log] [--timeout <seconds>]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT_SCRIPT="$SCRIPT_DIR/allow-clicker.applescript"
LOG_FILE="/tmp/chrome_click_watcher.log"
DEBUG_LOG="/tmp/chrome_click_watcher_debug.log"
TIMEOUT=5
INTERVAL=0.5
CLEAR_LOG=false
DEBUG_MODE=false
JSON_MODE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clear-log) CLEAR_LOG=true; shift ;;
        --debug) DEBUG_MODE=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        --timeout)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                TIMEOUT="$2"
                shift 2
            else
                echo "错误: --timeout 需要一个数字参数" >&2
                exit 1
            fi
            ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
done

log() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    if [ "$JSON_MODE" = true ]; then
        echo "{\"timestamp\":\"$timestamp\",\"message\":\"$1\"}"
    else
        echo "[$timestamp] $1" >> "$LOG_FILE"
    fi
}

log_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        local timestamp
        timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        if [ "$JSON_MODE" = true ]; then
            echo "{\"timestamp\":\"$timestamp\",\"level\":\"debug\",\"message\":\"$1\"}" >&2
        else
            echo "[$timestamp] [DEBUG] $1" >&2
        fi
    fi
}

cleanup() {
    log "监听结束 (信号中断)"
    exit 0
}

trap cleanup SIGINT SIGTERM

if [ "$CLEAR_LOG" = true ]; then
    > "$LOG_FILE"
    > "$DEBUG_LOG"
fi

log "监听启动，超时 ${TIMEOUT} 秒"

START_TIME=$(date +%s)
EXIT_CODE=1  # 默认退出码：超时

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    # 检查超时
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        log "超时退出 (${ELAPSED} 秒)"
        EXIT_CODE=1
        break
    fi
    
    # 调用检测脚本
    log_debug "调用检测脚本..."
    RESULT=$(osascript "$DETECT_SCRIPT" 2>>"$DEBUG_LOG")
    log_debug "检测结果: $RESULT"
    
    case "$RESULT" in
        "clicked")
            log "发现弹窗，点击「允许」按钮"
            EXIT_CODE=0
            break
            ;;
        "no_sheet")
            log "检测中... (无弹窗)"
            ;;
        "no_chrome")
            log "Chrome 未运行，退出"
            EXIT_CODE=2
            break
            ;;
        *)
            log "检测异常: $RESULT"
            EXIT_CODE=3
            break
            ;;
    esac
    
    sleep "$INTERVAL"
done

log "监听结束 (正常退出)"
exit $EXIT_CODE
