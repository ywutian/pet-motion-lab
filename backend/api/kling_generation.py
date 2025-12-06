#!/usr/bin/env python3
"""
可灵AI生成API路由
支持后台执行、重试机制、步骤间隔
使用 SQLite 数据库持久化历史记录，所有用户共享
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel
from typing import Optional
import os
import shutil
from pathlib import Path
import time
import tempfile
import threading
import traceback

from pipeline_kling import KlingPipeline
from utils.video_utils import extract_first_frame, extract_last_frame
from config import KLING_ACCESS_KEY, KLING_SECRET_KEY, KLING_VIDEO_ACCESS_KEY, KLING_VIDEO_SECRET_KEY
import database as db  # 导入数据库模块

router = APIRouter(prefix="/api/kling", tags=["kling"])

# 可灵AI凭证（从环境变量读取）
ACCESS_KEY = KLING_ACCESS_KEY
SECRET_KEY = KLING_SECRET_KEY
# 视频API凭证（海外版）
VIDEO_ACCESS_KEY = KLING_VIDEO_ACCESS_KEY
VIDEO_SECRET_KEY = KLING_VIDEO_SECRET_KEY

# 使用系统临时目录（Render 兼容）
TEMP_DIR = Path(tempfile.gettempdir()) / "pet_motion_lab"
TEMP_DIR.mkdir(parents=True, exist_ok=True)

UPLOAD_DIR = TEMP_DIR / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


class GenerationStatus(BaseModel):
    """生成状态"""
    pet_id: str
    status: str  # processing, completed, failed
    progress: int  # 0-100
    message: str
    results: Optional[dict] = None


# 内存中的任务状态缓存（用于实时进度更新，同时持久化到数据库）
task_status = {}

# 输出目录
OUTPUT_DIR = Path("output/kling_pipeline")


# ============================================
# 历史记录 API (使用数据库持久化，所有用户共享)
# ============================================

@router.get("/history")
async def get_generation_history(
    page: int = 1,
    page_size: int = 10,
    status_filter: str = ""
):
    """
    获取生成历史记录列表（所有用户共享）

    Args:
        page: 页码（从1开始）
        page_size: 每页数量
        status_filter: 状态过滤 (completed/failed/processing/空=全部)

    Returns:
        历史记录列表，包含预览图和基本信息
    """
    # 从数据库获取任务列表
    db_tasks, total = db.get_all_tasks(status_filter, page, page_size)

    history_list = []

    for task in db_tasks:
        pet_id = task['pet_id']
        pet_dir = OUTPUT_DIR / pet_id

        # 如果目录不存在，跳过（可能已被删除）
        if not pet_dir.exists():
            continue

        # 检查文件存在性
        has_transparent = (pet_dir / "transparent.png").exists()
        has_sit = (pet_dir / "base_images" / "sit.png").exists()
        has_concat_video = (pet_dir / "videos" / "all_transitions_concatenated.mp4").exists()
        has_gifs = (pet_dir / "gifs").exists() and any((pet_dir / "gifs").rglob("*.gif"))

        # 统计文件数量
        video_count = len(list((pet_dir / "videos").rglob("*.mp4"))) if (pet_dir / "videos").exists() else 0
        gif_count = len(list((pet_dir / "gifs").rglob("*.gif"))) if (pet_dir / "gifs").exists() else 0

        # 获取创建时间（优先使用数据库中的时间）
        created_at = task.get('created_at', pet_dir.stat().st_mtime)

        history_item = {
            "pet_id": pet_id,
            "breed": task.get("breed", "未知"),
            "color": task.get("color", ""),
            "species": task.get("species", ""),
            "status": task.get("status", "completed"),
            "progress": task.get("progress", 100),
            "message": task.get("message", ""),
            "created_at": created_at,
            "created_at_formatted": time.strftime("%Y-%m-%d %H:%M", time.localtime(created_at)),

            # 预览图
            "preview": {
                "thumbnail": f"/api/kling/download/{pet_id}/base_images/sit.png" if has_sit else None,
                "transparent": f"/api/kling/download/{pet_id}/transparent.png" if has_transparent else None,
            },

            # 文件统计
            "stats": {
                "video_count": video_count,
                "gif_count": gif_count,
                "has_concatenated_video": has_concat_video,
            },

            # 快捷链接
            "quick_links": {
                "concatenated_video": f"/api/kling/download/{pet_id}/videos/all_transitions_concatenated.mp4" if has_concat_video else None,
                "download_all": f"/api/kling/download-all/{pet_id}",
                "download_zip_gifs": f"/api/kling/download-zip/{pet_id}?include=gifs" if has_gifs else None,
            }
        }

        history_list.append(history_item)

    # 同时扫描输出目录，将未在数据库中的记录添加进去（兼容旧数据）
    if OUTPUT_DIR.exists():
        existing_pet_ids = {item['pet_id'] for item in history_list}

        for pet_dir in OUTPUT_DIR.iterdir():
            if not pet_dir.is_dir():
                continue

            pet_id = pet_dir.name
            if pet_id in existing_pet_ids:
                continue

            # 读取元数据
            metadata_path = pet_dir / "metadata.json"
            metadata = {}
            if metadata_path.exists():
                try:
                    with open(metadata_path, 'r', encoding='utf-8') as f:
                        metadata = json.load(f)
                except:
                    pass

            # 将旧数据迁移到数据库
            db.create_task(
                pet_id=pet_id,
                breed=metadata.get('breed', '未知'),
                color=metadata.get('color', ''),
                species=metadata.get('species', '')
            )
            db.update_task(pet_id, status='completed', progress=100)

    return JSONResponse({
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": (total + page_size - 1) // page_size,
        "items": history_list
    })


@router.get("/history/{pet_id}")
async def get_history_detail(pet_id: str):
    """
    获取单个历史记录的详细信息

    Args:
        pet_id: 宠物ID

    Returns:
        详细信息，包含所有生成的文件
    """
    pet_dir = OUTPUT_DIR / pet_id

    if not pet_dir.exists():
        raise HTTPException(status_code=404, detail="记录不存在")

    # 读取元数据
    metadata_path = pet_dir / "metadata.json"
    metadata = {}
    if metadata_path.exists():
        try:
            with open(metadata_path, 'r', encoding='utf-8') as f:
                metadata = json.load(f)
        except:
            pass

    # 获取任务状态
    task = task_status.get(pet_id, {})

    # 收集所有文件
    files = {
        "images": [],
        "transition_videos": [],
        "loop_videos": [],
        "transition_gifs": [],
        "loop_gifs": [],
        "concatenated_video": None,
    }

    # 图片
    images_dir = pet_dir / "base_images"
    if images_dir.exists():
        for img in images_dir.glob("*.png"):
            files["images"].append({
                "name": img.stem,
                "filename": img.name,
                "url": f"/api/kling/download/{pet_id}/base_images/{img.name}",
                "size": img.stat().st_size,
            })

    # 透明图
    transparent = pet_dir / "transparent.png"
    if transparent.exists():
        files["images"].insert(0, {
            "name": "transparent",
            "filename": "transparent.png",
            "url": f"/api/kling/download/{pet_id}/transparent.png",
            "size": transparent.stat().st_size,
        })

    # 过渡视频
    trans_videos_dir = pet_dir / "videos" / "transitions"
    if trans_videos_dir.exists():
        for video in sorted(trans_videos_dir.glob("*.mp4")):
            files["transition_videos"].append({
                "name": video.stem,
                "filename": video.name,
                "url": f"/api/kling/download/{pet_id}/videos/transitions/{video.name}",
                "size": video.stat().st_size,
            })

    # 循环视频
    loop_videos_dir = pet_dir / "videos" / "loops"
    if loop_videos_dir.exists():
        for video in sorted(loop_videos_dir.glob("*.mp4")):
            files["loop_videos"].append({
                "name": video.stem,
                "filename": video.name,
                "url": f"/api/kling/download/{pet_id}/videos/loops/{video.name}",
                "size": video.stat().st_size,
            })

    # 拼接视频
    concat_video = pet_dir / "videos" / "all_transitions_concatenated.mp4"
    if concat_video.exists():
        files["concatenated_video"] = {
            "name": "all_transitions_concatenated",
            "filename": "all_transitions_concatenated.mp4",
            "url": f"/api/kling/download/{pet_id}/videos/all_transitions_concatenated.mp4",
            "size": concat_video.stat().st_size,
        }

    # 过渡GIF
    trans_gifs_dir = pet_dir / "gifs" / "transitions"
    if trans_gifs_dir.exists():
        for gif in sorted(trans_gifs_dir.glob("*.gif")):
            files["transition_gifs"].append({
                "name": gif.stem,
                "filename": gif.name,
                "url": f"/api/kling/download/{pet_id}/gifs/transitions/{gif.name}",
                "size": gif.stat().st_size,
            })

    # 循环GIF
    loop_gifs_dir = pet_dir / "gifs" / "loops"
    if loop_gifs_dir.exists():
        for gif in sorted(loop_gifs_dir.glob("*.gif")):
            files["loop_gifs"].append({
                "name": gif.stem,
                "filename": gif.name,
                "url": f"/api/kling/download/{pet_id}/gifs/loops/{gif.name}",
                "size": gif.stat().st_size,
            })

    # 计算总大小
    total_size = sum(
        f.get("size", 0)
        for category in files.values()
        for f in (category if isinstance(category, list) else [category] if category else [])
    )

    return JSONResponse({
        "pet_id": pet_id,
        "breed": metadata.get("breed", task.get("breed", "未知")),
        "color": metadata.get("color", task.get("color", "")),
        "species": metadata.get("species", task.get("species", "")),
        "status": task.get("status", "completed" if metadata else "unknown"),
        "created_at": pet_dir.stat().st_mtime,
        "created_at_formatted": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(pet_dir.stat().st_mtime)),

        "files": files,

        "summary": {
            "total_images": len(files["images"]),
            "total_transition_videos": len(files["transition_videos"]),
            "total_loop_videos": len(files["loop_videos"]),
            "total_transition_gifs": len(files["transition_gifs"]),
            "total_loop_gifs": len(files["loop_gifs"]),
            "has_concatenated_video": files["concatenated_video"] is not None,
            "total_size": total_size,
            "total_size_formatted": _format_size(total_size),
        },

        "download_links": {
            "all_files": f"/api/kling/download-all/{pet_id}",
            "zip_gifs": f"/api/kling/download-zip/{pet_id}?include=gifs",
            "zip_videos": f"/api/kling/download-zip/{pet_id}?include=videos",
            "zip_all": f"/api/kling/download-zip/{pet_id}?include=all",
        },

        "metadata": metadata,
    })


def _format_size(size_bytes: int) -> str:
    """格式化文件大小"""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"


@router.delete("/history/{pet_id}")
async def delete_history(pet_id: str):
    """
    删除历史记录

    Args:
        pet_id: 宠物ID

    Returns:
        删除结果
    """
    pet_dir = OUTPUT_DIR / pet_id

    if not pet_dir.exists() and not db.get_task(pet_id):
        raise HTTPException(status_code=404, detail="记录不存在")

    # 删除目录
    if pet_dir.exists():
        shutil.rmtree(pet_dir)

    # 删除数据库记录
    db.delete_task(pet_id)

    # 删除内存中的任务状态
    if pet_id in task_status:
        del task_status[pet_id]

    return JSONResponse({
        "status": "success",
        "message": f"已删除记录: {pet_id}"
    })


def _save_metadata(pet_id: str, metadata: dict):
    """保存元数据到文件"""
    try:
        pet_dir = OUTPUT_DIR / pet_id
        pet_dir.mkdir(parents=True, exist_ok=True)

        metadata_path = pet_dir / "metadata.json"
        with open(metadata_path, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, ensure_ascii=False, indent=2)

        print(f"📝 元数据已保存: {metadata_path}")
    except Exception as e:
        print(f"⚠️ 保存元数据失败: {e}")


@router.post("/init")
async def init_pet_task(
    file: UploadFile = File(...),
    breed: str = Form(...),
    color: str = Form(...),
    species: str = Form(...),
    weight: str = Form(""),
    birthday: str = Form("")
):
    """
    初始化宠物任务（必须上传原始图片）

    Args:
        file: 原始宠物图片
        breed: 品种（如：布偶猫）
        color: 颜色（如：蓝色）
        species: 物种（猫/犬）
        weight: 重量（可选，如：5kg）
        birthday: 生日（可选，如：2020-01-01）

    Returns:
        任务ID和初始状态
    """
    # 生成任务ID
    pet_id = f"pet_{int(time.time())}"

    # 保存上传的文件
    upload_path = UPLOAD_DIR / f"{pet_id}_{file.filename}"
    with open(upload_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 初始化任务状态（同时保存到内存和数据库）
    task_status[pet_id] = {
        "status": "initialized",
        "progress": 0,
        "message": "任务已创建",
        "uploaded_image": str(upload_path),
        "breed": breed,
        "color": color,
        "species": species,
        "weight": weight,
        "birthday": birthday,
        "current_step": 0,
        "results": {
            "step1_background_removed": None,
            "step2_base_image": None,
            "step3_initial_videos": [],
            "step4_remaining_videos": [],
            "step5_loop_videos": [],
            "step6_gifs": []
        }
    }

    # 持久化到数据库
    db.create_task(pet_id=pet_id, breed=breed, color=color, species=species,
                   weight=weight, birthday=birthday)

    return JSONResponse({
        "pet_id": pet_id,
        "status": "initialized",
        "message": "任务已创建，可以开始执行各个步骤"
    })


@router.post("/step1/{pet_id}")
async def step1_remove_background(
    pet_id: str,
    file: Optional[UploadFile] = File(None)
):
    """
    步骤1: 去除背景（使用 Remove.bg API）
    - 不上传文件：使用初始化时的原始图片，调用 Remove.bg API 去除背景
    - 上传文件：使用自定义图片（已去除背景的图片）
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    try:
        task = task_status[pet_id]

        # 如果用户上传了自定义图片，直接使用
        if file:
            custom_path = UPLOAD_DIR / f"{pet_id}_step1_custom_{file.filename}"
            with open(custom_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

            task["results"]["step1_background_removed"] = str(custom_path)
            task["current_step"] = max(task["current_step"], 1)
            task["message"] = "步骤1: 使用自定义图片（跳过背景去除）"
            task["status"] = "step1_completed"

            return JSONResponse({
                "pet_id": pet_id,
                "step": 1,
                "status": "completed",
                "result": str(custom_path),
                "custom": True
            })

        # 否则使用本地模型自动去除背景
        if not task["uploaded_image"]:
            raise HTTPException(status_code=400, detail="没有原始图片，请上传自定义图片")

        task["status"] = "processing"
        task["progress"] = 10
        task["message"] = "步骤1: 正在使用 Remove.bg API 去除背景..."

        # 导入本地背景去除工具
        import sys
        from pathlib import Path
        sys.path.append(str(Path(__file__).parent.parent))
        from utils.image_utils import remove_background

        # 设置输出路径
        output_dir = Path("output/kling_pipeline") / pet_id
        output_dir.mkdir(parents=True, exist_ok=True)
        transparent_path = output_dir / "transparent.png"

        # 执行背景去除
        result = remove_background(task["uploaded_image"], str(transparent_path))

        task["results"]["step1_background_removed"] = result
        task["current_step"] = max(task["current_step"], 1)
        task["progress"] = 15
        task["message"] = "步骤1完成: 背景已去除（Remove.bg API）"
        task["status"] = "step1_completed"

        return JSONResponse({
            "pet_id": pet_id,
            "step": 1,
            "status": "completed",
            "result": result,
            "custom": False
        })
    except Exception as e:
        task_status[pet_id]["status"] = "failed"
        task_status[pet_id]["message"] = f"步骤1失败: {str(e)}"
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/step2/{pet_id}")
async def step2_generate_base_image(
    pet_id: str,
    file: Optional[UploadFile] = File(None)
):
    """
    步骤2: 生成基础坐姿图片
    可选：上传自定义图片跳过此步骤
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id]

    try:
        # 如果用户上传了自定义图片，直接使用
        if file:
            custom_path = UPLOAD_DIR / f"{pet_id}_step2_custom_{file.filename}"
            with open(custom_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

            task["results"]["step2_base_image"] = str(custom_path)
            task["current_step"] = 2
            task["message"] = "步骤2: 使用自定义图片"
            task["status"] = "step2_completed"

            return JSONResponse({
                "pet_id": pet_id,
                "step": 2,
                "status": "completed",
                "result": str(custom_path),
                "custom": True
            })

        # 否则执行自动生成
        if task["current_step"] < 1:
            raise HTTPException(status_code=400, detail="请先完成步骤1或上传自定义图片")

        task["status"] = "processing"
        task["progress"] = 20
        task["message"] = "步骤2: 正在生成基础坐姿图片..."

        pipeline = KlingPipeline(
            access_key=ACCESS_KEY,
            secret_key=SECRET_KEY,
            output_dir="output/kling_pipeline",
            video_access_key=VIDEO_ACCESS_KEY,
            video_secret_key=VIDEO_SECRET_KEY
        )

        # 执行步骤2
        result = pipeline.step2_generate_base_image(
            transparent_image=task["results"]["step1_background_removed"],
            breed=task["breed"],
            color=task["color"],
            species=task["species"],
            pet_id=pet_id
        )

        task["results"]["step2_base_image"] = result
        task["current_step"] = 2
        task["progress"] = 30
        task["message"] = "步骤2完成: 基础坐姿图片已生成（含背景去除）"
        task["status"] = "step2_completed"

        return JSONResponse({
            "pet_id": pet_id,
            "step": 2,
            "status": "completed",
            "result": result,
            "custom": False
        })
    except Exception as e:
        task_status[pet_id]["status"] = "failed"
        task_status[pet_id]["message"] = f"步骤2失败: {str(e)}"
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# 后台任务配置（增强重试机制）
# ============================================
BACKGROUND_MAX_RETRIES = 5       # 最大重试次数（5次后才报错）
BACKGROUND_RETRY_DELAY = 60      # 重试间隔（秒）- 1分钟起
BACKGROUND_STEP_INTERVAL = 15    # 步骤间隔（秒）
BACKGROUND_API_INTERVAL = 10     # API调用间隔（秒）


def run_pipeline_in_background(
    pet_id: str,
    upload_path: str,
    breed: str,
    color: str,
    species: str,
    weight: str = "",
    birthday: str = ""
):
    """
    在后台线程中执行完整的生成流程

    重试机制：
    - 每个API调用失败后会自动重试
    - 最多重试5次，间隔时间递增（1分钟、1.5分钟、2分钟...）
    - 超过5次才会标记为失败

    Args:
        pet_id: 宠物任务ID
        upload_path: 上传图片路径
        breed: 品种
        color: 颜色
        species: 物种
        weight: 重量
        birthday: 生日
    """
    try:
        print(f"\n{'='*70}")
        print(f"🚀 后台任务启动: {pet_id}")
        print(f"📋 品种: {breed}, 颜色: {color}, 物种: {species}")
        print(f"🔧 重试: {BACKGROUND_MAX_RETRIES}次, 间隔: {BACKGROUND_RETRY_DELAY}s")
        print(f"⏳ 步骤间隔: {BACKGROUND_STEP_INTERVAL}s, API间隔: {BACKGROUND_API_INTERVAL}s")
        print(f"{'='*70}\n")

        # 状态回调函数
        def status_callback(progress: int, message: str, step: str = None):
            if progress >= 0:
                task_status[pet_id]["progress"] = progress
            task_status[pet_id]["message"] = message
            if step:
                task_status[pet_id]["current_step"] = step

        # 创建Pipeline实例（带重试和间隔配置）
        pipeline = KlingPipeline(
            access_key=ACCESS_KEY,
            secret_key=SECRET_KEY,
            output_dir="output/kling_pipeline",
            max_retries=BACKGROUND_MAX_RETRIES,
            retry_delay=BACKGROUND_RETRY_DELAY,
            step_interval=BACKGROUND_STEP_INTERVAL,
            api_interval=BACKGROUND_API_INTERVAL,
            status_callback=status_callback,
            video_access_key=VIDEO_ACCESS_KEY,
            video_secret_key=VIDEO_SECRET_KEY
        )

        # 解析weight为浮点数（用于v3.0智能分析）
        weight_float = 0.0
        if weight:
            try:
                # 支持 "5kg" 或 "5" 格式
                weight_float = float(weight.replace("kg", "").replace("公斤", "").strip())
            except ValueError:
                weight_float = 0.0

        # 执行完整流程（传递weight和birthday启用v3.0提示词）
        results = pipeline.run_full_pipeline(
            uploaded_image=upload_path,
            breed=breed,
            color=color,
            species=species,
            pet_id=pet_id,
            weight=weight_float,
            birthday=birthday
        )

        # 完成
        task_status[pet_id]["status"] = "completed"
        task_status[pet_id]["progress"] = 100
        task_status[pet_id]["message"] = "✅ 生成完成！"
        task_status[pet_id]["results"] = results

        # 保存元数据到文件（用于历史记录）
        _save_metadata(pet_id, {
            "breed": breed,
            "color": color,
            "species": species,
            "weight": weight,
            "birthday": birthday,
            "created_at": task_status[pet_id].get("started_at", time.time()),
            "completed_at": time.time(),
            "status": "completed",
        })

        # 同步到数据库（持久化，所有用户可见）
        db.update_task(pet_id, status='completed', progress=100,
                       message='✅ 生成完成！', results=results,
                       completed_at=time.time())

        print(f"\n{'='*70}")
        print(f"✅ 后台任务完成: {pet_id}")
        print(f"{'='*70}\n")

    except Exception as e:
        error_msg = str(e)
        error_trace = traceback.format_exc()

        print(f"\n{'='*70}")
        print(f"❌ 后台任务失败: {pet_id}")
        print(f"错误: {error_msg}")
        print(f"堆栈:\n{error_trace}")
        print(f"{'='*70}\n")

        task_status[pet_id]["status"] = "failed"
        task_status[pet_id]["message"] = f"❌ 生成失败: {error_msg}"
        task_status[pet_id]["error"] = error_trace

        # 同步到数据库
        db.update_task(pet_id, status='failed',
                       message=f'❌ 生成失败: {error_msg}')


@router.post("/generate")
async def generate_pet_animations(
    file: UploadFile = File(...),
    breed: str = Form(...),
    color: str = Form(...),
    species: str = Form(...),
    weight: str = Form(""),
    birthday: str = Form("")
):
    """
    生成宠物动画完整流程（后台执行，立即返回）

    Args:
        file: 上传的宠物图片
        breed: 品种（如：布偶猫）
        color: 颜色（如：蓝色）
        species: 物种（猫/犬）
        weight: 重量（可选，如：5kg）
        birthday: 生日（可选，如：2020-01-01）

    Returns:
        任务ID和初始状态（任务在后台执行）
    """
    # 生成任务ID
    pet_id = f"pet_{int(time.time())}"

    # 保存上传的文件
    upload_path = UPLOAD_DIR / f"{pet_id}_{file.filename}"
    with open(upload_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 初始化任务状态（同时保存到内存和数据库）
    task_status[pet_id] = {
        "status": "processing",
        "progress": 0,
        "message": "🚀 任务已创建，正在后台处理...",
        "current_step": "init",
        "breed": breed,
        "color": color,
        "species": species,
        "weight": weight,
        "birthday": birthday,
        "results": None,
        "error": None,
        "started_at": time.time()
    }

    # 持久化到数据库
    db.create_task(pet_id=pet_id, breed=breed, color=color, species=species,
                   weight=weight, birthday=birthday)
    db.update_task(pet_id, status='processing', started_at=time.time())

    # 启动后台线程执行生成流程
    thread = threading.Thread(
        target=run_pipeline_in_background,
        args=(pet_id, str(upload_path), breed, color, species, weight, birthday),
        daemon=True  # 守护线程，主进程退出时自动结束
    )
    thread.start()

    print(f"📤 后台任务已启动: {pet_id}")

    return JSONResponse({
        "pet_id": pet_id,
        "status": "processing",
        "message": "🚀 任务已创建，正在后台处理中...",
        "note": "请使用 GET /api/kling/status/{pet_id} 查询进度"
    })


@router.post("/step3/{pet_id}")
async def step3_generate_initial_videos(
    pet_id: str,
    file: Optional[UploadFile] = File(None)
):
    """
    步骤3: 生成初始3个过渡视频 (sit→walk, sit→rest, rest→sleep)
    可选：上传自定义图片（坐姿）跳过步骤1-2直接生成视频

    注意：此API会立即返回，视频生成在后台进行
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id]

    # 如果用户上传了自定义图片，使用它作为基础图片
    base_image = None
    if file:
        custom_path = UPLOAD_DIR / f"{pet_id}_step3_custom_{file.filename}"
        with open(custom_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        base_image = str(custom_path)
        task["results"]["step2_base_image"] = base_image  # 更新基础图片
    elif task["current_step"] >= 2:
        base_image = task["results"]["step2_base_image"]
    else:
        raise HTTPException(status_code=400, detail="请先完成步骤2或上传自定义图片")

    task["status"] = "processing"
    task["progress"] = 35
    task["message"] = "步骤3: 正在生成初始过渡视频..."

    # 在后台线程中执行视频生成
    def process_step3():
        try:
            pipeline = KlingPipeline(
                access_key=ACCESS_KEY,
                secret_key=SECRET_KEY,
                output_dir="output/kling_pipeline",
                video_access_key=VIDEO_ACCESS_KEY,
                video_secret_key=VIDEO_SECRET_KEY
            )

            # 执行步骤3
            results = pipeline.step3_generate_initial_videos(
                base_image=base_image,
                breed=task["breed"],
                color=task["color"],
                species=task["species"],
                pet_id=pet_id
            )

            task["results"]["step3_initial_videos"] = results
            task["current_step"] = 3
            task["progress"] = 50
            task["message"] = "步骤3完成: 初始过渡视频已生成"
            task["status"] = "step3_completed"
        except Exception as e:
            task["status"] = "failed"
            task["message"] = f"步骤3失败: {str(e)}"
            print(f"❌ 步骤3失败: {str(e)}")

    # 启动后台线程
    import threading
    thread = threading.Thread(target=process_step3)
    thread.start()

    # 立即返回
    return JSONResponse({
        "pet_id": pet_id,
        "step": 3,
        "status": "processing",
        "message": "步骤3已开始，正在后台生成视频...",
        "custom": file is not None
    })


@router.get("/step3/status/{pet_id}")
async def get_step3_status(pet_id: str):
    """
    查询步骤3的状态
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id]

    return JSONResponse({
        "pet_id": pet_id,
        "step": 3,
        "status": task["status"],
        "progress": task["progress"],
        "message": task["message"],
        "results": task["results"].get("step3_initial_videos") if task["status"] == "step3_completed" else None
    })


# 保留原来的错误处理部分
def _handle_step3_error(pet_id: str, e: Exception):
    """处理步骤3错误"""
    if pet_id in task_status:
        task_status[pet_id]["status"] = "failed"
        task_status[pet_id]["message"] = f"步骤3失败: {str(e)}"
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/step4/{pet_id}")
async def step4_generate_remaining_videos(pet_id: str):
    """
    步骤4: 生成剩余9个过渡视频
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id]
    if task["current_step"] < 3:
        raise HTTPException(status_code=400, detail="请先完成步骤3")

    try:
        task["status"] = "processing"
        task["progress"] = 55
        task["message"] = "步骤4: 正在生成剩余过渡视频..."

        pipeline = KlingPipeline(
            access_key=ACCESS_KEY,
            secret_key=SECRET_KEY,
            output_dir="output/kling_pipeline",
            video_access_key=VIDEO_ACCESS_KEY,
            video_secret_key=VIDEO_SECRET_KEY
        )

        # 执行步骤4
        results = pipeline.step4_generate_remaining_videos(
            initial_videos=task["results"]["step3_initial_videos"],
            breed=task["breed"],
            color=task["color"],
            species=task["species"],
            pet_id=pet_id
        )

        task["results"]["step4_remaining_videos"] = results
        task["current_step"] = 4
        task["progress"] = 70
        task["message"] = "步骤4完成: 剩余过渡视频已生成"
        task["status"] = "step4_completed"

        return JSONResponse({
            "pet_id": pet_id,
            "step": 4,
            "status": "completed",
            "results": results
        })
    except Exception as e:
        task_status[pet_id]["status"] = "failed"
        task_status[pet_id]["message"] = f"步骤4失败: {str(e)}"
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/step5/{pet_id}")
async def step5_generate_loop_videos(pet_id: str):
    """
    步骤5: 生成4个循环视频
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id]
    if task["current_step"] < 4:
        raise HTTPException(status_code=400, detail="请先完成步骤4")

    try:
        task["status"] = "processing"
        task["progress"] = 75
        task["message"] = "步骤5: 正在生成循环视频..."

        pipeline = KlingPipeline(
            access_key=ACCESS_KEY,
            secret_key=SECRET_KEY,
            output_dir="output/kling_pipeline",
            video_access_key=VIDEO_ACCESS_KEY,
            video_secret_key=VIDEO_SECRET_KEY
        )

        # 执行步骤5
        results = pipeline.step5_generate_loop_videos(
            base_images=task["results"]["step3_initial_videos"]["extracted_frames"],
            breed=task["breed"],
            color=task["color"],
            species=task["species"],
            pet_id=pet_id
        )

        task["results"]["step5_loop_videos"] = results
        task["current_step"] = 5
        task["progress"] = 85
        task["message"] = "步骤5完成: 循环视频已生成"
        task["status"] = "step5_completed"

        return JSONResponse({
            "pet_id": pet_id,
            "step": 5,
            "status": "completed",
            "results": results
        })
    except Exception as e:
        task_status[pet_id]["status"] = "failed"
        task_status[pet_id]["message"] = f"步骤5失败: {str(e)}"
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/step6/{pet_id}")
async def step6_convert_to_gifs(pet_id: str):
    """
    步骤6: 将所有视频转换为GIF
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id]
    if task["current_step"] < 5:
        raise HTTPException(status_code=400, detail="请先完成步骤5")

    try:
        task["status"] = "processing"
        task["progress"] = 90
        task["message"] = "步骤6: 正在转换为GIF..."

        pipeline = KlingPipeline(
            access_key=ACCESS_KEY,
            secret_key=SECRET_KEY,
            output_dir="output/kling_pipeline",
            video_access_key=VIDEO_ACCESS_KEY,
            video_secret_key=VIDEO_SECRET_KEY
        )

        # 收集所有视频
        all_videos = []
        all_videos.extend(task["results"]["step3_initial_videos"]["videos"])
        all_videos.extend(task["results"]["step4_remaining_videos"])
        all_videos.extend(task["results"]["step5_loop_videos"])

        # 执行步骤6
        results = pipeline.step6_convert_to_gifs(
            videos=all_videos,
            pet_id=pet_id
        )

        task["results"]["step6_gifs"] = results
        task["current_step"] = 6
        task["progress"] = 100
        task["message"] = "所有步骤完成！"
        task["status"] = "completed"

        return JSONResponse({
            "pet_id": pet_id,
            "step": 6,
            "status": "completed",
            "results": results
        })
    except Exception as e:
        task_status[pet_id]["status"] = "failed"
        task_status[pet_id]["message"] = f"步骤6失败: {str(e)}"
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/status/{pet_id}")
async def get_generation_status(pet_id: str):
    """
    查询生成状态（实时进度）

    Args:
        pet_id: 宠物ID

    Returns:
        生成状态，包含：
        - status: 状态 (processing/completed/failed)
        - progress: 进度百分比 (0-100)
        - message: 当前操作描述
        - current_step: 当前步骤
        - elapsed_time: 已用时间（秒）
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id].copy()

    # 计算已用时间
    if "started_at" in task:
        task["elapsed_time"] = round(time.time() - task["started_at"], 1)
        task["elapsed_time_formatted"] = _format_duration(task["elapsed_time"])

    return JSONResponse(task)


def _format_duration(seconds: float) -> str:
    """格式化时长为可读字符串"""
    if seconds < 60:
        return f"{int(seconds)}秒"
    elif seconds < 3600:
        mins = int(seconds // 60)
        secs = int(seconds % 60)
        return f"{mins}分{secs}秒"
    else:
        hours = int(seconds // 3600)
        mins = int((seconds % 3600) // 60)
        return f"{hours}小时{mins}分"


@router.get("/results/{pet_id}")
async def get_generation_results(pet_id: str):
    """
    获取生成结果
    
    Args:
        pet_id: 宠物ID
    
    Returns:
        生成结果详情
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")
    
    status = task_status[pet_id]
    
    if status["status"] != "completed":
        raise HTTPException(status_code=400, detail="任务尚未完成")
    
    return JSONResponse(status["results"])


@router.delete("/task/{pet_id}")
async def delete_task(pet_id: str):
    """
    删除任务
    
    Args:
        pet_id: 宠物ID
    
    Returns:
        删除结果
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")
    
    # 删除任务状态
    del task_status[pet_id]
    
    # 删除输出文件（可选）
    output_dir = Path("output/kling_pipeline") / pet_id
    if output_dir.exists():
        shutil.rmtree(output_dir)
    
    return JSONResponse({"message": "任务已删除"})


@router.get("/download/{pet_id}/{filename:path}")
async def download_file_simple(pet_id: str, filename: str):
    """
    下载生成的文件（简化版，文件直接在pet_id目录下）

    Args:
        pet_id: 宠物ID
        filename: 文件名（如 transparent.png 或 videos/sit2walk.mp4）

    Returns:
        文件下载
    """
    # 构建文件路径（支持相对路径和绝对路径）
    base_dir = Path("output/kling_pipeline") / pet_id
    file_path = base_dir / filename

    print(f"📥 下载请求（简化）: pet_id={pet_id}, filename={filename}")
    print(f"📁 文件路径: {file_path}")

    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        raise HTTPException(status_code=404, detail=f"文件不存在: {file_path}")

    # 根据文件扩展名确定媒体类型
    suffix = file_path.suffix.lower()
    media_type = None
    if suffix in ['.png', '.jpg', '.jpeg']:
        media_type = "image/png" if suffix == '.png' else "image/jpeg"
    elif suffix in ['.mp4', '.avi', '.mov']:
        media_type = "video/mp4"
    elif suffix == '.gif':
        media_type = "image/gif"
    else:
        media_type = "application/octet-stream"

    print(f"✅ 返回文件: {file_path}, 类型: {media_type}")

    return FileResponse(
        path=str(file_path),
        media_type=media_type,
        filename=filename.split('/')[-1]  # 只使用文件名，不包含路径
    )


@router.get("/download/{pet_id}/{file_type}/{filename:path}")
async def download_file(pet_id: str, file_type: str, filename: str):
    """
    下载生成的文件（完整版，文件在子目录中）

    Args:
        pet_id: 宠物ID
        file_type: 文件类型目录 (base_images/images/videos/gifs等)
        filename: 文件名（可以包含子路径）

    Returns:
        文件下载
    """
    # 构建文件路径
    base_dir = Path("output/kling_pipeline") / pet_id
    file_path = base_dir / file_type / filename

    print(f"📥 下载请求: pet_id={pet_id}, file_type={file_type}, filename={filename}")
    print(f"📁 文件路径: {file_path}")

    if not file_path.exists():
        print(f"❌ 文件不存在: {file_path}")
        raise HTTPException(status_code=404, detail=f"文件不存在: {file_path}")

    # 根据文件扩展名确定媒体类型
    suffix = file_path.suffix.lower()
    media_type = None
    if suffix in ['.png', '.jpg', '.jpeg']:
        media_type = "image/png" if suffix == '.png' else "image/jpeg"
    elif suffix in ['.mp4', '.avi', '.mov']:
        media_type = "video/mp4"
    elif suffix == '.gif':
        media_type = "image/gif"
    else:
        media_type = "application/octet-stream"

    print(f"✅ 返回文件: {file_path}, 类型: {media_type}")

    return FileResponse(
        path=str(file_path),
        media_type=media_type,
        filename=filename
    )


@router.get("/download-all/{pet_id}")
async def get_all_download_links(pet_id: str, base_url: str = ""):
    """
    获取所有可下载文件的链接列表（含GIF和拼接视频）

    Args:
        pet_id: 宠物ID
        base_url: 基础URL（可选，用于生成完整URL）

    Returns:
        所有文件的下载链接，分类整理
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id]
    results = task.get("results", {})
    steps = results.get("steps", {})

    # 基础路径前缀
    api_prefix = f"{base_url}/api/kling/download/{pet_id}"

    download_links = {
        "status": task.get("status"),
        "pet_id": pet_id,

        # 图片资源
        "images": {
            "original": None,           # 原始图片
            "transparent": None,        # 去背景图片
            "sit": None,                # 坐姿基础图
            "walk": None,               # 行走姿势图
            "rest": None,               # 趴卧姿势图
            "sleep": None,              # 睡眠姿势图
        },

        # 过渡视频 (12个)
        "transition_videos": [],

        # 循环视频 (4个)
        "loop_videos": [],

        # GIF动图
        "gifs": {
            "transitions": [],          # 过渡动图
            "loops": [],                # 循环动图
        },

        # 拼接视频
        "concatenated_video": None,

        # 快捷下载（最重要的文件）
        "quick_download": {
            "all_gifs": [],             # 所有GIF
            "main_video": None,         # 拼接视频
        }
    }

    # ========== 图片 ==========
    if steps.get("original"):
        download_links["images"]["original"] = f"{api_prefix}/original.jpg"

    if steps.get("transparent"):
        download_links["images"]["transparent"] = f"{api_prefix}/transparent.png"

    if steps.get("base_sit"):
        download_links["images"]["sit"] = f"{api_prefix}/base_images/sit.png"

    # 其他姿势图片
    for pose in ["walk", "rest", "sleep"]:
        pose_path = f"output/kling_pipeline/{pet_id}/base_images/{pose}.png"
        if Path(pose_path).exists():
            download_links["images"][pose] = f"{api_prefix}/base_images/{pose}.png"

    # ========== 过渡视频 ==========
    if steps.get("first_transitions"):
        for name, path in steps["first_transitions"].items():
            download_links["transition_videos"].append({
                "name": name,
                "filename": f"{name}.mp4",
                "url": f"{api_prefix}/videos/transitions/{name}.mp4"
            })

    if steps.get("remaining_transitions"):
        for name, path in steps["remaining_transitions"].items():
            download_links["transition_videos"].append({
                "name": name,
                "filename": f"{name}.mp4",
                "url": f"{api_prefix}/videos/transitions/{name}.mp4"
            })

    # ========== 循环视频 ==========
    if steps.get("loop_videos"):
        for name, path in steps["loop_videos"].items():
            download_links["loop_videos"].append({
                "name": name,
                "filename": f"{name}.mp4",
                "url": f"{api_prefix}/videos/loops/{name}.mp4"
            })

    # ========== GIF ==========
    if steps.get("gifs"):
        gifs_data = steps["gifs"]

        # 过渡GIF
        if gifs_data.get("transitions"):
            for name, path in gifs_data["transitions"].items():
                gif_info = {
                    "name": name,
                    "filename": f"{name}.gif",
                    "url": f"{api_prefix}/gifs/transitions/{name}.gif"
                }
                download_links["gifs"]["transitions"].append(gif_info)
                download_links["quick_download"]["all_gifs"].append(gif_info)

        # 循环GIF
        if gifs_data.get("loops"):
            for name, path in gifs_data["loops"].items():
                gif_info = {
                    "name": name,
                    "filename": f"{name}.gif",
                    "url": f"{api_prefix}/gifs/loops/{name}.gif"
                }
                download_links["gifs"]["loops"].append(gif_info)
                download_links["quick_download"]["all_gifs"].append(gif_info)

    # ========== 拼接视频 ==========
    if steps.get("concatenated_video"):
        download_links["concatenated_video"] = {
            "name": "all_transitions",
            "filename": "all_transitions_concatenated.mp4",
            "url": f"{api_prefix}/videos/all_transitions_concatenated.mp4"
        }
        download_links["quick_download"]["main_video"] = download_links["concatenated_video"]

    # ========== 统计信息 ==========
    download_links["summary"] = {
        "total_images": sum(1 for v in download_links["images"].values() if v),
        "total_transition_videos": len(download_links["transition_videos"]),
        "total_loop_videos": len(download_links["loop_videos"]),
        "total_gifs": len(download_links["quick_download"]["all_gifs"]),
        "has_concatenated_video": download_links["concatenated_video"] is not None,
    }

    return JSONResponse(download_links)


@router.get("/download-zip/{pet_id}")
async def download_all_as_zip(pet_id: str, include: str = "gifs"):
    """
    打包下载所有文件为ZIP

    Args:
        pet_id: 宠物ID
        include: 包含内容 (gifs/videos/all)
            - gifs: 只包含GIF
            - videos: 只包含视频
            - all: 包含所有文件

    Returns:
        ZIP文件下载
    """
    import zipfile
    import io
    from fastapi.responses import StreamingResponse

    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    base_dir = Path("output/kling_pipeline") / pet_id

    if not base_dir.exists():
        raise HTTPException(status_code=404, detail="输出目录不存在")

    # 创建ZIP文件（内存中）
    zip_buffer = io.BytesIO()

    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:

        if include in ["gifs", "all"]:
            # 添加GIF文件
            gifs_dir = base_dir / "gifs"
            if gifs_dir.exists():
                for gif_file in gifs_dir.rglob("*.gif"):
                    arcname = f"gifs/{gif_file.relative_to(gifs_dir)}"
                    zip_file.write(gif_file, arcname)
                    print(f"  📦 添加: {arcname}")

        if include in ["videos", "all"]:
            # 添加视频文件
            videos_dir = base_dir / "videos"
            if videos_dir.exists():
                for video_file in videos_dir.rglob("*.mp4"):
                    arcname = f"videos/{video_file.relative_to(videos_dir)}"
                    zip_file.write(video_file, arcname)
                    print(f"  📦 添加: {arcname}")

        if include == "all":
            # 添加图片文件
            images_dir = base_dir / "base_images"
            if images_dir.exists():
                for img_file in images_dir.glob("*.png"):
                    arcname = f"images/{img_file.name}"
                    zip_file.write(img_file, arcname)
                    print(f"  📦 添加: {arcname}")

            # 添加透明图
            transparent = base_dir / "transparent.png"
            if transparent.exists():
                zip_file.write(transparent, "images/transparent.png")

    zip_buffer.seek(0)

    filename = f"{pet_id}_{include}.zip"

    return StreamingResponse(
        zip_buffer,
        media_type="application/zip",
        headers={
            "Content-Disposition": f"attachment; filename={filename}"
        }
    )


@router.post("/extract-frames")
async def extract_frames_from_video(
    file: UploadFile = File(...),
    pet_id: str = Form(...)
):
    """
    从上传的视频中提取首帧和尾帧

    Args:
        file: 上传的视频文件
        pet_id: 宠物ID

    Returns:
        包含首帧和尾帧路径的JSON
    """
    try:
        print(f"\n🎬 提取视频帧: pet_id={pet_id}, filename={file.filename}")

        # 保存上传的视频
        video_filename = f"uploaded_{int(time.time())}_{file.filename}"
        video_path = UPLOAD_DIR / video_filename

        with open(video_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        print(f"✅ 视频已保存: {video_path}")

        # 创建输出目录
        output_dir = Path("output/kling_pipeline") / pet_id / "extracted_frames"
        output_dir.mkdir(parents=True, exist_ok=True)

        # 提取首帧
        first_frame_filename = f"{Path(file.filename).stem}_first_frame.png"
        first_frame_path = str(output_dir / first_frame_filename)
        extract_first_frame(str(video_path), first_frame_path)
        print(f"✅ 首帧已提取: {first_frame_path}")

        # 提取尾帧
        last_frame_filename = f"{Path(file.filename).stem}_last_frame.png"
        last_frame_path = str(output_dir / last_frame_filename)
        extract_last_frame(str(video_path), last_frame_path)
        print(f"✅ 尾帧已提取: {last_frame_path}")

        # 删除临时视频文件
        video_path.unlink()
        print(f"🗑️ 临时视频已删除: {video_path}")

        return JSONResponse({
            "status": "success",
            "message": "帧提取完成",
            "first_frame": first_frame_path,
            "last_frame": last_frame_path
        })

    except Exception as e:
        print(f"❌ 提取帧失败: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"提取帧失败: {str(e)}")

