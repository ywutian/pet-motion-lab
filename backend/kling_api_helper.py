#!/usr/bin/env python3
"""
可灵AI API 封装
支持文生图和图生图功能
使用JWT认证方式
"""

import requests
import json
import time
import jwt
from pathlib import Path


class KlingAPI:
    """可灵AI API封装类"""
    
    # API 端点
    BASE_URL_CN = "https://api-beijing.klingai.com"  # 国内版
    BASE_URL_GLOBAL = "https://api.klingai.com"      # 海外版

    def __init__(self, access_key: str, secret_key: str, 
                 video_access_key: str = None, video_secret_key: str = None):
        """
        初始化可灵API
        
        Args:
            access_key: 图片API的Access Key（国内版）
            secret_key: 图片API的Secret Key（国内版）
            video_access_key: 视频API的Access Key（海外版），如果不提供则使用图片API的密钥
            video_secret_key: 视频API的Secret Key（海外版），如果不提供则使用图片API的密钥
        """
        # 图片API凭证（国内版）
        self.access_key = access_key
        self.secret_key = secret_key
        self.base_url = self.BASE_URL_CN
        
        # 视频API凭证（海外版）
        self.video_access_key = video_access_key or access_key
        self.video_secret_key = video_secret_key or secret_key

        # 调试信息
        if not self.access_key:
            print("❌ 错误: 图片API access_key 为空！")
        else:
            print(f"✅ 图片API access_key 已设置: {self.access_key[:10]}...")

        if not self.secret_key:
            print("❌ 错误: 图片API secret_key 为空！")
        else:
            print(f"✅ 图片API secret_key 已设置: {self.secret_key[:10]}...")
            
        if self.video_access_key != self.access_key:
            print(f"✅ 视频API access_key 已设置（海外版）: {self.video_access_key[:10]}...")
            print(f"✅ 视频API secret_key 已设置（海外版）: {self.video_secret_key[:10]}...")

    def _encode_jwt_token(self, for_video: bool = False) -> str:
        """
        生成JWT Token（遵循可灵AI官方文档）
        
        Args:
            for_video: 是否为视频API生成token（使用海外版凭证）
        """
        ak = self.video_access_key if for_video else self.access_key
        sk = self.video_secret_key if for_video else self.secret_key
        
        headers = {
            "alg": "HS256",
            "typ": "JWT"
        }
        payload = {
            "iss": ak,
            "exp": int(time.time()) + 1800,  # 有效时间：当前时间+1800s(30min)
            "nbf": int(time.time()) - 5  # 开始生效的时间：当前时间-5秒
        }

        # 调试信息
        api_type = "视频API（海外版）" if for_video else "图片API（国内版）"
        print(f"🔐 生成JWT Token ({api_type}):")
        print(f"   iss (access_key): {ak[:10] if ak else 'EMPTY'}...")
        print(f"   secret_key: {sk[:10] if sk else 'EMPTY'}...")

        token = jwt.encode(payload, sk, headers=headers)
        return token

    def _get_auth_headers(self, for_video: bool = False) -> dict:
        """获取认证头"""
        api_token = self._encode_jwt_token(for_video=for_video)
        return {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {api_token}'
        }
    
    def text_to_image(
        self,
        prompt: str,
        negative_prompt: str = "",
        aspect_ratio: str = "1:1",
        image_count: int = 1,
    ) -> dict:
        """
        文生图API
        
        Args:
            prompt: 正向提示词
            negative_prompt: 负向提示词
            aspect_ratio: 宽高比 (1:1, 16:9, 9:16等)
            image_count: 生成图片数量
        
        Returns:
            包含task_id的字典
        """
        url = f"{self.base_url}/v1/images/generations"
        headers = self._get_auth_headers()
        
        payload = {
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "aspect_ratio": aspect_ratio,
            "image_count": image_count,
        }
        
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            # 提取task_id
            if 'data' in data and 'task_id' in data['data']:
                return {'task_id': data['data']['task_id']}
            elif 'task_id' in data:
                return {'task_id': data['task_id']}
            else:
                raise Exception(f"响应中未找到task_id: {data}")
        else:
            raise Exception(f"API请求失败: {response.status_code} - {response.text}")
    
    def query_task(self, task_id: str) -> dict:
        """
        查询任务状态
        
        Args:
            task_id: 任务ID
        
        Returns:
            任务状态信息
        """
        url = f"{self.base_url}/v1/images/generations/{task_id}"
        headers = self._get_auth_headers()
        
        response = requests.get(url, headers=headers, timeout=30)
        
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"查询任务失败: {response.status_code} - {response.text}")
    
    def wait_for_task(self, task_id: str, max_wait_seconds: int = 300, poll_interval: int = 5) -> dict:
        """
        等待任务完成

        Args:
            task_id: 任务ID
            max_wait_seconds: 最大等待时间（秒）
            poll_interval: 轮询间隔（秒）

        Returns:
            完成的任务信息
        """
        start_time = time.time()
        retry_count = 0

        while time.time() - start_time < max_wait_seconds:
            retry_count += 1

            task_data = self.query_task(task_id)

            # 提取状态
            status = None
            if 'data' in task_data and 'task_status' in task_data['data']:
                status = task_data['data']['task_status']
            elif 'status' in task_data:
                status = task_data['status']

            print(f"  查询 #{retry_count}: 状态={status}")

            # 检查是否完成
            if status in ['succeed', 'completed', 'success']:
                return task_data
            elif status in ['failed', 'error']:
                error_msg = task_data.get('message', '未知错误')
                raise Exception(f"任务失败: {error_msg}")

            # 等待后继续轮询
            time.sleep(poll_interval)

        raise Exception(f"任务超时（{max_wait_seconds}秒）")

    def image_to_image(
        self,
        image_path: str,
        prompt: str,
        negative_prompt: str = "",
        aspect_ratio: str = "1:1",
        image_count: int = 1,
    ) -> dict:
        """
        图生图API (使用kling-v2模型)

        Args:
            image_path: 输入图片路径
            prompt: 正向提示词
            negative_prompt: 负向提示词
            aspect_ratio: 宽高比 (1:1, 16:9, 4:3, 3:2, 2:3, 3:4, 9:16, 21:9)
            image_count: 生成图片数量

        Returns:
            包含task_id的字典
        """
        # 创建图生图任务（kling-v2模型）
        url = f"{self.base_url}/v1/images/generations"
        headers = self._get_auth_headers()

        # 读取图片并转换为base64
        import base64
        with open(image_path, 'rb') as f:
            image_data = f.read()
            image_base64 = base64.b64encode(image_data).decode('utf-8')

        print(f"  📤 图片已编码为base64，大小: {len(image_base64)} 字符")

        payload = {
            "model_name": "kling-v2",
            "image": image_base64,
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "aspect_ratio": aspect_ratio,
            "image_count": image_count,
        }

        # 添加重试机制
        max_retries = 3
        for attempt in range(max_retries):
            try:
                response = requests.post(url, headers=headers, json=payload, timeout=60)

                if response.status_code == 200:
                    data = response.json()
                    # 提取task_id
                    if 'data' in data and 'task_id' in data['data']:
                        return {'task_id': data['data']['task_id']}
                    elif 'task_id' in data:
                        return {'task_id': data['task_id']}
                    else:
                        raise Exception(f"响应中未找到task_id: {data}")
                else:
                    raise Exception(f"API请求失败: {response.status_code} - {response.text}")
            except (requests.exceptions.ConnectionError, ConnectionResetError) as e:
                if attempt < max_retries - 1:
                    wait_time = (attempt + 1) * 2  # 2秒, 4秒, 6秒
                    print(f"  ⚠️ 连接失败，{wait_time}秒后重试 (尝试 {attempt + 1}/{max_retries})...")
                    time.sleep(wait_time)
                else:
                    raise Exception(f"连接失败，已重试{max_retries}次: {e}")

    def image_to_video(
        self,
        image_path: str,
        prompt: str,
        negative_prompt: str = "",
        duration: int = 5,
        aspect_ratio: str = "16:9",
        model_name: str = "kling-v2-5-turbo",
        mode: str = "pro",
    ) -> dict:
        """
        图生视频API（使用base64编码）

        Args:
            image_path: 输入图片路径
            prompt: 提示词
            negative_prompt: 负向提示词
            duration: 视频时长（秒）
            aspect_ratio: 宽高比
            model_name: 模型名称，默认 "kling-v2-5-turbo" (最新，性价比高)
            mode: 生成模式，"std" 标准模式(720p) 或 "pro" 专业模式(1080p)，默认 "pro"

        Returns:
            包含task_id的字典
        """
        # 读取图片并转换为base64
        import base64
        with open(image_path, 'rb') as f:
            image_data = f.read()
            image_base64 = base64.b64encode(image_data).decode('utf-8')

        print(f"  📤 图片已编码为base64，大小: {len(image_base64)} 字符")
        print(f"  🎬 使用模型: {model_name} (模式: {mode})")

        # 创建视频生成任务（使用海外版API）
        video_url = f"{self.BASE_URL_GLOBAL}/v1/videos/image2video"
        headers = self._get_auth_headers(for_video=True)  # 使用视频API凭证

        payload = {
            "model_name": model_name,
            "mode": mode,
            "image": image_base64,
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "duration": duration,
            "aspect_ratio": aspect_ratio,
        }

        # 添加重试机制
        max_retries = 3
        for attempt in range(max_retries):
            try:
                # 增加超时时间到120秒，因为视频生成需要较长时间
                video_response = requests.post(video_url, headers=headers, json=payload, timeout=120)

                if video_response.status_code == 200:
                    data = video_response.json()
                    if 'data' in data and 'task_id' in data['data']:
                        return {'task_id': data['data']['task_id']}
                    elif 'task_id' in data:
                        return {'task_id': data['task_id']}
                    else:
                        raise Exception(f"响应中未找到task_id: {data}")
                else:
                    raise Exception(f"创建视频任务失败: {video_response.status_code} - {video_response.text}")
            except (requests.exceptions.ConnectionError, ConnectionResetError) as e:
                if attempt < max_retries - 1:
                    wait_time = (attempt + 1) * 2  # 2秒, 4秒, 6秒
                    print(f"  ⚠️ 连接失败，{wait_time}秒后重试 (尝试 {attempt + 1}/{max_retries})...")
                    time.sleep(wait_time)
                else:
                    raise Exception(f"连接失败，已重试{max_retries}次: {e}")

    def query_video_task(self, task_id: str) -> dict:
        """
        查询视频任务状态（使用海外版API）

        Args:
            task_id: 任务ID

        Returns:
            任务状态信息
        """
        url = f"{self.BASE_URL_GLOBAL}/v1/videos/image2video/{task_id}"
        headers = self._get_auth_headers(for_video=True)  # 使用视频API凭证

        response = requests.get(url, headers=headers, timeout=30)

        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"查询视频任务失败: {response.status_code} - {response.text}")

    def wait_for_video_task(self, task_id: str, max_wait_seconds: int = 600, poll_interval: int = 10) -> dict:
        """
        等待视频任务完成

        Args:
            task_id: 任务ID
            max_wait_seconds: 最大等待时间（秒）
            poll_interval: 轮询间隔（秒）

        Returns:
            完成的任务信息
        """
        start_time = time.time()
        retry_count = 0

        while time.time() - start_time < max_wait_seconds:
            retry_count += 1

            task_data = self.query_video_task(task_id)

            # 提取状态
            status = None
            if 'data' in task_data and 'task_status' in task_data['data']:
                status = task_data['data']['task_status']
            elif 'status' in task_data:
                status = task_data['status']

            print(f"  查询 #{retry_count}: 状态={status}")

            # 检查是否完成
            if status in ['succeed', 'completed', 'success']:
                return task_data
            elif status in ['failed', 'error']:
                error_msg = task_data.get('message', '未知错误')
                raise Exception(f"任务失败: {error_msg}")

            # 等待后继续轮询
            time.sleep(poll_interval)

        raise Exception(f"任务超时（{max_wait_seconds}秒）")

    def download_image(self, image_url: str, output_path: str) -> str:
        """
        下载图片

        Args:
            image_url: 图片URL
            output_path: 输出路径

        Returns:
            保存的文件路径
        """
        response = requests.get(image_url, timeout=60)

        if response.status_code == 200:
            # 确保输出目录存在
            Path(output_path).parent.mkdir(parents=True, exist_ok=True)

            with open(output_path, 'wb') as f:
                f.write(response.content)

            return output_path
        else:
            raise Exception(f"下载图片失败: {response.status_code}")

    def download_video(self, video_url: str, output_path: str) -> str:
        """
        下载视频

        Args:
            video_url: 视频URL
            output_path: 输出路径

        Returns:
            保存的文件路径
        """
        response = requests.get(video_url, timeout=120)

        if response.status_code == 200:
            # 确保输出目录存在
            Path(output_path).parent.mkdir(parents=True, exist_ok=True)

            with open(output_path, 'wb') as f:
                f.write(response.content)

            return output_path
        else:
            raise Exception(f"下载视频失败: {response.status_code}")

