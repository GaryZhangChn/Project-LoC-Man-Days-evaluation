const fs = require('fs');
const path = require('path');

const CONFIG = {
    BE_LOW_BOUND: 80, BE_HIGH_BOUND: 120, BE_RECOMMENDED: 100,  // 后端基准
    FE_LOW_BOUND: 150, FE_HIGH_BOUND: 200, FE_RECOMMENDED: 175, // 前端模板型较快
    COMPLEXITY_FACTOR: 1.2,
    FRONTEND_EXTS: ['.tsx', '.ts', '.css', '.scss', '.html', '.js', '.jsp'],
    BACKEND_EXTS: ['.java', '.sql', '.xml', '.properties', '.yml', '.yaml', '.gradle'],
    WEIGHTS: {
        '.java': 1.0, '.tsx': 1.0, '.ts': 1.0, '.js': 1.0, '.sql': 1.0, '.jsp': 1.0,
        '.xml': 0.5, '.yml': 0.5, '.yaml': 0.5, '.gradle': 0.5, '.properties': 0.5, '.css': 0.5, '.scss': 0.5, '.html': 0.5
    },
    EXCLUDE_DIRS: ['node_modules', '.next', '.git', '.vscode', 'dist', 'build', 'out', 'public', 'target', 'bin', '.gradle', '.idea', 'classes', 'WEB-INF/classes'],
    EXCLUDE_EXTS: ['.class', '.swf', '.jar', '.war', '.zip', '.lock'],
    // 屏蔽编译产物和连带行数庞大的自动生成文件
    EXCLUDE_NAMES: new Set(['pnpm-lock.yaml', 'yarn.lock', 'package-lock.json', 'Gemfile.lock', 'poetry.lock'])
};

const COLORS = { BLUE: '\x1b[34m', GREEN: '\x1b[32m', YELLOW: '\x1b[33m', GRAY: '\x1b[90m', NC: '\x1b[0m' };
function log(color, msg) { console.log(`${color}${msg}${COLORS.NC}`); }

function countLoc(dir, stats = { feW: 0, beW: 0, feCount: 0, beCount: 0 }) {
    for (const file of fs.readdirSync(dir)) {
        const fullPath = path.join(dir, file);
        const relativePath = path.relative(process.cwd(), fullPath);
        
        if (fs.statSync(fullPath).isDirectory()) {
            if (!CONFIG.EXCLUDE_DIRS.includes(file) && !CONFIG.EXCLUDE_DIRS.includes(relativePath)) {
                countLoc(fullPath, stats);
            }
        } else {
            const ext = path.extname(file).toLowerCase();
            if (CONFIG.EXCLUDE_EXTS.includes(ext)) continue;
            if (CONFIG.EXCLUDE_NAMES.has(file)) continue; // 过滤锁文件
            
            if (CONFIG.WEIGHTS[ext]) {
                const lines = fs.readFileSync(fullPath, 'utf8').split('\n').length;
                if (CONFIG.FRONTEND_EXTS.includes(ext)) { stats.feW += lines * CONFIG.WEIGHTS[ext]; stats.feCount++; }
                else if (CONFIG.BACKEND_EXTS.includes(ext)) { stats.beW += lines * CONFIG.WEIGHTS[ext]; stats.beCount++; }
            }
        }
    }
    return stats;
}

log(COLORS.BLUE, '=== 通用项目代码评估工具 (前后端拆分版) ===');
log(COLORS.GRAY, `扫描路径: ${process.cwd()}`);

try {
    const stats = countLoc(process.cwd());
    const totalW = stats.feW + stats.beW;
    if (totalW === 0) { log(COLORS.YELLOW, '警告: 未找到匹配的源码文件。'); process.exit(0); }

    const feMd = (w) => `${((w / CONFIG.FE_HIGH_BOUND) * CONFIG.COMPLEXITY_FACTOR).toFixed(1)} - ${((w / CONFIG.FE_LOW_BOUND) * CONFIG.COMPLEXITY_FACTOR).toFixed(1)}`;
    const beMd = (w) => `${((w / CONFIG.BE_HIGH_BOUND) * CONFIG.COMPLEXITY_FACTOR).toFixed(1)} - ${((w / CONFIG.BE_LOW_BOUND) * CONFIG.COMPLEXITY_FACTOR).toFixed(1)}`;
    const feMin = (stats.feW / CONFIG.FE_HIGH_BOUND) * CONFIG.COMPLEXITY_FACTOR;
    const feMax = (stats.feW / CONFIG.FE_LOW_BOUND) * CONFIG.COMPLEXITY_FACTOR;
    const beMin = (stats.beW / CONFIG.BE_HIGH_BOUND) * CONFIG.COMPLEXITY_FACTOR;
    const beMax = (stats.beW / CONFIG.BE_LOW_BOUND) * CONFIG.COMPLEXITY_FACTOR;
    const totalMin = feMin + beMin;
    const totalMax = feMax + beMax;
    const totalRec = (stats.feW / CONFIG.FE_RECOMMENDED + stats.beW / CONFIG.BE_RECOMMENDED) * CONFIG.COMPLEXITY_FACTOR;

    console.log(`----------------------------------------`);
    log(COLORS.NC, `前端 (Frontend): 加权行数: ${COLORS.GREEN}${Math.round(stats.feW)}${COLORS.NC} | 预估: ${COLORS.YELLOW}${feMd(stats.feW)}${COLORS.NC} 人日`);
    log(COLORS.NC, `后端 (Backend):  加权行数: ${COLORS.GREEN}${Math.round(stats.beW)}${COLORS.NC} | 预估: ${COLORS.YELLOW}${beMd(stats.beW)}${COLORS.NC} 人日`);
    console.log(`----------------------------------------`);

    log(COLORS.BLUE, '=== 总项目评估结果 ===');
    log(COLORS.NC, `工作量区间: ${COLORS.GREEN}${totalMin.toFixed(1)} - ${totalMax.toFixed(1)} 人日${COLORS.NC}`);
    log(COLORS.NC, `推荐参考值: ${COLORS.YELLOW}${totalRec.toFixed(1)} 人日${COLORS.NC}`);
    console.log(`----------------------------------------`);
    log(COLORS.GRAY, '(结果仅供参考，详情见 README.md)');
} catch (err) { log(COLORS.RED, `错误: ${err.message}`); }
