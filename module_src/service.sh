#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 开机服务脚本 (service.sh)
# 功能：系统引导 late_start 阶段被 Root 管理器拉起，绝对异步非阻塞
# ==============================================================================

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"

# 绝不在主进程中做耗时操作，立即放入后台执行
(
    # 等待系统基础服务就绪
    sleep 10

    # 检查 boot-completed.sh 是否存在，若存在且支持则由该脚本处理自启
    if [ -f "${MODDIR}/boot-completed.sh" ]; then
        sh "${MODDIR}/boot-completed.sh"
    fi
) &

exit 0
