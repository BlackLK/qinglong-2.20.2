# -*- coding: utf-8 -*-
"""
==============================================================================
青龙 Android Root 模块 - 自动化构建与打包脚本 (build_module.py)
功能：
1. 提取青龙 2.20.2 源码与编译产物 (包含 .git 仓库)
2. 彻底实体化解析 pnpm 虚拟软链接树 (消除跨平台解压导致的假文本软链接)
3. 提取 Node.js ARM64 运行库与 glibc 动态依赖库
4. 强制转换所有 Shell 脚本换行符为 Unix LF
5. 打包输出兼容 Magisk / KernelSU / SukiSU Ultra 的模块 ZIP 刷入包
==============================================================================
"""

import os
import shutil
import zipfile
import glob

def convert_to_unix_lf(file_path):
    with open(file_path, 'rb') as f:
        content = f.read()
    normalized = content.replace(b'\r\n', b'\n')
    with open(file_path, 'wb') as f:
        f.write(normalized)

def resolve_pnpm_tree(nm_dir):
    """递归遍历整个 node_modules 目录，将所有假软链接文本文件彻底替换为实体文件/目录"""
    print("[1.5/4] Resolving and materializing all pnpm virtual dependencies...")
    fixed_count = 0
    for root, dirs, files in os.walk(nm_dir):
        for f in files:
            full_path = os.path.join(root, f)
            if os.path.isfile(full_path) and os.path.getsize(full_path) < 300:
                try:
                    with open(full_path, 'r', encoding='utf-8') as fp:
                        line = fp.read().strip()
                    if line.startswith('.pnpm/') or line.startswith('../') or line.startswith('./'):
                        target_norm = os.path.normpath(os.path.join(root, line.replace('/', os.sep)))
                        if os.path.exists(target_norm):
                            os.remove(full_path)
                            if os.path.isdir(target_norm):
                                shutil.copytree(target_norm, full_path)
                            else:
                                shutil.copy2(target_norm, full_path)
                            fixed_count += 1
                except:
                    pass
    print(f"      [OK] Materialized {fixed_count} pnpm dependency links.")

def materialize_hoisted(nm_dir, names):
    """补齐被 pnpm 提升(hoisted)到顶层 node_modules 但源中缺失的依赖。

    原因：winston-daily-rotate-file 等 via .pnpm 的依赖在运行时要求其提升依赖
    （如 moment）存在于 node_modules/<name>。若源里该顶层软链缺失，运行时报
    `winston.transports.DailyRotateFile is not a constructor`。这里从
    .pnpm/<name>@*/node_modules/<name> 实体化复制到顶层，保证可解析。
    """
    print("[1.5b/4] Materializing hoisted top-level dependencies...")
    for name in names:
        top = os.path.join(nm_dir, name)
        if os.path.exists(top):
            continue
        candidates = sorted(glob.glob(os.path.join(nm_dir, ".pnpm", name + "@*", "node_modules", name)))
        if candidates:
            src = candidates[0]
            if os.path.isdir(src):
                shutil.copytree(src, top)
            else:
                shutil.copy2(src, top)
            print(f"      + materialized hoisted: {name}")
        else:
            print(f"      !! cannot find hoisted src for: {name}")

def build():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    src_dir = os.path.join(base_dir, "module_src")
    payload_dir = os.path.join(src_dir, "payload")
    payload_ql = os.path.join(payload_dir, "ql")
    payload_runtime = os.path.join(payload_dir, "runtime")
    runtime_bin = os.path.join(payload_runtime, "bin")
    runtime_lib = os.path.join(payload_runtime, "lib")
    
    print("==================================================")
    print("       Starting QingLong Android Root Module Build")
    print("==================================================")
    
    os.makedirs(payload_ql, exist_ok=True)
    os.makedirs(runtime_bin, exist_ok=True)
    os.makedirs(runtime_lib, exist_ok=True)

    # 1. 复制青龙 2.20.2
    work_ql_dir = os.path.join(base_dir, "work_extracted", "qinglong-android-work", "ql")
    if os.path.exists(work_ql_dir) and not os.path.exists(os.path.join(payload_ql, "package.json")):
        print("[1/4] Copying QingLong 2.20.2 files (with .git)...")
        for item in os.listdir(work_ql_dir):
            if item in ["__MACOSX", ".DS_Store", "Thumbs.db"]:
                continue
            s = os.path.join(work_ql_dir, item)
            d = os.path.join(payload_ql, item)
            if os.path.isdir(s):
                if os.path.exists(d):
                    shutil.rmtree(d)
                shutil.copytree(s, d, ignore=shutil.ignore_patterns('*.DS_Store', '__MACOSX', 'Thumbs.db'))
            else:
                shutil.copy2(s, d)
        print("      [OK] QingLong payload ready")
    else:
        print("[1/4] QingLong payload ready")

    # 实体化 pnpm 依赖树
    nm_dir = os.path.join(payload_ql, "node_modules")
    resolve_pnpm_tree(nm_dir)
    materialize_hoisted(nm_dir, [
        "moment",            # winston-daily-rotate-file 提升依赖，缺失会致 logger 崩溃
        "vue-tsc", "typescript",  # 工具链，非运行必需但 pnpm 会提升
        "semver", "glob",
    ])

    # 2. 提取 glibc
    rootfs_usr = os.path.join(base_dir, "rootfs_extracted", "qinglong-rootfs", "filesystem", "usr")
    glibc_src = os.path.join(rootfs_usr, "lib", "aarch64-linux-gnu")
    if os.path.exists(glibc_src):
        print("[2/4] Processing glibc runtime libraries...")
        real_files = {}
        for f in os.listdir(glibc_src):
            full = os.path.join(glibc_src, f)
            if os.path.isfile(full) and os.path.getsize(full) > 0:
                real_files[f] = full
        
        for f in os.listdir(glibc_src):
            full = os.path.join(glibc_src, f)
            if os.path.isfile(full):
                dest = os.path.join(runtime_lib, f)
                if os.path.getsize(full) > 0:
                    shutil.copy2(full, dest)
                else:
                    matched = None
                    for rf_name, rf_path in real_files.items():
                        if rf_name.startswith(f + ".") or rf_name.startswith(f.split(".so")[0]):
                            matched = rf_path
                            break
                    if matched:
                        shutil.copy2(matched, dest)
                    elif f == "libstdc++.so.6" and "libstdc++.so.6.0.30" in real_files:
                        shutil.copy2(real_files["libstdc++.so.6.0.30"], dest)
        print("      [OK] All glibc libraries resolved and materialized")

    # 3. 转换脚本 Unix LF
    # 通用规则：无扩展名的 shell wrapper（#! 开头的小文本）与常见脚本/配置一并转换
    print("[3/4] Normalizing scripts to Unix LF...")
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            if file.endswith((".sh", ".prop", ".conf")):
                convert_to_unix_lf(os.path.join(root, file))
                continue
            p = os.path.join(root, file)
            if ("." not in file) and (os.path.isfile(p)) and (os.path.getsize(p) < 4096):
                try:
                    with open(p, "rb") as f:
                        head = f.read(2)
                    if head == b"#!":
                        convert_to_unix_lf(p)
                except Exception:
                    pass
    print("      [OK] Unix LF check passed")

    # 3.5 将青龙 spawn 的 /bin/bash 替换为 runtime 内的 bash-sh 加载器
    # 原因：Android /system/bin 只读，无法放置 /bin/bash；且 bash 依赖 runtime 的 glibc。
    #       bash-sh 通过 ld-linux --library-path 显式加载 bash.real，保证 bash 脚本任务可执行。
    print("[3.5/4] Redirecting /bin/bash to runtime bash-sh loader...")
    bash_holder = "/data/adb/qinglong/runtime/bin/bash-sh"
    replace_count = 0
    for root, dirs, files in os.walk(os.path.join(payload_ql, "static", "build")):
        for file in files:
            if not file.endswith(".js"):
                continue
            p = os.path.join(root, file)
            with open(p, "r", encoding="utf-8-sig") as f:
                content = f.read()
            new_content = content.replace("'/bin/bash'", f"'{bash_holder}'").replace('"/bin/bash"', f'"{bash_holder}"')
            if new_content != content:
                with open(p, "w", encoding="utf-8") as f:
                    f.write(new_content)
                replace_count += 1
    print(f"      [OK] Redirected in {replace_count} compiled JS file(s).")

    # 3.6 修复 getOSReleaseInfo 在 Android 上读 /etc/os-release 抛 ENOENT，
    #     导致面板装依赖时 detectOS 未处理 rejection、进程崩溃。
    #     读取失败时回退返回 Debian 兼容内容（detectOS 将识别为 Debian）。
    print("[3.6/4] Patching getOSReleaseInfo for Android (no /etc/os-release)...")
    util_js = os.path.join(payload_ql, "static", "build", "config", "util.js")
    with open(util_js, "r", encoding="utf-8") as f:
        content = f.read()
    patched = """async function getOSReleaseInfo() {
    try {
        return await fs.readFile('/etc/os-release', 'utf8');
    }
    catch (e) {
        return 'ID=debian\\nNAME="Debian GNU/Linux"\\nPRETTY_NAME="Debian GNU/Linux 12 (bookworm)"\\n';
    }
}"""
    old_fn = """async function getOSReleaseInfo() {
    const osRelease = await fs.readFile('/etc/os-release', 'utf8');
    return osRelease;
}"""
    if old_fn in content:
        content = content.replace(old_fn, patched)
        with open(util_js, "w", encoding="utf-8") as f:
            f.write(content)
        print("      [OK] getOSReleaseInfo patched.")
    elif "ID=debian" in content:
        print("      [OK] getOSReleaseInfo already patched.")
    else:
        print("      !! WARN: getOSReleaseInfo pattern not found, manual check needed!")

    # 4. 打包 ZIP
    # 从 module.prop 读取模块版本号，用于命名输出 ZIP
    module_prop = os.path.join(src_dir, "module.prop")
    mod_version = "1.0.3"
    with open(module_prop, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("version="):
                mod_version = line.split("=", 1)[1].strip().split()[0]
                break
    output_zip = os.path.join(base_dir, f"QingLong-Android-Root-Module-v{mod_version}.zip")
    print(f"[4/4] Creating zip: {os.path.basename(output_zip)}...")
    if os.path.exists(output_zip):
        os.remove(output_zip)

    with zipfile.ZipFile(output_zip, 'w', compression=zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(src_dir):
            for file in files:
                if file in [".DS_Store", "Thumbs.db"] or "__MACOSX" in root:
                    continue
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, src_dir)
                zipf.write(file_path, rel_path)

    print("==================================================")
    print(f"Build Success! Output: {output_zip}")
    print(f"Size: {os.path.getsize(output_zip) / (1024*1024):.2f} MB")
    print("==================================================")

if __name__ == "__main__":
    build()
