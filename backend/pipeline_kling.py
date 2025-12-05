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
from typing import Dict, List, Optional, Callable, Any
from kling_api_helper import KlingAPI
from prompt_config.prompts import (
    get_base_pose_prompt,
    get_transition_prompt,
    get_loop_prompt,
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
        status_callback: Callable = None
    ):
        self.kling = KlingAPI(access_key, secret_key)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # 重试配置
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.step_interval = step_interval
        self.api_interval = api_interval

        # 状态回调（用于更新任务状态）
        self.status_callback = status_callback

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

        # ==================== 步骤5: 生成剩余过渡视频 ====================
        self._update_status(55, "步骤5: 生成剩余过渡视频...", "step5")
        print("\n🎬 步骤5: 生成剩余过渡视频")
        remaining_videos = self._generate_remaining_transitions()
        results["steps"]["remaining_transitions"] = remaining_videos

        self._wait_interval(self.step_interval, "步骤5完成")

        # ==================== 步骤6: 生成循环视频 ====================
        self._update_status(75, "步骤6: 生成循环视频...", "step6")
        print("\n🔄 步骤6: 生成循环视频")
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

    def _generate_base_image(self, pose: str, transparent_image: str) -> str:
        """生成基准图（图生图），带重试机制"""
        # 如果使用v3.0 prompt系统
        if self.use_v3_prompts and pose == "sit" and self.weight > 0 and self.birthday:
            from prompt_config.prompt_generator_v3 import generate_sit_prompt_v3
            prompt = generate_sit_prompt_v3(
                breed_name=self.breed,
                weight=self.weight,
                gender=self.gender,
                birthday=self.birthday,
                color=self.color
            )
            print(f"  使用v3.0 Prompt生成器 (三行格式)")
        else:
            # 使用旧版prompt
            prompt = get_base_pose_prompt(pose, self.breed, self.color, self.species)

        print(f"  提示词: {prompt}")
        print(f"  使用图生图API，输入图片: {transparent_image}")

        def do_generate():
            # 使用图生图API
            result = self.kling.image_to_image(
                image_path=transparent_image,
                prompt=prompt,
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
        """生成前3个过渡视频并提取首尾帧"""
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
        # 如果使用v3.0 prompt系统
        if self.use_v3_prompts and self.body_type:
            from prompt_config.prompt_generator_v3 import generate_transition_prompt_v3
            prompt = generate_transition_prompt_v3(
                transition,
                self.breed,
                self.body_type,
                self.color
            )
        else:
            # 使用旧版prompt
            prompt = get_transition_prompt(transition, self.breed, self.color, self.species)

        print(f"    提示词: {prompt}")

        def do_generate():
            # 调用可灵AI图生视频
            result = self.kling.image_to_video(
                image_path=start_image,
                prompt=prompt,
                duration=5,
                aspect_ratio="16:9"
            )

            task_id = result['task_id']
            print(f"    任务ID: {task_id}")

            # 等待完成
            task_data = self.kling.wait_for_video_task(task_id, max_wait_seconds=600)

            # 提取视频URL
            video_url = self._extract_video_url(task_data)

            # 下载视频
            output_path = str(self.videos_dir / "transitions" / f"{transition}.mp4")
            self.kling.download_video(video_url, output_path)

            return output_path

        # 带重试执行
        output_path = self._retry_operation(do_generate, f"生成过渡视频 {transition}")

        print(f"    ✅ {transition}.mp4 已生成")

        # API调用间隔
        self._wait_interval(self.api_interval, "视频生成间隔")

        return output_path

    def _generate_remaining_transitions(self) -> Dict:
        """生成剩余9个过渡视频"""
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
        """生成4个循环视频，带重试机制"""
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

            # 如果使用v3.0 prompt系统
            if self.use_v3_prompts and self.body_type:
                from prompt_config.prompt_generator_v3 import generate_loop_prompt_v3
                prompt = generate_loop_prompt_v3(
                    pose,
                    self.breed,
                    self.body_type,
                    self.color
                )
            else:
                # 使用旧版prompt
                prompt = get_loop_prompt(pose, self.breed, self.color, self.species)

            print(f"    提示词: {prompt}")

            def do_generate(p=pose, pi=pose_image, pr=prompt):
                # 调用可灵AI图生视频
                result = self.kling.image_to_video(
                    image_path=pi,
                    prompt=pr,
                    duration=5,
                    aspect_ratio="16:9"
                )

                task_id = result['task_id']
                print(f"    任务ID: {task_id}")

                # 等待完成
                task_data = self.kling.wait_for_video_task(task_id, max_wait_seconds=600)

                # 提取视频URL
                video_url = self._extract_video_url(task_data)

                # 下载视频
                output_path = str(self.videos_dir / "loops" / f"{p}.mp4")
                self.kling.download_video(video_url, output_path)

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
        
        # 输出路径
        output_path = str(self.videos_dir / "all_transitions_concatenated.mp4")
        
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

