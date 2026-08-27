#!/system/bin/sh
# ==============================================================================
# 青龙面板 · 清除数据工具 (action.sh)
# 作用：永久删除青龙面板全部用户数据目录 /data/adb/qinglong-data
# 安全机制：两段式确认 —— 第一次点击只显示警告，第二次点击才真正执行
# ==============================================================================

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong-wipe-data"
export MODDIR

DATA_DIR="/data/adb/qinglong-data"
PENDING="${DATA_DIR}/.wipe_pending"

stop_panel() {
    # 停止运行中的面板进程，避免边跑边删
    local pid=""
    [ -f "${DATA_DIR}/run/qinglong.pid" ] && pid=$(cat "${DATA_DIR}/run/qinglong.pid" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -15 "$pid" 2>/dev/null
        i=0; while [ "$i" -lt 5 ] && kill -0 "$pid" 2>/dev/null; do sleep 1; i=$((i+1)); done
        kill -9 "$pid" 2>/dev/null
    fi
    for p in /proc/[0-9]*/cmdline; do
        c=$(cat "$p" 2>/dev/null | tr '\0' ' ')
        case "$c" in
            *app_single.js*|*dns_forwarder.js*)
                dp=$(basename $(dirname "$p") | tr -dc '0-9')
                kill -9 "$dp" 2>/dev/null ;;
        esac
    done
}

echo "=========================================="
echo "      青龙面板 · 用户数据清除工具"
echo "=========================================="

if [ ! -d "$DATA_DIR" ]; then
    echo "[INFO] 未检测到用户数据目录"
    echo "       (${DATA_DIR})"
    echo "面板尚未初始化过, 无需清除。"
    exit 0
fi

if [ -f "$PENDING" ]; then
    # ---------- 第二次点击：校验是否在确认有效期内 ----------
    now=$(date +%s)
    mark=$(stat -c %Y "$PENDING" 2>/dev/null || echo "$now")
    age=$((now - mark))
    if [ "$age" -gt 120 ]; then
        echo "[INFO] 上次确认已超过 2 分钟, 自动作废。"
        echo "       如确实要清除数据, 请从头再次点击「执行」。"
        echo ""
        rm -f "$PENDING"
        exit 0
    fi
    # ---------- 在有效期内：真正执行清除 ----------
    echo "[1/3] 停止青龙面板进程..."
    stop_panel
    echo "[OK] 进程已停止"
    echo ""
    echo "[2/3] 清除用户数据..."
    rm -rf "$DATA_DIR"
    if [ -d "$DATA_DIR" ]; then
        echo "[ERROR] 删除失败! 请检查是否有进程占用后重试。"
        exit 1
    fi
    echo "[OK] ${DATA_DIR} 已完全清除"
    echo ""
    echo "[3/3] 完成!"
    echo "------------------------------------------"
    echo "面板已恢复出厂状态:"
    echo "请重启设备(或重刷面板模块), 然后在管理器中"
    echo "点击青龙模块「执行」重新初始化。"
    echo "=========================================="
else
    # ---------- 第一次点击：仅警告与确认 ----------
    echo "⚠️⚠️⚠️  危险操作警告  ⚠️⚠️⚠️"
    echo ""
    echo "再次点击「执行」将【永久删除】全部用户数据:"
    echo "定时任务 / 环境变量 / 脚本 / 数据库 / 已装依赖"
    echo ""
    echo "删除后【无法恢复】!"
    echo ""
    echo "如果只是想卸载或升级面板、保留数据,"
    echo "请不要使用本工具, 直接操作主模块即可。"
    echo ""
    echo "确认要彻底重置, 请在 2 分钟内再次点击「执行」。"
    echo "(超过 2 分钟未确认, 本次操作将自动作废)"
    mkdir -p "$DATA_DIR" 2>/dev/null
    echo "1" > "$PENDING"
fi
exit 0