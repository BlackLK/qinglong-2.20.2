// ==============================================================================
// 青龙 Android Root 模块 - Winston 兼容性 preload (preload-winston.js)
// 通过 NODE_OPTIONS=--require 注入到所有 node 进程（含 cron 子进程），保证对
// 顶层 winston 实例挂载 DailyRotateFile。
// 背景：winston-daily-rotate-file 处于 .pnpm 隔离目录，内部 require('winston')
//       解析到自己的 winston 副本，副作用无法挂到 logger 实际使用的顶层实例，
//       导致报 "DailyRotateFile is not a constructor"。此处显式挂载到顶层实例。
// ==============================================================================
try {
    const topWinston = require("winston");
    topWinston.transports.DailyRotateFile = require("winston-daily-rotate-file");
} catch (e) {
    // 交给后续实际 logger 加载时报错提示
}