#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 信息展示脚本 (info.sh)
# ==============================================================================

[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"
. "${MANAGER_DIR}/common.sh"
. "${MANAGER_DIR}/status.sh"

echo "=================================================="
echo "           QingLong 青龙面板 运行信息             "
echo "=================================================="

echo "模块版本       : 1.0.0"
echo "青龙版本       : ${DEFAULT_QL_VERSION}"
echo "Root 管理器    : $(detect_root_manager)"
echo "系统架构 (ABI) : $(get_device_abi)"
echo "Android 版本   : $(get_android_version)"

if [ -f "$AUTOSTART_FILE" ] && [ "$(cat "$AUTOSTART_FILE" 2>/dev/null)" = "1" ]; then
    echo "开机自启       : ON (已开启)"
else
    echo "开机自启       : OFF (已关闭)"
fi

if check_qinglong_status; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    echo "运行状态       : RUNNING (运行中)"
    echo "进程 PID       : ${PID}"
    echo "默认访问端口   : ${DEFAULT_QL_PORT}"
else
    echo "运行状态       : STOPPED (已停止)"
    echo "进程 PID       : -"
    echo "默认访问端口   : ${DEFAULT_QL_PORT}"
fi

echo "--------------------------------------------------"
echo "程序安装目录   : ${QL_ROOT}"
echo "当前激活版本   : $(readlink "${QL_CURRENT}" 2>/dev/null || echo "${QL_CURRENT}")"
echo "用户数据目录   : ${QL_DATA_ROOT}"
echo "=================================================="
