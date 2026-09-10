#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 启动管理脚本 (start.sh)
# ==============================================================================

[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
MANAGER_DIR="${MODDIR}/manager"
. "${MANAGER_DIR}/common.sh"
. "${MANAGER_DIR}/status.sh"

log_info "正在启动青龙面板服务..."

if check_qinglong_status; then
    current_pid=$(cat "$PID_FILE" 2>/dev/null)
    log_warn "青龙面板已在运行中 (PID: ${current_pid})，无需重复启动！"
    exit 0
fi

if ! acquire_lock "start"; then
    exit 1
fi
trap 'release_lock' EXIT INT TERM

if [ ! -d "$QL_CURRENT" ]; then
    log_error "未找到青龙当前版本目录: ${QL_CURRENT}"
    exit 1
fi

# 确保动态库与链接器执行权限
chmod 0755 "${QL_RUNTIME}/lib/ld-linux-aarch64.so.1" 2>/dev/null
chmod 0755 "${QL_RUNTIME}/lib/"*.so* 2>/dev/null
chmod 0755 "${QL_RUNTIME}/bin/node.real" 2>/dev/null

NODE_EXEC="${QL_RUNTIME}/lib/ld-linux-aarch64.so.1 --library-path ${QL_RUNTIME}/lib ${QL_RUNTIME}/bin/node.real"

mkdir -p "${QL_USER_SCRIPTS}" "${QL_USER_CONFIG}" "${QL_USER_DB}" "${QL_USER_LOGS}" "${QL_USER_RUN}" "${QL_USER_BACKUPS}" 2>/dev/null

# 启动本地 DNS 转发器（幂等）：
# glibc 程序（python/curl/wget/pip 等）缺失 /etc/resolv.conf 时默认查询 127.0.0.1:53，
# 由 dns_forwarder.js 转发至上游公共 DNS，恢复模块内所有 glibc 二进制的域名解析。
if ! netstat -uln 2>/dev/null | grep -q "127.0.0.1:53"; then
    if [ -f "${QL_RUNTIME}/bin/dns_forwarder.js" ]; then
        nohup $NODE_EXEC "${QL_RUNTIME}/bin/dns_forwarder.js" >> "${QL_USER_LOGS}/dns_forwarder.log" 2>&1 &
    fi
fi

export QL_DIR="${QL_CURRENT}"
export QL_DATA_DIR="${QL_DATA_ROOT}"
# node_modules/.bin 提供 ql/task 命令 (订阅任务 command 以 ql 开头)
export PATH="${QL_RUNTIME}/bin:${QL_CURRENT}/bin:${QL_CURRENT}/node_modules/.bin:${PATH}"
# NODE_PATH 除青龙依赖外，加入 pnpm 全局目录（面板安装的 nodejs 依赖），保证任务可 require
PNPM_GLOBAL_NM="${QL_DATA_ROOT}/.pnpm-home/global/5/node_modules"
[ -d "$PNPM_GLOBAL_NM" ] && export NODE_PATH="${QL_CURRENT}/node_modules:${QL_RUNTIME}/lib/node_modules:${PNPM_GLOBAL_NM}:${NODE_PATH}" || export NODE_PATH="${QL_CURRENT}/node_modules:${QL_RUNTIME}/lib/node_modules:${NODE_PATH}"
export LD_LIBRARY_PATH="${QL_RUNTIME}/lib:${LD_LIBRARY_PATH}"
# git 镜像加速: 读 config/git_mirror.conf (镜像前缀), 通过 url.insteadOf
# 把 github 地址自动重写到镜像 (订阅/任务无需改 URL; 置空配置即停用)
GIT_MIRROR_CONF="${QL_DATA_ROOT}/config/git_mirror.conf"
if [ -s "$GIT_MIRROR_CONF" ]; then
    MIRROR_PREFIX=$(head -n 1 "$GIT_MIRROR_CONF" 2>/dev/null | tr -d " \r\n")
    if [ -n "$MIRROR_PREFIX" ]; then
        export GIT_CONFIG_COUNT=2
        export GIT_CONFIG_KEY_0="url.${MIRROR_PREFIX}https://github.com/.insteadOf"
        export GIT_CONFIG_VALUE_0="https://github.com/"
        export GIT_CONFIG_KEY_1="url.${MIRROR_PREFIX}https://raw.githubusercontent.com/.insteadOf"
        export GIT_CONFIG_VALUE_1="https://raw.githubusercontent.com/"
    fi
fi
export HOME="${QL_DATA_ROOT}"
export LANG="zh_CN.UTF-8"
export LC_ALL="zh_CN.UTF-8"
# Android 无 /etc/ssl/certs：为任务内 curl/wget/python(ssl) 等提供根证书
export SSL_CERT_FILE="${QL_RUNTIME}/etc/ssl/certs/ca-certificates.crt"

# [关键修复] Node 的 os.tmpdir() 默认落 /tmp，Android 无 /tmp 且根分区只读，
# 开机自启路径曾因此 proper-lockfile ENOENT 崩溃（手动路径因环境差异侥幸可用）。
# 统一指向确定可写的缓存目录，保证两条启动路径行为一致。
mkdir -p "${QL_CACHE}/tmp" 2>/dev/null
export TMPDIR="${QL_CACHE}/tmp"
mkdir -p /tmp 2>/dev/null

cd "${QL_CURRENT}" || { log_error "无法进入青龙程序目录"; exit 1; }

START_LOG="${QL_USER_LOGS}/start.log"
echo "==================== 青龙启动记录 $(get_timestamp) ====================" >> "$START_LOG"

# 启动后端服务（按优先级查找正确的启动入口）
# 通过 NODE_OPTIONS 注入 winston 兼容 preload：winston-daily-rotate-file 处于
# .pnpm 隔离目录，其内部 winston 副本无法向顶层实例挂载 transports.DailyRotateFile，
# 导致 logger 报 "DailyRotateFile is not a constructor"。对 app_single 及所有 node
# 子进程（cron 任务）统一注入该挂载。
export NODE_OPTIONS="--require ${QL_CURRENT}/static/build/preload-winston.js"

# 优先使用单进程启动器 app_single.js：
# 原 app.js 采用 cluster 多进程编排，在 Android 经 ld-linux 间接启动 node 时，
# worker 的 IPC 无法建立，net.listen 走 cluster._getServer 分支抛 TypeError 死循环。
# 单进程方案保持 cluster.isPrimary=true，让 node:net 直接本地监听，可稳定启动。
if [ -f "${QL_CURRENT}/static/build/app_single.js" ]; then
    nohup $NODE_EXEC "${QL_CURRENT}/static/build/app_single.js" >> "$START_LOG" 2>&1 &
    QL_NEW_PID=$!
elif [ -f "${QL_CURRENT}/static/build/app.js" ]; then
    nohup $NODE_EXEC "${QL_CURRENT}/static/build/app.js" >> "$START_LOG" 2>&1 &
    QL_NEW_PID=$!
elif [ -f "${QL_CURRENT}/back/app.js" ]; then
    nohup $NODE_EXEC "${QL_CURRENT}/back/app.js" >> "$START_LOG" 2>&1 &
    QL_NEW_PID=$!
elif [ -f "${QL_CURRENT}/app.js" ]; then
    nohup $NODE_EXEC "${QL_CURRENT}/app.js" >> "$START_LOG" 2>&1 &
    QL_NEW_PID=$!
else
    log_error "未找到青龙后端启动入口文件！"
    exit 1
fi

if [ -n "$QL_NEW_PID" ] && kill -0 "$QL_NEW_PID" 2>/dev/null; then
    echo "$QL_NEW_PID" > "$PID_FILE"
    log_ok "青龙服务已在后台成功启动 (PID: ${QL_NEW_PID})"
    log_info "Web 访问地址: http://127.0.0.1:${DEFAULT_QL_PORT} 或 手机IP:${DEFAULT_QL_PORT}"
    rm -f "$FAIL_COUNT_FILE" 2>/dev/null
    exit 0
else
    log_error "青龙服务启动失败，请查看日志: ${START_LOG}"
    rm -f "$PID_FILE" 2>/dev/null
    exit 1
fi
