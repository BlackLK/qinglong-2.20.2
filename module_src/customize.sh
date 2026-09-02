#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 模块刷入安装脚本 (customize.sh)
# 功能：兼容 Magisk / KernelSU / SukiSU Ultra，执行环境检查、分段解压、文件部署与初始化
# 特性：SKIPUNZIP 分段解压 + 实时进度日志 + 报错日志位置指引 + 磁盘占用报告
# 安全原则：刷入过程绝不启动青龙服务，默认开机自启关闭 (AUTOSTART=0)
# ==============================================================================

# 本脚本接管解压流程 (管理器不再静默解压), 以实现分阶段进度日志
SKIPUNZIP=1

type ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }

type set_perm >/dev/null 2>&1 || set_perm() {
    local target="$1"
    local uid="$2"
    local gid="$3"
    local mod="$4"
    chown "${uid}:${gid}" "$target" 2>/dev/null
    chmod "$mod" "$target" 2>/dev/null
}

type set_perm_recursive >/dev/null 2>&1 || set_perm_recursive() {
    local dir="$1"
    local uid="$2"
    local gid="$3"
    local dmod="$4"
    local fmod="$5"
    chown -R "${uid}:${gid}" "$dir" 2>/dev/null
    find "$dir" -type d -exec chmod "$dmod" {} + 2>/dev/null
    find "$dir" -type f -exec chmod "$fmod" {} + 2>/dev/null
}

# ----------------- 安装日志持久化 -----------------
# 安装过程的全部输出同步写入日志文件，安装失败时可按此路径排查
INSTALL_LOG="/data/adb/qinglong-data/logs/install.log"
mkdir -p /data/adb/qinglong-data/logs 2>/dev/null
: > "$INSTALL_LOG" 2>/dev/null
logp() {
    ui_print "$1"
    echo "[$(date '+%H:%M:%S')] $1" >> "$INSTALL_LOG" 2>/dev/null
}

# 报错兜底: 无论脚本在哪一步异常中断, 都保证用户知道日志位置
install_exit_hint() {
    _rc=$?
    [ "$_rc" -ne 0 ] || return 0
    ui_print " "
    ui_print "!! 安装已异常中断 (错误码 $_rc)"
    ui_print "!! 完整安装日志: /data/adb/qinglong-data/logs/install.log"
    ui_print "!! 查看命令: su -c 'cat /data/adb/qinglong-data/logs/install.log'"
}
trap install_exit_hint EXIT

logp "========================================"
logp "       QingLong 青龙面板 Android 模块   "
logp "========================================"
logp "模块版本   : v1.0.20 (QL 2.20.2)"
logp "构建特征   : 分段解压进度 + 实时提取日志 + 报错日志指引 + 安装占用报告"
logp "安装日志   : ${INSTALL_LOG}"
logp "(如安装报错, 可在该文件中查看完整记录)"

# ----------------- [0/7] 兼容性声明与管理器识别 -----------------
logp "[0/7] 兼容性声明"
logp "--------------------------------------------------"
logp "本模块目前只在以下环境完成完整测试:"
logp "  Root 管理器 : SukiSU Ultra"
logp "  测试设备    : 联想 Y700 四代平板"
logp ""
logp "其他 Root 管理器适配情况:"
if [ "$KSU" = "true" ]; then
    logp "  当前检测到: KernelSU 系管理器 (含 SukiSU)"
elif [ -n "$MAGISK_VER" ]; then
    logp "  当前检测到: Magisk ($MAGISK_VER)"
    logp "  注意: Magisk 官方 App 没有模块[执行]按钮,"
    logp "  需通过开机自启或终端命令管理面板!"
else
    logp "  当前未识别出管理器类型"
fi
logp "  - KernelSU     : 理论兼容,未经实机验证"
logp "  - Magisk App   : 无法使用执行按钮,未经实机验证"
logp "--------------------------------------------------"

# ----------------- [1/7] 检查设备架构与环境 -----------------
logp "[1/7] 正在检测设备环境..."
ARCH=$(getprop ro.product.cpu.abi 2>/dev/null)
ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null)

logp "- Android 版本: ${ANDROID_VER:-未知}"
logp "- 设备 ABI 架构: ${ARCH:-未知}"

case "$ARCH" in
    *arm64*|*aarch64*)
        logp "[OK] CPU 架构校验通过 (ARM64)"
        ;;
    *)
        logp "[WARN] 检测到非 arm64 架构，可能存在二进制兼容风险。"
        ;;
esac

# ----------------- [2/7] 检查存储空间 -----------------
logp "[2/7] 检查存储空间..."
FREE_SPACE_KB=$(df /data 2>/dev/null | tail -n 1 | awk '{print $(NF-2)}')
if [ -n "$FREE_SPACE_KB" ] && [ "$FREE_SPACE_KB" -lt 307200 ]; then
    logp "[ERROR] /data 分区可用空间不足 300MB，安装终止！"
    logp "[ERROR] 完整安装日志: /data/adb/qinglong-data/logs/install.log"
    exit 1
fi
logp "[OK] 存储空间充足"

# ----------------- [3/7] 部署目标安装目录 -----------------
logp "[3/7] 初始化安装目录结构..."
QL_ROOT="/data/adb/qinglong"
QL_VERSIONS="${QL_ROOT}/versions/2.20.2"
QL_RUNTIME="${QL_ROOT}/runtime"
QL_DATA_ROOT="/data/adb/qinglong-data"

mkdir -p "$QL_VERSIONS" "$QL_RUNTIME/bin" "$QL_RUNTIME/lib" "$QL_ROOT/cache"
mkdir -p "$QL_DATA_ROOT/scripts" "$QL_DATA_ROOT/config" "$QL_DATA_ROOT/database" "$QL_DATA_ROOT/logs" "$QL_DATA_ROOT/backups" "$QL_DATA_ROOT/run"
logp "[OK] 目录结构初始化完成"

# ----------------- [4/7] 分段解压模块文件 (实时进度) -----------------
# 本模块安装包约 180MB, 解压后约 515MB / 3.2万个小文件。
# 通过 SKIPUNZIP=1 接管解压, 分 4 个阶段提取, 每阶段打印内容、体量与实时进度。
PROGRESS_PID=""
pstart() { # $1=监视目录 $2=预计总量(MB)
    ( _n=0
      while [ "$_n" -lt 90 ]; do
          sleep 8
          _n=$((_n + 1))
          _cur=$(du -sk "$1" 2>/dev/null | awk '{print $1}')
          [ -n "$_cur" ] || continue
          _mb=$((_cur / 1024))
          [ "$_mb" -ge "$2" ] && break
          logp "        ... 已解压约 ${_mb}MB / ${2}MB"
      done ) &
    PROGRESS_PID=$!
}
pstop() {
    if [ -n "$PROGRESS_PID" ]; then
        kill "$PROGRESS_PID" 2>/dev/null
        wait "$PROGRESS_PID" 2>/dev/null
        PROGRESS_PID=""
    fi
}
UZ_T0=$(date +%s)
UZ_T_ALL=$UZ_T0
uz_ok() { logp "  [OK] $1 完成 (耗时 $(( $(date +%s) - UZ_T0 ))s)"; }

logp "[4/7] 开始分段解压模块文件 (全程约 2-4 分钟, 请勿退出安装页!)"

# 阶段 1/4: 模块脚本与管理器 (秒级)
UZ_T0=$(date +%s)
unzip -oq "$ZIPFILE" 'module.prop' 'customize.sh' 'action.sh' \
    'action.1_start-qinglong.sh' 'action.2_stop-qinglong.sh' 'action.3_toggle-autostart.sh' \
    'service.sh' 'boot-completed.sh' 'uninstall.sh' 'manager/*' -d "$MODPATH" 2>/dev/null
if [ $? -ne 0 ]; then
    logp "[ERROR] 模块脚本解压失败! 完整日志: ${INSTALL_LOG}"
    exit 2
fi
uz_ok "[1/4] 模块脚本与管理器 (10 个文件)"

# 阶段 2/4: 青龙程序框架 (前端页面 + 后端编译产物 + 示例脚本, 约30MB)
UZ_T0=$(date +%s)
logp "  正在解压 [2/4] 青龙程序框架 (前端+后端+脚本, 约30MB)..."
pstart "$MODPATH/payload/ql" 29
unzip -oq "$ZIPFILE" \
    'payload/ql/static/*' 'payload/ql/back/*' 'payload/ql/sample/*' \
    'payload/ql/shell/*' 'payload/ql/docker/*' 'payload/ql/src/*' \
    'payload/ql/.env*' \
    'payload/ql/package.json' 'payload/ql/pnpm-lock.yaml' \
    'payload/ql/ecosystem.config.js' 'payload/ql/version.yaml' \
    'payload/ql/README.md' 'payload/ql/LICENSE' 'payload/ql/tsconfig.json' \
    'payload/ql/nodemon.json' 'payload/ql/typings.d.ts' -d "$MODPATH" 2>/dev/null
UZ_RC=$?
pstop
if [ "$UZ_RC" -ne 0 ]; then
    logp "[ERROR] 青龙程序框架解压失败 (错误码 $UZ_RC)! 完整日志: ${INSTALL_LOG}"
    exit 2
fi
uz_ok "[2/4] 青龙程序框架 (833 个文件)"

# 阶段 3/4: NodeJS 依赖库 (最耗时的一步, 约217MB / 2.9万个小文件)
UZ_T0=$(date +%s)
logp "  正在解压 [3/4] NodeJS 依赖库 (2.9万个小文件, 约217MB)..."
logp "  >> 这是耗时最长的一步, 约 1-2 分钟, 进度持续刷新 <<"
pstart "$MODPATH/payload/ql/node_modules" 217
unzip -oq "$ZIPFILE" 'payload/ql/node_modules/*' -d "$MODPATH" 2>/dev/null
UZ_RC=$?
pstop
if [ "$UZ_RC" -ne 0 ]; then
    logp "[ERROR] NodeJS 依赖库解压失败 (错误码 $UZ_RC)! 完整日志: ${INSTALL_LOG}"
    exit 2
fi
uz_ok "[3/4] NodeJS 依赖库 (29036 个文件)"

# 阶段 4/4: 运行时环境 (Node.js/Python3/bash/glibc 动态库, 约241MB)
UZ_T0=$(date +%s)
logp "  正在解压 [4/4] 运行时环境 (Node/Python/bash/glibc, 约241MB)..."
pstart "$MODPATH/payload/runtime" 241
unzip -oq "$ZIPFILE" 'payload/runtime/*' -d "$MODPATH" 2>/dev/null
UZ_RC=$?
pstop
if [ "$UZ_RC" -ne 0 ]; then
    logp "[ERROR] 运行时环境解压失败 (错误码 $UZ_RC)! 完整日志: ${INSTALL_LOG}"
    exit 2
fi
uz_ok "[4/4] 运行时环境 (2059 个文件)"

logp "[OK] 分段解压全部完成, 总耗时 $(( $(date +%s) - UZ_T_ALL ))s"

# ----------------- [5/7] 部署文件到工作目录 -----------------
logp "[5/7] 部署文件到工作目录 /data/adb/qinglong (复制约 470MB, 约 1-2 分钟)"

# 5.0 清理旧版本程序残留（关键修复）
# 背景: 升级刷入时旧版残留的 node_modules 会让 cp -af 嵌套复制成
# node_modules/node_modules, 旧树缺失 object-assign 等传递依赖, 启动报
# Cannot find module。versions/2.20.2 是纯程序目录(用户数据在
# qinglong-data, 经软链接挂载, 不受影响), 整目录清理最彻底。
logp "[5.0/7] 清理旧版本程序残留 (仅程序目录, 用户数据不受影响)..."
UZ_T0=$(date +%s)
rm -rf "$QL_VERSIONS"
logp "   [OK] 旧程序目录已清理 (耗时 $(( $(date +%s) - UZ_T0 ))s)"

# 5.1 青龙核心程序（源码编译产物 + 前端）
logp "[5.1/7] 部署青龙核心程序 (~30MB)..."
UZ_T0=$(date +%s)
# [关键修复] Android toybox cp 语义: `cp -af src 已存在的dst/` 会把 src 的
# 内容展开到 dst 根下, 导致 static/build/app_single.js 落到 2.20.2/build/
# 层级错位。必须先创建目标子目录, 再用 /. 复制内容, 两端语义一致。
for d in static back sample shell docker src; do
    if [ -d "$MODPATH/payload/ql/$d" ]; then
        mkdir -p "$QL_VERSIONS/$d"
        cp -af "$MODPATH/payload/ql/$d/." "$QL_VERSIONS/$d/"
    fi
done
for f in package.json pnpm-lock.yaml ecosystem.config.js version.yaml README.md LICENSE typings.d.ts tsconfig.json nodemon.json; do
    [ -f "$MODPATH/payload/ql/$f" ] && cp -af "$MODPATH/payload/ql/$f" "$QL_VERSIONS/" 2>/dev/null
done
# [关键修复] .env 是启动硬需求(config/index.js 缺失即抛错), 必须就位:
# 优先包内自带 .env, 缺失时从 .env.example 兜底生成
if [ -f "$MODPATH/payload/ql/.env" ]; then
    cp -af "$MODPATH/payload/ql/.env" "$QL_VERSIONS/.env"
elif [ -f "$MODPATH/payload/ql/.env.example" ]; then
    cp -af "$MODPATH/payload/ql/.env.example" "$QL_VERSIONS/.env"
fi
[ -f "$QL_VERSIONS/.env" ] && logp "   [OK] .env 配置文件就位" || logp "   [WARN] .env 缺失, 面板可能无法启动!"
logp "   [OK] 核心程序部署完成 (耗时 $(( $(date +%s) - UZ_T0 ))s)"

# 5.2 NodeJS 依赖库（最大的部分）
logp "[5.2/7] 部署 NodeJS 依赖库 (~220MB, 2.9万个小文件)..."
UZ_T0=$(date +%s)
pstart "$QL_VERSIONS/node_modules" 220
cp -af "$MODPATH/payload/ql/node_modules" "$QL_VERSIONS/node_modules"
pstop
logp "   [OK] NodeJS 依赖库部署完成 (耗时 $(( $(date +%s) - UZ_T0 ))s)"

# 5.3 运行时环境（Node/Python/bash 工具链）
logp "[5.3/7] 部署运行时环境 (~245MB: Node/Python/bash/DNS修复)..."
UZ_T0=$(date +%s)
if [ -d "$MODPATH/payload/runtime/bin" ]; then
    cp -af "$MODPATH/payload/runtime/bin" "$QL_RUNTIME/bin_tmp" && rm -rf "$QL_RUNTIME/bin" && mv "$QL_RUNTIME/bin_tmp" "$QL_RUNTIME/bin"
    logp "   [OK] 命令行工具与加载器就绪"
fi
if [ -d "$MODPATH/payload/runtime/lib" ]; then
    logp "        正在释放动态链接库，请稍候..."
    cp -af "$MODPATH/payload/runtime/lib/." "$QL_RUNTIME/lib/"
    logp "   [OK] 动态链接库就绪"
fi
[ -d "$MODPATH/payload/runtime/etc" ] && cp -af "$MODPATH/payload/runtime/etc" "$QL_RUNTIME/etc"
logp "   [OK] 运行时环境部署完成 (耗时 $(( $(date +%s) - UZ_T0 ))s)"
logp "[OK] 运行时环境部署完成"

# 修复动态链接库符号链接
cd "${QL_RUNTIME}/lib" 2>/dev/null
for f in *.so.*; do
    if [ -f "$f" ] && [ ! -s "$f" ]; then
        target=$(ls ${f}.* 2>/dev/null | head -n 1)
        if [ -n "$target" ] && [ -s "$target" ]; then
            ln -sf "$target" "$f" 2>/dev/null
        fi
    fi
done
[ -s "libstdc++.so.6.0.30" ] && ln -sf "libstdc++.so.6.0.30" "libstdc++.so.6" 2>/dev/null
[ -s "libgcc_s.so.1" ] && ln -sf "libgcc_s.so.1" "libgcc_s.so" 2>/dev/null

# 创建 current 符号链接指向 2.20.2
ln -sfn "$QL_VERSIONS" "${QL_ROOT}/current"

# 将 data 目录软链接到独立的用户数据目录（必须先删除现有目录再创建软链接）
if [ -d "${QL_ROOT}/current/data" ] && [ ! -L "${QL_ROOT}/current/data" ]; then
    rm -rf "${QL_ROOT}/current/data"
fi
ln -sfn "$QL_DATA_ROOT" "${QL_ROOT}/current/data"

# [关键修复] Android 端再次实体化 pnpm 假软链接文本文件（zip解压跨平台/编码原因可能残留）
logp "[5.4/7] 正在校验 pnpm 依赖（实体化虚拟软链接）..."
NM_DIR="${QL_VERSIONS}/node_modules"
FIXED_COUNT=0
if [ -d "$NM_DIR" ]; then
    # 收集所有假软链接候选：小尺寸的文本文件（内容可能是 ../../xxx/.pnpm/xxx 这种路径）
    TMP_LIST_FILE="${QL_ROOT}/cache/_pnpm_fix_list.txt"
    find "$NM_DIR" -type f -size -200c 2>/dev/null > "$TMP_LIST_FILE" 2>/dev/null

    while IFS= read -r full_path; do
        [ -z "$full_path" ] && continue
        [ ! -f "$full_path" ] && continue
        content=$(cat "$full_path" 2>/dev/null | head -n 1 | tr -d '\r\n\t ')
        # 只处理典型 pnpm 软链接格式：以 .pnpm/ 或 ../ 开头（相对路径）
        case "$content" in
            .pnpm/*|../*|./*)
                target_norm=$(cd "$(dirname "$full_path")" 2>/dev/null && cd "$(dirname "$content")" 2>/dev/null && pwd)/$(basename "$content")
                [ ! -e "$target_norm" ] && target_norm=""
                if [ -z "$target_norm" ]; then
                    # try another way: normalize
                    parent_dir="$(dirname "$full_path")"
                    # 把 content 路径拼接在 parent_dir 后再规范化
                    candidate="${parent_dir}/${content}"
                    # 用 cd 去 ../
                    target_norm=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd)/$(basename "$candidate")
                    [ ! -e "$target_norm" ] && target_norm=""
                fi
                if [ -n "$target_norm" ] && [ -e "$target_norm" ]; then
                    rm -f "$full_path"
                    if [ -d "$target_norm" ]; then
                        cp -af "$target_norm/." "$full_path/" 2>/dev/null || cp -af "$target_norm" "$full_path" 2>/dev/null
                    else
                        cp -af "$target_norm" "$full_path" 2>/dev/null
                    fi
                    FIXED_COUNT=$((FIXED_COUNT + 1))
                fi
                ;;
        esac
    done < "$TMP_LIST_FILE"
    rm -f "$TMP_LIST_FILE" 2>/dev/null
fi
logp "[OK] 已二次修复 pnpm 软链接: ${FIXED_COUNT} 个（解决 invalid ELF header / SyntaxError 问题）"

logp "[OK] 青龙 2.20.2 程序与运行环境就绪"

# ----------------- [6/7] 安全配置与权限（分步，跳过大目录） -----------------
# 性能说明: 依赖库有约 3 万个小文件, 逐文件 chmod 需数分钟;
# 这些文件由 root 进程读取, 权限不影响功能, 因此跳过深层遍历。
logp "[6/7] 配置安全状态与权限..."

logp "[6.1/7] 写入安全配置 (强制不自启)..."
# 每次刷入都强制重置为不自启: 保留旧数据但清掉旧的自启状态,
# 刷完重启后面板保持停止, 需用户手动点「执行」启动 (启动时再开自启)
echo "0" > "${QL_DATA_ROOT}/config/autostart.conf"
rm -f "${QL_DATA_ROOT}/run/qinglong.pid" 2>/dev/null
logp "[OK] 开机自启状态: [OFF] 已强制重置为关闭"

logp "[6.2/7] 配置根目录管理脚本权限..."
for f in action.sh service.sh boot-completed.sh uninstall.sh customize.sh module.prop; do
    [ -f "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755
done
logp "   [OK] 完成"

if [ -d "$MODPATH/manager" ]; then
    logp "[6.3/7] 配置 manager 管理脚本权限..."
    chmod -R 0755 "$MODPATH/manager" 2>/dev/null
    logp "   [OK] 完成"
fi

if [ -d "$QL_RUNTIME/bin" ]; then
    logp "[6.4/7] 配置运行时命令可执行位 (bash/node/python/curl 等)..."
    chmod 0755 "$QL_RUNTIME/bin/"* 2>/dev/null
    logp "   [OK] 完成"
fi

# 仅处理数据目录顶层, 不递归遍历深层依赖文件 (避免数分钟级卡顿)
logp "[6.5/7] 数据目录权限 (仅顶层, 不遍历深层文件)..."
find "$QL_DATA_ROOT" -maxdepth 1 -exec chmod 0777 {} + 2>/dev/null
logp "[OK] 全部权限配置完成"

# ----------------- [7/7] 校验、清理与占用报告 -----------------
logp "[7/7] 校验安装完整性..."
VERIFY_OK=1
for f in "${QL_VERSIONS}/static/build/app_single.js" \
         "${QL_VERSIONS}/node_modules" \
         "${QL_RUNTIME}/bin/node.real" \
         "${QL_RUNTIME}/bin/bash.real" \
         "${QL_RUNTIME}/bin/python3.11.real"; do
    if [ -e "$f" ]; then
        logp "   [OK] $(basename "$f")"
    else
        logp "   [MISSING] $f"
        VERIFY_OK=0
    fi
done
if [ "$VERIFY_OK" != "1" ]; then
    logp "[ERROR] 存在缺失文件, 安装中止! 请重新刷入;"
    logp "[ERROR] 若反复刷入仍缺失, 请查看完整安装日志排查:"
    logp "[ERROR] ${INSTALL_LOG}"
    exit 3
fi
logp "[OK] 所有关键文件就位"

# 清理模块内的冗余程序副本: payload 已完整部署到 /data/adb/qinglong,
# 删除模块内副本可释放约 500MB 空间, 并显著加快管理器随后的权限配置阶段。
logp "[7.5/7] 清理模块内冗余副本 (约500MB / 3.2万个小文件, 约需30秒-1分钟)..."
rm -rf "$MODPATH/payload" 2>/dev/null
logp "[OK] 已自动清理模块内冗余副本, 释放约 500MB 空间"

# 安装后磁盘占用报告 (逐项统计, 每项打印进度, 避免看起来卡住)
logp "[7.6/7] 统计磁盘占用 (文件数量大, 每项约需10-30秒)..."
human_kb() {
    awk -v k="$1" 'BEGIN{
        if (k+0<=0)         printf "0 KB";
        else if (k<1024)    printf "%d KB", k;
        else if (k<1048576) printf "%.1f MB", k/1024;
        else                printf "%.2f GB", k/1048576;
    }'
}
dsk() {
    [ -e "$1" ] || { echo 0; return; }
    du -sk "$1" 2>/dev/null | awk '{print $1}'
}
logp "  正在统计: 程序本体+前端..."
KB_CORE=$(dsk "${QL_VERSIONS}/static")
logp "  正在统计: NodeJS 依赖库 (最慢项, 约2.9万个文件)..."
KB_NM=$(dsk "${QL_VERSIONS}/node_modules")
logp "  正在统计: 运行时环境..."
KB_RT=$(dsk "$QL_RUNTIME")
logp "  正在统计: 用户数据目录..."
KB_DATA=$(dsk "$QL_DATA_ROOT")
TOTAL=$((KB_CORE + KB_NM + KB_RT + KB_DATA))
logp "--------------------------------------------------"
logp "[ 磁盘占用报告 ]"
logp "  程序本体+前端      $(human_kb $KB_CORE)"
logp "  NodeJS 依赖库      $(human_kb $KB_NM)"
logp "  运行时(Node/Py等)  $(human_kb $KB_RT)"
logp "  用户数据目录       $(human_kb $KB_DATA)"
logp "  模块内冗余副本     已自动清理"
logp "  合计               $(human_kb $TOTAL)"
logp "--------------------------------------------------"
logp "说明: 内存(CPU/RAM)占用在运行中才有意义,"
logp "启动面板时会自动打印实时资源报告。"

logp "========================================"
logp "          青龙模块 刷入成功！           "
logp "========================================"
logp "青龙版本   : 2.20.2"
logp "当前状态   : STOPPED (已停止)"
logp "开机自启   : OFF (已关闭)"
logp ""
logp "--------------------------------------------------"
logp "模块制作者 : stuka"
logp "青龙面板   : https://github.com/whyour/qinglong"
logp "本模块项目 : https://github.com/BlackLK/qinglong-2.20.2"
logp "--------------------------------------------------"
logp ""
logp "⚠️ 安全设计提示："
logp "本模块遵循安全设计原则，刷入后【不会】自动启动青龙。"
logp "请在手机重启完成后，进入 Root 管理器中的："
logp "「QingLong 青龙面板 -> 执行/Action」手动启动服务。"
logp "(启动的同时会自动开启开机自启与资源报告)"
logp "========================================"
logp "📋 日志位置 (排查报错用):"
logp "  安装日志: /data/adb/qinglong-data/logs/install.log"
logp "  启动日志: /data/adb/qinglong-data/logs/start.log"
logp "  (若点击「执行」后面板未启动成功, 查看启动日志)"
logp "  查看命令: su -c \"tail -n 50 <日志路径>\""
logp "========================================"
