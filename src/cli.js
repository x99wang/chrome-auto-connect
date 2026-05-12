#!/usr/bin/env node

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const VERSION = '1.0.2';
const SCRIPTS_DIR = path.join(__dirname, '..', 'scripts');

// 颜色定义
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function showHelp() {
  console.log(`
${colors.cyan}Chrome Auto Connect${colors.reset} v${VERSION}

${colors.green}自动连接已运行的 Chrome 浏览器，并处理「允许调试」弹窗${colors.reset}

${colors.yellow}用法:${colors.reset}
  chrome-auto-connect <command> [options]

${colors.yellow}命令:${colors.reset}
  status  检查环境、页面状态，输出连接命令
  start   自动连接 Chrome DevTools CLI
  allow   检测并点击「允许」按钮

${colors.yellow}选项:${colors.reset}
  --debug           显示详细调试信息
  --json            输出 JSON 格式
  --sync            同步模式（仅 allow 命令）
  --timeout <sec>   设置超时时间（默认 2 秒）
  -h, --help        显示帮助信息
  -v, --version     显示版本号

${colors.yellow}示例:${colors.reset}
  chrome-auto-connect status                检查状态
  chrome-auto-connect start --json          以 JSON 格式连接
  chrome-auto-connect allow --sync          同步检测并点击「允许」
  chrome-auto-connect allow --timeout 5     设置 5 秒超时
  `);
}

function showVersion() {
  console.log(`chrome-auto-connect v${VERSION}`);
}

function getScriptPath(scriptName) {
  return path.join(SCRIPTS_DIR, scriptName);
}

function runScript(scriptName, args = []) {
  const scriptPath = getScriptPath(scriptName);
  
  if (!fs.existsSync(scriptPath)) {
    console.error(`${colors.red}错误: 脚本不存在: ${scriptPath}${colors.reset}`);
    process.exit(1);
  }

  const child = spawn('bash', [scriptPath, ...args], {
    stdio: 'inherit',
    cwd: SCRIPTS_DIR
  });

  child.on('exit', (code) => {
    process.exit(code || 0);
  });

  child.on('error', (err) => {
    console.error(`${colors.red}错误: ${err.message}${colors.reset}`);
    process.exit(1);
  });
}

function runNodeScript(scriptName, args = []) {
  const scriptPath = getScriptPath(scriptName);
  
  if (!fs.existsSync(scriptPath)) {
    console.error(`${colors.red}错误: 脚本不存在: ${scriptPath}${colors.reset}`);
    process.exit(1);
  }

  const child = spawn('node', [scriptPath, ...args], {
    stdio: 'inherit',
    cwd: SCRIPTS_DIR
  });

  child.on('exit', (code) => {
    process.exit(code || 0);
  });

  child.on('error', (err) => {
    console.error(`${colors.red}错误: ${err.message}${colors.reset}`);
    process.exit(1);
  });
}

// 解析参数
const args = process.argv.slice(2);
let command = '';
let options = {
  debug: false,
  json: false,
  sync: false,
  timeout: ''
};

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  
  switch (arg) {
    case 'status':
    case 'start':
    case 'allow':
      command = arg;
      break;
    case '--debug':
      options.debug = true;
      break;
    case '--json':
      options.json = true;
      break;
    case '--sync':
      options.sync = true;
      break;
    case '--timeout':
      if (i + 1 < args.length) {
        options.timeout = args[++i];
      }
      break;
    case '-h':
    case '--help':
      showHelp();
      process.exit(0);
      break;
    case '-v':
    case '--version':
      showVersion();
      process.exit(0);
      break;
    default:
      if (!command && !arg.startsWith('-')) {
        command = arg;
      }
      break;
  }
}

// 如果没有指定命令，显示帮助
if (!command) {
  showHelp();
  process.exit(0);
}

// 构造传递给脚本的参数
const scriptArgs = [];
if (options.debug) scriptArgs.push('--debug');
if (options.json) scriptArgs.push('--json');
if (options.sync) scriptArgs.push('--sync');
if (options.timeout) scriptArgs.push('--timeout', options.timeout);

// 执行命令
switch (command) {
  case 'status':
  case 'start':
  case 'allow':
    runScript('chrome-auto-connect.sh', [command, ...scriptArgs]);
    break;
  default:
    console.error(`${colors.red}未知命令: ${command}${colors.reset}`);
    showHelp();
    process.exit(1);
}
