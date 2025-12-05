#!/usr/bin/env python3
"""
数据库模块 - 使用 SQLite 持久化历史记录
所有用户共享同一份历史记录
"""

import sqlite3
import json
import time
from pathlib import Path
from typing import Optional, List, Dict, Any
from contextlib import contextmanager
import threading

# 数据库文件路径
DB_PATH = Path("output/pet_motion_lab.db")


class Database:
    """SQLite 数据库管理器"""
    
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
        self._init_database()
    
    def _get_connection(self) -> sqlite3.Connection:
        """获取当前线程的数据库连接"""
        if not hasattr(self._local, 'connection') or self._local.connection is None:
            DB_PATH.parent.mkdir(parents=True, exist_ok=True)
            self._local.connection = sqlite3.connect(str(DB_PATH), check_same_thread=False)
            self._local.connection.row_factory = sqlite3.Row
        return self._local.connection
    
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
            
            # 创建索引
            cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_status ON generation_history(status)
            ''')
            cursor.execute('''
                CREATE INDEX IF NOT EXISTS idx_created_at ON generation_history(created_at DESC)
            ''')
            
        print("✅ 数据库初始化完成")
    
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
        except sqlite3.IntegrityError:
            # pet_id 已存在，更新
            return self.update_task(pet_id, status='initialized', progress=0, 
                                   message='任务已创建', breed=breed, color=color,
                                   species=species, weight=weight, birthday=birthday)
    
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
            return cursor.rowcount > 0
        except Exception as e:
            print(f"❌ 更新任务失败: {e}")
            return False
    
    def get_task(self, pet_id: str) -> Optional[Dict[str, Any]]:
        """获取任务详情"""
        with self.get_cursor() as cursor:
            cursor.execute('SELECT * FROM generation_history WHERE pet_id = ?', (pet_id,))
            row = cursor.fetchone()
            if row:
                return self._row_to_dict(row)
        return None
    
    def get_all_tasks(self, status_filter: str = '', page: int = 1, 
                      page_size: int = 20) -> tuple[List[Dict], int]:
        """获取所有任务列表"""
        offset = (page - 1) * page_size
        
        with self.get_cursor() as cursor:
            # 获取总数
            if status_filter:
                cursor.execute('SELECT COUNT(*) FROM generation_history WHERE status = ?', 
                             (status_filter,))
            else:
                cursor.execute('SELECT COUNT(*) FROM generation_history')
            total = cursor.fetchone()[0]
            
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
    
    def delete_task(self, pet_id: str) -> bool:
        """删除任务"""
        with self.get_cursor() as cursor:
            cursor.execute('DELETE FROM generation_history WHERE pet_id = ?', (pet_id,))
            return cursor.rowcount > 0
    
    def _row_to_dict(self, row: sqlite3.Row) -> Dict[str, Any]:
        """将数据库行转换为字典"""
        d = dict(row)
        # 解析 JSON 字段
        if 'results' in d and d['results']:
            try:
                d['results'] = json.loads(d['results'])
            except:
                d['results'] = {}
        if 'metadata' in d and d['metadata']:
            try:
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

