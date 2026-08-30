#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 资源综合报告 (report.sh)
# 以等宽"文字表格"形式输出三类信息：
#   1) 内存占用   : 青龙常驻进程 RAM (RSS)
#   2) 磁盘占用   : 程序/运行时/依赖/脚本/数据库/配置/日志/缓存/备份 分类
#   3) 用户数据   : 定时任务/环境变量/依赖/应用授权/订阅 记录数 (读 sqlite)
# ==============================================================================

[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"
. "${MANAGER_DIR}/common.sh"
. "${MANAGER_DIR}/status.sh"

RT_BIN="${QL_RUNTIME}/bin"
export PATH="${RT_BIN}:${PATH}"
BASH_SH="${RT_BIN}/bash-sh"

# ---------- 工具函数 ----------
human_kb() {
    # 把 KB 数值格式化为人类可读大小
    awk -v k="$1" 'BEGIN{
        if (k+0<=0)            printf "0 KB";
        else if (k<1024)       printf "%d KB", k;
        else if (k<1048576)    printf "%.1f MB", k/1024;
        else                   printf "%.2f GB", k/1048576;
    }'
}

du_kb() {
    # 目录不存在或为空返回 0
    [ -e "$1" ] || { echo 0; return; }
    du -sk "$1" 2>/dev/null | awk '{print $1}'
}

row() {
    # 文字表格行: row "<标签>" "<值>"
    printf "  %-22s %s\n" "$1" "$2"
}

# ============================================================
echo ""
echo "=========================================="
echo "        QingLong 青龙面板 资源报告        "
echo "=========================================="

# ---------- 1. 内存占用 ----------
echo ""
echo "[ 内存占用 (RAM, 常驻进程) ]"
TOTAL_RSS=0
PROJ=$(cat "$PID_FILE" 2>/dev/null)

collect_rss() {
    local pid="$1" name="$2"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        rss=$(awk '/^VmRSS:/{print $2}' "/proc/${pid}/status" 2>/dev/null)
        if [ -n "$rss" ]; then
            TOTAL_RSS=$((TOTAL_RSS + rss))
            printf "  %-20s PID %-8s RSS %s\n" "${name}" "${pid}" "$(human_kb "$rss")"
            return
        fi
    fi
    printf "  %-20s %s\n" "${name}" "-"
}

# 面板主进程 + 其 node 子进程
if check_qinglong_status; then
    collect_rss "$PROJ" "面板主进程"
    for p in /proc/[0-9]*/cmdline; do
        cp_args=$(cat "$p" 2>/dev/null | tr '\0' ' ')
        case "$cp_args" in
            *node.real*app_single.js*) ;;
            *node.real*dns_forwarder*)
                dp=$(basename $(dirname "$p") | tr -dc '0-9')
                collect_rss "$dp" "DNS 转发器"
                ;;
        esac
    done
else
    echo "  面板未运行，无常驻内存占用"
fi

# dns forwarder 可能由 start.sh 拉起而主进程未统计到时兜底再扫一次
FOUND_DNS=0
for p in /proc/[0-9]*/cmdline; do
    cp_args=$(cat "$p" 2>/dev/null | tr '\0' ' ')
    case "$cp_args" in *node.real*dns_forwarder*) FOUND_DNS=1 ;; esac
done

# ---------- 2. 磁盘占用 ----------
echo ""
echo "[ 磁盘占用 ]"

VER_TOTAL=$(du_kb "$QL_VERSIONS")
NM_DIR="${QL_VERSIONS}/node_modules"
NM_SIZE=$(du_kb "$NM_DIR")
QL_PROG=$((VER_TOTAL - NM_SIZE))

RUNTIME_TOTAL=$(du_kb "$QL_RUNTIME")
PYLIB_SIZE=$(du_kb "${QL_RUNTIME}/lib/python3.11")
PYLIB=$((PYLIB_SIZE + $(du_kb "${QL_RUNTIME}/bin/python3.11.real")))

DEPS_DATA=0
for d in "${QL_DATA_ROOT}/dep_cache" "${QL_DATA_ROOT}/.pnpm-home"; do
    DEPS_DATA=$((DEPS_DATA + $(du_kb "$d")))
done

LOGS_KB=$(( $(du_kb "$QL_USER_LOGS") + $(du_kb "${QL_DATA_ROOT}/run") ))
CACHE_KB=$(du_kb "${QL_ROOT}/cache")

DISK_ROWS=""
DISK_SUM=0
add_disk() {
    label="$1"; kb="$2"
    DISK_SUM=$((DISK_SUM + kb))
    DISK_ROWS="${DISK_ROWS}$(printf "  %-26s %10s\n" "${label}" "$(human_kb "$kb")")\n"
}

add_disk "QingLong 程序本体"     "$QL_PROG"
add_disk "NodeJS 依赖库"         "$((NM_SIZE + DEPS_DATA))"
add_disk "Python3 运行环境"      "$PYLIB"
add_disk "Node/系统 运行库"      "$((RUNTIME_TOTAL - PYLIB))"
add_disk "用户脚本"              "$(du_kb "$QL_USER_SCRIPTS")"
add_disk "数据库"                "$(du_kb "$QL_USER_DB")"
add_disk "配置文件"              "$(du_kb "$QL_USER_CONFIG")"
add_disk "日志与运行记录"        "$LOGS_KB"
add_disk "缓存"                  "$CACHE_KB"
add_disk "备份存档"              "$(du_kb "$QL_USER_BACKUPS")"

printf "%b" "$DISK_ROWS"
printf "  %-26s %10s\n" "------------------------------------" "--------"
printf "  %-26s %10s\n" "合计" "$(human_kb "$DISK_SUM")"

# ---------- 3. 用户数据 ----------
echo ""
echo "[ 用户数据 ]"
STAT_PY="${MODDIR}/manager/db_stats.py"
if [ -f "$STAT_PY" ] && command -v python3 >/dev/null 2>&1; then
    "$BASH_SH" -c "python3 $STAT_PY 2>/dev/null"
elif check_qinglong_status; then
    # 面板运行中且本地 python 不在 PATH 时，走绝对路径 wrapper 兜底
    ls "$QL_USER_SCRIPTS"/*.js "$QL_USER_SCRIPTS"/*.py 2>/dev/null | wc -l | awk '{printf "  %-22s %d 个文件\n", "用户脚本数", $1}'
fi

# 数据目录整体
DATA_TOTAL=$(du_kb "$QL_DATA_ROOT")
echo ""
printf "  %-24s %12s (%s)\n" "用户数据目录合计" "$(human_kb "$DATA_TOTAL")" "${QL_DATA_ROOT}"

# ---------- 访问信息 ----------
echo ""
if check_qinglong_status; then
    IP=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="src"){print $(i+1); exit}}')
    [ -z "$IP" ] && IP="<设备IP>"
    echo "------------------------------------------"
    echo "  Web 面板: http://${IP}:5700  状态: RUNNING"
else
    echo "------------------------------------------"
    echo "  状态: STOPPED (执行本按钮可启动)"
    echo "  启动报错日志: ${QL_USER_LOGS}/start.log"
    echo "  查看: su -c \"tail -n 50 ${QL_USER_LOGS}/start.log\""
fi
echo "=========================================="