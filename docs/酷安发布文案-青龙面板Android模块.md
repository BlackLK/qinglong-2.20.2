 2.20.2青龙模块
 搞了一个比较新的青龙模块，现在已经测试得比较全了。对应 NodeJS、Python 3 部分Linux这些依赖安装都没问题，我自己也试了一下。
测试是在SukiSU Ultra上面测试的,其他的这个root管理器我就没有测了，测试设备联想y700四代。
这个青龙面板，我是拿的qinglong-2.20.2-debian-arm64.tar的这个包改的，去掉了这个debian,所以可能有些Linux一些依赖就安装不了。
在管理器里点一下「执行」按钮就能启动面板，再点一下就停止。启动的时候会自动把开机自启也打开，还会顺便显示一份占用情况，内存吃了多少、磁盘用了多少，一目了然。
网络也是通的。Android 上没有标准 DNS 和证书，这类程序默认连不上网，我都处理好了，HTTPS 访问正常，GitHub 也能直连。
面板和数据是分开装的，装完之后路径在这两个地方：
- 面板程序：/data/adb/qinglong（程序本体、前端、运行环境都在这）
- 用户数据：/data/adb/qinglong-data（脚本、定时任务、环境变量、数据库、配置、日志，还有你自己装的 NodeJS 和 Python3 依赖，全都在这）
装好之后浏览器访问 http://设备IP:5700 就能打开面板。
所以以后卸载重刷模块，数据和任务都不会丢，如果需要清除数据，你需要手动去把这个目录删掉，或者安装我的这个清除数据的辅助模块，可以直接通过运行这个辅助模块删除这个数据。
QingLong-Android-Root-Module-v1.0.13.zip 这个是青龙模块 
QingLong-DataWipe-v1.0.4.zip 这个是清除数据的辅助模块（可选，不装后续自己去删除/data/adb/qinglong-data）
模块下载地址：https://github.com/BlackLK/qinglong-2.20.2/releases/tag/v1.0.13

