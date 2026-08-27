#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - 模块刷入安装脚本 (customize.sh)
# 功能：兼容 Magisk / KernelSU / SukiSU Ultra，执行环境检查、文件部署与初始化
# 安全原则：刷入过程绝不启动青龙服务，默认开机自启关闭 (AUTOSTART=0)
# ==============================================================================

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

ui_print "========================================"
ui_print "       QingLong 青龙面板 Android 模块   "
ui_print "========================================"
ui_print "模块版本   : v1.0.13 (QL 2.20.2)"
ui_print "构建特征   : 含安装占用报告 + 分段部署日志"

# ----------------- [0/7] 兼容性声明与管理器识别 -----------------
ui_print "[0/7] 兼容性声明"
ui_print "--------------------------------------------------"
ui_print "本模块目前只在以下环境完成完整测试:"
ui_print "  Root 管理器 : SukiSU Ultra"
ui_print "  测试设备    : 联想 Y700 四代平板"
ui_print ""
ui_print "其他 Root 管理器适配情况:"
if [ "$KSU" = "true" ]; then
    ui_print "  当前检测到: KernelSU 系管理器 (含 SukiSU)"
elif [ -n "$MAGISK_VER" ]; then
    ui_print "  当前检测到: Magisk ($MAGISK_VER)"
    ui_print "  注意: Magisk 官方 App 没有模块[执行]按钮,"
    ui_print "  需通过开机自启或终端命令管理面板!"
else
    ui_print "  当前未识别出管理器类型"
fi
ui_print "  - KernelSU     : 理论兼容,未经实机验证"
ui_print "  - Magisk App   : 无法使用执行按钮,未经实机验证"
ui_print "--------------------------------------------------"
ui_print ""
ui_print "提示: 如果上方 'Extracting module files' 阶段"
ui_print "停留了 1-3 分钟,属于正常现象!"
ui_print "本模块安装包约 175MB (含 NodeJS 全量依赖库),"
ui_print "解压耗时与设备闪存性能相关,请耐心等待。"

# ----------------- [1/7] 检查设备架构与环境 -----------------
ui_print "[1/7] 正在检测设备环境..."
ARCH=$(getprop ro.product.cpu.abi 2>/dev/null)
ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null)

ui_print "- Android 版本: ${ANDROID_VER:-未知}"
ui_print "- 设备 ABI 架构: ${ARCH:-未知}"

case "$ARCH" in
    *arm64*|*aarch64*)
        ui_print "[OK] CPU 架构校验通过 (ARM64)"
        ;;
    *)
        ui_print "[WARN] 检测到非 arm64 架构，可能存在二进制兼容风险。"
        ;;
esac

# ----------------- [2/7] 检查存储空间 -----------------
ui_print "[2/7] 检查存储空间..."
FREE_SPACE_KB=$(df /data 2>/dev/null | tail -n 1 | awk '{print $(NF-2)}')
if [ -n "$FREE_SPACE_KB" ] && [ "$FREE_SPACE_KB" -lt 307200 ]; then
    ui_print "[ERROR] /data 分区可用空间不足 300MB，安装终止！"
    exit 1
fi
ui_print "[OK] 存储空间充足"

# ----------------- [3/7] 部署目标安装目录 -----------------
ui_print "[3/7] 初始化安装目录结构..."
QL_ROOT="/data/adb/qinglong"
QL_VERSIONS="${QL_ROOT}/versions/2.20.2"
QL_RUNTIME="${QL_ROOT}/runtime"
QL_DATA_ROOT="/data/adb/qinglong-data"

mkdir -p "$QL_VERSIONS" "$QL_RUNTIME/bin" "$QL_RUNTIME/lib" "$QL_ROOT/cache"
mkdir -p "$QL_DATA_ROOT/scripts" "$QL_DATA_ROOT/config" "$QL_DATA_ROOT/database" "$QL_DATA_ROOT/logs" "$QL_DATA_ROOT/backups" "$QL_DATA_ROOT/run"
ui_print "[OK] 目录结构初始化完成"

# ----------------- [4/7] 释放青龙核心程序与运行库（分段进度） -----------------
ui_print "[4.0/7] 开始部署文件 (约175MB，全程1-3分钟)"
ui_print "        请耐心等待，每一步完成都会有提示..."

# 4.1 青龙核心程序（源码编译产物 + 前端）
ui_print "[4.1/7] 部署青龙核心程序 (~35MB)..."
if [ -d "$MODPATH/payload/ql/static" ]; then
    cp -af "$MODPATH/payload/ql/static" "$QL_VERSIONS/" && ui_print "   [OK] 后端服务与前端页面就绪"
fi
for item in back sample shell docker; do
    [ -d "$MODPATH/payload/ql/$item" ] && cp -af "$MODPATH/payload/ql/$item" "$QL_VERSIONS/" 2>/dev/null
done
for f in package.json pnpm-lock.yaml ecosystem.config.js version.yaml README.md LICENSE typings.d.ts tsconfig.json nodemon.json; do
    [ -f "$MODPATH/payload/ql/$f" ] && cp -af "$MODPATH/payload/ql/$f" "$QL_VERSIONS/" 2>/dev/null
done

# 4.2 NodeJS 依赖库（最大的部分）
ui_print "[4.2/7] 部署 NodeJS 依赖库 (~90MB)..."
ui_print "        这是最耗时的一步，请勿锁屏或离开..."
cp -af "$MODPATH/payload/ql/node_modules" "$QL_VERSIONS/node_modules"
ui_print "   [OK] NodeJS 依赖库部署完成"

# 4.3 运行时环境（Node/Python/bash 工具链）
ui_print "[4.3/7] 部署运行时环境 (~45MB: Node/Python/bash/DNS修复)..."
if [ -d "$MODPATH/payload/runtime/bin" ]; then
    cp -af "$MODPATH/payload/runtime/bin" "$QL_RUNTIME/bin_tmp" && rm -rf "$QL_RUNTIME/bin" && mv "$QL_RUNTIME/bin_tmp" "$QL_RUNTIME/bin"
    ui_print "   [OK] 命令行工具与加载器就绪"
fi
if [ -d "$MODPATH/payload/runtime/lib" ]; then
    ui_print "        正在释放动态链接库，请稍候..."
    cp -af "$MODPATH/payload/runtime/lib/." "$QL_RUNTIME/lib/"
    ui_print "   [OK] 动态链接库就绪"
fi
[ -d "$MODPATH/payload/runtime/etc" ] && cp -af "$MODPATH/payload/runtime/etc" "$QL_RUNTIME/etc"
ui_print "[OK] 运行时环境部署完成"

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
ui_print "[4.4/7] 正在校验 pnpm 依赖（实体化虚拟软链接）..."
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
ui_print "[OK] 已二次修复 pnpm 软链接: ${FIXED_COUNT} 个（解决 invalid ELF header / SyntaxError 问题）"

ui_print "[OK] 青龙 2.20.2 程序与运行环境就绪"

# ----------------- [5/7] 初始化默认配置 -----------------
ui_print "[5/7] 写入安全配置 (强制不自启)..."
# 每次刷入都强制重置为不自启: 保留旧数据但清掉旧的自启状态,
# 刷完重启后面板保持停止, 需用户手动点「执行」启动 (启动时再开自启)
echo "0" > "${QL_DATA_ROOT}/config/autostart.conf"
rm -f "${QL_DATA_ROOT}/run/qinglong.pid" 2>/dev/null
ui_print "[OK] 开机自启状态: [OFF] 已强制重置为关闭"

# ----------------- [6/7] 赋予脚本执行权限（分步，跳过大目录） -----------------
# 性能说明: payload 内有约 20+ 万个依赖库文件, 逐文件 chmod 需数分钟;
# 这些文件由 root 进程读取, 权限不影响功能, 因此完全跳过权限遍历。
ui_print "[6.1/7] 配置根目录管理脚本权限..."
for f in action.sh service.sh boot-completed.sh uninstall.sh customize.sh module.prop; do
    [ -f "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755
done
ui_print "   [OK] 完成"

if [ -d "$MODPATH/manager" ]; then
    ui_print "[6.2/7] 配置 manager 管理脚本权限..."
    chmod -R 0755 "$MODPATH/manager" 2>/dev/null
    ui_print "   [OK] 完成"
fi

if [ -d "$QL_RUNTIME/bin" ]; then
    ui_print "[6.3/7] 配置运行时命令可执行位 (bash/node/python/curl 等)..."
    chmod 0755 "$QL_RUNTIME/bin/"* 2>/dev/null
    ui_print "   [OK] 完成"
fi

ui_print "[6.4/7] 数据目录权限 (跳过海量依赖文件, 无需遍历)..."
chmod -R 0777 "$QL_DATA_ROOT" 2>/dev/null
ui_print "[OK] 全部权限配置完成"

# ----------------- [7/7] 安装完成与安全提示 -----------------
ui_print "[7/7] 校验安装完整性..."
VERIFY_OK=1
for f in "${QL_VERSIONS}/static/build/app_single.js" \
         "${QL_VERSIONS}/node_modules" \
         "${QL_RUNTIME}/bin/node.real" \
         "${QL_RUNTIME}/bin/bash.real" \
         "${QL_RUNTIME}/bin/python3.11.real"; do
    if [ -e "$f" ]; then
        ui_print "   [OK] $(basename "$f")"
    else
        ui_print "   [MISSING] $f"
        VERIFY_OK=0
    fi
done
if [ "$VERIFY_OK" = "1" ]; then
    ui_print "[OK] 所有关键文件就位"
else
    ui_print "[WARN] 存在缺失文件, 请重新刷入!"
fi

# ----------------- [7.5/7] 安装后磁盘占用报告 -----------------
ui_print ""
ui_print "[7/7] 统计磁盘占用 (约需数秒)..."
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
KB_CORE=$(dsk "${QL_VERSIONS}/static")
KB_NM=$(dsk "${QL_VERSIONS}/node_modules")
KB_RT=$(dsk "$QL_RUNTIME")
KB_DATA=$(dsk "$QL_DATA_ROOT")
KB_MOD=$(dsk "$MODPATH/payload")
TOTAL=$((KB_CORE + KB_NM + KB_RT + KB_DATA + KB_MOD))
ui_print "--------------------------------------------------"
ui_print "[ 磁盘占用报告 ]"
ui_print "  程序本体+前端      $(human_kb $KB_CORE)"
ui_print "  NodeJS 依赖库      $(human_kb $KB_NM)"
ui_print "  运行时(Node/Py等)  $(human_kb $KB_RT)"
ui_print "  用户数据目录       $(human_kb $KB_DATA)"
ui_print "  模块本体(可删)     $(human_kb $KB_MOD)"
ui_print "  合计               $(human_kb $TOTAL)"
ui_print "--------------------------------------------------"
ui_print "说明: 内存(CPU/RAM)占用在运行中才有意义,"
ui_print "启动面板时会自动打印实时资源报告。"

ui_print "========================================"
ui_print "          青龙模块 刷入成功！           "
ui_print "========================================"
ui_print "青龙版本   : 2.20.2"
ui_print "当前状态   : STOPPED (已停止)"
ui_print "开机自启   : OFF (已关闭)"
ui_print ""
ui_print "--------------------------------------------------"
ui_print "模块制作者 : stuka"
ui_print "青龙面板   : https://github.com/whyour/qinglong"
ui_print "本模块项目 : https://github.com/BlackLK/qinglong-2.20.2"
ui_print "--------------------------------------------------"
ui_print ""
ui_print "⚠️ 安全设计提示："
ui_print "本模块遵循安全设计原则，刷入后【不会】自动启动青龙。"
ui_print "请在手机重启完成后，进入 Root 管理器中的："
ui_print "「QingLong 青龙面板 -> 执行/Action」手动启动服务。"
ui_print "(启动的同时会自动开启开机自启与资源报告)"
ui_print "========================================"
