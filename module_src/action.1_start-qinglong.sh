#!/system/bin/sh
# ==============================================================================
# Button 1: 启动青龙 / Start QingLong
# ==============================================================================

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"

. "${MANAGER_DIR}/common.sh"

echo "=================================================="
echo "          QingLong - Start Service                "
echo "=================================================="

sh "${MANAGER_DIR}/start.sh"
