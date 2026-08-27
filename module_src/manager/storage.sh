#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 存储统计脚本 (storage.sh)
# ==============================================================================

[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"
. "${MANAGER_DIR}/common.sh"

echo "=================================================="
echo "           QingLong 青龙面板 存储占用统计         "
echo "=================================================="

get_size() {
    local target_dir="$1"
    if [ -e "$target_dir" ]; then
        du -sh "$target_dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

echo "1. 青龙程序版本库 (${QL_VERSIONS})   : $(get_size "$QL_VERSIONS")"
echo "2. Node.js 运行环境 (${QL_RUNTIME})   : $(get_size "$QL_RUNTIME")"
echo "3. 用户脚本目录     (${QL_USER_SCRIPTS}) : $(get_size "$QL_USER_SCRIPTS")"
echo "4. 用户配置目录     (${QL_USER_CONFIG})  : $(get_size "$QL_USER_CONFIG")"
echo "5. 数据库文件       (${QL_USER_DB})      : $(get_size "$QL_USER_DB")"
echo "6. 运行与操作日志   (${QL_USER_LOGS})    : $(get_size "$QL_USER_LOGS")"
echo "7. 数据备份存档     (${QL_USER_BACKUPS}) : $(get_size "$QL_USER_BACKUPS")"
echo "8. 临时缓存         (${QL_CACHE})        : $(get_size "$QL_CACHE")"
echo "--------------------------------------------------"
echo "青龙总占用空间      : $(get_size "$QL_ROOT") (程序) + $(get_size "$QL_DATA_ROOT") (数据)"
echo "=================================================="
