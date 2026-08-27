#!/system/bin/sh
# ==============================================================================
# 全局递归修复 pnpm 软链接脚本 (深度递归所有 .pnpm 虚拟目录)
# ==============================================================================

NM_DIR="/data/adb/qinglong/versions/2.20.2/node_modules"
cd "$NM_DIR" || exit 1

count=0
# 递归查找 node_modules 下所有小于 300 字节的文件
find "$NM_DIR" -type f -size -300c | while read -r f; do
    target=$(cat "$f" 2>/dev/null)
    case "$target" in
        .*/*)
            dir=$(dirname "$f")
            base=$(basename "$f")
            rm -f "$f"
            (cd "$dir" && ln -sf "$target" "$base")
            count=$((count + 1))
            ;;
    esac
done

echo "[OK] 全局递归修复完成！"
