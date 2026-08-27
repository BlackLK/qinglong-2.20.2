#!/system/bin/sh
# ==============================================================================
# Button 3: 开机自启 切换开关 / Toggle AutoStart (ON <-> OFF)
# 按钮作用：
#   点击一次 -> 如果当前是关闭 就开启； 如果当前是开启 就关闭
# ==============================================================================

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"

. "${MANAGER_DIR}/common.sh"

echo "=================================================="
echo "      QingLong - Toggle Boot AutoStart            "
echo "=================================================="

mkdir -p "${QL_USER_CONFIG}" 2>/dev/null

CURRENT_STATE="$(cat "$AUTOSTART_FILE" 2>/dev/null)"

echo ""

if [ "$CURRENT_STATE" = "1" ]; then
    # 当前是 ON -> 切换到 OFF
    echo "0" > "$AUTOSTART_FILE"
    sync
    log_ok "--------------------------------------------------"
    log_ok "  Before: AutoStart [ON]  Enabled"
    log_ok "  Action: Disable Boot AutoStart"
    log_ok "  After : AutoStart [OFF] Disabled"
    log_ok "--------------------------------------------------"
    echo ""
    echo "  +----------------------------------------------+"
    echo "  |  Next boot: QingLong WON'T auto-start.       |"
    echo "  |  Please click [Start QingLong] manually.     |"
    echo "  +----------------------------------------------+"
    echo ""
    echo "  [按钮提示] 再点一次本按钮，会重新开启开机自启。"
else
    # 当前是 OFF 或未设置 -> 切换到 ON
    echo "1" > "$AUTOSTART_FILE"
    sync
    log_ok "--------------------------------------------------"
    log_ok "  Before: AutoStart [OFF] Disabled"
    log_ok "  Action: Enable Boot AutoStart"
    log_ok "  After : AutoStart [ON]  Enabled"
    log_ok "--------------------------------------------------"
    echo ""
    echo "  +----------------------------------------------+"
    echo "  |  Next boot (after system fully booted):      |"
    echo "  |  QingLong will start automatically,         |"
    echo "  |  listen on port 5700.                        |"
    echo "  +----------------------------------------------+"
    echo ""
    echo "  [Button Hint] Click this button again to disable auto start."
fi

echo ""
echo "=================================================="
