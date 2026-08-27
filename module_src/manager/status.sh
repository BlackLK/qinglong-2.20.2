#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 运行状态检测脚本 (status.sh)
# ==============================================================================

[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"
[ -f "${MANAGER_DIR}/common.sh" ] && . "${MANAGER_DIR}/common.sh"

check_qinglong_status() {
    if [ ! -f "$PID_FILE" ]; then
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -z "$pid" ]; then
        rm -f "$PID_FILE" 2>/dev/null
        return 1
    fi

    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE" 2>/dev/null
        return 1
    fi

    local cmdline_path="/proc/${pid}/cmdline"
    if [ -f "$cmdline_path" ]; then
        local cmdline
        cmdline=$(tr '\0' ' ' < "$cmdline_path" 2>/dev/null)
        case "$cmdline" in
            *node*|*qinglong*|*app.js*|*app.ts*|*pm2*)
                return 0
                ;;
            *)
                rm -f "$PID_FILE" 2>/dev/null
                return 1
                ;;
        esac
    fi

    return 0
}

print_status_summary() {
    if check_qinglong_status; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        echo "RUNNING (运行中, PID: ${pid})"
    else
        echo "STOPPED (已停止)"
    fi
}

if [ "${0##*/}" = "status.sh" ]; then
    print_status_summary
fi
