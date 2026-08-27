# 青龙面板 Android Root 模块

把 [青龙面板](https://github.com/whyour/qinglong)（whyour/qinglong **v2.20.2**）跑在 Android ARM64 设备上的 Magisk / KernelSU 系 Root 模块。无需 Termux、无需 Docker、无需 Chroot，刷入即用。

> 已实测环境：**SukiSU Ultra** + **联想 Y700 四代**。KernelSU 理论兼容（未实机验证）；Magisk 官方 App 无模块「执行」按钮，不推荐。

## 下载

前往 [Releases](https://github.com/BlackLK/qinglong-2.20.2/releases) 下载：

| 文件 | 说明 |
|---|---|
| `QingLong-Android-Root-Module-vX.X.X.zip` | 青龙面板主模块（必需） |
| `QingLong-DataWipe-vX.X.X.zip` | 用户数据清除工具（可选，彻底重置时用） |
| `node.real` | Node.js linux-arm64 主程序，仅克隆源码自行构建时需要 |

## 功能

- **单按钮智能启停**：在 Root 管理器里点「执行」启动面板（同时自动开启开机自启），再点一次停止（关闭自启）
- **启动资源报告**：启动时在日志打印内存（RAM）与磁盘占用、用户数据统计（任务/环境变量/依赖数量）
- **安装占用报告**：刷入完成时打印各部分磁盘占用明细
- **完整任务环境**：内置 `bash`、`python3.11`（含 pip）、`pnpm`，以及 `jq / curl / wget / openssl / tar / unzip / sed` 等 Linux 工具
- **依赖管理**：面板内可直接安装 NodeJS / Python3 / Linux 三类依赖
- **网络开箱即用**：内置本地 DNS 转发器与 CA 证书修复，HTTPS / GitHub 直连可用
- **数据与程序分离**：程序装在 `/data/adb/qinglong`，用户数据（脚本/数据库/配置/已装依赖）在 `/data/adb/qinglong-data`，卸载重刷不丢数据

## 刷入与使用

1. 在 Root 管理器中刷入主模块 zip（解压部署约 1~3 分钟，属正常现象）
2. **重启设备**（首次刷入后面板默认不自启）
3. 管理器中点击「青龙面板」模块的 **执行** 按钮 → 日志出现 `ALL SERVICES READY` 即启动成功
4. 浏览器访问 `http://<设备IP>:5700/`

> 单进程架构说明：原版青龙使用 Node.js cluster 多进程编排，在 Android 的动态链接器环境下 worker 无法初始化。本模块将服务合并为单进程（`app_single.js`）以绕过该限制，gRPC(5500) 与 HTTP(5700) 由同一进程监听。

## 数据清除工具（可选模块）

独立小模块，装上后管理器多一个「执行」按钮：

- **第一次点击**：仅显示危险警告，不会删除任何东西
- **2 分钟内再次点击**：停止面板并永久清除 `/data/adb/qinglong-data`
- 超过 2 分钟未确认，操作自动作废

普通卸载/升级主模块**不需要**安装它。

## 从源码构建

```bash
git clone https://github.com/BlackLK/qinglong-2.20.2.git
cd qinglong-2.20.2

# node.real 超过 GitHub 100MB 单文件限制，未入库，需自行放置：
# 从 https://nodejs.org/dist/latest-v20.x/ 下载 node-v20.x.x-linux-arm64.tar.xz
# 解出 bin/node，重命名为 node.real，放到 module_src/payload/runtime/bin/node.real

python build_module.py       # 生成主模块 zip
python build_wipe_module.py  # 生成清除数据模块 zip
```

## 目录结构

```
├── module_src/            # 青龙面板主模块源码
│   ├── customize.sh       # 刷入安装脚本（分段进度日志）
│   ├── service.sh         # 开机自启（受 autostart.conf 控制）
│   ├── action.sh          # 管理器「执行」按钮（智能启停）
│   ├── manager/           # 启动/停止/状态/资源报告脚本
│   └── payload/
│       ├── ql/            # 青龙 2.20.2 程序 + app_single.js 单进程入口
│       └── runtime/       # bash / python3 / pnpm / node 及 glibc 运行库
├── module_src_wipe/       # 用户数据清除模块源码
├── build_module.py        # 主模块打包脚本
├── build_wipe_module.py   # 清除模块打包脚本
└── docs/                  # 发布文案等文档
```

## 已知限制

- 仅支持 **ARM64** 设备
- 基于 Debian arm64 官方包裁剪，部分依赖 `apt` 的 Linux 程序不可用（面板不会崩溃，仅提示不支持）
- 面板内「在线更新青龙版本」不可用，升级方式为重刷新版模块

## 免责声明

本项目仅供学习研究，请遵守目标网站的服务条款，勿用于非法用途。使用本模块产生的一切后果由使用者自行承担。

## 鸣谢

- [whyour/qinglong](https://github.com/whyour/qinglong) — 青龙面板官方项目
- [KernelSU](https://github.com/tiann/KernelSU) / [SukiSU Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) — Root 方案
