#!/system/bin/sh
# ==============================================================================
# Button 2: 停止青龙 / Stop QingLong
# ==============================================================================

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"

. "${MANAGER_DIR}/common.sh"

echo "=================================================="
echo "          QingLong - Stop Service                 "
echo "=================================================="

sh "${MANAGER_DIR}/stop.sh"
