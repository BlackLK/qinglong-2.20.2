"use strict";
// ==============================================================================
// 青龙 Android Root 模块 - 单进程启动器 (app_single.js)
// 作用：绕开 app.js 的 cluster 多进程编排，在同一进程内启动 gRPC(5500) + HTTP(5700)
// 原因：Android 上经 ld-linux 间接启动 node 时，cluster worker 的 IPC 无法建立，
//       net.listen 会走 cluster._getServer 分支导致 TypeError 死循环（worker 反复重启）。
//       保持 cluster.isPrimary = true（默认），使 node:net 直接本地监听，彻底避开该问题。
// ==============================================================================
// 修复 winston.transports.DailyRotateFile 未挂载：
// winston-daily-rotate-file 位于 .pnpm 隔离目录，其内部 require('winston') 解析到
// 自己的 winston 副本，副作用挂到副本，导致顶层 winston.transports.DailyRotateFile
// 为 undefined（logger 报 "DailyRotateFile is not a constructor"）。在此显式挂载到
// logger 实际使用的顶层 winston 实例。
try {
    var topWinston = require("winston");
    var DRF = require("winston-daily-rotate-file");
    topWinston.transports.DailyRotateFile = DRF;
} catch (e) { /* 交由后续 logger 加载报错 */ }
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) result[k] = mod[k];
    __importStar_default(result, mod);
    return result;
};
function __importStar_default(result, mod) { result["default"] = mod["default"] || mod; }
require("reflect-metadata");
const cors_1 = __importDefault(require("cors"));
const compression_1 = __importDefault(require("compression"));
const helmet_1 = __importDefault(require("helmet"));
const express_1 = __importDefault(require("express"));
const typedi_1 = require("typedi");
const config_1 = __importDefault(require("./config"));
const logger_1 = __importDefault(require("./loaders/logger"));

// 捕获未处理异常，防止静默崩溃
process.on("uncaughtException", (err) => {
    logger_1.default.error("single: uncaughtException:", err);
});
process.on("unhandledRejection", (err) => {
    logger_1.default.error("single: unhandledRejection:", err);
});

async function start() {
    try {
        logger_1.default.info("single: initializing DB");
        const dbLoader = await Promise.resolve().then(() => __importStar(require("./loaders/db")));
        await dbLoader.default();

        // ---- gRPC service (5500) ----
        logger_1.default.info("single: starting gRPC");
        const { GrpcServerService } = require("./services/grpc");
        const grpcServer = typedi_1.Container.get(GrpcServerService);
        await grpcServer.initialize();

        // ---- HTTP service (5700) ----
        logger_1.default.info("single: starting HTTP");
        const app = express_1.default();
        app.use((req, res, next) => {
            if (req.query.t) { delete req.query.t; }
            next();
        });
        const { monitoringMiddleware } = require("./middlewares/monitoring");
        app.use(helmet_1.default({ contentSecurityPolicy: false }));
        app.use(cors_1.default(config_1.default.cors));
        app.use(compression_1.default());
        app.use(monitoringMiddleware);

        const { HttpServerService } = require("./services/http");
        const httpServer = typedi_1.Container.get(HttpServerService);
        const appLoader = await Promise.resolve().then(() => __importStar(require("./loaders/app")));
        await appLoader.default({ app });
        const server = await httpServer.initialize(app, config_1.default.port);
        const serverLoader = await Promise.resolve().then(() => __importStar(require("./loaders/server")));
        await serverLoader.default({ server });

        logger_1.default.info("single: ALL SERVICES READY");
        const onExit = () => {
            Promise.allSettled([grpcServer.shutdown(), httpServer.shutdown()]).finally(() => process.exit(0));
        };
        process.on("SIGTERM", onExit);
        process.on("SIGINT", onExit);
    } catch (error) {
        logger_1.default.error("single: FAILED to start:", error);
        process.exit(1);
    }
}
start();