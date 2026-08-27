#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 开机完成事件处理脚本 (boot-completed.sh)
# 功能：等待 Android 系统完全启动后，按需启动青龙；内置防卡死与连续失败熔断机制
# ==============================================================================

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"

# 引入公共库
. "${MANAGER_DIR}/common.sh"
. "${MANAGER_DIR}/status.sh"

# 1. 循环等待直到 Android 报告 sys.boot_completed=1（最多等待 60 秒）
TIMEOUT=60
while [ "$TIMEOUT" -gt 0 ]; do
    BOOT_STATUS=$(getprop sys.boot_completed 2>/dev/null)
    [ "$BOOT_STATUS" = "1" ] && break
    sleep 2
    TIMEOUT=$((TIMEOUT - 2))
done

# 2. 检查是否开启了开机自启
if [ ! -f "$AUTOSTART_FILE" ] || [ "$(cat "$AUTOSTART_FILE" 2>/dev/null)" != "1" ]; then
    # 未开启自启，安全退出
    exit 0
fi

# 3. 连续失败熔断保护 (防止因坏境异常反复启动导致系统卡顿)
MAX_FAIL=3
CURRENT_FAILS=0
[ -f "$FAIL_COUNT_FILE" ] && CURRENT_FAILS=$(cat "$FAIL_COUNT_FILE" 2>/dev/null)
[ -z "$CURRENT_FAILS" ] && CURRENT_FAILS=0

if [ "$CURRENT_FAILS" -ge "$MAX_FAIL" ]; then
    log_error "青龙连续启动失败达到 ${MAX_FAIL} 次，触发熔断保护！已自动关闭开机自启。"
    echo "0" > "$AUTOSTART_FILE"
    exit 1
fi

# 4. 执行启动
log_info "系统已就绪，正在按配置自启青龙面板..."
sh "${MANAGER_DIR}/start.sh"

# 5. 验证启动结果
sleep 3
if check_qinglong_status; then
    log_ok "开机自启青龙面板成功！"
    rm -f "$FAIL_COUNT_FILE" 2>/dev/null
else
    CURRENT_FAILS=$((CURRENT_FAILS + 1))
    echo "$CURRENT_FAILS" > "$FAIL_COUNT_FILE"
    log_error "开机自启青龙面板失败 (当前连续失败次数: ${CURRENT_FAILS}/${MAX_FAIL})"
fi

exit 0
