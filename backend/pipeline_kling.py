#!/usr/bin/env python3
"""
可灵AI完整流程Pipeline
从上传图片到生成所有视频和GIF的完整流程
支持后台执行、重试机制、步骤间隔
"""

import os
import json
import time
import random
import traceback
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Callable, Any
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
from kling_api_helper import KlingAPI
import config
from prompt_config.prompts import (
    FIRST_TRANSITIONS,
    POSES,
    get_all_transitions,
)
from utils.image_utils import remove_background, ensure_square
from utils.video_utils import extract_first_frame, extract_last_frame, convert_mp4_to_gif, concatenate_videos


# ============================================
# 重试配置（增强版）
# ============================================
DEFAULT_MAX_RETRIES = 5          # 默认最大重试次数（增加到5次）
DEFAULT_RETRY_DELAY = 60         # 默认重试间隔（秒）- 1分钟
DEFAULT_STEP_INTERVAL = 15       # 默认步骤间隔（秒）
DEFAULT_API_INTERVAL = 10        # API调用间隔（秒）
DEFAULT_MAX_RETRY_DELAY = 300    # 最大重试延迟（秒）- 5分钟


def retry_with_backoff(
    func: Callable,
    max_retries: int = DEFAULT_MAX_RETRIES,
    base_delay: int = DEFAULT_RETRY_DELAY,
    max_delay: int = DEFAULT_MAX_RETRY_DELAY,
    exceptions: tuple = (Exception,),
    on_retry: Callable = None
) -> Any:
    """
    带指数退避的重试装饰器（增强版）

    - 默认重试5次
    - 每次重试间隔递增（指数退避）
    - 超过5次才会抛出异常

    Args:
        func: 要执行的函数
        max_retries: 最大重试次数（默认5次）
        base_delay: 基础延迟时间（秒，默认60秒）
        max_delay: 最大延迟时间（秒，默认300秒=5分钟）
        exceptions: 需要捕获重试的异常类型
        on_retry: 重试时的回调函数 (attempt, error, delay)

    Returns:
        函数执行结果
    """
    last_exception = None

    for attempt in range(max_retries + 1):
        try:
            return func()
        except exceptions as e:
            last_exception = e
            error_msg = str(e)

            if attempt < max_retries:
                # 计算延迟时间（指数退避 + 随机抖动）
                # 第1次: 60s, 第2次: 120s, 第3次: 180s (capped), 第4次: 240s (capped), 第5次: 300s
                delay = min(base_delay * (1 + attempt * 0.5) + random.uniform(0, 10), max_delay)

                if on_retry:
                    on_retry(attempt + 1, e, delay)
                else:
                    print(f"  ⚠️ 第 {attempt + 1}/{max_retries} 次尝试失败: {error_msg[:100]}")
                    print(f"  ⏳ 等待 {delay:.0f} 秒后重试...")

                time.sleep(delay)
            else:
                print(f"  ❌ 已达最大重试次数 ({max_retries}次)，任务失败")

    raise last_exception


def step_interval(seconds: int = DEFAULT_STEP_INTERVAL, message: str = None):
    """步骤间隔等待"""
    if message:
        print(f"\n⏸️  {message}")
    print(f"⏳ 等待 {seconds} 秒后继续...")
    time.sleep(seconds)


class KlingPipeline:
    """可灵AI完整流程（支持后台执行、重试、步骤间隔）"""

    def __init__(
        self,
        access_key: str,
        secret_key: str,
        output_dir: str = "output/kling_pipeline",
        use_v3_prompts: bool = False,
        # 重试配置
        max_retries: int = DEFAULT_MAX_RETRIES,
        retry_delay: int = DEFAULT_RETRY_DELAY,
        # 间隔配置
        step_interval: int = DEFAULT_STEP_INTERVAL,
        api_interval: int = DEFAULT_API_INTERVAL,
        # 状态回调
        status_callback: Callable = None,
        # 视频模型配置
        video_model_name: str = "kling-v2-1-master",
        video_model_mode: str = "pro",
        # 视频 API 密钥（可选，如果不传则与图片 API 相同）
        video_access_key: str = None,
        video_secret_key: str = None,
    ):
        # 图片 API 实例 - 统一使用海外版
        self.kling = KlingAPI(
            access_key,
            secret_key,
            base_url=config.KLING_BASE_URL
        )
        print(f"✅ 图片生成使用海外版 API: {config.KLING_BASE_URL}")

        # 视频 API 实例 - 统一使用海外版
        if video_access_key and video_secret_key:
            self.kling_video = KlingAPI(
                video_access_key,
                video_secret_key,
                base_url=config.KLING_BASE_URL
            )
            print("✅ 视频生成使用独立 API 密钥（海外版）")
        else:
            self.kling_video = self.kling
            print("ℹ️ 视频生成复用图片 API 密钥（海外版）")

        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # 重试配置
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.step_interval = step_interval
        self.api_interval = api_interval

        # 状态回调（用于更新任务状态）
        self.status_callback = status_callback

        # 视频模型配置
        self.video_model_name = video_model_name
        self.video_model_mode = video_model_mode

        # 宠物配置
        self.breed = ""
        self.color = ""
        self.species = ""
        self.weight = 0.0  # v3.0新增
        self.gender = ""   # v3.0新增
        self.birthday = "" # v3.0新增

        # v3.0智能分析结果
        self.body_type = ""
        self.age_stage = ""

        # 是否使用v3.0 prompt系统
        self.use_v3_prompts = use_v3_prompts

        # 路径
        self.pet_dir = None
        self.images_dir = None
        self.videos_dir = None
        self.gifs_dir = None

    def _update_status(self, progress: int, message: str, step: str = None):
        """更新任务状态"""
        print(f"📊 [{progress}%] {message}")
        if self.status_callback:
            self.status_callback(progress, message, step)

    def _wait_interval(self, seconds: int = None, message: str = "步骤间隔"):
        """等待间隔"""
        wait_time = seconds or self.step_interval
        print(f"⏳ {message}，等待 {wait_time} 秒...")
        time.sleep(wait_time)

    def _retry_operation(self, operation: Callable, operation_name: str) -> Any:
        """
        带重试的操作执行

        - 最多重试5次
        - 间隔时间递增：1分钟 → 1.5分钟 → 2分钟 → 2.5分钟 → 3分钟
        - 超过5次才会抛出异常
        """
        def on_retry(attempt, error, delay):
            error_msg = str(error)[:100]  # 截断错误信息
            print(f"\n  {'='*50}")
            print(f"  ⚠️ {operation_name} 失败")
            print(f"  📍 第 {attempt}/{self.max_retries} 次重试")
            print(f"  ❌ 错误: {error_msg}")
            print(f"  ⏳ 将在 {delay:.0f} 秒后重试...")
            print(f"  {'='*50}\n")
            self._update_status(-1, f"⚠️ {operation_name} 失败，第{attempt}次重试中（等待{int(delay)}秒）...")

        return retry_with_backoff(
            operation,
            max_retries=self.max_retries,
            base_delay=self.retry_delay,
            on_retry=on_retry
        )
    
    def setup_pet_directories(self, pet_id: str):
        """设置宠物输出目录"""
        self.pet_dir = self.output_dir / pet_id
        self.images_dir = self.pet_dir / "base_images"
        self.videos_dir = self.pet_dir / "videos"
        self.gifs_dir = self.pet_dir / "gifs"
        
        self.images_dir.mkdir(parents=True, exist_ok=True)
        (self.videos_dir / "transitions").mkdir(parents=True, exist_ok=True)
        (self.videos_dir / "loops").mkdir(parents=True, exist_ok=True)
        (self.gifs_dir / "transitions").mkdir(parents=True, exist_ok=True)
        (self.gifs_dir / "loops").mkdir(parents=True, exist_ok=True)
    
    def step1_remove_background(self, uploaded_image: str, pet_id: str) -> str:
        """
        步骤1: 去除背景

        Args:
            uploaded_image: 原始图片路径
            pet_id: 宠物ID

        Returns:
            透明背景图片路径
        """
        self.setup_pet_directories(pet_id)

        print(f"🎨 步骤1: 去除背景")
        transparent_path = self.pet_dir / "transparent.png"
        remove_background(uploaded_image, str(transparent_path))
        print(f"✅ 背景已去除: {transparent_path}")

        return str(transparent_path)

    def step2_generate_base_image(
        self,
        transparent_image: str,
        breed: str,
        color: str,
        species: str,
        pet_id: str,
        remove_bg_after: bool = True
    ) -> str:
        """
        步骤2: 生成基础坐姿图片

        Args:
            transparent_image: 透明背景图片路径
            breed: 品种
            color: 颜色
            species: 物种
            pet_id: 宠物ID
            remove_bg_after: 生成后是否去除背景（默认True）

        Returns:
            坐姿图片路径
        """
        self.breed = breed
        self.color = color
        self.species = species
        self.setup_pet_directories(pet_id)

        print(f"🖼️  步骤2: 生成基础坐姿图片")
        sit_image_raw = self._generate_base_image("sit", transparent_image)
        print(f"✅ 坐姿图片已生成: {sit_image_raw}")

        # 生成后去除背景
        if remove_bg_after:
            print(f"🎨 步骤2.5: 去除生成图片的背景")
            sit_image_clean = str(self.images_dir / "sit_clean.png")
            remove_background(sit_image_raw, sit_image_clean)
            print(f"✅ sit图片背景已去除: {sit_image_clean}")
            # 覆盖原sit.png
            import shutil
            shutil.copy(sit_image_clean, sit_image_raw)
            print(f"✅ 已更新sit.png为去背景版本")

        return sit_image_raw

    def step3_generate_initial_videos(
        self,
        base_image: str,
        breed: str,
        color: str,
        species: str,
        pet_id: str
    ) -> Dict:
        """
        步骤3: 生成初始3个过渡视频

        Args:
            base_image: 坐姿图片路径
            breed: 品种
            color: 颜色
            species: 物种
            pet_id: 宠物ID

        Returns:
            包含视频路径和提取帧的字典
        """
        self.breed = breed
        self.color = color
        self.species = species
        self.setup_pet_directories(pet_id)

        print(f"🎬 步骤3: 生成初始过渡视频")
        videos, other_poses, first_frames, last_frames = self._generate_first_transitions(base_image)
        print(f"✅ 初始视频已生成")

        return {
            "videos": videos,
            "extracted_frames": other_poses,
            "first_frames": first_frames,
            "last_frames": last_frames
        }

    def run_full_pipeline(
        self,
        uploaded_image: str,
        breed: str,
        color: str,
        species: str,
        pet_id: Optional[str] = None,
        remove_background_flag: bool = True,  # 默认启用背景去除
        # v3.0新增参数
        weight: float = 0.0,
        gender: str = "",
        birthday: str = ""
    ) -> Dict:
        """
        运行完整流程
        
        Args:
            uploaded_image: 用户上传的图片路径
            breed: 品种（如：布偶猫）
            color: 颜色（如：蓝色）
            species: 物种（猫/犬）
            pet_id: 宠物ID（可选，默认使用时间戳）
            remove_background_flag: 是否去除背景（默认False）
        
        Returns:
            包含所有生成结果的字典
        """
        if pet_id is None:
            pet_id = f"pet_{int(time.time())}"
        
        self.breed = breed
        self.color = color
        self.species = species
        self.weight = weight
        self.gender = gender
        self.birthday = birthday
        
        # 如果使用v3.0系统，进行智能分析
        if self.use_v3_prompts and weight > 0 and birthday:
            from prompt_config.intelligent_analyzer import analyze_pet_info
            analysis = analyze_pet_info(breed, weight, birthday)
            self.body_type = analysis["body_type"]
            self.age_stage = analysis["age_stage"]
            print(f"🧠 v3.0智能分析: 年龄{analysis['age_years']}岁 ({analysis['age_stage']})，体型: {self.body_type}")
        
        self.setup_pet_directories(pet_id)

        print("=" * 70)
        print(f"🚀 开始完整流程: {breed}{color}{species}")
        print(f"📁 输出目录: {self.pet_dir}")
        print(f"🔧 背景去除: {'启用' if remove_background_flag else '跳过'}")
        print(f"🔄 重试次数: {self.max_retries}, 重试间隔: {self.retry_delay}s")
        print(f"⏳ 步骤间隔: {self.step_interval}s, API间隔: {self.api_interval}s")
        print("=" * 70)

        results = {
            "pet_id": pet_id,
            "breed": breed,
            "color": color,
            "species": species,
            "steps": {}
        }

        import shutil

        # ==================== 步骤1: 保存原图 ====================
        self._update_status(5, "步骤1: 保存原图...", "step1")
        print("\n📤 步骤1: 保存原图")
        original_path = self.pet_dir / "original.jpg"
        shutil.copy(uploaded_image, original_path)
        results["steps"]["original"] = str(original_path)
        print(f"✅ 原图已保存: {original_path}")

        self._wait_interval(self.step_interval, "步骤1完成")

        # ==================== 步骤2: 去背景（生成前）====================
        self._update_status(10, "步骤2: 去除背景（第1次）...", "step2")
        print("\n🎨 步骤2: 去除背景（生成sit前）")
        transparent_path = self.pet_dir / "transparent.png"

        if remove_background_flag:
            # 背景去除（不需要重试，Remove.bg API很稳定）
            remove_background(str(original_path), str(transparent_path))
            print(f"✅ 背景已去除: {transparent_path}")
        else:
            print(f"⚠️  跳过背景去除，直接使用原图")
            shutil.copy(str(original_path), transparent_path)
            print(f"✅ 已复制原图到: {transparent_path}")

        results["steps"]["transparent"] = str(transparent_path)

        self._wait_interval(self.step_interval, "步骤2完成")

        # ==================== 步骤3: 生成第一张基准图（sit）====================
        self._update_status(20, "步骤3: 生成基础坐姿图片（可灵API）...", "step3")
        print("\n🖼️  步骤3: 生成第一张基准图（sit）- 调用可灵API")
        sit_image_raw = self._generate_base_image("sit", str(transparent_path))
        results["steps"]["base_sit_raw"] = sit_image_raw

        self._wait_interval(self.step_interval, "步骤3完成")

        # ==================== 步骤3.5: 去背景（生成后）====================
        self._update_status(25, "步骤3.5: 去除生成图片背景（第2次）...", "step3.5")
        print("\n🎨 步骤3.5: 去除sit图片的背景")
        sit_image_clean = str(self.images_dir / "sit_clean.png")

        if remove_background_flag:
            # 背景去除（不需要重试，Remove.bg API很稳定）
            remove_background(sit_image_raw, sit_image_clean)
            print(f"✅ sit图片背景已去除: {sit_image_clean}")
            # 覆盖原sit.png
            shutil.copy(sit_image_clean, sit_image_raw)
            print(f"✅ 已更新sit.png为去背景版本")
        else:
            print(f"⚠️  跳过sit图片背景去除")

        sit_image = sit_image_raw  # 最终的sit图片
        results["steps"]["base_sit"] = sit_image

        self._wait_interval(self.step_interval, "步骤3.5完成")

        # ==================== 步骤4: 生成前3个过渡视频 + 提取首尾帧 ====================
        self._update_status(35, "步骤4: 生成初始过渡视频 + 提取首尾帧...", "step4")
        print("\n🎬 步骤4: 生成前3个过渡视频 + 提取首尾帧")
        print("  📌 视频: sit→walk, sit→rest, rest→sleep")
        print("  📌 提取尾帧作为其他姿势基础图: walk.png, rest.png, sleep.png")
        first_videos, other_poses, first_frames, last_frames = self._generate_first_transitions(sit_image)
        results["steps"]["first_transitions"] = first_videos
        results["steps"]["other_base_images"] = other_poses
        results["steps"]["first_frames"] = first_frames
        results["steps"]["last_frames"] = last_frames

        self._update_status(50, "步骤4完成: 3个过渡视频 + 首尾帧已提取", "step4_done")
        self._wait_interval(self.step_interval, "步骤4完成")

        # ==================== 步骤5: 并发生成剩余过渡视频 ====================
        self._update_status(55, "步骤5: 并发生成剩余过渡视频（并发数：3）...", "step5")
        print("\n🎬 步骤5: 并发生成剩余过渡视频")
        print("  📌 可灵API支持并发3，将同时生成多个视频以加速")
        remaining_videos = self._generate_remaining_transitions()
        results["steps"]["remaining_transitions"] = remaining_videos

        self._wait_interval(self.step_interval, "步骤5完成")

        # ==================== 步骤6: 并发生成循环视频 ====================
        self._update_status(75, "步骤6: 并发生成循环视频（并发数：3）...", "step6")
        print("\n🔄 步骤6: 并发生成循环视频")
        print("  📌 4个循环视频将并发生成")
        loop_videos = self._generate_loop_videos()
        results["steps"]["loop_videos"] = loop_videos

        self._wait_interval(self.step_interval, "步骤6完成")

        # ==================== 步骤7: 转换为GIF ====================
        self._update_status(90, "步骤7: 转换视频为GIF...", "step7")
        print("\n🎞️  步骤7: 转换所有视频为GIF")
        gifs = self._convert_all_to_gif()
        results["steps"]["gifs"] = gifs

        self._wait_interval(self.step_interval, "步骤7完成")

        # ==================== 步骤8: 拼接所有过渡视频 ====================
        self._update_status(95, "步骤8: 拼接过渡视频...", "step8")
        print("\n🎬 步骤8: 拼接所有过渡视频为长视频")
        concatenated_video = self._concatenate_transition_videos()
        results["steps"]["concatenated_video"] = concatenated_video

        # 保存元数据
        metadata_path = self.pet_dir / "metadata.json"
        with open(metadata_path, 'w', encoding='utf-8') as f:
            json.dump(results, f, ensure_ascii=False, indent=2)

        self._update_status(100, "✅ 完整流程完成！", "completed")
        print("\n" + "=" * 70)
        print("✅ 完整流程完成！")
        print(f"📊 元数据已保存: {metadata_path}")
        print("=" * 70)

        return results

    def run_image_generation_only(
        self,
        uploaded_image: str,
        breed: str,
        color: str,
        species: str,
        pet_id: str,
        remove_background_flag: bool = True,
        weight: float = 0.0,
        gender: str = "",
        birthday: str = ""
    ) -> Dict:
        """
        只执行图片生成部分（步骤1-3.5）
        用于多模型对比测试时，先生成一张坐姿图供所有视频模型共用

        Args:
            uploaded_image: 用户上传的图片路径
            breed: 品种
            color: 颜色
            species: 物种
            pet_id: 宠物ID
            remove_background_flag: 是否去除背景
            weight: 重量（用于v3.0智能分析）
            gender: 性别
            birthday: 生日

        Returns:
            包含坐姿图路径的字典
        """
        import shutil

        self.breed = breed
        self.color = color
        self.species = species
        self.weight = weight
        self.gender = gender
        self.birthday = birthday

        # 如果使用v3.0系统，预先确定体型（即使没有体重/生日也要有兜底）
        if self.use_v3_prompts:
            from prompt_config.breed_database import get_breed_config
            breed_config = get_breed_config(breed)

            if breed_config:
                # 默认体型：使用品种标准体型
                self.body_type = breed_config.get("standard_size")
            else:
                self.body_type = None

            # 如果提供了完整的体重和生日，再尝试做更精细的智能分析
            if weight > 0 and birthday:
                try:
                    from prompt_config.intelligent_analyzer import analyze_pet_info
                    analysis = analyze_pet_info(breed, weight, birthday)
                    self.body_type = analysis.get("body_type", self.body_type)
                    self.age_stage = analysis.get("age_stage")
                    print(
                        f"🧠 v3.0智能分析: 年龄{analysis['age_years']}岁 ({analysis['age_stage']})，体型: {self.body_type}"
                    )
                except Exception as e:
                    print(f"⚠️ v3.0智能分析失败，使用品种标准体型: {self.body_type}，错误: {e}")

        self.setup_pet_directories(pet_id)

        print("=" * 70)
        print(f"🖼️  开始图片生成流程（步骤1-3.5）: {breed}{color}{species}")
        print(f"📁 输出目录: {self.pet_dir}")
        print("=" * 70)

        results = {
            "pet_id": pet_id,
            "breed": breed,
            "color": color,
            "species": species,
            "steps": {}
        }

        # ==================== 步骤1: 保存原图 ====================
        self._update_status(5, "步骤1: 保存原图...", "step1")
        print("\n📤 步骤1: 保存原图")
        original_path = self.pet_dir / "original.jpg"
        shutil.copy(uploaded_image, original_path)
        results["steps"]["original"] = str(original_path)
        print(f"✅ 原图已保存: {original_path}")

        self._wait_interval(self.step_interval, "步骤1完成")

        # ==================== 步骤2: 去背景（生成前）====================
        self._update_status(10, "步骤2: 去除背景（第1次）...", "step2")
        print("\n🎨 步骤2: 去除背景（生成sit前）")
        transparent_path = self.pet_dir / "transparent.png"

        if remove_background_flag:
            remove_background(str(original_path), str(transparent_path))
            print(f"✅ 背景已去除: {transparent_path}")
        else:
            print(f"⚠️  跳过背景去除，直接使用原图")
            shutil.copy(str(original_path), transparent_path)
            print(f"✅ 已复制原图到: {transparent_path}")

        results["steps"]["transparent"] = str(transparent_path)

        self._wait_interval(self.step_interval, "步骤2完成")

        # ==================== 步骤3: 生成第一张基准图（sit）====================
        self._update_status(20, "步骤3: 生成基础坐姿图片（可灵API）...", "step3")
        print("\n🖼️  步骤3: 生成第一张基准图（sit）- 调用可灵API")
        sit_image_raw = self._generate_base_image("sit", str(transparent_path))
        results["steps"]["base_sit_raw"] = sit_image_raw

        self._wait_interval(self.step_interval, "步骤3完成")

        # ==================== 步骤3.5: 去背景（生成后）====================
        self._update_status(25, "步骤3.5: 去除生成图片背景（第2次）...", "step3.5")
        print("\n🎨 步骤3.5: 去除sit图片的背景")
        sit_image_clean = str(self.images_dir / "sit_clean.png")

        if remove_background_flag:
            remove_background(sit_image_raw, sit_image_clean)
            print(f"✅ sit图片背景已去除: {sit_image_clean}")
            shutil.copy(sit_image_clean, sit_image_raw)
            print(f"✅ 已更新sit.png为去背景版本")
        else:
            print(f"⚠️  跳过sit图片背景去除")

        sit_image = sit_image_raw
        results["steps"]["base_sit"] = sit_image

        self._update_status(30, "✅ 图片生成完成！", "image_done")
        print("\n" + "=" * 70)
        print("✅ 图片生成流程完成！")
        print(f"📷 坐姿图: {sit_image}")
        print("=" * 70)

        return results

    def run_video_only_pipeline(
        self,
        sit_image: str,
        breed: str,
        color: str,
        species: str,
        pet_id: str,
        shared_base_images_dir: str = None
    ) -> Dict:
        """
        只执行视频生成部分（步骤4-8）
        用于多模型对比测试时，使用共享的坐姿图生成视频

        Args:
            sit_image: 坐姿图路径（已生成好的）
            breed: 品种
            color: 颜色
            species: 物种
            pet_id: 宠物ID（每个模型独立的ID）
            shared_base_images_dir: 共享的base_images目录（可选，用于复制坐姿图）

        Returns:
            包含所有视频结果的字典
        """
        import shutil

        self.breed = breed
        self.color = color
        self.species = species

        self.setup_pet_directories(pet_id)

        print("=" * 70)
        print(f"🎬 开始视频生成流程（步骤4-8）: {breed}{color}{species}")
        print(f"📁 输出目录: {self.pet_dir}")
        print(f"🎬 视频模型: {self.video_model_name} (模式: {self.video_model_mode})")
        print(f"📷 使用坐姿图: {sit_image}")
        print("=" * 70)

        results = {
            "pet_id": pet_id,
            "breed": breed,
            "color": color,
            "species": species,
            "video_model": self.video_model_name,
            "video_mode": self.video_model_mode,
            "steps": {}
        }

        # 复制坐姿图到当前模型的目录
        local_sit_image = str(self.images_dir / "sit.png")
        shutil.copy(sit_image, local_sit_image)
        results["steps"]["base_sit"] = local_sit_image
        print(f"📷 已复制坐姿图到: {local_sit_image}")

        # ==================== 步骤4: 生成前3个过渡视频 + 提取首尾帧 ====================
        self._update_status(35, "步骤4: 生成初始过渡视频 + 提取首尾帧...", "step4")
        print("\n🎬 步骤4: 生成前3个过渡视频 + 提取首尾帧")
        print("  📌 视频: sit→walk, sit→rest, rest→sleep")
        print("  📌 提取尾帧作为其他姿势基础图: walk.png, rest.png, sleep.png")
        first_videos, other_poses, first_frames, last_frames = self._generate_first_transitions(local_sit_image)
        results["steps"]["first_transitions"] = first_videos
        results["steps"]["other_base_images"] = other_poses
        results["steps"]["first_frames"] = first_frames
        results["steps"]["last_frames"] = last_frames

        self._update_status(50, "步骤4完成: 3个过渡视频 + 首尾帧已提取", "step4_done")
        self._wait_interval(self.step_interval, "步骤4完成")

        # ==================== 步骤5: 并发生成剩余过渡视频 ====================
        self._update_status(55, "步骤5: 并发生成剩余过渡视频（并发数：3）...", "step5")
        print("\n🎬 步骤5: 并发生成剩余过渡视频")
        print("  📌 可灵API支持并发3，将同时生成多个视频以加速")
        remaining_videos = self._generate_remaining_transitions()
        results["steps"]["remaining_transitions"] = remaining_videos

        self._wait_interval(self.step_interval, "步骤5完成")

        # ==================== 步骤6: 并发生成循环视频 ====================
        self._update_status(75, "步骤6: 并发生成循环视频（并发数：3）...", "step6")
        print("\n🔄 步骤6: 并发生成循环视频")
        print("  📌 4个循环视频将并发生成")
        loop_videos = self._generate_loop_videos()
        results["steps"]["loop_videos"] = loop_videos

        self._wait_interval(self.step_interval, "步骤6完成")

        # ==================== 步骤7: 转换为GIF ====================
        self._update_status(90, "步骤7: 转换视频为GIF...", "step7")
        print("\n🎞️  步骤7: 转换所有视频为GIF")
        gifs = self._convert_all_to_gif()
        results["steps"]["gifs"] = gifs

        self._wait_interval(self.step_interval, "步骤7完成")

        # ==================== 步骤8: 拼接所有过渡视频 ====================
        self._update_status(95, "步骤8: 拼接过渡视频...", "step8")
        print("\n🎬 步骤8: 拼接所有过渡视频为长视频")
        concatenated_video = self._concatenate_transition_videos()
        results["steps"]["concatenated_video"] = concatenated_video

        # 保存元数据
        metadata_path = self.pet_dir / "metadata.json"
        with open(metadata_path, 'w', encoding='utf-8') as f:
            json.dump(results, f, ensure_ascii=False, indent=2)

        self._update_status(100, "✅ 视频生成完成！", "completed")
        print("\n" + "=" * 70)
        print("✅ 视频生成流程完成！")
        print(f"📊 元数据已保存: {metadata_path}")
        print("=" * 70)

        return results

    def _generate_base_image(self, pose: str, transparent_image: str) -> str:
        """生成基准图（图生图），带重试机制"""
        # 使用v3.0 prompt系统（唯一版本）生成结构化单行prompt
        from prompt_config.prompt_generator_v3 import generate_sit_prompt_v3
        prompt, negative_prompt = generate_sit_prompt_v3(
            breed_name=self.breed,
            species=self.species,
        )
        print(f"  使用v3.0 Prompt生成器 (支持negative_prompt)")
        print(f"  负向提示词: {negative_prompt}")

        print(f"  提示词: {prompt}")
        print(f"  使用图生图API，输入图片: {transparent_image}")

        def do_generate():
            # 使用图生图API
            result = self.kling.image_to_image(
                image_path=transparent_image,
                prompt=prompt,
                negative_prompt=negative_prompt,
                aspect_ratio="1:1",
                image_count=1
            )

            task_id = result['task_id']
            print(f"  任务ID: {task_id}")

            # 等待完成
            task_data = self.kling.wait_for_task(task_id, max_wait_seconds=300)

            # 提取图片URL
            image_url = self._extract_image_url(task_data)

            # 下载图片
            output_path = str(self.images_dir / f"{pose}.png")
            self.kling.download_image(image_url, output_path)

            return output_path

        # 带重试执行
        output_path = self._retry_operation(do_generate, f"生成{pose}图片")

        print(f"  ✅ {pose}.png 已生成")

        # API调用间隔
        self._wait_interval(self.api_interval, "API调用间隔")

        return output_path

    def _generate_first_transitions(self, sit_image: str) -> tuple:
        """
        生成前3个过渡视频并提取首尾帧（优化版：部分并发）
        
        优化策略：
        - sit2walk 和 sit2rest 可以并发（都从 sit.png 开始）
        - rest2sleep 需要等 sit2rest 完成后才能开始（需要 rest.png）
        """
        videos = {}
        other_poses = {}
        first_frames = {}
        last_frames = {}

        print("\n📦 优化生成策略：sit2walk + sit2rest 并发，然后 rest2sleep")
        
        # ========== 阶段1: 并发生成 sit2walk 和 sit2rest ==========
        self._update_status(35, "步骤4.1: 并发生成 sit2walk + sit2rest...", "step4.1")
        print("\n  🚀 阶段1: 并发生成 sit2walk 和 sit2rest（并发数：2）")
        print("  🔄 重试配置: 最多 3 次，间隔 30 秒")
        
        parallel_transitions = ["sit2walk", "sit2rest"]
        max_retries = 3
        retry_delay = 30
        
        def generate_with_retry(transition, start_img, max_attempts=3):
            """带重试的单个视频生成"""
            last_error = None
            for attempt in range(1, max_attempts + 1):
                try:
                    print(f"    [{transition}] 第{attempt}次尝试...")
                    video_path = self._generate_transition_video_no_wait(transition, start_img)
                    return video_path, None
                except Exception as e:
                    last_error = str(e)
                    print(f"    [{transition}] 第{attempt}次失败: {last_error[:50]}...")
                    if attempt < max_attempts:
                        print(f"    [{transition}] 等待 {retry_delay} 秒后重试...")
                        time.sleep(retry_delay)
            return None, last_error
        
        # 并发执行（带重试）
        parallel_results = {}
        failed_transitions = []
        
        with ThreadPoolExecutor(max_workers=2) as executor:
            future_to_task = {
                executor.submit(generate_with_retry, t, sit_image, max_retries): t
                for t in parallel_transitions
            }
            
            for future in as_completed(future_to_task):
                transition = future_to_task[future]
                try:
                    video_path, error = future.result()
                    if video_path:
                        parallel_results[transition] = video_path
                        videos[transition] = video_path
                        print(f"  ✅ {transition} 完成")
                        
                        # 提取首尾帧
                        end_pose = transition.split("2")[1]
                        
                        # 提取首帧
                        first_frame_path = str(self.images_dir / f"{transition}_first_frame.png")
                        extract_first_frame(video_path, first_frame_path)
                        first_frames[transition] = first_frame_path
                        
                        # 提取尾帧
                        end_image_path = str(self.images_dir / f"{end_pose}.png")
                        last_frame_path = str(self.images_dir / f"{transition}_last_frame.png")
                        extract_last_frame(video_path, end_image_path)
                        extract_last_frame(video_path, last_frame_path)
                        other_poses[end_pose] = end_image_path
                        last_frames[transition] = last_frame_path
                        print(f"  ✅ {end_pose}.png 已提取")
                    else:
                        print(f"  ❌ {transition} 最终失败: {error}")
                        failed_transitions.append(transition)
                        
                except Exception as e:
                    print(f"  ❌ {transition} 异常: {e}")
                    failed_transitions.append(transition)
        
        if failed_transitions:
            print(f"\n  ⚠️ 警告: {len(failed_transitions)} 个视频生成失败: {failed_transitions}")
        
        self._update_status(42, "步骤4.1完成: sit2walk + sit2rest 已生成", "step4.1_done")
        
        # ========== 阶段2: 生成 rest2sleep ==========
        self._update_status(43, "步骤4.2: 生成 rest2sleep...", "step4.2")
        print("\n  🎬 阶段2: 生成 rest2sleep（需要 rest.png）")
        
        rest_image = other_poses.get("rest")
        if not rest_image:
            raise Exception("rest.png 尚未生成，无法生成 rest2sleep")
        
        try:
            video_path = self._generate_transition_video("rest2sleep", rest_image)
            videos["rest2sleep"] = video_path
            
            # 提取首尾帧
            first_frame_path = str(self.images_dir / "rest2sleep_first_frame.png")
            extract_first_frame(video_path, first_frame_path)
            first_frames["rest2sleep"] = first_frame_path
            
            end_image_path = str(self.images_dir / "sleep.png")
            last_frame_path = str(self.images_dir / "rest2sleep_last_frame.png")
            extract_last_frame(video_path, end_image_path)
            extract_last_frame(video_path, last_frame_path)
            other_poses["sleep"] = end_image_path
            last_frames["rest2sleep"] = last_frame_path
            print(f"  ✅ sleep.png 已提取")
            
        except Exception as e:
            print(f"  ❌ rest2sleep 失败: {e}")
        
        self._update_status(50, "步骤4完成: 3个初始视频 + 首尾帧已提取", "step4_done")
        
        return videos, other_poses, first_frames, last_frames

    def _generate_first_transitions_sequential(self, sit_image: str) -> tuple:
        """生成前3个过渡视频并提取首尾帧（顺序版本，备用）"""
        videos = {}
        other_poses = {}
        first_frames = {}
        last_frames = {}

        total = len(FIRST_TRANSITIONS)
        base_progress = 35  # 步骤4起始进度

        for idx, transition in enumerate(FIRST_TRANSITIONS):
            # 更新进度 - 视频生成 (35% - 47%)
            progress = base_progress + int((idx / total) * 12)
            self._update_status(progress, f"生成初始视频 ({idx+1}/{total}): {transition}...")

            print(f"\n  生成 {transition}... [{idx+1}/{total}]")

            # 确定起始图片
            if transition == "sit2walk" or transition == "sit2rest":
                start_image = sit_image
            elif transition == "rest2sleep":
                start_image = other_poses.get("rest")
                if not start_image:
                    raise Exception("rest.png 尚未生成，无法生成 rest2sleep")
            else:
                raise Exception(f"未知的首批过渡: {transition}")

            # 生成视频
            video_path = self._generate_transition_video(transition, start_image)
            videos[transition] = video_path

            # 更新进度 - 提取首尾帧 (47% - 50%)
            frame_progress = 47 + int((idx / total) * 3)
            end_pose = transition.split("2")[1]
            self._update_status(frame_progress, f"提取首尾帧 ({idx+1}/{total}): {transition} → {end_pose}.png")

            # 提取首帧
            start_pose = transition.split("2")[0]
            first_frame_path = str(self.images_dir / f"{transition}_first_frame.png")
            extract_first_frame(video_path, first_frame_path)
            first_frames[transition] = first_frame_path
            print(f"  ✅ {transition}_first_frame.png 已提取")

            # 提取尾帧
            end_image_path = str(self.images_dir / f"{end_pose}.png")
            last_frame_path = str(self.images_dir / f"{transition}_last_frame.png")
            extract_last_frame(video_path, end_image_path)
            extract_last_frame(video_path, last_frame_path)
            other_poses[end_pose] = end_image_path
            last_frames[transition] = last_frame_path
            print(f"  ✅ {end_pose}.png 已提取（作为后续视频的起始图）")
            print(f"  ✅ {transition}_last_frame.png 已提取")

        return videos, other_poses, first_frames, last_frames

    def _generate_transition_video(self, transition: str, start_image: str) -> str:
        """生成单个过渡视频，带重试机制"""
        # 使用v3.0 prompt系统（唯一版本）
        # 确保有体型信息（即使没有体重/生日也能工作）
        if not getattr(self, "body_type", None):
            from prompt_config.breed_database import get_breed_config
            breed_config = get_breed_config(self.breed)
            if breed_config:
                self.body_type = breed_config.get("standard_size")
            else:
                self.body_type = ""

        from prompt_config.prompt_generator_v3 import generate_transition_prompt_v3
        prompt, negative_prompt = generate_transition_prompt_v3(
            transition=transition,
            breed_name=self.breed,
            species=self.species,
        )

        print(f"    提示词: {prompt}")
        print(f"    负向: {negative_prompt[:50]}...")
        print(f"    🎬 视频模型: {self.video_model_name} (模式: {self.video_model_mode})")

        def do_generate():
            # 调用可灵AI图生视频（使用视频专用 API）
            result = self.kling_video.image_to_video(
                image_path=start_image,
                prompt=prompt,
                negative_prompt=negative_prompt,
                duration=5,
                aspect_ratio="16:9",
                model_name=self.video_model_name,
                mode=self.video_model_mode
            )

            task_id = result['task_id']
            print(f"    任务ID: {task_id}")

            # 等待完成
            task_data = self.kling_video.wait_for_video_task(task_id, max_wait_seconds=600)

            # 提取视频URL
            video_url = self._extract_video_url(task_data)

            # 下载视频
            output_path = str(self.videos_dir / "transitions" / f"{transition}.mp4")
            self.kling_video.download_video(video_url, output_path)

            return output_path

        # 带重试执行
        output_path = self._retry_operation(do_generate, f"生成过渡视频 {transition}")

        print(f"    ✅ {transition}.mp4 已生成")

        # API调用间隔
        self._wait_interval(self.api_interval, "视频生成间隔")

        return output_path

    def _run_video_tasks_concurrent(
        self,
        tasks: List[Dict],
        task_type: str,
        max_concurrent: int = 3,
        base_progress: int = 50,
        progress_range: int = 20,
        max_retries: int = 3,
        retry_delay: int = 30
    ) -> Dict:
        """
        并发执行视频生成任务（可灵API支持并发3）
        带完善的重试机制
        
        Args:
            tasks: 任务列表，每个任务包含:
                - transition: 过渡名称 (如 "walk2sit") 或 pose: 姿势名称 (如 "sit")
                - start_image: 起始图片路径
            task_type: 任务类型 ("transition" 或 "loop")
            max_concurrent: 最大并发数（默认3，可灵API限制）
            base_progress: 基础进度百分比
            progress_range: 进度范围
            max_retries: 单个任务最大重试次数（默认3）
            retry_delay: 重试间隔秒数（默认30秒）
            
        Returns:
            生成的视频路径字典
        """
        results = {}
        failed_tasks = []  # 记录失败的任务用于重试
        total = len(tasks)
        completed = 0
        lock = threading.Lock()
        
        if total == 0:
            return results
            
        print(f"\n🚀 并发任务启动: {total} 个任务，最大并发数 {max_concurrent}")
        print(f"  🔄 重试配置: 最多 {max_retries} 次，间隔 {retry_delay} 秒")
        
        def generate_single_task(task_info, attempt=1):
            """单个任务的执行函数（带重试）"""
            nonlocal completed
            
            if task_type == "transition":
                name = task_info["transition"]
                start_image = task_info["start_image"]
                try:
                    video_path = self._generate_transition_video_no_wait(name, start_image)
                    with lock:
                        completed += 1
                        progress = base_progress + int((completed / total) * progress_range)
                        self._update_status(progress, f"并发生成中 ({completed}/{total}): {name} ✅")
                    return (name, video_path, None, task_info)
                except Exception as e:
                    error_msg = str(e)
                    print(f"  ⚠️ {name} 第{attempt}次尝试失败: {error_msg[:50]}...")
                    return (name, None, error_msg, task_info)
            else:  # loop
                name = task_info["pose"]
                start_image = task_info["start_image"]
                try:
                    video_path = self._generate_loop_video_no_wait(name, start_image)
                    with lock:
                        completed += 1
                        progress = base_progress + int((completed / total) * progress_range)
                        self._update_status(progress, f"并发生成中 ({completed}/{total}): {name}_loop ✅")
                    return (name, video_path, None, task_info)
                except Exception as e:
                    error_msg = str(e)
                    print(f"  ⚠️ {name}_loop 第{attempt}次尝试失败: {error_msg[:50]}...")
                    return (name, None, error_msg, task_info)
        
        def run_batch(batch_tasks, attempt=1):
            """执行一批任务"""
            batch_results = {}
            batch_failed = []
            
            with ThreadPoolExecutor(max_workers=max_concurrent) as executor:
                future_to_task = {
                    executor.submit(generate_single_task, task, attempt): task 
                    for task in batch_tasks
                }
                
                for future in as_completed(future_to_task):
                    task = future_to_task[future]
                    try:
                        name, video_path, error, task_info = future.result()
                        if video_path:
                            batch_results[name] = video_path
                            print(f"  ✅ {name} 完成")
                        else:
                            batch_failed.append(task_info)
                    except Exception as e:
                        task_name = task.get("transition") or task.get("pose")
                        print(f"  ❌ {task_name} 异常: {e}")
                        batch_failed.append(task)
            
            return batch_results, batch_failed
        
        # 第一轮执行
        print(f"\n📦 第1轮执行 ({len(tasks)} 个任务)...")
        results, failed_tasks = run_batch(tasks, attempt=1)
        
        # 重试失败的任务
        current_attempt = 2
        while failed_tasks and current_attempt <= max_retries:
            print(f"\n🔄 第{current_attempt}轮重试 ({len(failed_tasks)} 个失败任务)...")
            print(f"  ⏳ 等待 {retry_delay} 秒后重试...")
            time.sleep(retry_delay)
            
            # 重试时降低并发数，减少压力
            retry_concurrent = max(1, max_concurrent - 1)
            print(f"  📦 重试并发数: {retry_concurrent}")
            
            retry_results, still_failed = run_batch(failed_tasks, attempt=current_attempt)
            results.update(retry_results)
            failed_tasks = still_failed
            current_attempt += 1
        
        # 最终报告
        success_count = len(results)
        fail_count = len(failed_tasks)
        
        print(f"\n📊 并发任务完成:")
        print(f"  ✅ 成功: {success_count}/{total}")
        if fail_count > 0:
            print(f"  ❌ 失败: {fail_count}/{total}")
            for task in failed_tasks:
                task_name = task.get("transition") or task.get("pose")
                print(f"     - {task_name}")
        
        return results

    def _generate_transition_video_no_wait(self, transition: str, start_image: str) -> str:
        """生成单个过渡视频（无间隔等待版本，用于并发）"""
        # 使用v3.0 prompt系统
        if not getattr(self, "body_type", None):
            from prompt_config.breed_database import get_breed_config
            breed_config = get_breed_config(self.breed)
            if breed_config:
                self.body_type = breed_config.get("standard_size")
            else:
                self.body_type = ""

        from prompt_config.prompt_generator_v3 import generate_transition_prompt_v3
        prompt, negative_prompt = generate_transition_prompt_v3(
            transition=transition,
            breed_name=self.breed,
            species=self.species,
        )

        print(f"    [{transition}] 提示词: {prompt[:50]}...")
        print(f"    [{transition}] 负向: {negative_prompt[:40]}...")

        def do_generate():
            result = self.kling_video.image_to_video(
                image_path=start_image,
                prompt=prompt,
                negative_prompt=negative_prompt,
                duration=5,
                aspect_ratio="16:9",
                model_name=self.video_model_name,
                mode=self.video_model_mode
            )

            task_id = result['task_id']
            print(f"    [{transition}] 任务ID: {task_id}")

            task_data = self.kling_video.wait_for_video_task(task_id, max_wait_seconds=600)
            video_url = self._extract_video_url(task_data)

            output_path = str(self.videos_dir / "transitions" / f"{transition}.mp4")
            self.kling_video.download_video(video_url, output_path)

            return output_path

        return self._retry_operation(do_generate, f"生成过渡视频 {transition}")

    def _generate_loop_video_no_wait(self, pose: str, pose_image: str) -> str:
        """生成单个循环视频（无间隔等待版本，用于并发）"""
        if not getattr(self, "body_type", None):
            from prompt_config.breed_database import get_breed_config
            breed_config = get_breed_config(self.breed)
            if breed_config:
                self.body_type = breed_config.get("standard_size")
            else:
                self.body_type = ""

        from prompt_config.prompt_generator_v3 import generate_loop_prompt_v3
        prompt, negative_prompt = generate_loop_prompt_v3(
            pose=pose,
            breed_name=self.breed,
            species=self.species,
        )

        print(f"    [{pose}_loop] 提示词: {prompt[:50]}...")
        print(f"    [{pose}_loop] 负向: {negative_prompt[:40]}...")

        def do_generate():
            result = self.kling_video.image_to_video(
                image_path=pose_image,
                prompt=prompt,
                negative_prompt=negative_prompt,
                duration=5,
                aspect_ratio="16:9",
                model_name=self.video_model_name,
                mode=self.video_model_mode
            )

            task_id = result['task_id']
            print(f"    [{pose}_loop] 任务ID: {task_id}")

            task_data = self.kling_video.wait_for_video_task(task_id, max_wait_seconds=600)
            video_url = self._extract_video_url(task_data)

            output_path = str(self.videos_dir / "loops" / f"{pose}_loop.mp4")
            self.kling_video.download_video(video_url, output_path)

            return output_path

        return self._retry_operation(do_generate, f"生成循环视频 {pose}_loop")

    def _generate_remaining_transitions(self) -> Dict:
        """生成剩余9个过渡视频（并发版本，最多3个并发）"""
        all_transitions = get_all_transitions()
        remaining = [t for t in all_transitions if t not in FIRST_TRANSITIONS]

        total = len(remaining)
        print(f"\n📦 并发生成剩余 {total} 个过渡视频（并发数：3）")

        # 准备任务列表
        tasks = []
        for transition in remaining:
            start_pose = transition.split("2")[0]
            start_image = str(self.images_dir / f"{start_pose}.png")
            
            if not os.path.exists(start_image):
                print(f"  ⚠️  跳过 {transition}：{start_pose}.png 不存在")
                continue
            
            tasks.append({
                "transition": transition,
                "start_image": start_image
            })

        # 并发执行
        videos = self._run_video_tasks_concurrent(
            tasks=tasks,
            task_type="transition",
            max_concurrent=3,
            base_progress=55,
            progress_range=17
        )

        return videos

    def _generate_remaining_transitions_sequential(self) -> Dict:
        """生成剩余9个过渡视频（顺序版本，备用）"""
        all_transitions = get_all_transitions()
        remaining = [t for t in all_transitions if t not in FIRST_TRANSITIONS]

        total = len(remaining)
        base_progress = 55  # 步骤5起始进度

        videos = {}
        for idx, transition in enumerate(remaining):
            # 更新进度 (55% - 72%)
            progress = base_progress + int((idx / total) * 17)
            self._update_status(progress, f"生成剩余视频 ({idx+1}/{total}): {transition}...")

            print(f"\n  生成 {transition}... [{idx+1}/{total}]")

            start_pose = transition.split("2")[0]
            start_image = str(self.images_dir / f"{start_pose}.png")

            if not os.path.exists(start_image):
                print(f"  ⚠️  跳过 {transition}：{start_pose}.png 不存在")
                continue

            video_path = self._generate_transition_video(transition, start_image)
            videos[transition] = video_path

        return videos

    def _generate_loop_videos(self) -> Dict:
        """生成4个循环视频（并发版本，最多3个并发）"""
        print(f"\n📦 并发生成 {len(POSES)} 个循环视频（并发数：3）")

        # 准备任务列表
        tasks = []
        for pose in POSES:
            pose_image = str(self.images_dir / f"{pose}.png")
            if not os.path.exists(pose_image):
                print(f"  ⚠️  跳过 {pose}：{pose}.png 不存在")
                continue
            
            tasks.append({
                "pose": pose,
                "start_image": pose_image
            })

        # 并发执行
        videos = self._run_video_tasks_concurrent(
            tasks=tasks,
            task_type="loop",
            max_concurrent=3,
            base_progress=75,
            progress_range=13
        )

        return videos

    def _generate_loop_videos_sequential(self) -> Dict:
        """生成4个循环视频（顺序版本，备用）"""
        videos = {}
        total = len(POSES)
        base_progress = 75  # 步骤6起始进度

        for idx, pose in enumerate(POSES):
            # 更新进度 (75% - 88%)
            progress = base_progress + int((idx / total) * 13)
            self._update_status(progress, f"生成循环视频 ({idx+1}/{total}): {pose}...")

            print(f"\n  生成循环视频: {pose}... [{idx+1}/{total}]")

            pose_image = str(self.images_dir / f"{pose}.png")
            if not os.path.exists(pose_image):
                print(f"  ⚠️  跳过 {pose}：{pose}.png 不存在")
                continue

            # 使用v3.0 prompt系统（唯一版本）
            # 确保有体型信息（即使没有体重/生日也能工作）
            if not getattr(self, "body_type", None):
                from prompt_config.breed_database import get_breed_config
                breed_config = get_breed_config(self.breed)
                if breed_config:
                    self.body_type = breed_config.get("standard_size")
                else:
                    self.body_type = ""

            from prompt_config.prompt_generator_v3 import generate_loop_prompt_v3
            prompt, negative_prompt = generate_loop_prompt_v3(
                pose=pose,
                breed_name=self.breed,
                species=self.species,
            )

            print(f"    提示词: {prompt}")
            print(f"    负向: {negative_prompt[:50]}...")
            print(f"    🎬 视频模型: {self.video_model_name} (模式: {self.video_model_mode})")

            def do_generate(p=pose, pi=pose_image, pr=prompt, neg=negative_prompt):
                # 调用可灵AI图生视频（使用视频专用 API）
                result = self.kling_video.image_to_video(
                    image_path=pi,
                    prompt=pr,
                    negative_prompt=neg,
                    duration=5,
                    aspect_ratio="16:9",
                    model_name=self.video_model_name,
                    mode=self.video_model_mode
                )

                task_id = result['task_id']
                print(f"    任务ID: {task_id}")

                # 等待完成
                task_data = self.kling_video.wait_for_video_task(task_id, max_wait_seconds=600)

                # 提取视频URL
                video_url = self._extract_video_url(task_data)

                # 下载视频
                output_path = str(self.videos_dir / "loops" / f"{p}.mp4")
                self.kling_video.download_video(video_url, output_path)

                return output_path

            # 带重试执行
            try:
                output_path = self._retry_operation(
                    lambda: do_generate(pose, pose_image, prompt),
                    f"生成循环视频 {pose}"
                )
                print(f"    ✅ {pose}.mp4 已生成")
                videos[pose] = output_path

                # API调用间隔
                self._wait_interval(self.api_interval, "循环视频生成间隔")
            except Exception as e:
                print(f"    ❌ {pose} 循环视频生成失败: {str(e)}")
                # 继续处理其他姿势

        return videos

    def _convert_all_to_gif(self) -> Dict:
        """转换所有视频为GIF"""
        gifs = {"transitions": {}, "loops": {}}

        # 转换过渡视频
        transitions_dir = self.videos_dir / "transitions"
        if transitions_dir.exists():
            for video_file in transitions_dir.glob("*.mp4"):
                gif_path = str(self.gifs_dir / "transitions" / f"{video_file.stem}.gif")
                convert_mp4_to_gif(str(video_file), gif_path, fps_reduction=2, max_width=480)
                gifs["transitions"][video_file.stem] = gif_path

        # 转换循环视频
        loops_dir = self.videos_dir / "loops"
        if loops_dir.exists():
            for video_file in loops_dir.glob("*.mp4"):
                gif_path = str(self.gifs_dir / "loops" / f"{video_file.stem}.gif")
                convert_mp4_to_gif(str(video_file), gif_path, fps_reduction=2, max_width=480)
                gifs["loops"][video_file.stem] = gif_path

        return gifs

    def _concatenate_transition_videos(self) -> str:
        """拼接所有过渡视频为一个长视频"""
        try:
            transitions_dir = self.videos_dir / "transitions"

            if not transitions_dir.exists():
                print("  ⚠️  过渡视频目录不存在，跳过拼接")
                return None

            # 获取所有过渡视频
            video_files = sorted(transitions_dir.glob("*.mp4"))

            if not video_files:
                print("  ⚠️  没有找到过渡视频，跳过拼接")
                return None

            # 智能排序：尝试形成连贯的动作序列
            ordered_videos = self._sort_videos_by_transition(video_files)

            # 生成动态文件名：{species}_{breed}_{model_name}_{timestamp}.mp4
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            model_name_safe = self.video_model_name.replace('-', '_')
            filename = f"{self.species}_{self.breed}_{model_name_safe}_{timestamp}.mp4"
            output_path = str(self.videos_dir / filename)
            
            print(f"  📹 准备拼接 {len(ordered_videos)} 个过渡视频...")
            print(f"  拼接顺序:")
            for i, video in enumerate(ordered_videos, 1):
                print(f"    {i}. {Path(video).stem}")
            
            # 执行拼接
            concatenate_videos(
                [str(v) for v in ordered_videos],
                output_path,
                resize_to_first=True
            )
            
            print(f"  ✅ 拼接完成: {output_path}")
            return output_path
            
        except Exception as e:
            print(f"  ❌ 拼接视频失败: {e}")
            traceback.print_exc()
            return None
    
    def _sort_videos_by_transition(self, video_files: list) -> list:
        """
        根据过渡关系智能排序视频，形成连贯的动作序列
        使用欧拉路径算法寻找最佳顺序
        """
        import re
        from collections import defaultdict
        
        # 解析文件名: name -> (start_state, end_state)
        graph = defaultdict(list)
        out_degree = defaultdict(int)
        in_degree = defaultdict(int)
        
        valid_files = []
        for f in video_files:
            name = f.stem
            # 匹配 pattern: something2something
            match = re.search(r'([a-zA-Z]+)2([a-zA-Z]+)', name)
            if match:
                start, end = match.groups()
                start = start.lower()
                end = end.lower()
                
                graph[start].append((end, f))
                out_degree[start] += 1
                in_degree[end] += 1
                valid_files.append(f)
        
        if not valid_files:
            return sorted(video_files, key=lambda x: x.name)
        
        # 对邻接表排序
        for node in graph:
            graph[node].sort(key=lambda x: x[1].name)
        
        # 寻找起点（优先从sit开始）
        start_node = 'sit' if 'sit' in out_degree else (max(out_degree, key=out_degree.get) if out_degree else None)
        
        if not start_node:
            return sorted(video_files, key=lambda x: x.name)
        
        print(f"  🔄 从 '{start_node}' 姿势开始构建连贯序列...")
        
        # Hierholzer 算法寻找欧拉路径
        path = []
        temp_graph = {k: v[:] for k, v in graph.items()}
        
        def dfs(u):
            while temp_graph[u]:
                v, filename = temp_graph[u].pop(0)
                dfs(v)
                path.append(filename)
        
        dfs(start_node)
        
        # 逆序
        ordered_path = path[::-1]
        
        # 检查是否所有视频都包含
        if len(ordered_path) != len(valid_files):
            used_files = set(ordered_path)
            leftover = [f for f in valid_files if f not in used_files]
            if leftover:
                print(f"  ⚠️  部分视频无法连贯连接，追加 {len(leftover)} 个视频到末尾")
                ordered_path.extend(sorted(leftover, key=lambda x: x.name))
        
        return ordered_path

    def _extract_image_url(self, task_data: dict) -> str:
        """从任务数据中提取图片URL"""
        # 根据可灵AI的实际响应格式调整
        # 新格式: data.task_result.images[0].url
        if 'data' in task_data and 'task_result' in task_data['data']:
            task_result = task_data['data']['task_result']
            if 'images' in task_result and len(task_result['images']) > 0:
                return task_result['images'][0]['url']
        # 旧格式: data.images[0].url
        elif 'data' in task_data and 'images' in task_data['data']:
            return task_data['data']['images'][0]['url']
        # 直接格式: images[0].url
        elif 'images' in task_data:
            return task_data['images'][0]['url']
        else:
            raise Exception(f"无法从响应中提取图片URL: {task_data}")

    def _extract_video_url(self, task_data: dict) -> str:
        """从任务数据中提取视频URL"""
        # 根据可灵AI的实际响应格式调整
        # 新格式: data.task_result.videos[0].url
        if 'data' in task_data and 'task_result' in task_data['data']:
            task_result = task_data['data']['task_result']
            if 'videos' in task_result and len(task_result['videos']) > 0:
                return task_result['videos'][0]['url']
        # 旧格式: data.videos[0].url
        elif 'data' in task_data and 'videos' in task_data['data']:
            return task_data['data']['videos'][0]['url']
        elif 'data' in task_data and 'video_url' in task_data['data']:
            return task_data['data']['video_url']
        # 直接格式
        elif 'videos' in task_data:
            return task_data['videos'][0]['url']
        elif 'video_url' in task_data:
            return task_data['video_url']
        else:
            raise Exception(f"无法从响应中提取视频URL: {task_data}")

