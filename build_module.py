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
import re
import shutil
import zipfile
import glob
import json
from collections import deque

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

def _read_pkg_version(pkg_dir):
    pj = os.path.join(pkg_dir, "package.json")
    if not os.path.isfile(pj):
        return None
    try:
        with open(pj, "r", encoding="utf-8-sig") as f:
            return json.load(f).get("version")
    except Exception:
        return None

def _read_pkg_name(pkg_dir):
    pj = os.path.join(pkg_dir, "package.json")
    if not os.path.isfile(pj):
        return None
    try:
        with open(pj, "r", encoding="utf-8-sig") as f:
            return json.load(f).get("name")
    except Exception:
        return None

def _list_siblings(entry_nm, exclude):
    """列出 .pnpm/<entry>/node_modules 下除自身外的全部依赖包, 返回 [(dep_name, dep_dir)]"""
    out = []
    if not os.path.isdir(entry_nm):
        return out
    for d in os.listdir(entry_nm):
        if d.startswith("."):
            continue
        full = os.path.join(entry_nm, d)
        if d.startswith("@"):
            if os.path.isdir(full):
                for sub in os.listdir(full):
                    sub_full = os.path.join(full, sub)
                    if os.path.isdir(sub_full):
                        name = d + "/" + sub
                        if name != exclude:
                            out.append((name, sub_full))
        elif os.path.isdir(full) and d != exclude:
            out.append((d, full))
    return out

def materialize_full_deps(nm_dir):
    """自动补齐顶层 node_modules 缺失的全部传递依赖.

    背景: pnpm 顶层软链接在 Windows 打包流程中会丢失, 导致设备上
    `Cannot find module 'xxx'` 启动崩溃 (如 object-assign/cors)。
    策略 (任务队列式, 递归收敛):
      1. 从当前顶层包出发, 沿 .pnpm 的兄弟依赖关系 BFS 出完整可达依赖宇宙;
      2. 依赖名在全宇宙中只有一个版本 -> 提升到顶层 node_modules (npm hoist 语义);
      3. 存在多版本冲突的依赖 -> 嵌套进每个使用者包自己的
         <使用者>/node_modules/<依赖>, 保证 Node 从使用者目录解析时命中正确版本;
      4. 每放置一个包, 其自身依赖继续按 2/3 处理, 直到收敛。
    """
    print("[1.5c/4] Auto-materializing ALL missing top-level dependencies (fixpoint)...")

    # --- A. 枚举当前顶层包 ---
    top_pkgs = []  # (name, dir)
    for name in os.listdir(nm_dir):
        if name.startswith("."):
            continue
        full = os.path.join(nm_dir, name)
        if name.startswith("@") and os.path.isdir(full):
            for sub in os.listdir(full):
                sub_full = os.path.join(full, sub)
                if os.path.isdir(sub_full):
                    top_pkgs.append((name + "/" + sub, sub_full))
        elif os.path.isdir(full):
            top_pkgs.append((name, full))

    # --- B0. 定位顶层包在 .pnpm 中的主条目目录 ---
    # 优先精确匹配 "<enc(name)>@<ver>" 主条目; 其次 peer 变体条目前缀
    # "<enc(name)>@<ver>_..." (如 "express-rate-limit@7.4.1_express@4.21.2")
    pnpm_dir = os.path.join(nm_dir, ".pnpm")
    entry_cache = {}

    def find_own_entry(name, ver):
        if (name, ver) in entry_cache:
            return entry_cache[(name, ver)]
        result = None
        enc = name.replace("/", "+")
        if os.path.isdir(pnpm_dir):
            if ver:
                exact = os.path.join(pnpm_dir, enc + "@" + str(ver), "node_modules", *name.split("/"))
                if os.path.isdir(exact):
                    result = exact
            if result is None:
                # ver 未知(顶层 scoped 软链接经 zip 往返损坏成空目录)或精确条目缺失:
                # 按名字前缀匹配 .pnpm 条目, 优先主条目(无 "_" peer 后缀)
                prefix = enc + "@"
                cands = []
                for e in os.listdir(pnpm_dir):
                    if e.startswith(prefix):
                        c = os.path.join(pnpm_dir, e, "node_modules", *name.split("/"))
                        if os.path.isdir(c):
                            cands.append(e)
                if cands:
                    no_peer = [e for e in cands if "_" not in e[len(prefix):]]
                    pick = sorted(no_peer or cands, key=len)[0]
                    result = os.path.join(pnpm_dir, pick, "node_modules", *name.split("/"))
        entry_cache[(name, ver)] = result
        return result

    # --- B. BFS 依赖宇宙: 依据 package.json dependencies + entry 内兄弟解析 ---
    # pnpm 语义: entry 的 node_modules 下, 宿主包 + 它的全部依赖副本。
    # 某个包的依赖 = 其 package.json dependencies 声明的名字, 解析到
    # 同 entry 下的同名兄弟目录。绝不能把兄弟目录互相当作依赖 (会引入
    # 虚假的循环依赖导致嵌套爆炸)。
    def entry_root_of(pkg_dir):
        """包目录 -> 其所在 entry 的 node_modules 根目录"""
        parent = os.path.dirname(pkg_dir)
        base = os.path.basename(parent)
        if base.startswith("@"):
            return os.path.dirname(parent)  # scoped 包: 再上一层
        if base == "node_modules":
            return parent  # 普通包
        return None

    def resolve_dep(dep_name, entry_root):
        """在 entry 内解析依赖; 缺失时回退到 .pnpm 主条目"""
        cand = os.path.join(entry_root, *dep_name.split("/"))
        if os.path.isdir(cand):
            return cand
        enc = dep_name.replace("/", "+")
        if os.path.isdir(pnpm_dir):
            for e in os.listdir(pnpm_dir):
                if e.startswith(enc + "@"):
                    c = os.path.join(pnpm_dir, e, "node_modules", *dep_name.split("/"))
                    if os.path.isdir(c):
                        return c
        return None

    def deps_of(pkg_dir):
        entry_root = entry_root_of(pkg_dir)
        pj = os.path.join(pkg_dir, "package.json")
        if not entry_root or not os.path.isfile(pj):
            return []
        try:
            with open(pj, "r", encoding="utf-8-sig") as f:
                names = json.load(f).get("dependencies") or {}
        except Exception:
            return []
        out = []
        self_id = os.path.abspath(pkg_dir)
        for dep_name in names:
            dep_dir = resolve_dep(dep_name, entry_root)
            if dep_dir and os.path.abspath(dep_dir) != self_id:
                out.append((dep_name, dep_dir))
        return out

    universe = {}
    stack = []
    initial = []  # (name, dest_pkg_dir, entry_pkg_dir)
    for name, dir_ in top_pkgs:
        ver = _read_pkg_version(dir_)
        entry_pkg = find_own_entry(name, ver)
        if entry_pkg and os.path.isdir(entry_pkg):
            dest_pkg = os.path.join(nm_dir, *name.split("/"))
            # 顶层 scoped 软链接经 zip 往返会损坏成空目录(无 package.json):
            # 删除后由下方放置阶段从 .pnpm 条目回填实体
            if os.path.isdir(dest_pkg) and not os.path.isfile(os.path.join(dest_pkg, "package.json")):
                shutil.rmtree(dest_pkg, ignore_errors=True)
            initial.append((name, dest_pkg, entry_pkg))
            stack.append(entry_pkg)
        else:
            print(f"      ! no .pnpm entry for top-level: {name}@{ver} (skip)")
    while stack:
        pkg_dir = stack.pop()
        if pkg_dir in universe:
            continue
        deps = deps_of(pkg_dir)
        universe[pkg_dir] = deps
        for _dn, dd in deps:
            if dd not in universe:
                stack.append(dd)

    # --- C. 冲突分析: 依赖名 -> {版本: set(使用者 pkg_dir)} ---
    dep_versions = {}
    for pkg_dir, deps in universe.items():
        for dep_name, dep_dir in deps:
            ver = _read_pkg_version(dep_dir) or "unknown"
            dep_versions.setdefault(dep_name, {}).setdefault(ver, set()).add(pkg_dir)
    conflicted = {n for n, v in dep_versions.items() if len(v) > 1}
    for n in sorted(conflicted):
        print(f"      ~ version conflict: {n} -> " +
              ", ".join(f"{v}({len(u)} users)" for v, u in dep_versions[n].items()))

    # --- D. 任务队列放置 ---
    copied = [0]

    def copy_tree(src, dst):
        # 目标已存在时按包版本决定: 版本一致->幂等跳过; 版本不一致->强制重拷
        # (修复历史构建漏放冲突嵌套依赖后, 后续构建永远无人补漏的问题)
        if os.path.exists(dst):
            if _read_pkg_version(src) == _read_pkg_version(dst):
                return
            print(f"      ~ version drift at {dst}: "
                  f"{_read_pkg_version(dst)} -> {_read_pkg_version(src)}, re-copy")
            shutil.rmtree(dst, ignore_errors=True)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copytree(src, dst)
        copied[0] += 1

    tasks = deque()
    for name, dest_pkg, entry_pkg in initial:
        tasks.append((entry_pkg, dest_pkg, 0))
    done = set()
    placed = []
    MAX_DEPTH = 6  # 防护: 嵌套深度上限, 杜绝循环依赖导致的套娃失控
    while tasks:
        pkg_dir, dest, depth = tasks.popleft()
        key = (pkg_dir, dest)
        if key in done:
            continue
        done.add(key)
        placed.append((dest, depth))
        copy_tree(pkg_dir, dest)
        if depth >= MAX_DEPTH:
            print(f"      ! max depth reached at {dest}, skip deeper nesting")
            continue
        for dep_name, dep_dir in universe.get(pkg_dir, []):
            if dep_name in conflicted:
                # 冲突依赖: 嵌套进使用者包私有 node_modules
                tasks.append((dep_dir, os.path.join(dest, "node_modules", *dep_name.split("/")), depth + 1))
            else:
                # 唯一版本: 提升到顶层, 并继续处理其依赖
                top_dst = os.path.join(nm_dir, *dep_name.split("/"))
                copy_tree(dep_dir, top_dst)
                tasks.append((dep_dir, top_dst, depth + 1))

    print(f"      [OK] universe size: {len(universe)} packages, copied {copied[0]} dirs, nested-conflict deps: {len(conflicted)}")

    # ---- E. verify 驱动的缺口补放 (最多 3 轮): 对版本感知校验发现的
    #         缺失/错配依赖, 从 .pnpm 找满足声明范围的条目, 精准嵌套到使用者旁 ----
    for _round in range(1, 9):
        missing = verify_deps_complete(placed, pnpm_dir)
        if not missing:
            break
        print(f"      ~ verify round {_round}: {len(missing)} gaps -> fixing...")
        added = 0
        fix_tasks = deque()
        udepth_map = dict(placed)
        for dep_key, users in list(missing.items()):
            if dep_key.startswith('<pkg-missing:'):
                # 幽灵条目: drift 重拷父包时 rmtree 连带删除了已嵌套的依赖,
                # 从死路径反解出 user 与包名, 重新补放
                p = dep_key[len('<pkg-missing:'):]
                if p.endswith('>'):
                    p = p[:-1]
                p = p.replace('/', '\\')
                idx = p.rfind('\\node_modules\\')
                if idx < 0:
                    continue
                user = p[:idx]
                name = p[idx + len('\\node_modules\\'):].replace('\\', '/')
                rng = '*'
                users = [user] if os.path.isdir(user) else []
            else:
                key = dep_key.split(' (实际')[0].strip()
                name, _, rng = key.rpartition('@')
                if not name:
                    name, rng = key, '*'
                if not rng:
                    rng = '*'
            for user in users:
                if not os.path.isdir(user):
                    continue
                if udepth_map.get(user, 0) >= 6:
                    continue
                if not os.path.isdir(pnpm_dir):
                    continue
                enc = name.replace('/', '+')
                prefix = enc + '@'
                cands = []
                for e in os.listdir(pnpm_dir):
                    if not e.startswith(prefix):
                        continue
                    c = os.path.join(pnpm_dir, e, 'node_modules', *name.split('/'))
                    if os.path.isfile(os.path.join(c, 'package.json')):
                        v = _read_pkg_version(c)
                        if _sat_semver(v, rng):
                            prio = 0 if '_' not in e[len(prefix):] else 1
                            cands.append((prio, e, c))
                if not cands:
                    print(f"      ! no matching .pnpm entry for {name}@{rng} (user: {os.path.basename(user)})")
                    continue
                cands.sort()
                _prio, _e, c = cands[0]
                dst = os.path.join(user, 'node_modules', *name.split('/'))
                fix_tasks.append((c, dst, udepth_map.get(user, 0) + 1))
        # 依赖展开: 与主循环同规则递归补齐新放包的依赖,
        # 但 fixer 只往使用者旁嵌套, 绝不 hoist 到顶层 (避免污染 ql 直接依赖版本)
        fdone = set()
        while fix_tasks:
            pkg_dir, dest, depth = fix_tasks.popleft()
            fkey = (pkg_dir, dest)
            if fkey in fdone:
                continue
            fdone.add(fkey)
            placed.append((dest, depth))
            copy_tree(pkg_dir, dest)
            added += 1
            if depth >= 6:
                continue
            for dep_name, dep_dir in universe.get(pkg_dir, []):
                ndst = os.path.join(dest, 'node_modules', *dep_name.split('/'))
                if dep_name in conflicted:
                    fix_tasks.append((dep_dir, ndst, depth + 1))
                else:
                    fix_tasks.append((dep_dir, ndst, depth + 1))
        print(f"      ~ round {_round}: placed {added} missing dep copies")
        if added == 0:
            break

    missing = verify_deps_complete(placed, pnpm_dir)
    if missing:
        print(f"      !! VERIFY FAILED after fix rounds: {len(missing)} deps still problematic:")
        for dep, users in sorted(missing.items())[:15]:
            print(f"         {dep} (required by: {', '.join(users[:3])})")
        raise SystemExit("Build aborted: node_modules still incomplete!")
    print("      [OK] verify clean: all dependencies resolvable with satisfying versions")
    return placed

def _sat_semver(ver, rng):
    """简化 semver 判断: 实际版本 ver 是否满足声明范围 rng.
    支持 ^x.y.z / ~x.y.z / 精确版本 / * ; 其余范围(标签/git/或运算)放行."""
    rng = (rng or '').strip()
    if rng in ('*', '', 'latest', 'x'):
        return True
    if '||' in rng:
        return any(_sat_semver(ver, part) for part in rng.split('||'))
    m = re.match(r'^[\^~>]*\s*(\d+)\.(\d+)(?:\.(\d+))?', rng)
    if not m:
        return True
    maj, mi = int(m.group(1)), int(m.group(2))
    parts = (ver or '').split('.')
    try:
        vmaj, vmin = int(parts[0]), int(parts[1])
    except Exception:
        return True
    if rng.startswith('^'):
        if vmaj != maj:
            return False
        return maj > 0 or vmin >= mi
    if rng.startswith('~'):
        return vmaj == maj and vmin == mi
    if re.match(r'^\d+\.\d+\.\d+$', rng):
        return (ver or '') == rng
    return True


def verify_deps_complete(placed, pnpm_dir=None):
    """按 Node 的逐级向上解析规则, 校验每个已放置包的 dependencies 均可解析,
    且实际解析到的版本满足使用者的 semver 声明 (v1.0.20 修复: 原来只查存在性,
    导致 node-schedule 旁缺少 cron-parser@4.9.0 却被顶层 5.4.0 糊弄过关).
    placed 为 [(dest, depth)]; 深度达到上限的叶子包跳过校验.
    返回缺失/错配清单 {dep_name: [使用者路径]}"""
    missing = {}

    def find_dep_dir(pkg_dir, dep):
        parts = dep.split("/")
        cur = pkg_dir
        for _ in range(12):
            cand = os.path.join(cur, "node_modules", *parts)
            if os.path.isdir(cand):
                return cand
            parent = os.path.dirname(cur)
            if parent == cur:
                return None
            cur = parent
        return None

    for pkg_dir, depth in placed:
        if depth >= 6:
            continue  # 深度上限叶子包: 设计上不再嵌套, 跳过
        if not os.path.isdir(pkg_dir):
            missing.setdefault("<pkg-missing:" + pkg_dir + ">", []).append("-")
            continue
        pj = os.path.join(pkg_dir, "package.json")
        if not os.path.isfile(pj):
            continue
        try:
            with open(pj, "r", encoding="utf-8") as f:
                deps = json.load(f).get("dependencies") or {}
        except Exception:
            continue
        for dep, declared in deps.items():
            dep_dir = find_dep_dir(pkg_dir, dep)
            if dep_dir is None:
                missing.setdefault(dep, []).append(pkg_dir)
                continue
            actual = _read_pkg_version(dep_dir)
            if 'github.com+' in dep_dir.replace('\\', '/'):
                continue  # git fork 依赖的 version 字段不可信 (如 @whyour/sqlite3 标 1.0.3 实为 5.x)
            if not _sat_semver(actual, declared):
                # .pnpm 中不存在任何满足声明的版本时, 现状即最优, 放行
                # (如 git fork 依赖 @whyour/sqlite3 版本字段标 1.0.3, 实为 5.x 代码)
                if pnpm_dir and os.path.isdir(pnpm_dir):
                    enc0 = dep.replace('/', '+')
                    sat_any = False
                    for e0 in os.listdir(pnpm_dir):
                        if e0.startswith(enc0 + '@'):
                            v0 = _read_pkg_version(os.path.join(pnpm_dir, e0, 'node_modules', *dep.split('/')))
                            if _sat_semver(v0, declared):
                                sat_any = True
                                break
                    if not sat_any:
                        continue
                missing.setdefault(f"{dep}@{declared} (实际 {actual}, 版本不满足)", []).append(pkg_dir)
    return missing

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

    nm_dir = os.path.join(payload_ql, "node_modules")
    # FRESH_NM=1: 从源码全量重建 node_modules (修复历史构建遗留的漏放依赖)
    src_nm = os.path.join(base_dir, "work_extracted", "qinglong-android-work", "ql", "node_modules")
    if os.environ.get("FRESH_NM") == "1" and os.path.isdir(src_nm):
        print("[1.4/4] FRESH_NM=1: rebuilding node_modules from source...")
        shutil.rmtree(nm_dir, ignore_errors=True)
        shutil.copytree(src_nm, nm_dir)
        print("      [OK] node_modules rebuilt from source")
    # 实体化 pnpm 依赖树
    resolve_pnpm_tree(nm_dir)
    # 自动补齐顶层缺失的全部传递依赖 (pnpm 软链接在 Windows 打包时丢失的修复)
    placed = materialize_full_deps(nm_dir)
    pnpm_dir = os.path.join(nm_dir, ".pnpm")
    missing = verify_deps_complete(placed, pnpm_dir)
    if missing:
        print(f"      !! VERIFY FAILED: {len(missing)} deps still missing:")
        for dep, users in sorted(missing.items())[:20]:
            print(f"         {dep} (required by: {', '.join(users[:5])})")
        raise SystemExit("Build aborted: node_modules still incomplete!")
    print("      [OK] All dependencies resolvable at top-level.")

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
