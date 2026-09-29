// ==============================================================================
// 青龙 Android Root 模块 - 本地 DNS 转发器 (dns_forwarder.js)
// 背景：glibc 程序（python/curl/wget/pip 等）做域名解析依赖 /etc/resolv.conf，
//       而 Android 根分区只读无法提供该文件。glibc 在缺失 resolv.conf 时会默认
//       使用 127.0.0.1 作为 DNS 服务器。本转发器监听 127.0.0.1:53 并将查询
//       转发至上游公共 DNS，使模块内所有 glibc 二进制的域名解析恢复正常。
// ==============================================================================
"use strict";
const dgram = require("dgram");

const PORT = 53;
const HOST = "127.0.0.1";
const UPSTREAMS = ["223.5.5.5", "119.29.29.29"]; // 阿里 DNS / 腾讯 DNS

// reuseAddr: 双方都设 SO_REUSEADDR 时 Linux 允许 wildcard+具体地址共存绑定,
// 避免与系统热点的 dnsmasq (0.0.0.0:53) 冲突导致热点开启后自动关闭
const server = dgram.createSocket({ type: "udp4", reuseAddr: true });
let upIdx = 0;

server.on("message", (msg, rinfo) => {
    const targets = [];
    // 主选 + 全部备用都发一遍，最先到达者胜出（简单可靠）
    targets.push(UPSTREAMS[upIdx % UPSTREAMS.length]);
    UPSTREAMS.forEach((u) => { if (!targets.includes(u)) targets.push(u); });
    upIdx++;

    let settled = false;
    targets.forEach((up) => {
        const client = dgram.createSocket("udp4");
        const timer = setTimeout(() => {
            if (!settled) { /* keep waiting for others */ }
            try { client.close(); } catch (e) {}
        }, 4000);
        client.on("message", (answer) => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            try { client.close(); } catch (e) {}
            server.send(answer, rinfo.port, rinfo.address);
        });
        client.on("error", () => {
            clearTimeout(timer);
            try { client.close(); } catch (e) {}
        });
        client.send(msg, 53, up, (err) => {
            if (err) { clearTimeout(timer); try { client.close(); } catch (e) {} }
        });
    });
});

server.on("error", (err) => {
    console.error("[dns-forwarder] error:", err.message);
    process.exit(1);
});

server.bind(PORT, HOST, () => {
    console.log(`[dns-forwarder] listening on ${HOST}:${PORT} -> ${UPSTREAMS.join(", ")}`);
});
