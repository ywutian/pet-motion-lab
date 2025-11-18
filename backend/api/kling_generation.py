#!/usr/bin/env python3
"""
可灵AI生成API路由
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

from pipeline_kling import KlingPipeline
from utils.video_utils import extract_first_frame, extract_last_frame
from config import KLING_ACCESS_KEY, KLING_SECRET_KEY

router = APIRouter(prefix="/api/kling", tags=["kling"])

# 可灵AI凭证（从环境变量读取）
ACCESS_KEY = KLING_ACCESS_KEY
SECRET_KEY = KLING_SECRET_KEY

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


# 存储任务状态（实际应用中应使用数据库）
task_status = {}


@router.post("/init")
async def init_pet_task(
    file: UploadFile = File(...),
    breed: str = Form(...),
    color: str = Form(...),
    species: str = Form(...)
):
    """
    初始化宠物任务（必须上传原始图片）

    Args:
        file: 原始宠物图片
        breed: 品种（如：布偶猫）
        color: 颜色（如：蓝色）
        species: 物种（猫/犬）

    Returns:
        任务ID和初始状态
    """
    # 生成任务ID
    pet_id = f"pet_{int(time.time())}"

    # 保存上传的文件
    upload_path = UPLOAD_DIR / f"{pet_id}_{file.filename}"
    with open(upload_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 初始化任务状态
    task_status[pet_id] = {
        "status": "initialized",
        "progress": 0,
        "message": "任务已创建",
        "uploaded_image": str(upload_path),
        "breed": breed,
        "color": color,
        "species": species,
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
    步骤1: 去除背景（使用本地rembg模型）
    - 不上传文件：使用初始化时的原始图片，调用本地模型去除背景
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
        task["message"] = "步骤1: 正在使用本地模型去除背景..."

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
        task["message"] = "步骤1完成: 背景已去除（本地模型）"
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
            output_dir="output/kling_pipeline"
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
        task["message"] = "步骤2完成: 基础坐姿图片已生成"
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


@router.post("/generate")
async def generate_pet_animations(
    file: UploadFile = File(...),
    breed: str = Form(...),
    color: str = Form(...),
    species: str = Form(...)
):
    """
    生成宠物动画完整流程（一次性执行所有步骤）

    Args:
        file: 上传的宠物图片
        breed: 品种（如：布偶猫）
        color: 颜色（如：蓝色）
        species: 物种（猫/犬）

    Returns:
        任务ID和初始状态
    """
    # 生成任务ID
    pet_id = f"pet_{int(time.time())}"

    # 保存上传的文件
    upload_path = UPLOAD_DIR / f"{pet_id}_{file.filename}"
    with open(upload_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 初始化任务状态
    task_status[pet_id] = {
        "status": "processing",
        "progress": 0,
        "message": "任务已创建，开始处理...",
        "results": None
    }

    # 异步执行生成流程（实际应用中应使用后台任务）
    try:
        pipeline = KlingPipeline(
            access_key=ACCESS_KEY,
            secret_key=SECRET_KEY,
            output_dir="output/kling_pipeline"
        )

        # 更新状态
        task_status[pet_id]["progress"] = 10
        task_status[pet_id]["message"] = "正在去除背景..."

        results = pipeline.run_full_pipeline(
            uploaded_image=str(upload_path),
            breed=breed,
            color=color,
            species=species,
            pet_id=pet_id
        )

        # 完成
        task_status[pet_id]["status"] = "completed"
        task_status[pet_id]["progress"] = 100
        task_status[pet_id]["message"] = "生成完成！"
        task_status[pet_id]["results"] = results
        
    except Exception as e:
        task_status[pet_id]["status"] = "failed"
        task_status[pet_id]["message"] = f"生成失败: {str(e)}"
    
    return JSONResponse({
        "pet_id": pet_id,
        "status": "processing",
        "message": "任务已创建，正在处理中..."
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
                output_dir="output/kling_pipeline"
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
            output_dir="output/kling_pipeline"
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
            output_dir="output/kling_pipeline"
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
            output_dir="output/kling_pipeline"
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
    查询生成状态

    Args:
        pet_id: 宠物ID

    Returns:
        生成状态
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    return JSONResponse(task_status[pet_id])


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
async def get_all_download_links(pet_id: str):
    """
    获取所有可下载文件的链接列表

    Args:
        pet_id: 宠物ID

    Returns:
        所有文件的下载链接
    """
    if pet_id not in task_status:
        raise HTTPException(status_code=404, detail="任务不存在")

    task = task_status[pet_id]
    results = task.get("results", {})

    download_links = {
        "step1_background_removed": None,
        "step2_base_image": None,
        "step3_videos": [],
        "step3_frames": [],
        "step4_videos": [],
        "step5_videos": [],
        "step6_gifs": []
    }

    # 步骤1: 背景去除图片
    if results.get("step1_background_removed"):
        filename = Path(results["step1_background_removed"]).name
        download_links["step1_background_removed"] = f"/api/kling/download/{pet_id}/image/{filename}"

    # 步骤2: 基础图片
    if results.get("step2_base_image"):
        filename = Path(results["step2_base_image"]).name
        download_links["step2_base_image"] = f"/api/kling/download/{pet_id}/image/{filename}"

    # 步骤3: 初始视频和帧
    if results.get("step3_initial_videos"):
        for video in results["step3_initial_videos"].get("videos", []):
            filename = Path(video).name
            download_links["step3_videos"].append({
                "name": filename,
                "url": f"/api/kling/download/{pet_id}/video/{filename}"
            })
        for frame in results["step3_initial_videos"].get("extracted_frames", []):
            filename = Path(frame).name
            download_links["step3_frames"].append({
                "name": filename,
                "url": f"/api/kling/download/{pet_id}/image/{filename}"
            })

    # 步骤4: 剩余视频
    if results.get("step4_remaining_videos"):
        for video in results["step4_remaining_videos"]:
            filename = Path(video).name
            download_links["step4_videos"].append({
                "name": filename,
                "url": f"/api/kling/download/{pet_id}/video/{filename}"
            })

    # 步骤5: 循环视频
    if results.get("step5_loop_videos"):
        for video in results["step5_loop_videos"]:
            filename = Path(video).name
            download_links["step5_videos"].append({
                "name": filename,
                "url": f"/api/kling/download/{pet_id}/video/{filename}"
            })

    # 步骤6: GIF
    if results.get("step6_gifs"):
        for gif in results["step6_gifs"]:
            filename = Path(gif).name
            download_links["step6_gifs"].append({
                "name": filename,
                "url": f"/api/kling/download/{pet_id}/gif/{filename}"
            })

    return JSONResponse(download_links)


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

