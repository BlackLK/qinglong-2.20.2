#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 公共函数库 (common.sh)
# 功能：定义路径常量、环境检测、日志输出、敏感信息保护等基础函数
# ==============================================================================

# ----------------- 基础路径定义 -----------------
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"

# 青龙程序本体与运行库主目录
QL_ROOT="/data/adb/qinglong"
QL_VERSIONS="${QL_ROOT}/versions"
QL_CURRENT="${QL_ROOT}/current"
QL_RUNTIME="${QL_ROOT}/runtime"
QL_CACHE="${QL_ROOT}/cache"

# 用户数据独立目录（升级/卸载默认保护）
QL_DATA_ROOT="/data/adb/qinglong-data"
QL_USER_SCRIPTS="${QL_DATA_ROOT}/scripts"
QL_USER_CONFIG="${QL_DATA_ROOT}/config"
QL_USER_DB="${QL_DATA_ROOT}/database"
QL_USER_LOGS="${QL_DATA_ROOT}/logs"
QL_USER_BACKUPS="${QL_DATA_ROOT}/backups"
QL_USER_RUN="${QL_DATA_ROOT}/run"

# 关键运行时控制文件
PID_FILE="${QL_USER_RUN}/qinglong.pid"
LOCK_FILE="${QL_USER_RUN}/operation.lock"
AUTOSTART_FILE="${QL_USER_CONFIG}/autostart.conf"
FAIL_COUNT_FILE="${QL_USER_RUN}/boot_fail.count"

# 默认青龙配置
DEFAULT_QL_PORT=5700
DEFAULT_QL_VERSION="2.20.2"

# ----------------- 日志打印与记录函数 -----------------
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "[Timestamp]"
}

log_info() {
    local msg="$1"
    echo "$(get_timestamp) [INFO] ${msg}"
}

log_ok() {
    local msg="$1"
    echo "$(get_timestamp) [OK] ${msg}"
}

log_warn() {
    local msg="$1"
    echo "$(get_timestamp) [WARN] ${msg}"
}

log_error() {
    local msg="$1"
    echo "$(get_timestamp) [ERROR] ${msg}"
}

# ----------------- Root 环境与设备检测 -----------------
detect_root_manager() {
    if [ -n "$KSU" ] || [ -f "/data/adb/ksu/bin/busybox" ] || [ -d "/data/adb/ksu" ]; then
        echo "KernelSU"
    elif [ -n "$APATCH" ] || [ -f "/data/adb/ap/bin/busybox" ] || [ -d "/data/adb/ap" ]; then
        echo "SukiSU / APatch"
    elif [ -d "/data/adb/magisk" ] || [ -f "/data/adb/magisk/busybox" ]; then
        echo "Magisk"
    else
        echo "通用 Root 环境"
    fi
}

get_device_abi() {
    getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a"
}

get_android_version() {
    getprop ro.build.version.release 2>/dev/null || echo "未知"
}

# ----------------- 并发操作锁控制 -----------------
acquire_lock() {
    local action_name="$1"
    mkdir -p "${QL_USER_RUN}" 2>/dev/null
    if [ -f "$LOCK_FILE" ]; then
        local locked_time
        locked_time=$(cat "$LOCK_FILE" 2>/dev/null)
        log_warn "检测到已有操作正在执行 (锁定时间: ${locked_time:-未知})，请稍后再试！"
        return 1
    fi
    echo "$(get_timestamp) - ${action_name}" > "$LOCK_FILE"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE" 2>/dev/null
}
