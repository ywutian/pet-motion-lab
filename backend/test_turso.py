#!/usr/bin/env python3
"""
测试 Turso 数据库连接
运行方式: 
  export TURSO_DATABASE_URL="libsql://xxx.turso.io"
  export TURSO_AUTH_TOKEN="你的token"
  python test_turso.py
"""

import os
import sys

# 从环境变量读取
TURSO_DATABASE_URL = os.environ.get("TURSO_DATABASE_URL", "")
TURSO_AUTH_TOKEN = os.environ.get("TURSO_AUTH_TOKEN", "")

print("=" * 60)
print("🔧 Turso 连接测试 (使用 libsql_client)")
print("=" * 60)
print()

# 检查环境变量
print("1️⃣ 检查环境变量:")
print(f"   TURSO_DATABASE_URL: {TURSO_DATABASE_URL if TURSO_DATABASE_URL else '❌ 未设置'}")
print(f"   TURSO_AUTH_TOKEN: {'✅ 已设置 (长度: ' + str(len(TURSO_AUTH_TOKEN)) + ')' if TURSO_AUTH_TOKEN else '❌ 未设置'}")
print()

if not TURSO_DATABASE_URL or not TURSO_AUTH_TOKEN:
    print("❌ 请先设置环境变量!")
    print()
    print("示例:")
    print('  export TURSO_DATABASE_URL="libsql://your-db-name.turso.io"')
    print('  export TURSO_AUTH_TOKEN="your-auth-token"')
    sys.exit(1)

# 尝试导入 libsql_client
print("2️⃣ 检查 libsql_client 模块:")
try:
    import libsql_client
    print(f"   ✅ libsql_client 已安装")
except ImportError as e:
    print(f"   ❌ 导入失败: {e}")
    print("   请运行: pip install libsql-client")
    sys.exit(1)
print()

# 转换 URL
url = TURSO_DATABASE_URL
if url.startswith("libsql://"):
    url = url.replace("libsql://", "https://")
print(f"3️⃣ 转换 URL: {url}")
print()

# 尝试连接
print("4️⃣ 尝试连接 Turso:")
try:
    client = libsql_client.create_client_sync(
        url=url,
        auth_token=TURSO_AUTH_TOKEN
    )
    print(f"   ✅ 连接成功!")
except Exception as e:
    print(f"   ❌ 连接失败: {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
print()

# 测试查询
print("5️⃣ 测试查询:")
try:
    result = client.execute("SELECT 1 as test")
    print(f"   ✅ 查询成功: {result.rows}")
except Exception as e:
    print(f"   ❌ 查询失败: {e}")
    sys.exit(1)
print()

# 创建测试表
print("6️⃣ 测试创建表:")
try:
    client.execute('''
        CREATE TABLE IF NOT EXISTS test_connection (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT,
            created_at REAL
        )
    ''')
    print(f"   ✅ 创建表成功!")
except Exception as e:
    print(f"   ❌ 创建表失败: {e}")
print()

# 插入测试数据
print("7️⃣ 测试插入数据:")
import time
try:
    client.execute(
        "INSERT INTO test_connection (message, created_at) VALUES (?, ?)",
        ["Hello from test script!", time.time()]
    )
    print(f"   ✅ 插入成功!")
except Exception as e:
    print(f"   ❌ 插入失败: {e}")
print()

# 查询数据
print("8️⃣ 测试查询数据:")
try:
    result = client.execute("SELECT * FROM test_connection ORDER BY id DESC LIMIT 5")
    print(f"   ✅ 查询到 {len(result.rows)} 条记录:")
    for row in result.rows:
        print(f"      {row}")
except Exception as e:
    print(f"   ❌ 查询失败: {e}")
print()

# 关闭连接
client.close()

print("=" * 60)
print("✅ 所有测试通过! Turso 连接正常")
print("=" * 60)
