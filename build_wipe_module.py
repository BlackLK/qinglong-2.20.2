#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""打包「青龙面板 · 清除数据工具」独立模块 zip"""
import os, zipfile, re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "module_src_wipe")

with open(os.path.join(SRC, "module.prop"), encoding="utf-8") as f:
    prop = f.read()
ver = re.search(r"^version=(.+)$", prop, re.M).group(1).strip()
code = re.search(r"^versionCode=(\d+)", prop, re.M).group(1)
out_name = f"QingLong-DataWipe-v{ver.split()[0]}.zip"
out_path = os.path.join(HERE, out_name)

# 模块内脚本的换行必须是 LF
if os.path.exists(out_path):
    os.remove(out_path)
with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as z:
    for fn in ("module.prop", "customize.sh", "action.sh", "uninstall.sh"):
        p = os.path.join(SRC, fn)
        with open(p, "rb") as f:
            data = f.read().replace(b"\r\n", b"\n")
        z.writestr(fn, data)

print(f"OK: {out_path}")
print(f"    version={ver} code={code} size={os.path.getsize(out_path)} bytes")
