#!/usr/bin/env python3
"""
数据库模块 - 支持本地 SQLite 和云端 Turso
所有用户共享同一份历史记录
"""

import json
import time
import os
import sqlite3
from pathlib import Path
from typing import Optional, List, Dict, Any
from contextlib import contextmanager
import threading

# 检查是否使用 Turso 云数据库
TURSO_DATABASE_URL = os.environ.get("TURSO_DATABASE_URL", "")
TURSO_AUTH_TOKEN = os.environ.get("TURSO_AUTH_TOKEN", "")

# 本地数据库文件路径（备用）
LOCAL_DB_PATH = Path("output/pet_motion_lab.db")

# 是否使用 Turso
USE_TURSO = bool(TURSO_DATABASE_URL and TURSO_AUTH_TOKEN)

# 启动时打印数据库配置（调试用）
print(f"🔧 数据库配置检查:")
print(f"   TURSO_DATABASE_URL: {'已设置 (' + TURSO_DATABASE_URL[:50] + '...)' if TURSO_DATABASE_URL else '❌ 未设置'}")
print(f"   TURSO_AUTH_TOKEN: {'已设置 (长度: ' + str(len(TURSO_AUTH_TOKEN)) + ')' if TURSO_AUTH_TOKEN else '❌ 未设置'}")
print(f"   USE_TURSO: {USE_TURSO}")


class TursoConnection:
    """Turso 数据库连接包装器（使用 libsql_client HTTP API）"""
    
    def __init__(self, url: str, auth_token: str):
        import libsql_client
        
        # 转换 URL 格式：libsql:// -> https://
        if url.startswith("libsql://"):
            url = url.replace("libsql://", "https://")
        
        self.client = libsql_client.create_client_sync(
            url=url,
            auth_token=auth_token
        )
        print(f"✅ Turso 连接已创建: {url[:50]}...")
    
    def cursor(self):
        return TursoCursor(self.client)
    
    def commit(self):
        # libsql_client 自动提交
        pass
    
    def rollback(self):
        # libsql_client 不支持显式回滚
        pass
    
    def close(self):
        self.client.close()


class TursoCursor:
    """Turso 游标包装器"""
    
    def __init__(self, client):
        self.client = client
        self._result = None
        self._rows = []
        self._index = 0
    
    def execute(self, sql: str, params: tuple = None):
        # 将 ? 占位符转换为 libsql_client 格式
        if params:
            # libsql_client 使用位置参数
            self._result = self.client.execute(sql, list(params))
        else:
            self._result = self.client.execute(sql)
        
        self._rows = self._result.rows if self._result else []
        self._index = 0
        return self
    
    def fetchone(self):
        if self._index < len(self._rows):
            row = self._rows[self._index]
            self._index += 1
            return row
        return None
    
    def fetchall(self):
        return self._rows


def get_db_connection():
    """获取数据库连接（自动选择 Turso 或本地 SQLite）"""
    if USE_TURSO:
        try:
            print(f"🔗 正在连接 Turso...")
            conn = TursoConnection(TURSO_DATABASE_URL, TURSO_AUTH_TOKEN)
            
            # 测试连接
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            print(f"✅ Turso 连接测试成功: {result}")
            
            return conn
        except ImportError as e:
            print(f"❌ libsql_client 导入失败: {e}")
            print(f"⚠️ 回退到本地 SQLite 数据库")
        except Exception as e:
            print(f"❌ Turso 连接失败: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            print(f"⚠️ 回退到本地 SQLite 数据库")
        
        # 回退到本地数据库
        LOCAL_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(str(LOCAL_DB_PATH), check_same_thread=False)
        conn.row_factory = sqlite3.Row
        return conn
    else:
        LOCAL_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(str(LOCAL_DB_PATH), check_same_thread=False)
        conn.row_factory = sqlite3.Row
        print(f"📁 已连接到本地数据库: {LOCAL_DB_PATH}")
        return conn


class Database:
    """数据库管理器 - 支持 Turso 和本地 SQLite"""
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        self._local = threading.local()
        self._connection = None
        self._init_database()
    
    def _get_connection(self):
        """获取数据库连接"""
        if self._connection is None:
            self._connection = get_db_connection()
        return self._connection
    
    @contextmanager
    def get_cursor(self):
        """获取数据库游标的上下文管理器"""
        conn = self._get_connection()
        cursor = conn.cursor()
        try:
            yield cursor
            conn.commit()
        except Exception as e:
            conn.rollback()
            raise e
    
    def _init_database(self):
        """初始化数据库表"""
        try:
            with self.get_cursor() as cursor:
                # 创建历史记录表
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS generation_history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        pet_id TEXT UNIQUE NOT NULL,
                        breed TEXT DEFAULT '',
                        color TEXT DEFAULT '',
                        species TEXT DEFAULT '',
                        weight TEXT DEFAULT '',
                        birthday TEXT DEFAULT '',
                        status TEXT DEFAULT 'initialized',
                        progress INTEGER DEFAULT 0,
                        message TEXT DEFAULT '',
                        current_step TEXT DEFAULT '',
                        results TEXT DEFAULT '{}',
                        metadata TEXT DEFAULT '{}',
                        created_at REAL NOT NULL,
                        updated_at REAL NOT NULL,
                        started_at REAL,
                        completed_at REAL
                    )
                ''')
                
                # 创建索引（Turso 兼容语法）
                cursor.execute('''
                    CREATE INDEX IF NOT EXISTS idx_status ON generation_history(status)
                ''')
                cursor.execute('''
                    CREATE INDEX IF NOT EXISTS idx_created_at ON generation_history(created_at DESC)
                ''')
            
            db_type = "Turso 云数据库" if USE_TURSO else "本地 SQLite"
            print(f"✅ 数据库初始化完成 ({db_type})")
        except Exception as e:
            print(f"⚠️ 数据库初始化警告: {e}")
            import traceback
            traceback.print_exc()
    
    def create_task(self, pet_id: str, breed: str = '', color: str = '', 
                    species: str = '', weight: str = '', birthday: str = '') -> bool:
        """创建新任务"""
        now = time.time()
        try:
            with self.get_cursor() as cursor:
                cursor.execute('''
                    INSERT INTO generation_history 
                    (pet_id, breed, color, species, weight, birthday, status, progress, 
                     message, created_at, updated_at, results)
                    VALUES (?, ?, ?, ?, ?, ?, 'initialized', 0, '任务已创建', ?, ?, '{}')
                ''', (pet_id, breed, color, species, weight, birthday, now, now))
            return True
        except Exception as e:
            if 'UNIQUE constraint' in str(e) or 'IntegrityError' in str(e):
                # pet_id 已存在，更新
                return self.update_task(pet_id, status='initialized', progress=0, 
                                       message='任务已创建', breed=breed, color=color,
                                       species=species, weight=weight, birthday=birthday)
            print(f"❌ 创建任务失败: {e}")
            return False
    
    def update_task(self, pet_id: str, **kwargs) -> bool:
        """更新任务状态"""
        if not kwargs:
            return False
        
        kwargs['updated_at'] = time.time()
        
        # 处理 results 字段（需要 JSON 序列化）
        if 'results' in kwargs and isinstance(kwargs['results'], dict):
            kwargs['results'] = json.dumps(kwargs['results'], ensure_ascii=False)
        
        if 'metadata' in kwargs and isinstance(kwargs['metadata'], dict):
            kwargs['metadata'] = json.dumps(kwargs['metadata'], ensure_ascii=False)
        
        set_clause = ', '.join([f'{k} = ?' for k in kwargs.keys()])
        values = list(kwargs.values()) + [pet_id]
        
        try:
            with self.get_cursor() as cursor:
                cursor.execute(f'''
                    UPDATE generation_history SET {set_clause} WHERE pet_id = ?
                ''', values)
            return True
        except Exception as e:
            print(f"❌ 更新任务失败: {e}")
            return False
    
    def get_task(self, pet_id: str) -> Optional[Dict[str, Any]]:
        """获取任务详情"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute('SELECT * FROM generation_history WHERE pet_id = ?', (pet_id,))
                row = cursor.fetchone()
                if row:
                    return self._row_to_dict(row)
        except Exception as e:
            print(f"❌ 获取任务失败: {e}")
        return None
    
    def get_all_tasks(self, status_filter: str = '', page: int = 1, 
                      page_size: int = 20) -> tuple[List[Dict], int]:
        """获取所有任务列表"""
        offset = (page - 1) * page_size
        
        try:
            with self.get_cursor() as cursor:
                # 获取总数
                if status_filter:
                    cursor.execute('SELECT COUNT(*) FROM generation_history WHERE status = ?', 
                                 (status_filter,))
                else:
                    cursor.execute('SELECT COUNT(*) FROM generation_history')
                result = cursor.fetchone()
                total = result[0] if result else 0
                
                # 获取分页数据
                if status_filter:
                    cursor.execute('''
                        SELECT * FROM generation_history 
                        WHERE status = ? 
                        ORDER BY created_at DESC 
                        LIMIT ? OFFSET ?
                    ''', (status_filter, page_size, offset))
                else:
                    cursor.execute('''
                        SELECT * FROM generation_history 
                        ORDER BY created_at DESC 
                        LIMIT ? OFFSET ?
                    ''', (page_size, offset))
                
                rows = cursor.fetchall()
                items = [self._row_to_dict(row) for row in rows]
            
            return items, total
        except Exception as e:
            print(f"❌ 获取任务列表失败: {e}")
            import traceback
            traceback.print_exc()
            return [], 0
    
    def delete_task(self, pet_id: str) -> bool:
        """删除任务"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute('DELETE FROM generation_history WHERE pet_id = ?', (pet_id,))
            return True
        except Exception as e:
            print(f"❌ 删除任务失败: {e}")
            return False
    
    def _row_to_dict(self, row) -> Dict[str, Any]:
        """将数据库行转换为字典"""
        columns = ['id', 'pet_id', 'breed', 'color', 'species', 'weight', 'birthday',
                  'status', 'progress', 'message', 'current_step', 'results', 
                  'metadata', 'created_at', 'updated_at', 'started_at', 'completed_at']
        
        # 兼容不同返回格式
        if hasattr(row, 'keys'):
            # sqlite3.Row
            d = dict(row)
        elif isinstance(row, (list, tuple)):
            # Turso 或普通元组
            d = dict(zip(columns, row))
        else:
            d = dict(row)
        
        # 解析 JSON 字段
        if 'results' in d and d['results']:
            try:
                if isinstance(d['results'], str):
                    d['results'] = json.loads(d['results'])
            except:
                d['results'] = {}
        if 'metadata' in d and d['metadata']:
            try:
                if isinstance(d['metadata'], str):
                    d['metadata'] = json.loads(d['metadata'])
            except:
                d['metadata'] = {}
        return d


# 全局数据库实例
db = Database()


# 便捷函数
def create_task(pet_id: str, **kwargs) -> bool:
    return db.create_task(pet_id, **kwargs)

def update_task(pet_id: str, **kwargs) -> bool:
    return db.update_task(pet_id, **kwargs)

def get_task(pet_id: str) -> Optional[Dict[str, Any]]:
    return db.get_task(pet_id)

def get_all_tasks(status_filter: str = '', page: int = 1, 
                  page_size: int = 20) -> tuple[List[Dict], int]:
    return db.get_all_tasks(status_filter, page, page_size)

def delete_task(pet_id: str) -> bool:
    return db.delete_task(pet_id)


# 打印当前数据库配置
if __name__ == "__main__":
    print(f"🔧 数据库配置:")
    print(f"   USE_TURSO: {USE_TURSO}")
    print(f"   TURSO_DATABASE_URL: {TURSO_DATABASE_URL[:30]}..." if TURSO_DATABASE_URL else "   TURSO_DATABASE_URL: (未设置)")
    print(f"   LOCAL_DB_PATH: {LOCAL_DB_PATH}")
