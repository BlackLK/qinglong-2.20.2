#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 停止管理脚本 (stop.sh)
# ==============================================================================

[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"
. "${MANAGER_DIR}/common.sh"
. "${MANAGER_DIR}/status.sh"

log_info "正在停止青龙面板服务..."

if ! check_qinglong_status; then
    log_info "青龙面板当前未在运行。"
    rm -f "$PID_FILE" 2>/dev/null
    exit 0
fi

if ! acquire_lock "stop"; then
    exit 1
fi
trap 'release_lock' EXIT INT TERM

PID=$(cat "$PID_FILE" 2>/dev/null)

if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    log_info "发送优雅停止信号 (SIGTERM, PID: ${PID})..."
    kill -15 "$PID" 2>/dev/null

    COUNT=0
    while kill -0 "$PID" 2>/dev/null && [ "$COUNT" -lt 10 ]; do
        sleep 1
        COUNT=$((COUNT + 1))
    done

    if kill -0 "$PID" 2>/dev/null; then
        log_warn "进程未在规定时间内退出，执行强制终止 (SIGKILL, PID: ${PID})..."
        kill -9 "$PID" 2>/dev/null
        sleep 1
    fi
fi

pkill -f "qinglong" 2>/dev/null
pkill -f "node.real" 2>/dev/null
rm -f "$PID_FILE" 2>/dev/null

log_ok "青龙面板服务已完全停止。"
exit 0
