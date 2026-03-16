#!/bin/bash

# --- 核心配置 ---
# 后端生产力基准 (逻辑密集型: Java, SQL)
BE_LOW_BOUND=80
BE_HIGH_BOUND=120
BE_RECOMMENDED=100
# 前端生产力基准 (UI/模板型: TSX, TS, CSS 较快)
FE_LOW_BOUND=150
FE_HIGH_BOUND=200
FE_RECOMMENDED=175
COMPLEXITY_FACTOR=1.2

# --- 颜色输出 ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m'

printf -- "${BLUE}=== 通用项目代码评估工具 (前后端拆分版) ===${NC}\n"
printf -- "${GRAY}当前目录: $(pwd)${NC}\n"
printf -- "${GRAY}正在扫描文件...${NC}\n"

# 辅助函数：统计某扩展名文件的总行数 (不分大小写)
# 用法: count_ext_lines ".java"
count_ext_lines() {
    local ext=$1
    find . -type d \( -name 'node_modules' -o -name '.next' -o -name 'out' -o -name '.git' -o -name 'target' -o -name 'bin' -o -name '.gradle' -o -name '.idea' -o -name 'build' -o -name 'dist' -o -name 'classes' \) -prune \
        -o -type f -iname "*${ext}" ! -iname "*.lock" -print0 2>/dev/null \
        | xargs -0 grep -l '' 2>/dev/null \
        | xargs cat 2>/dev/null \
        | wc -l | tr -d ' '
}

count_ext_files() {
    local ext=$1
    find . -type d \( -name 'node_modules' -o -name '.next' -o -name 'out' -o -name '.git' -o -name 'target' -o -name 'bin' -o -name '.gradle' -o -name '.idea' -o -name 'build' -o -name 'dist' -o -name 'classes' \) -prune \
        -o -type f -iname "*${ext}" ! -iname "*.lock" -print 2>/dev/null \
        | grep -v "^\\.$" | wc -l | tr -d ' '
}

printf -- "----------------------------------------\n"
printf -- "${BLUE}文件发现摘要:${NC}\n"

# --- 发现各类型文件 ---
java_n=$(count_ext_files ".java"); java_l=$(count_ext_lines ".java")
sql_n=$(count_ext_files ".sql");   sql_l=$(count_ext_lines ".sql")
jsp_n=$(count_ext_files ".jsp");   jsp_l=$(count_ext_lines ".jsp")
xml_n=$(count_ext_files ".xml");   xml_l=$(count_ext_lines ".xml")
prop_n=$(count_ext_files ".properties"); prop_l=$(count_ext_lines ".properties")
yml_n=$(count_ext_files ".yml");   yml_l=$(count_ext_lines ".yml")
css_n=$(count_ext_files ".css");   css_l=$(count_ext_lines ".css")
html_n=$(count_ext_files ".html"); html_l=$(count_ext_lines ".html")
js_n=$(count_ext_files ".js");     js_l=$(count_ext_lines ".js")
ts_n=$(count_ext_files ".ts");     ts_l=$(count_ext_lines ".ts")
tsx_n=$(count_ext_files ".tsx");   tsx_l=$(count_ext_lines ".tsx")

print_stat() {
    local label=$1 n=$2 l=$3
    if [ "$n" -gt 0 ] 2>/dev/null; then
        printf -- "  %-20s %4d 个文件  %7d 行\n" "$label" "$n" "$l"
    fi
}

print_stat ".java  (后端逻辑)" "$java_n" "$java_l"
print_stat ".sql   (后端逻辑)" "$sql_n"  "$sql_l"
print_stat ".xml   (后端配置)" "$xml_n"  "$xml_l"
print_stat ".properties (配置)" "$prop_n" "$prop_l"
print_stat ".yml   (配置)"     "$yml_n"  "$yml_l"
print_stat ".jsp   (前端逻辑)" "$jsp_n"  "$jsp_l"
print_stat ".css   (前端配置)" "$css_n"  "$css_l"
print_stat ".html  (前端配置)" "$html_n" "$html_l"
print_stat ".js    (前端逻辑)" "$js_n"   "$js_l"
print_stat ".ts    (前端逻辑)" "$ts_n"   "$ts_l"
print_stat ".tsx   (前端逻辑)" "$tsx_n"  "$tsx_l"

# --- 加权计算 ---
# 后端: java/sql 权重 1.0, xml/properties/yml 权重 0.5
BE_W=$(echo "scale=2; ($java_l + $sql_l) * 1.0 + ($xml_l + $prop_l + $yml_l) * 0.5" | bc)
# 前端: jsx/js/ts/tsx 权重 1.0, css/html 权重 0.5
FE_W=$(echo "scale=2; ($jsp_l + $js_l + $ts_l + $tsx_l) * 1.0 + ($css_l + $html_l) * 0.5" | bc)
TOTAL_W=$(echo "$FE_W + $BE_W" | bc)

total_files=$((java_n + sql_n + jsp_n + xml_n + prop_n + yml_n + css_n + html_n + js_n + ts_n + tsx_n))
if [ "$total_files" -eq 0 ]; then
    printf -- "${YELLOW}警告: 未找到任何匹配的源码文件。${NC}\n"
    printf -- "${GRAY}提示: 请检查当前目录是否包含 src/com 等代码目录。${NC}\n"
    exit 0
fi

FE_W_INT=$(echo "$FE_W" | awk '{printf "%d", $1}')
BE_W_INT=$(echo "$BE_W" | awk '{printf "%d", $1}')

printf -- "----------------------------------------\n"
printf -- "前端 (Frontend): 加权行数: ${GREEN}$FE_W_INT${NC} | 预估: $(echo "scale=1; ($FE_W / $FE_HIGH_BOUND) * $COMPLEXITY_FACTOR" | bc) - $(echo "scale=1; ($FE_W / $FE_LOW_BOUND) * $COMPLEXITY_FACTOR" | bc) 人日\n"
printf -- "后端 (Backend):  加权行数: ${GREEN}$BE_W_INT${NC} | 预估: $(echo "scale=1; ($BE_W / $BE_HIGH_BOUND) * $COMPLEXITY_FACTOR" | bc) - $(echo "scale=1; ($BE_W / $BE_LOW_BOUND) * $COMPLEXITY_FACTOR" | bc) 人日\n"
printf -- "----------------------------------------\n"

FE_MIN=$(echo "scale=1; ($FE_W / $FE_HIGH_BOUND) * $COMPLEXITY_FACTOR" | bc)
FE_MAX=$(echo "scale=1; ($FE_W / $FE_LOW_BOUND) * $COMPLEXITY_FACTOR" | bc)
BE_MIN=$(echo "scale=1; ($BE_W / $BE_HIGH_BOUND) * $COMPLEXITY_FACTOR" | bc)
BE_MAX=$(echo "scale=1; ($BE_W / $BE_LOW_BOUND) * $COMPLEXITY_FACTOR" | bc)
MD_MIN=$(echo "scale=1; $FE_MIN + $BE_MIN" | bc)
MD_MAX=$(echo "scale=1; $FE_MAX + $BE_MAX" | bc)
MD_REC=$(echo "scale=1; ($FE_W / $FE_RECOMMENDED + $BE_W / $BE_RECOMMENDED) * $COMPLEXITY_FACTOR" | bc)

printf -- "${BLUE}=== 总项目评估结果 ===${NC}\n"
printf -- "工作量区间: ${GREEN}$MD_MIN - $MD_MAX 人日${NC}\n"
printf -- "推荐参考值: ${YELLOW}$MD_REC 人日${NC}\n"
printf -- "----------------------------------------\n"
printf -- "${GRAY}(结果仅供参考，详情见 README.md)${NC}\n"
