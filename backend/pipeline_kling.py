#!/usr/bin/env python3
"""
可灵AI完整流程Pipeline
从上传图片到生成所有视频和GIF的完整流程
"""

import os
import json
import time
from pathlib import Path
from typing import Dict, List, Optional
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
from utils.video_utils import extract_first_frame, extract_last_frame, convert_mp4_to_gif


class KlingPipeline:
    """可灵AI完整流程"""
    
    def __init__(
        self,
        access_key: str,
        secret_key: str,
        output_dir: str = "output/kling_pipeline"
    ):
        self.kling = KlingAPI(access_key, secret_key)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # 宠物配置
        self.breed = ""
        self.color = ""
        self.species = ""
        
        # 路径
        self.pet_dir = None
        self.images_dir = None
        self.videos_dir = None
        self.gifs_dir = None
    
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
        pet_id: str
    ) -> str:
        """
        步骤2: 生成基础坐姿图片

        Args:
            transparent_image: 透明背景图片路径
            breed: 品种
            color: 颜色
            species: 物种
            pet_id: 宠物ID

        Returns:
            坐姿图片路径
        """
        self.breed = breed
        self.color = color
        self.species = species
        self.setup_pet_directories(pet_id)

        print(f"🖼️  步骤2: 生成基础坐姿图片")
        sit_image = self._generate_base_image("sit", transparent_image)
        print(f"✅ 坐姿图片已生成: {sit_image}")

        return sit_image

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
        pet_id: Optional[str] = None
    ) -> Dict:
        """
        运行完整流程
        
        Args:
            uploaded_image: 用户上传的图片路径
            breed: 品种（如：布偶猫）
            color: 颜色（如：蓝色）
            species: 物种（猫/犬）
            pet_id: 宠物ID（可选，默认使用时间戳）
        
        Returns:
            包含所有生成结果的字典
        """
        if pet_id is None:
            pet_id = f"pet_{int(time.time())}"
        
        self.breed = breed
        self.color = color
        self.species = species
        self.setup_pet_directories(pet_id)
        
        print("=" * 70)
        print(f"🚀 开始完整流程: {breed}{color}{species}")
        print(f"📁 输出目录: {self.pet_dir}")
        print("=" * 70)
        
        results = {
            "pet_id": pet_id,
            "breed": breed,
            "color": color,
            "species": species,
            "steps": {}
        }
        
        # 步骤1: 保存原图
        print("\n📤 步骤1: 保存原图")
        original_path = self.pet_dir / "original.jpg"
        import shutil
        shutil.copy(uploaded_image, original_path)
        results["steps"]["original"] = str(original_path)
        print(f"✅ 原图已保存: {original_path}")
        
        # 步骤2: 去背景
        print("\n🎨 步骤2: 去除背景")
        transparent_path = self.pet_dir / "transparent.png"
        remove_background(str(original_path), str(transparent_path))
        results["steps"]["transparent"] = str(transparent_path)
        
        # 步骤3: 生成第一张基准图（sit）
        print("\n🖼️  步骤3: 生成第一张基准图（sit）")
        sit_image = self._generate_base_image("sit", str(transparent_path))
        results["steps"]["base_sit"] = sit_image
        
        # 步骤4: 生成前3个过渡视频 + 提取尾帧
        print("\n🎬 步骤4: 生成前3个过渡视频")
        first_videos, other_poses = self._generate_first_transitions(sit_image)
        results["steps"]["first_transitions"] = first_videos
        results["steps"]["other_base_images"] = other_poses
        
        # 步骤5: 生成剩余过渡视频
        print("\n🎬 步骤5: 生成剩余过渡视频")
        remaining_videos = self._generate_remaining_transitions()
        results["steps"]["remaining_transitions"] = remaining_videos
        
        # 步骤6: 生成循环视频
        print("\n🔄 步骤6: 生成循环视频")
        loop_videos = self._generate_loop_videos()
        results["steps"]["loop_videos"] = loop_videos
        
        # 步骤7: 转换为GIF
        print("\n🎞️  步骤7: 转换所有视频为GIF")
        gifs = self._convert_all_to_gif()
        results["steps"]["gifs"] = gifs
        
        # 保存元数据
        metadata_path = self.pet_dir / "metadata.json"
        with open(metadata_path, 'w', encoding='utf-8') as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        
        print("\n" + "=" * 70)
        print("✅ 完整流程完成！")
        print(f"📊 元数据已保存: {metadata_path}")
        print("=" * 70)

        return results

    def _generate_base_image(self, pose: str, transparent_image: str) -> str:
        """生成基准图（图生图）"""
        prompt = get_base_pose_prompt(pose, self.breed, self.color, self.species)
        print(f"  提示词: {prompt}")
        print(f"  使用图生图API，输入图片: {transparent_image}")

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

        print(f"  ✅ {pose}.png 已生成")
        return output_path

    def _generate_first_transitions(self, sit_image: str) -> tuple:
        """生成前3个过渡视频并提取首尾帧"""
        videos = {}
        other_poses = {}
        first_frames = {}
        last_frames = {}

        for transition in FIRST_TRANSITIONS:
            print(f"\n  生成 {transition}...")

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

            # 提取首帧
            start_pose = transition.split("2")[0]
            first_frame_path = str(self.images_dir / f"{transition}_first_frame.png")
            extract_first_frame(video_path, first_frame_path)
            first_frames[transition] = first_frame_path
            print(f"  ✅ {transition}_first_frame.png 已提取")

            # 提取尾帧
            end_pose = transition.split("2")[1]
            end_image_path = str(self.images_dir / f"{end_pose}.png")
            last_frame_path = str(self.images_dir / f"{transition}_last_frame.png")
            extract_last_frame(video_path, end_image_path)
            extract_last_frame(video_path, last_frame_path)
            other_poses[end_pose] = end_image_path
            last_frames[transition] = last_frame_path
            print(f"  ✅ {end_pose}.png 已提取")
            print(f"  ✅ {transition}_last_frame.png 已提取")

        return videos, other_poses, first_frames, last_frames

    def _generate_transition_video(self, transition: str, start_image: str) -> str:
        """生成单个过渡视频"""
        prompt = get_transition_prompt(transition, self.breed, self.color, self.species)
        print(f"    提示词: {prompt}")

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

        print(f"    ✅ {transition}.mp4 已生成")
        return output_path

    def _generate_remaining_transitions(self) -> Dict:
        """生成剩余9个过渡视频"""
        all_transitions = get_all_transitions()
        remaining = [t for t in all_transitions if t not in FIRST_TRANSITIONS]

        videos = {}
        for transition in remaining:
            print(f"\n  生成 {transition}...")

            start_pose = transition.split("2")[0]
            start_image = str(self.images_dir / f"{start_pose}.png")

            if not os.path.exists(start_image):
                print(f"  ⚠️  跳过 {transition}：{start_pose}.png 不存在")
                continue

            video_path = self._generate_transition_video(transition, start_image)
            videos[transition] = video_path

        return videos

    def _generate_loop_videos(self) -> Dict:
        """生成4个循环视频"""
        videos = {}

        for pose in POSES:
            print(f"\n  生成循环视频: {pose}...")

            pose_image = str(self.images_dir / f"{pose}.png")
            if not os.path.exists(pose_image):
                print(f"  ⚠️  跳过 {pose}：{pose}.png 不存在")
                continue

            prompt = get_loop_prompt(pose, self.breed, self.color, self.species)
            print(f"    提示词: {prompt}")

            # 调用可灵AI图生视频
            result = self.kling.image_to_video(
                image_path=pose_image,
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
            output_path = str(self.videos_dir / "loops" / f"{pose}.mp4")
            self.kling.download_video(video_url, output_path)

            print(f"    ✅ {pose}.mp4 已生成")
            videos[pose] = output_path

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

