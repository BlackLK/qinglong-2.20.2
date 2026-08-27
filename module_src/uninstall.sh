#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 模块卸载脚本 (uninstall.sh)
# 功能：模块在 Root 管理器中被删除时触发；停止进程、清理模块与运行环境、保留用户数据
# ==============================================================================

# 1. 停止运行中的青龙面板进程
if [ -f "/data/adb/qinglong-data/run/qinglong.pid" ]; then
    PID=$(cat "/data/adb/qinglong-data/run/qinglong.pid" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        kill -15 "$PID" 2>/dev/null
        sleep 1
        kill -9 "$PID" 2>/dev/null
    fi
fi
pkill -f "qinglong" 2>/dev/null

# 2. 清理程序本体与运行库目录 (保留 /data/adb/qinglong-data 用户数据)
rm -rf "/data/adb/qinglong" 2>/dev/null

# 3. 清理运行时临时文件
rm -f "/data/adb/qinglong-data/run/qinglong.pid" 2>/dev/null
rm -f "/data/adb/qinglong-data/run/operation.lock" 2>/dev/null
rm -f "/data/adb/qinglong-data/run/boot_fail.count" 2>/dev/null

# 记录卸载日志
echo "$(date '+%Y-%m-%d %H:%M:%S') [OK] 青龙模块已成功卸载，用户数据目录 /data/adb/qinglong-data 已完整保留。" >> "/data/adb/qinglong-data/logs/uninstall.log" 2>/dev/null

exit 0
