#!/usr/bin/env node
// chrome-cli-check-pages.js
// 通过 CDP 协议检查页面状态

const WebSocket = require('ws');

// 解析命令行参数
const args = process.argv.slice(2);
const debugMode = args.includes('--debug');
const wsEndpoint = args.find(arg => !arg.startsWith('--'));

if (!wsEndpoint) {
    console.error('错误：请提供 WebSocket endpoint');
    console.error('用法：node chrome-cli-check-pages.js <ws-endpoint> [--debug]');
    process.exit(1);
}

// 调试日志
function debug(...messages) {
    if (debugMode) {
        console.error('[DEBUG]', ...messages);
    }
}

// 问题页面列表
const problemPages = [];

debug('正在连接 WebSocket:', wsEndpoint);

// 连接到 Chrome
const ws = new WebSocket(wsEndpoint);

ws.on('open', () => {
    debug('WebSocket 连接已打开');
    // 发送 Target.getTargets 命令获取所有页面
    const command = JSON.stringify({
        id: 1,
        method: 'Target.getTargets'
    });
    debug('发送命令:', command);
    ws.send(command);
});

ws.on('message', (data) => {
    try {
        const msg = JSON.parse(data.toString());
        debug('收到消息:', JSON.stringify(msg).substring(0, 200));

        if (msg.id === 1) {
            if (!msg.result || !Array.isArray(msg.result.targetInfos)) {
                console.error('无效的 CDP 响应:', JSON.stringify(msg));
                process.exit(1);
            }

            debug('获取到', msg.result.targetInfos.length, '个 targets');

            // 获取所有页面类型的 target
            const pages = msg.result.targetInfos.filter(t => t.type === 'page');
            debug('其中', pages.length, '个是页面');

            // 检查每个页面
            pages.forEach(page => {
                const url = page.url;
                const title = page.title || '无标题';

                debug('检查页面:', url);

                // 检查是否是可能导致 list_pages 卡住的页面
                if (isProblematicPage(url)) {
                    debug('发现问题页面:', url);
                    problemPages.push({
                        url: url,
                        title: title,
                        issue: getPageIssue(url)
                    });
                }
            });

            // 输出结果
            debug('输出结果，问题页面数量:', problemPages.length);
            outputResults(problemPages);

            // 关闭连接
            debug('关闭 WebSocket 连接');
            ws.close();
        }
    } catch (err) {
        console.error('解析消息失败:', err.message);
    }
});

ws.on('error', (err) => {
    debug('WebSocket 错误:', err.message);
    console.error('WebSocket 连接失败:', err.message);
    process.exit(1);
});

ws.on('close', () => {
    debug('WebSocket 连接已关闭');
    // close 事件在消息处理完成后触发，此时结果已输出，直接退出
    process.exit(0);
});

// 超时处理
setTimeout(() => {
    console.error('检查超时');
    process.exit(1);
}, 10000);

// 检查是否是问题页面
function isProblematicPage(url) {
    // Chrome 内部页面
    if (url.startsWith('chrome://') || url.startsWith('chrome-extension://')) {
        return true;
    }

    // DevTools 页面
    if (url.startsWith('devtools://')) {
        return true;
    }

    // 数据 URL
    if (url.startsWith('data:')) {
        return true;
    }

    // 关于页面
    if (url.startsWith('about:')) {
        return true;
    }

    // 其他可能有问题的协议
    if (url.startsWith('file://') || url.startsWith('blob:')) {
        return true;
    }

    return false;
}

// 获取页面问题描述
function getPageIssue(url) {
    if (url.startsWith('chrome://') || url.startsWith('chrome-extension://')) {
        return 'Chrome 内部页面，可能导致 list_pages 卡住';
    }

    if (url.startsWith('devtools://')) {
        return 'DevTools 页面，可能导致 list_pages 卡住';
    }

    if (url.startsWith('data:')) {
        return '数据 URL 页面，可能导致 list_pages 卡住';
    }

    if (url.startsWith('about:')) {
        return '关于页面，可能导致 list_pages 卡住';
    }

    if (url.startsWith('file://')) {
        return '本地文件页面，可能导致 list_pages 卡住';
    }

    if (url.startsWith('blob:')) {
        return 'Blob 页面，可能导致 list_pages 卡住';
    }

    return '未知问题';
}

// 输出结果
function outputResults(problemPages) {
    if (problemPages.length === 0) {
        console.log('NO_PROBLEMS');
    } else {
        console.log('PROBLEMS_FOUND');
        console.log(JSON.stringify(problemPages, null, 2));
    }
}
