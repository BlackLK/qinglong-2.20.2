# -*- coding: utf-8 -*-
"""
青龙 Android Root 模块 - 用户数据统计 (db_stats.py)
只读查询 database.sqlite，输出文字表格式的用户数据计数。
由 manager/report.sh 调用。
"""
import sqlite3
import os

DB_PATH = "/data/adb/qinglong-data/db/database.sqlite"

# 表名 -> 中文说明
TABLES = [
    ("Crontabs",      "定时任务"),
    ("Envs",          "环境变量"),
    ("Dependences",   "面板依赖"),
    ("Apps",          "应用授权"),
    ("Subscriptions", "订阅仓库"),
]

def main():
    if not os.path.exists(DB_PATH):
        print("  %-22s %s" % ("数据库", "尚未初始化"))
        return
    try:
        con = sqlite3.connect("file:" + DB_PATH + "?mode=ro", uri=True)
    except Exception:
        print("  %-22s %s" % ("数据库", "无法读取"))
        return
    counts = {}
    for table, _ in TABLES:
        try:
            counts[table] = con.execute(
                'SELECT COUNT(*) FROM "%s"' % table).fetchone()[0]
        except Exception:
            counts[table] = 0
    con.close()

    # 用户账号: 尝试 User 表；无则从 Auths 用户名字段去重统计
    user_count = None
    for t in ("Users", "User"):
        try:
            user_count = con_count(con, t)
            break
        except Exception:
            pass
    if user_count is None:
        try:
            user_count = con.execute(
                "SELECT COUNT(DISTINCT username) FROM Auths").fetchone()[0]
        except Exception:
            user_count = 0

    rows = [("用户账号", "%d 个" % user_count)]
    for table, label in TABLES:
        rows.append((label, "%d 个" % counts[table]))

    for label, val in rows:
        print("  %-24s %6s" % (label, val))

def con_count(con, table):
    return con.execute('SELECT COUNT(*) FROM "%s"' % table).fetchone()[0]

if __name__ == "__main__":
    main()
