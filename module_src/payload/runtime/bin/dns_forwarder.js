// ==============================================================================
// 青龙 Android Root 模块 - 本地 DNS 转发器 (dns_forwarder.js)
// 背景：glibc 程序（python/curl/wget/pip 等）做域名解析依赖 /etc/resolv.conf，
//       而 Android 根分区只读。v1.0.31 起 systemless 部署 /system/etc/resolv.conf
//       指向 127.0.0.2 (专属回环地址)；未生效的旧安装则 fallback 到 glibc 默认
//       的 127.0.0.1。
//
// v1.0.31 关键改动（修复用户反馈：开热点后面板 DNS 全部超时）：
//   - 双地址绑定：127.0.0.2:53 (专属, 首选) + 127.0.0.1:53 (兼容 fallback)
//   - 127.0.0.2 位于 loopback /8 段内, 系统 dnsmasq (热点) 永远不会绑定该地址,
//     与系统 53 端口服务物理隔离, 彻底消除端口争抢
//   - 127.0.0.1 绑定失败 (EADDRINUSE, 如 dnsmasq 未设 SO_REUSEADDR) 时自动重试,
//     不再影响 127.0.0.2 主通道
// ==============================================================================
"use strict";
const dgram = require("dgram");

const PORT = 53;
// 127.0.0.2: 专属通道 (resolv.conf systemless 部署后 glibc 直查此地址)
// 127.0.0.1: 兼容通道 (glibc 无 resolv.conf 时的默认查询地址)
const HOSTS = ["127.0.0.2", "127.0.0.1"];
const UPSTREAMS = ["223.5.5.5", "119.29.29.29"]; // 阿里 DNS / 腾讯 DNS

let upIdx = 0;

// 统一的查询处理: 主选 + 全部备用都发一遍, 最先到达者胜出
function handleMessage(msg, rinfo) {
    const targets = [];
    targets.push(UPSTREAMS[upIdx % UPSTREAMS.length]);
    UPSTREAMS.forEach((u) => { if (!targets.includes(u)) targets.push(u); });
    upIdx++;

    let settled = false;
    targets.forEach((up) => {
        const client = dgram.createSocket("udp4");
        const timer = setTimeout(() => {
            try { client.close(); } catch (e) {}
        }, 4000);
        client.on("message", (answer) => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            try { client.close(); } catch (e) {}
            // 回包给查询者 (经哪个 socket 收到无所谓, 源地址都是本机回环)
            servers.forEach((s) => {
                try { s.send(answer, rinfo.port, rinfo.address); } catch (e) {}
            });
        });
        client.on("error", () => {
            clearTimeout(timer);
            try { client.close(); } catch (e) {}
        });
        client.send(msg, 53, up, (err) => {
            if (err) { clearTimeout(timer); try { client.close(); } catch (e) {} }
        });
    });
}

const servers = [];
const bound = [];

function bindWithRetry(host, attempts) {
    return new Promise((resolve) => {
        const tryOnce = (left) => {
            const s = dgram.createSocket({ type: "udp4", reuseAddr: true });
            s.on("message", handleMessage);
            s.on("error", (err) => {
                const retryable = err.code === "EADDRINUSE" && left > 0;
                console.error(`[dns-forwarder] bind ${host}:${PORT} failed: ${err.code}` +
                    (retryable ? `, retry in 2s (${left} left)` : ""));
                try { s.close(); } catch (e) {}
                if (retryable) return setTimeout(() => tryOnce(left - 1), 2000);
                resolve(false);
            });
            s.bind(PORT, host, () => {
                console.log(`[dns-forwarder] listening on ${host}:${PORT} -> ${UPSTREAMS.join(", ")}`);
                servers.push(s);
                resolve(true);
            });
        };
        tryOnce(attempts);
    });
}

(async () => {
    // 127.0.0.2 专属通道: 绑定失败视为致命 (无人会占用, 失败说明环境异常)
    const main = await bindWithRetry(HOSTS[0], 1);
    // 127.0.0.1 兼容通道: 可能被 dnsmasq 短暂占用, 重试 5 次
    const compat = await bindWithRetry(HOSTS[1], 5);
    if (!main && !compat) {
        console.error("[dns-forwarder] FATAL: all bind attempts failed, exiting");
        process.exit(1);
    }
    bound.push(...(main ? [HOSTS[0]] : []), ...(compat ? [HOSTS[1]] : []));
    console.log(`[dns-forwarder] ready on [${bound.join(", ")}]` +
        (main && !compat ? " (compat port busy by system service, main channel active)" : ""));
})();
