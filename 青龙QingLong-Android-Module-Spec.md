# QingLong Android Root Module

> QingLong Android Root Module 完整项目设计、功能需求、安全规范与开发规格说明

---

# 1. 项目简介

本项目旨在将 QingLong（青龙面板）适配为一个适用于 Android Root 环境的轻量级模块。

目标 Root 环境：

- Magisk
- KernelSU
- SukiSU Ultra

模块一次刷入后，用户可以长期通过 Root 管理器中的 **Action / 执行** 功能管理 QingLong，无需反复刷入模块。

核心目标：

> **轻量、稳定、安全、可回滚、易维护。**

---

# 2. 设计原则

项目设计优先级：

1. 安全
2. 稳定
3. 兼容性
4. 可恢复性
5. 功能完整
6. 轻量
7. 界面美观

原则：

> 在不影响安全和稳定性的情况下，尽可能减少代码、依赖、常驻进程和系统修改。

---

# 3. 不使用 WebUI

本项目第一版不制作独立 WebUI。

不使用：

- HTML
- CSS
- JavaScript
- WebView
- 独立 Android App
- 独立管理后台

使用 Root 管理器自身提供的：

```text
Root Manager
    ↓
QingLong Module
    ↓
Action / 执行
    ↓
action.sh
    ↓
Shell 管理菜单
    ↓
实时日志
```

这样可以：

- 减少文件数量
- 减少运行时依赖
- 减少兼容性问题
- 减少 RAM 占用
- 减少后台常驻进程
- 简化维护
- 提高 Magisk / KernelSU / SukiSU Ultra 兼容性

---

# 4. 支持的 Root 管理器

目标兼容：

- Magisk
- KernelSU
- SukiSU Ultra

核心模块尽量使用通用机制：

```text
module.prop
action.sh
service.sh
boot-completed.sh
uninstall.sh
```

不要依赖某一个 Root 管理器的专有 UI。

---

# 5. 模块安装方式

主要安装方式：

```text
Root 管理器
    ↓
选择 QingLong Module ZIP
    ↓
刷入
    ↓
查看安装日志
    ↓
安装完成
```

不把 Recovery 作为通用安装方式。

尤其针对 KernelSU，应优先通过 KernelSU Manager 等支持模块安装的 Root 管理器进行安装。

---

# 6. 第一次刷入后的默认行为

刷入模块后：

```text
QingLong = STOPPED
AUTOSTART = OFF
```

也就是说：

> **刷入模块 ≠ 启动 QingLong。**

刷入过程中禁止启动 QingLong。

这样可以避免：

- QingLong Runtime 异常
- Node.js 异常
- Python 异常
- 数据库异常
- 配置异常

导致安装完成后立即启动服务。

---

# 7. 首次刷入详细日志

刷入模块时必须提供详细安装日志。

示例：

```text
========================================
       QingLong Android Module
========================================

[INFO] 开始安装 QingLong Android Module
[INFO] 模块版本：1.0.0

[1/10] 检查设备环境
[INFO] Android：15
[INFO] ABI：arm64-v8a
[INFO] Root：KernelSU
[OK] 设备环境符合要求

[2/10] 检查存储空间
[INFO] 所需空间：XXX MB
[INFO] 可用空间：X.XX GB
[OK] 存储空间充足

[3/10] 检查模块安装环境
[OK] /data/adb 可用
[OK] 模块目录可用

[4/10] 安装 QingLong Runtime
[INFO] 正在安装 Runtime...
[OK] Runtime 安装完成

[5/10] 安装 QingLong
[INFO] QingLong 版本：2.20.2
[INFO] 正在释放文件...
[OK] QingLong 安装完成

[6/10] 创建用户数据目录
[OK] scripts
[OK] config
[OK] database
[OK] logs
[OK] backups

[7/10] 初始化模块配置
[OK] 开机自启：关闭
[OK] QingLong：停止

[8/10] 检查运行环境
[OK] Runtime
[OK] QingLong Runtime
[OK] QingLong

[9/10] 检查模块文件
[OK] action.sh
[OK] service.sh
[OK] boot-completed.sh
[OK] uninstall.sh

[10/10] 安装完成

========================================
安装成功
========================================

QingLong 版本：2.20.2
模块状态：已启用
QingLong 状态：已停止
开机自启：关闭

⚠️ 请重启手机完成模块初始化。

重启后可以进入 Root 管理器：
QingLong → 执行

========================================
```

---

# 8. 日志规范

统一使用四种日志等级：

```text
[INFO]  普通过程
[OK]    操作成功
[WARN]  警告
[ERROR] 错误
```

示例：

```text
[INFO] 正在检查 Runtime
[OK] Runtime 正常
[WARN] 检测到旧版本
[ERROR] SHA256 校验失败
```

禁止输出敏感信息。

---

# 9. 敏感信息保护

日志中禁止直接打印：

- Cookie
- Token
- Authorization
- API Key
- 密码
- Secret
- 环境变量中的敏感值

错误示例：

```text
[INFO] Cookie=xxxxxxxx
```

正确：

```text
[INFO] Cookie：已配置
```

---

# 10. 模块目录

推荐模块目录：

```text
/data/adb/modules/qinglong/
```

建议结构：

```text
qinglong/
├── module.prop
├── action.sh
├── service.sh
├── boot-completed.sh
├── uninstall.sh
│
├── bin/
│   ├── ql
│   ├── ql-start
│   ├── ql-stop
│   ├── ql-status
│   └── ql-version
│
└── config/
    └── default.conf
```

---

# 11. QingLong 程序与用户数据分离

这是项目的重要设计。

不要把程序和用户数据混在一起。

推荐：

```text
/data/adb/qinglong/
```

用于：

- QingLong Runtime
- QingLong 程序
- 已安装版本
- 管理脚本
- 缓存

而：

```text
/data/adb/qinglong-data/
```

用于：

- 用户脚本
- Cookie
- 环境变量
- 数据库
- 配置
- 日志
- 备份

---

# 12. 推荐最终目录

```text
/data/adb/qinglong/
│
├── versions/
│   ├── 2.20.2/
│   ├── 2.21.0/
│   └── ...
│
├── current
│
├── runtime/
│   ├── node/
│   ├── python/
│   └── lib/
│
├── bin/
│
├── manager/
│
└── cache/

/data/adb/qinglong-data/
│
├── scripts/
├── config/
├── database/
├── logs/
├── backups/
├── cache/
└── run/
```

---

# 13. 当前版本机制

不要直接覆盖旧版本。

不推荐：

```text
2.20.2
    ↓
删除
    ↓
安装 2.21.0
```

推荐：

```text
versions/
├── 2.20.2/
└── 2.21.0/

current → 2.21.0
```

这样出现问题时可以：

```text
current → 2.20.2
```

快速恢复。

---

# 14. 模块版本与 QingLong 版本分离

必须区分：

```text
Module Version
```

和：

```text
QingLong Version
```

例如：

```text
Module：
1.0.0

QingLong：
2.20.2
```

以后：

```text
Module：
1.1.0

QingLong：
2.20.2
```

也可以成立。

模块自身更新不应该强制升级 QingLong。

---

# 15. Action 管理菜单

最终菜单：

```text
========================================
        QingLong Manager
========================================

当前版本：2.20.2
状态：STOPPED
开机自启：OFF

----------------------------------------

1. 启动 QingLong
2. 停止 QingLong
3. 重启 QingLong

4. 开启开机自启
5. 关闭开机自启

6. 当前 QingLong 信息
7. 存储占用
8. 查看日志

9. 版本管理

0. 退出

========================================

请输入：
```

---

# 16. 启动

启动流程：

```text
检查 Runtime
    ↓
检查当前版本
    ↓
检查配置
    ↓
检查是否已经运行
    ↓
启动 QingLong
    ↓
等待启动
    ↓
检查进程
    ↓
检查端口
    ↓
健康检查
```

日志示例：

```text
[INFO] 正在启动 QingLong...

[1/4] 检查 Runtime
[OK] Runtime 正常

[2/4] 检查配置
[OK] 配置正常

[3/4] 启动进程
[OK] PID：12345

[4/4] 检查服务
[OK] Port：5700
[OK] QingLong 正常运行

================================
启动成功
================================
```

---

# 17. 停止

停止流程：

```text
读取 PID
    ↓
发送 SIGTERM
    ↓
等待正常退出
    ↓
确认进程结束
```

只有正常退出失败时才使用：

```text
SIGKILL
```

不要一开始就使用：

```text
kill -9
```

---

# 18. 重启

重启：

```text
停止
    ↓
确认退出
    ↓
启动
    ↓
健康检查
```

---

# 19. 状态判断

不能只通过 PID 判断状态。

至少检查：

```text
PID
+
进程
+
端口
+
健康状态
```

最终状态：

```text
RUNNING
STOPPED
STARTING
STOPPING
ERROR
UNKNOWN
```

---

# 20. 开机自启

提供：

```text
4. 开启开机自启
5. 关闭开机自启
```

默认：

```text
AUTOSTART=0
```

开启：

```text
AUTOSTART=1
```

---

# 21. 开机自启流程

```text
Android 启动
    ↓
系统完成启动
    ↓
boot-completed.sh
    ↓
读取 AUTOSTART
    ↓
AUTOSTART=0
    ↓
什么都不做
```

如果：

```text
AUTOSTART=1
```

则：

```text
启动 QingLong
    ↓
检查状态
    ↓
健康检查
```

---

# 22. 不在早期启动阶段运行 QingLong

禁止在早期启动阶段启动 QingLong。

尤其不要将 QingLong 启动逻辑放进：

```text
post-fs-data.sh
```

原因：

早期启动脚本出错可能影响 Android 启动流程。

QingLong 启动应该尽量放在：

```text
late_start
```

或者：

```text
boot-completed
```

阶段。

---

# 23. 不使用常驻管理 Daemon

第一版不创建：

```text
qinglong-manager-daemon
```

这种长期常驻进程。

管理操作：

```text
用户需要
    ↓
执行 action.sh
    ↓
完成
    ↓
脚本退出
```

这样：

- 更省 RAM
- 更省 CPU
- 更少后台进程
- 更少故障点
- 更安全

---

# 24. 启动失败保护

如果开启自启后 QingLong 连续启动失败：

```text
Android 启动
    ↓
QingLong 启动失败
    ↓
重试
    ↓
仍然失败
    ↓
达到失败阈值
```

自动：

```text
AUTOSTART=0
```

并记录日志：

```text
[ERROR] QingLong 连续启动失败。

为防止启动循环，
已自动关闭开机自启。

请进入：

Root Manager
→ QingLong
→ 执行
→ 查看日志
```

---

# 25. Bootloop 安全原则

绝对禁止：

- 无限循环
- 无限等待
- 无限启动
- 无限重试
- 无限重启
- 开机阶段网络下载
- 开机阶段版本升级
- 开机阶段版本降级
- 开机阶段数据库迁移

启动脚本必须尽可能短。

---

# 26. 升级与降级

版本管理统一使用：

```text
切换到指定版本
```

而不是把升级和降级写成两个完全独立的系统。

---

# 27. 版本管理菜单

```text
========== Version Manager ==========

当前版本：
2.20.2

1. 切换到指定版本
2. 查看已安装版本
3. 查看可用版本
4. 回滚上一版本
5. 清理旧版本

0. 返回

请输入：
```

---

# 28. 指定版本切换

用户输入：

```text
请输入目标版本：

> 2.21.0
```

程序自动判断：

```text
当前：2.20.2
目标：2.21.0

操作类型：升级
```

如果：

```text
当前：2.21.0
目标：2.20.2

操作类型：降级
```

---

# 29. 支持任意指定版本

原则上支持：

```text
2.19.0 → 2.20.2
2.20.2 → 2.21.0
2.21.0 → 2.20.2
2.22.0 → 2.19.0
2.19.0 → 2.22.0
```

前提：

- 目标版本存在
- 目标版本支持当前 ABI
- Runtime 可用
- SHA256 正确
- 存储空间足够
- 数据兼容性允许

---

# 30. 升级/降级前检查

执行版本切换前必须检查：

1. 目标版本是否存在
2. 设备架构
3. Runtime
4. 存储空间
5. 当前 QingLong 状态
6. 当前版本
7. 数据库状态
8. 网络状态
9. 目标文件完整性
10. SHA256

任何关键检查失败：

```text
停止操作
```

---

# 31. 升级/降级详细日志

示例：

```text
========== QingLong Version Manager ==========

当前版本：2.21.0
目标版本：2.20.2
操作类型：降级

[1/9] 检查目标版本
[INFO] 检查 2.20.2...
[OK] 目标版本存在

[2/9] 检查设备环境
[INFO] ABI：arm64-v8a
[OK] ABI 匹配

[3/9] 检查磁盘空间
[INFO] 所需：XXX MB
[INFO] 可用：X.XX GB
[OK] 空间充足

[4/9] 备份用户数据
[INFO] 备份数据库...
[OK] 数据库备份完成
[OK] 配置备份完成

[5/9] 下载目标版本
[INFO] 正在下载...
[OK] 下载完成

[6/9] SHA256 校验
[INFO] 正在校验...
[OK] SHA256 校验通过

[7/9] 安装目标版本
[INFO] 正在安装...
[OK] 安装完成

[8/9] 验证运行环境
[OK] Runtime
[OK] QingLong 文件

[9/9] 切换当前版本
[OK] current → 2.20.2

========================================
降级完成
========================================

当前版本：2.20.2
QingLong：STOPPED

⚠️ 请重启手机。

重启后：

自启 OFF → QingLong 保持停止
自启 ON  → 系统启动完成后自动启动

========================================
```

---

# 32. 升级/降级完成后禁止自动启动

这是固定规则。

```text
升级完成
    ↓
QingLong = STOPPED
```

```text
降级完成
    ↓
QingLong = STOPPED
```

禁止：

```text
升级完成
    ↓
自动启动 QingLong
```

---

# 33. 升级/降级完成后提示重启

完成以后必须显示：

```text
========================================

版本切换成功。

当前版本：
2.20.2

QingLong：
已停止

⚠️ 请重启手机后再使用 QingLong。

========================================
```

---

# 34. 升级前备份

每次版本切换前至少备份：

```text
database
config
```

建议：

```text
/data/adb/qinglong-data/backups/
```

例如：

```text
before-2.21.0-20260826/
```

---

# 35. 数据库兼容性

升级和降级不能假设数据库一定兼容。

必须：

```text
切换版本
    ↓
检查数据库版本
    ↓
检查目标 QingLong 兼容性
```

如果存在不可逆迁移风险：

```text
必须依赖升级前备份
```

禁止无条件覆盖数据库。

---

# 36. 升级失败回滚

例如：

```text
2.20.2
    ↓
2.21.0
```

如果 2.21.0 验证失败：

```text
2.21.0
    ↓
验证失败
    ↓
current → 2.20.2
```

然后：

```text
[ERROR] 新版本验证失败。

已自动恢复：
2.20.2

当前 QingLong：
STOPPED

请重启手机。
```

---

# 37. 网络失败保护

下载失败：

```text
[ERROR] 下载失败
```

必须保证：

```text
旧版本不删除
current 不改变
用户数据不改变
```

即：

```text
下载失败
=
整个版本操作取消
```

---

# 38. SHA256 校验

任何下载的 QingLong / Runtime 包：

```text
下载
    ↓
SHA256
    ↓
匹配
    ↓
安装
```

如果不匹配：

```text
[ERROR] SHA256 校验失败

安装已终止。

旧版本未修改。
用户数据未修改。
```

禁止继续安装。

---

# 39. 不允许边下载边安装

禁止：

```text
下载 10%
    ↓
开始覆盖旧版本
```

必须：

```text
完整下载
    ↓
完整校验
    ↓
完整准备
    ↓
开始安装
```

---

# 40. 下载临时目录

使用：

```text
/data/adb/qinglong/cache/
```

例如：

```text
cache/
└── qinglong-2.21.0.zip
```

流程：

```text
下载
    ↓
SHA256
    ↓
完整性检查
    ↓
安装
```

安装成功后删除临时文件。

---

# 41. 存储空间检查

升级前计算：

```text
目标包大小
+
解压空间
+
备份空间
+
安全余量
```

例如：

```text
需要：500 MB
可用：180 MB
```

则：

```text
[ERROR] 存储空间不足
```

直接拒绝操作。

---

# 42. 电量保护

可以进行轻量电量检查。

如果设备电量过低，并且当前操作涉及：

- 大文件下载
- 解压
- 备份
- 版本切换

则：

```text
[WARN] 当前电量较低。
建议连接充电器后继续。
```

电量检查失败本身不应该阻止普通操作。

---

# 43. 版本锁

危险操作必须使用锁机制。

例如：

```text
/data/adb/qinglong-data/run/operation.lock
```

防止：

```text
升级
升级
升级
```

同时执行。

如果已经有操作：

```text
[WARN] QingLong 正在执行其他操作。
请稍后再试。
```

---

# 44. 临时文件清理

成功或失败后都需要清理：

- 临时 ZIP
- 临时解压目录
- 临时下载文件
- 临时日志

但不得误删：

- 用户脚本
- 数据库
- 配置
- 备份
- 当前版本
- 已安装版本

---

# 45. Runtime 隔离

不要污染 Android 全局环境变量。

不要永久修改：

```text
PATH
NODE_PATH
PYTHONPATH
```

QingLong 启动时临时设置：

```text
PATH=/data/adb/qinglong/runtime/bin:$PATH
```

只影响 QingLong 进程。

---

# 46. 当前 QingLong 信息

Action：

```text
6. 当前 QingLong 信息
```

输出：

```text
========== QingLong Information ==========

QingLong：
版本：2.20.2

状态：
STOPPED

PID：
-

端口：
5700

开机自启：
OFF

架构：
arm64-v8a

Node.js：
XX.XX.X

Python：
X.X.X

===========================================
```

---

# 47. 存储占用

需要区分：

```text
QingLong 程序
Node.js Runtime
Python Runtime
依赖
用户脚本
数据库
配置
日志
缓存
备份
```

示例：

```text
========== Storage Information ==========

QingLong 程序：       126 MB
Node.js Runtime：      58 MB
Python Runtime：       42 MB
依赖：                183 MB
用户脚本：              17 MB
数据库：                12 MB
配置：                   4 MB
日志：                   8 MB
缓存：                  10 MB
备份：                   7 MB

------------------------------------------

逻辑大小：             512 MB
实际磁盘占用：         467 MB

==========================================
```

---

# 48. 逻辑大小与实际磁盘占用

同时显示：

```text
逻辑大小
实际磁盘占用
```

因为：

- 硬链接
- 软链接
- 稀疏文件
- 文件系统 Block

可能导致：

```text
文件大小总和
≠
实际磁盘占用
```

---

# 49. 存储统计刷新

不要每次进入菜单都完整扫描。

推荐：

```text
第一次进入
    ↓
读取/生成统计
```

用户选择：

```text
刷新存储统计
```

才重新扫描。

这样可以减少：

- IO
- CPU
- 等待时间

---

# 50. 日志查看

Action：

```text
8. 查看日志
```

输出：

```text
========== QingLong Logs ==========

[2026-08-26 14:20:01] [INFO] Starting
[2026-08-26 14:20:02] [OK] Runtime ready
[2026-08-26 14:20:03] [OK] QingLong started
...
```

需要记录：

- 启动
- 停止
- 重启
- 升级
- 降级
- 回滚
- 自启
- 错误

---

# 51. 日志大小限制

日志不能无限增长。

设置最大日志大小。

超过限制：

```text
轮转
```

或者：

```text
删除最旧日志
```

避免日志占满磁盘。

---

# 52. 卸载

默认：

```text
卸载模块
    ↓
停止 QingLong
    ↓
删除模块
    ↓
保留用户数据
```

保留：

- scripts
- config
- database
- logs
- backups

---

# 53. 完全删除

如果用户选择：

```text
卸载并删除所有 QingLong 数据
```

必须二次确认。

例如：

```text
⚠️ 危险操作

即将删除：

脚本
Cookie
环境变量
数据库
日志
依赖
版本
备份

总计：467 MB

请输入：

DELETE
```

只有输入：

```text
DELETE
```

才能执行。

---

# 54. 防止误删除

禁止使用：

```text
rm -rf /data/adb/
```

等宽泛删除方式。

所有删除操作必须：

1. 使用固定绝对路径
2. 检查路径是否存在
3. 检查路径是否符合预期
4. 确认路径属于 QingLong
5. 再执行删除

---

# 55. Runtime 隔离

不要污染 Android 全局环境变量。

不要永久修改：

```text
PATH
NODE_PATH
PYTHONPATH
```

QingLong 启动时临时设置：

```text
PATH=/data/adb/qinglong/runtime/bin:$PATH
```

只影响 QingLong 进程。

---

# 56. 不依赖 Debian

Debian 可以用于：

```text
开发环境
构建环境
```

但手机运行时不应该强制依赖 Debian。

不推荐：

```text
Android
    ↓
Debian
    ↓
QingLong
```

推荐：

```text
Android Root
    ↓
QingLong Runtime
    ↓
QingLong
```

---

# 57. 不依赖 Termux

不要求用户安装：

```text
Termux
```

QingLong 模块应该独立运行。

这样避免：

- Termux 版本问题
- PATH 问题
- 环境变量问题
- 用户误删 Termux
- Termux 权限问题

---

# 58. 不修改系统分区

原则上不修改：

```text
/system
/vendor
/product
/system_ext
```

主要使用：

```text
/data/adb/
```

和 QingLong 数据目录。

---

# 59. SELinux

第一版：

```text
不使用 sepolicy.rule
```

除非实际测试发现某个功能确实需要额外 SELinux 权限。

如果后续需要，再针对具体权限进行最小化设计。

---

# 60. init

第一版：

```text
不使用 initrc
```

避免将 QingLong 强行加入 Android init 服务体系。

---

# 61. Shell

管理脚本尽量使用：

```text
POSIX-ish Shell
+
BusyBox
```

尽量不依赖：

- Bash
- Zsh
- Perl
- Ruby
- Python
- Node.js

来执行模块自身的管理逻辑。

QingLong Runtime 本身需要什么运行环境，则由 QingLong Runtime 提供。

---

# 62. 模块路径

脚本不要硬编码模块路径。

推荐：

```sh
MODDIR=${0%/*}
```

然后通过：

```sh
$MODDIR
```

访问模块文件。

---

# 63. `module.prop`

模块应包含：

```text
id=
name=
version=
versionCode=
author=
description=
```

必要时可以提供：

```text
updateJson=
```

等字段。

模块 ID 发布后不要修改。

文件使用：

```text
Unix LF
```

换行。

---

# 64. `service.sh`

如果需要后台初始化，使用：

```text
service.sh
```

但不让其变成长期常驻管理 Daemon。

只执行必要初始化。

---

# 65. `boot-completed.sh`

用于系统完全启动后的：

```text
读取 AUTOSTART
    ↓
如果 OFF
    ↓
退出

如果 ON
    ↓
启动 QingLong
```

不执行：

- 下载
- 升级
- 降级
- 数据库迁移
- 大量扫描

---

# 66. 模块更新与 QingLong 更新分离

用户可能：

```text
Module：
1.0.0

QingLong：
2.20.2
```

模块升级：

```text
Module：
1.1.0

QingLong：
2.20.2
```

不能因为模块更新就强制升级 QingLong。

---

# 67. 版本 Manifest

版本信息建议独立维护。

每个版本至少包含：

```text
version
download
sha256
size
architecture
runtime
```

例如：

```text
{
    "version": "2.20.2",
    "architecture": "arm64-v8a",
    "size": "...",
    "sha256": "...",
    "download": "..."
}
```

实际实现时应根据最终发布源和 QingLong 官方发布格式确定。

---

# 68. 升级完整流程

```text
用户输入目标版本
        ↓
获取版本信息
        ↓
检查目标版本
        ↓
检查 ABI
        ↓
检查 Runtime
        ↓
检查磁盘空间
        ↓
检查当前状态
        ↓
停止 QingLong
        ↓
备份数据
        ↓
下载目标版本
        ↓
SHA256 校验
        ↓
完整解压
        ↓
完整性检查
        ↓
安装目标版本
        ↓
验证 Runtime
        ↓
验证 QingLong 文件
        ↓
切换 current
        ↓
保持 STOPPED
        ↓
提示重启
```

---

# 69. 任意关键步骤失败

统一原则：

```text
失败
 ↓
停止操作
 ↓
恢复旧状态
 ↓
清理临时文件
 ↓
保留用户数据
 ↓
输出错误原因
```

---

# 70. 升级失败

要求：

```text
升级失败
=
旧版本仍然可用
```

不能出现：

```text
升级失败
 ↓
旧版本删除
 ↓
新版本也不可用
 ↓
QingLong 完全无法使用
```

---

# 71. 降级失败

同样：

```text
降级失败
=
当前可用版本不被破坏
```

---

# 72. 网络失败

```text
网络失败
 ↓
取消操作
 ↓
旧版本不变
 ↓
用户数据不变
```

---

# 73. SHA256 失败

```text
SHA256 不匹配
 ↓
立即停止
 ↓
删除损坏文件
 ↓
旧版本不变
```

禁止继续安装。

---

# 74. 磁盘空间不足

必须在操作前检测。

例如：

```text
需要：500 MB
可用：180 MB
```

直接：

```text
[ERROR] 存储空间不足。
操作已取消。
```

---

# 75. 操作锁

所有危险操作必须加锁：

```text
升级
降级
回滚
删除版本
删除数据
```

推荐：

```text
/data/adb/qinglong-data/run/operation.lock
```

防止重复执行。

---

# 76. 并发操作

如果：

```text
升级正在进行
```

此时用户再次执行：

```text
升级
```

应该：

```text
[WARN] 已有版本操作正在执行。
请等待当前操作完成。
```

而不是同时运行。

---

# 77. 文件权限

建议：

```text
Shell：
0755

普通配置：
0644

敏感配置：
0600

Cookie：
0600

Token：
0600

Secret：
0600
```

---

# 78. 安全日志

日志可以记录：

```text
版本
状态
PID
错误
操作
时间
```

但不能记录：

```text
Cookie
Token
密码
Secret
API Key
```

---

# 79. 最终功能列表

## Root

- [x] Magisk
- [x] KernelSU
- [x] SukiSU Ultra
- [x] Root Manager Action
- [x] ZIP 安装

## 基础控制

- [x] 启动
- [x] 停止
- [x] 重启
- [x] 当前状态
- [x] 开启自启
- [x] 关闭自启

## 信息

- [x] 当前 QingLong 版本
- [x] Runtime 信息
- [x] Node.js 信息
- [x] Python 信息
- [x] PID
- [x] 端口
- [x] ABI
- [x] 当前运行状态

## 存储

- [x] QingLong 程序大小
- [x] Node.js Runtime 大小
- [x] Python Runtime 大小
- [x] 依赖大小
- [x] 用户脚本大小
- [x] 数据库大小
- [x] 配置大小
- [x] 日志大小
- [x] 缓存大小
- [x] 备份大小
- [x] 总逻辑大小
- [x] 实际磁盘占用

## 版本

- [x] 查看当前版本
- [x] 查看可用版本
- [x] 查看已安装版本
- [x] 指定版本升级
- [x] 指定版本降级
- [x] 指定版本切换
- [x] 回滚
- [x] 清理旧版本

## 日志

- [x] 刷入日志
- [x] 启动日志
- [x] 停止日志
- [x] 重启日志
- [x] 升级日志
- [x] 降级日志
- [x] 回滚日志
- [x] 错误日志
- [x] 存储统计日志

## 安全

- [x] 默认不自启
- [x] 刷入后不自动启动
- [x] 升级后不自动启动
- [x] 降级后不自动启动
- [x] 升降级完成提示重启
- [x] SHA256 校验
- [x] 存储空间检查
- [x] 数据备份
- [x] 升级失败回滚
- [x] 降级失败保护
- [x] 网络失败保护
- [x] 连续启动失败保护
- [x] 操作锁
- [x] 临时文件清理
- [x] 敏感信息脱敏
- [x] 卸载与数据删除分离
- [x] 危险操作二次确认
- [x] 不修改 system
- [x] 不使用不必要的 SELinux
- [x] 不使用 initrc
- [x] 不依赖 Debian
- [x] 不依赖 Termux
- [x] 不使用常驻管理 Daemon
- [x] 不使用 WebUI

---

# 80. 最终用户操作流程

## 第一次安装

```text
下载 ZIP
    ↓
Root Manager
    ↓
刷入模块
    ↓
查看详细安装日志
    ↓
安装成功
    ↓
QingLong STOPPED
    ↓
自启 OFF
    ↓
重启手机
```

---

## 正常启动

```text
Root Manager
    ↓
QingLong
    ↓
执行 / Action
    ↓
启动 QingLong
    ↓
查看实时日志
    ↓
启动成功
```

---

## 停止

```text
Root Manager
    ↓
QingLong
    ↓
执行 / Action
    ↓
停止
    ↓
查看日志
```

---

## 升级

```text
Root Manager
    ↓
QingLong
    ↓
执行 / Action
    ↓
版本管理
    ↓
切换到指定版本
    ↓
输入目标版本
    ↓
备份
    ↓
下载
    ↓
SHA256
    ↓
安装
    ↓
验证
    ↓
切换
    ↓
保持 STOPPED
    ↓
提示重启手机
```

---

## 降级

```text
Root Manager
    ↓
QingLong
    ↓
执行 / Action
    ↓
版本管理
    ↓
切换到指定版本
    ↓
输入旧版本
    ↓
备份
    ↓
下载
    ↓
SHA256
    ↓
安装
    ↓
验证
    ↓
切换
    ↓
保持 STOPPED
    ↓
提示重启手机
```

---

# 81. 开发阶段

建议分阶段开发，不要一次把所有功能混在一起。

## Phase 1：模块基础

实现：

- module.prop
- action.sh
- uninstall.sh
- 安装
- 卸载
- 基础日志

---

## Phase 2：QingLong Runtime

实现：

- Runtime
- QingLong
- 启动
- 停止
- 重启
- 状态
- PID
- 端口
- 日志

---

## Phase 3：开机自启

实现：

- AUTOSTART
- boot-completed.sh
- 启动失败检测
- 自启自动关闭保护

---

## Phase 4：存储统计

实现：

- 程序大小
- Runtime 大小
- 依赖大小
- 脚本大小
- 数据库大小
- 日志大小
- 缓存大小
- 备份大小
- 总大小
- 实际磁盘占用

---

## Phase 5：版本管理

实现：

- 指定版本
- 升级
- 降级
- 版本列表
- SHA256
- 下载
- 备份
- 回滚
- 旧版本清理

---

## Phase 6：兼容性测试

测试：

- Magisk
- KernelSU
- SukiSU Ultra

测试：

- Android 12
- Android 13
- Android 14
- Android 15
- Android 16

实际支持范围以最终测试结果为准。

---

## Phase 7：异常测试

必须测试：

- 断网
- DNS 失败
- 下载中断
- 文件损坏
- SHA256 错误
- 空间不足
- 权限错误
- Runtime 缺失
- QingLong 启动失败
- QingLong 停止失败
- 升级失败
- 降级失败
- 回滚失败
- 重复点击
- 并发执行
- 卸载
- 删除数据
- 开机自启失败

---

# 82. 最终安全目标

必须保证：

### 安装失败

```text
不影响 Android 正常启动
```

### 升级失败

```text
旧版本仍然存在
```

### 降级失败

```text
当前版本不被破坏
```

### 网络失败

```text
版本不发生改变
```

### SHA256 失败

```text
拒绝安装
```

### 磁盘不足

```text
提前拒绝
```

### QingLong 启动失败

```text
不影响 Android 启动
```

### 自启连续失败

```text
自动关闭自启
```

### 卸载模块

```text
默认保留用户数据
```

### 删除数据

```text
必须明确确认
```

---

# 83. 版本说明

当前设计以：

```text
QingLong：2.20.2
```

作为初始测试版本。

后续可以通过版本管理器：

```text
2.20.2
    ↓
2.21.0
    ↓
2.22.x
```

或者：

```text
2.21.0
    ↓
2.20.2
```

进行指定版本切换。

实际可用版本必须以对应版本的官方发布包、Runtime 和 Android ARM64 兼容性测试结果为准。

---

# 84. 设计结论

最终采用：

```text
轻量 Root Module
+
Shell Action 管理器
+
QingLong Runtime
+
独立用户数据
+
多版本并存
+
current 版本切换
+
指定版本升级/降级
+
SHA256
+
自动备份
+
失败回滚
+
自启保护
+
详细日志
+
安全卸载
```

不采用：

```text
WebUI
独立 App
Debian
Termux
常驻管理 Daemon
system 分区修改
不必要 SELinux
早期 boot 阻塞
```

最终原则：

> **安全保护机制不能省，冗余功能可以省。**

> **用户数据永远优先于 QingLong 程序本身。**

> **旧版本永远尽可能保留到新版本确认可用。**

> **升级、降级、回滚完成后默认不启动 QingLong，并提示用户重启手机。**

> **所有重要操作都必须提供详细、可读、可追踪的日志。**

---

# 85. 最终项目定位

本项目不是一个复杂的 Android App，也不是一个完整的 Web 管理系统。

它的核心就是：

```text
一次刷入
    ↓
长期使用
    ↓
Root Manager Action
    ↓
Shell 管理
    ↓
启动 / 停止 / 重启
    ↓
状态 / 日志 / 存储
    ↓
指定版本升级 / 降级
    ↓
备份 / 校验 / 回滚
    ↓
安全运行
```

最终目标：

> **做一个真正适合 Android Root 环境的轻量 QingLong 模块：功能足够完整，但不引入不必要的 UI、Daemon、Debian、Termux、系统修改和额外依赖；所有可能影响系统稳定性的操作都必须有安全保护和回滚机制。**

---

# 86. 开发验收标准

在正式发布之前，必须满足：

- [ ] Magisk 能正常刷入
- [ ] KernelSU 能正常刷入
- [ ] SukiSU Ultra 能正常刷入
- [ ] 刷入过程有完整日志
- [ ] 刷入完成后 QingLong 默认停止
- [ ] 默认不开机自启
- [ ] 可以手动启动
- [ ] 可以手动停止
- [ ] 可以手动重启
- [ ] 可以开启自启
- [ ] 可以关闭自启
- [ ] 自启失败能够自动保护
- [ ] 可以查看当前版本
- [ ] 可以查看 Runtime
- [ ] 可以查看存储占用
- [ ] 可以查看日志
- [ ] 可以指定版本升级
- [ ] 可以指定版本降级
- [ ] 可以回滚
- [ ] 升级前自动备份
- [ ] 降级前自动备份
- [ ] SHA256 校验正常
- [ ] 网络失败不会破坏旧版本
- [ ] 磁盘不足不会进行半安装
- [ ] 升级失败可以恢复
- [ ] 降级失败不会破坏当前版本
- [ ] 升级完成后 QingLong 保持停止
- [ ] 降级完成后 QingLong 保持停止
- [ ] 升级/降级完成后提示重启
- [ ] 用户数据与程序分离
- [ ] 卸载模块默认保留用户数据
- [ ] 删除数据必须二次确认
- [ ] 不打印 Cookie / Token / 密码
- [ ] 不使用 WebUI
- [ ] 不依赖 Debian
- [ ] 不依赖 Termux
- [ ] 不使用常驻管理 Daemon
- [ ] 不修改 system/vendor/product
- [ ] 不依赖不必要的 SELinux 策略
- [ ] 不使用早期 boot 阻塞逻辑
- [ ] 所有危险操作均有锁机制
- [ ] 所有临时文件能够清理
- [ ] 所有错误都有明确日志

---

# 87. 文件名称与项目文档结构

本规格文件建议保存为：

```text
QingLong-Android-Module-Spec.md
```

项目建议结构：

```text
QingLong-Android-Module/
│
├── README.md
│
├── docs/
│   └── QingLong-Android-Module-Spec.md
│
├── module/
│   ├── module.prop
│   ├── action.sh
│   ├── service.sh
│   ├── boot-completed.sh
│   └── uninstall.sh
│
├── bin/
│   ├── ql
│   ├── ql-start
│   ├── ql-stop
│   ├── ql-status
│   └── ql-version
│
├── config/
│   └── default.conf
│
├── versions/
│   └── manifest.json
│
└── build/
```

建议保存位置：

```text
docs/QingLong-Android-Module-Spec.md
```

---

# 88. 最终开发原则与验收结论

本项目最终必须遵循以下原则：

## 第一原则：安全优先

宁可少一个功能，也不能增加导致 Android 无法启动的风险。

```text
安全
>
稳定
>
可恢复
>
兼容
>
功能
>
轻量
>
UI
```

---

## 第二原则：刷入不启动

模块刷入完成以后：

```text
QingLong：
STOPPED

AUTOSTART：
OFF
```

不得因为刷入模块而立即启动 QingLong。

---

## 第三原则：Action 管理

不制作 WebUI，不制作独立 App。

直接利用 Root 管理器的：

```text
模块
    ↓
执行 / Action
    ↓
Shell 菜单
    ↓
日志
```

完成管理。

---

## 第四原则：升级和降级必须支持指定版本

用户可以输入：

```text
2.20.2
```

也可以输入：

```text
2.21.0
```

系统自动判断：

```text
升级
```

或者：

```text
降级
```

并执行统一的版本切换流程。

---

## 第五原则：升级/降级不覆盖唯一版本

必须采用：

```text
versions/
├── 2.20.2/
├── 2.21.0/
└── ...

current → 目标版本
```

而不是：

```text
删除旧版本
↓
覆盖安装新版本
```

---

## 第六原则：升级/降级前备份

至少保护：

```text
database
config
```

并尽可能保留：

```text
scripts
Cookie
环境变量
logs
```

---

## 第七原则：升级/降级完成后不自动启动

无论：

```text
升级
```

还是：

```text
降级
```

完成后：

```text
QingLong = STOPPED
```

并明确提示：

```text
⚠️ 版本切换完成。
请重启手机后再使用 QingLong。
```

---

## 第八原则：失败必须可恢复

任何关键步骤失败：

```text
失败
 ↓
停止操作
 ↓
旧版本保持
 ↓
用户数据保持
 ↓
清理临时文件
 ↓
输出详细日志
```

必要时：

```text
自动回滚
```

---

## 第九原则：开机自启必须有保护

如果：

```text
AUTOSTART=1
```

但 QingLong 连续启动失败：

```text
启动失败
 ↓
有限次数重试
 ↓
仍然失败
 ↓
AUTOSTART=0
```

防止进入：

```text
启动循环
```

以及潜在的：

```text
Bootloop
```

---

## 第十原则：用户数据与程序分离

程序：

```text
/data/adb/qinglong/
```

用户数据：

```text
/data/adb/qinglong-data/
```

这样：

```text
QingLong 升级
≠
删除用户数据
```

并且：

```text
模块卸载
≠
删除用户数据
```

---

## 第十一原则：卸载默认保留数据

普通卸载：

```text
停止 QingLong
↓
删除模块
↓
保留用户数据
```

如果用户明确要求彻底删除：

```text
卸载并删除所有数据
```

必须二次确认。

---

## 第十二原则：日志必须详细

以下操作必须输出详细日志：

```text
模块刷入
启动
停止
重启
升级
降级
回滚
卸载
数据删除
存储统计
错误
```

并且：

```text
Cookie
Token
密码
API Key
Secret
```

等敏感信息必须脱敏。

---

## 第十三原则：轻量

不使用：

```text
WebUI
独立 App
Debian
Termux
常驻 Daemon
不必要的 Python
不必要的 Node.js 管理脚本
system 修改
vendor 修改
不必要 SELinux
initrc
```

模块自身管理逻辑尽量：

```text
Shell
+
BusyBox
```

完成。

---

## 第十四原则：最终架构

```text
                         Android
                            │
                       Root Manager
                            │
              ┌─────────────┼─────────────┐
              │             │             │
           Magisk        KernelSU     SukiSU Ultra
              │             │             │
              └─────────────┼─────────────┘
                            │
                    QingLong Module
                            │
              ┌─────────────┼─────────────┐
              │             │             │
          action.sh     service.sh   boot-completed.sh
              │             │             │
              └─────────────┼─────────────┘
                            │
                    QingLong Manager
                            │
        ┌─────────────┬─────┼─────┬─────────────┐
        │             │     │     │             │
       启动          停止   重启   信息          日志
        │             │     │     │             │
        └─────────────┴─────┼─────┴─────────────┘
                            │
                      Version Manager
                            │
                ┌───────────┼───────────┐
                │           │           │
              升级         降级         回滚
                │           │           │
                └───────────┼───────────┘
                            │
                    Safety Controller
                            │
       ┌────────────┬───────┼───────┬────────────┐
       │            │       │       │            │
     Backup       SHA256   Space   Lock       Rollback
       │            │       │       │            │
       └────────────┴───────┼───────┴────────────┘
                            │
                     QingLong Runtime
                            │
                         QingLong
                            │
                    QingLong User Data
```

---

# 最终结论

最终项目定位：

> **一个专门运行在 Android Root 环境中的轻量级 QingLong 模块。**

支持：

```text
Magisk
KernelSU
SukiSU Ultra
```

通过：

```text
Root Manager
    ↓
QingLong
    ↓
执行 / Action
```

完成：

```text
启动
停止
重启
开机自启
关闭自启
查看状态
查看版本
查看 Runtime
查看存储占用
查看日志
指定版本升级
指定版本降级
版本回滚
旧版本管理
```

并且具备：

```text
安装保护
启动保护
自启保护
升级保护
降级保护
SHA256 校验
磁盘空间检查
数据备份
失败回滚
操作锁
临时文件清理
敏感信息保护
安全卸载
数据删除二次确认
```

核心设计理念：

> **一次刷入，长期使用。**

> **默认不启动，用户手动控制。**

> **升级、降级均支持指定版本。**

> **升级、降级完成后保持停止，并提示重启。**

> **任何危险操作都有保护机制。**

> **程序与用户数据彻底分离。**

> **不使用 WebUI，不使用 Debian，不依赖 Termux，不增加不必要的常驻进程。**

> **在保证功能的前提下，尽可能做到轻量、安全、便捷、可恢复。**

---

## 文档结束

文件名：

```text
QingLong-Android-Module-Spec.md
```

建议项目位置：

```text
docs/QingLong-Android-Module-Spec.md
```