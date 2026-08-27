#!/system/bin/sh
# ==============================================================================
# 青龙 Android Root 模块 - Root 管理器 Action 操作菜单 (action.sh)
# 功能：兼容 Magisk / KernelSU / SukiSU Ultra 模块界面的执行入口与交互控制
# ==============================================================================

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/qinglong"
# 导出给子脚本 (manager/start.sh 等) 继承，避免其回退到默认安装路径
export MODDIR
MANAGER_DIR="${MODDIR}/manager"

# 载入公共函数库与状态检测
. "${MANAGER_DIR}/common.sh"
. "${MANAGER_DIR}/status.sh"

show_menu() {
    clear 2>/dev/null
    echo "=================================================="
    echo "          QingLong 青龙面板 管理控制台            "
    echo "=================================================="
    echo "当前版本 : ${DEFAULT_QL_VERSION}"
    echo "运行状态 : $(print_status_summary)"
    
    if [ -f "$AUTOSTART_FILE" ] && [ "$(cat "$AUTOSTART_FILE" 2>/dev/null)" = "1" ]; then
        echo "开机自启 : [ON] 已开启"
    else
        echo "开机自启 : [OFF] 已关闭"
    fi
    echo "--------------------------------------------------"
    echo " 1. 启动青龙面板"
    echo " 2. 停止青龙面板"
    echo " 3. 重启青龙面板"
    echo " 4. 开启开机自启"
    echo " 5. 关闭开机自启"
    echo " 6. 查看详细运行信息"
    echo " 7. 查看存储空间占用"
    echo " 8. 查看最近运行日志"
    echo " 0. 退出管理菜单"
    echo "=================================================="
}

# ---------- 执行操作编号对应的动作 ----------
do_action() {
    local CHOICE="$1"
    case "$CHOICE" in
        1)
            sh "${MANAGER_DIR}/start.sh"
            ;;
        2)
            sh "${MANAGER_DIR}/stop.sh"
            ;;
        3)
            log_info "正在重启青龙面板..."
            sh "${MANAGER_DIR}/stop.sh"
            sleep 1
            sh "${MANAGER_DIR}/start.sh"
            ;;
        4)
            mkdir -p "${QL_USER_CONFIG}" 2>/dev/null
            echo "1" > "$AUTOSTART_FILE"
            log_ok "开机自启已设置为 [ON] 开启。"
            ;;
        5)
            mkdir -p "${QL_USER_CONFIG}" 2>/dev/null
            echo "0" > "$AUTOSTART_FILE"
            log_ok "开机自启已设置为 [OFF] 关闭。"
            ;;
        6)
            sh "${MANAGER_DIR}/info.sh"
            ;;
        7)
            sh "${MANAGER_DIR}/storage.sh"
            ;;
        8)
            echo "================ 最近运行日志 ================"
            if [ -f "${QL_USER_LOGS}/start.log" ]; then
                tail -n 20 "${QL_USER_LOGS}/start.log" 2>/dev/null
            else
                echo "暂无运行日志。"
            fi
            echo "=============================================="
            ;;
        0|q|Q)
            echo "已退出管理菜单。"
            return 0
            ;;
        *)
            log_warn "无效的输入编号，请重新选择！"
            return 1
            ;;
    esac
    return 2
}

# ---------- 处理直接传入参数的情况 ----------
ACTION="$1"
if [ -n "$ACTION" ]; then
    case "$ACTION" in
        start)   ACTION_NUM="1" ;;
        stop)    ACTION_NUM="2" ;;
        restart) ACTION_NUM="3" ;;
        auto_on) ACTION_NUM="4" ;;
        auto_off) ACTION_NUM="5" ;;
        info|status) ACTION_NUM="6" ;;
        storage) ACTION_NUM="7" ;;
        log|logs) ACTION_NUM="8" ;;
        exit|quit|0) ACTION_NUM="0" ;;
        [0-8])  ACTION_NUM="$ACTION" ;;
    esac
    if [ -n "$ACTION_NUM" ]; then
        do_action "$ACTION_NUM"
        exit $?
    else
        log_warn "未知的参数: ${ACTION}，可用参数: start|stop|restart|auto_on|auto_off|info|storage|logs|0-8"
    fi
fi

# ---------- 检测是否为交互式环境（是否有 TTY） ----------
IS_INTERACTIVE=0
if [ -t 0 ] && [ -t 1 ]; then
    IS_INTERACTIVE=1
fi

# ---------- 非交互式环境（Root 管理器"执行"按钮）----------
# 单按钮智能切换：
#   面板停止中 → 开启开机自启 + 启动面板 + 输出资源报告
#   面板运行中 → 停止面板 + 关闭开机自启
if [ "$IS_INTERACTIVE" -ne 1 ]; then
    if check_qinglong_status; then
        echo "=========================================="
        echo " 青龙面板运行中 -> 本次动作: [停止]"
        echo "=========================================="
        # 1. 关闭开机自启
        do_action "5"
        # 2. 停止面板
        do_action "2"
        echo ""
        echo "下次点击「执行」将重新启动面板并开启自启"
        echo "模块作者: stuka | 项目: github.com/BlackLK/qinglong-2.20.2"
    else
        echo "=========================================="
        echo " 青龙面板未运行 -> 本次动作: [启动]"
        echo "=========================================="
        # 1. 开启开机自启
        mkdir -p "${QL_USER_CONFIG}" 2>/dev/null
        echo "1" > "$AUTOSTART_FILE"
        log_ok "[OK] 开机自启已开启"
        # 2. 启动面板
        sh "${MANAGER_DIR}/start.sh"
        # 3. 等待服务就绪 (最多约 40 秒): netstat 端口监听为准, HTTP 探测兜底
        CURL_BIN="${QL_RUNTIME}/bin/curl"
        READY=0
        i=0
        while [ "$i" -lt 20 ]; do
            if netstat -tln 2>/dev/null | grep -q ':5700.*LISTEN'; then
                READY=1
                break
            fi
            if [ -x "$CURL_BIN" ]; then
                CODE=$("$CURL_BIN" -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:5700/ 2>/dev/null)
                [ "$CODE" = "200" ] && { READY=1; break; }
            fi
            sleep 2
            i=$((i + 1))
        done
        if [ "$READY" = "1" ]; then
            log_ok "[OK] Web 服务就绪 (端口 5700 监听中)"
        else
            log_warn "[WARN] 端口未就绪，请稍后查看日志"
        fi
        # 4. 输出资源综合报告
        sh "${MANAGER_DIR}/report.sh"
        echo ""
        echo "再次点击「执行」即可停止面板并关闭自启"
        echo "--------------------------------------------------"
        echo "模块制作者 : stuka"
        echo "青龙面板   : https://github.com/whyour/qinglong"
        echo "本模块项目 : https://github.com/BlackLK/qinglong-2.20.2"
        echo "--------------------------------------------------"
    fi
    exit 0
fi

# 交互式菜单主循环
while true; do
    show_menu
    printf "请输入操作编号 [0-8]: "
    if ! read -r CHOICE; then
        echo ""
        echo "检测到输入结束 (EOF)，退出管理菜单。"
        exit 0
    fi

    echo ""
    do_action "$CHOICE"
    ACTION_RC=$?
    if [ "$ACTION_RC" -eq 0 ]; then
        exit 0
    fi

    echo ""
    printf "按回车键返回主菜单..."
    if ! read -r _; then
        echo ""
        exit 0
    fi
done
