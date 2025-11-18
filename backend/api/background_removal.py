#!/usr/bin/env python3
"""
背景去除 API 端点（仅保留此功能）
"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path
import uuid
import shutil
import sys
import tempfile
import os

# 添加项目根目录到路径
sys.path.append(str(Path(__file__).parent.parent))

# 尝试导入 rembg，如果不可用则提供友好错误
try:
    from utils.image_utils import remove_background
    REMBG_AVAILABLE = True
except ImportError:
    REMBG_AVAILABLE = False
    print("⚠️  警告: rembg 未安装，背景去除功能将不可用")

router = APIRouter(prefix="/api/background", tags=["background"])

# 使用系统临时目录（Render 兼容）
TEMP_DIR = Path(tempfile.gettempdir()) / "pet_motion_lab"
TEMP_DIR.mkdir(exist_ok=True, parents=True)

OUTPUT_DIR = TEMP_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True, parents=True)


@router.post("/remove")
async def remove_image_background(
    image: UploadFile = File(...),
):
    """
    去除图片背景

    Args:
        image: 输入图片

    Returns:
        透明背景的PNG图片
    """
    if not REMBG_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="背景去除功能不可用。请安装 rembg: pip install rembg"
        )

    try:
        # 保存上传的图片
        temp_id = str(uuid.uuid4())
        temp_input_path = TEMP_DIR / f"{temp_id}_input.png"
        temp_output_path = TEMP_DIR / f"{temp_id}_output.png"

        with open(temp_input_path, "wb") as f:
            shutil.copyfileobj(image.file, f)

        print(f"📤 收到图片: {image.filename}")
        print(f"🔧 开始去除背景...")

        # 去除背景
        result_path = remove_background(str(temp_input_path), str(temp_output_path))

        print(f"✅ 背景去除完成: {result_path}")

        # 返回结果
        return FileResponse(
            result_path,
            media_type="image/png",
            filename=f"no_bg_{image.filename}",
            headers={"Content-Disposition": f"attachment; filename=no_bg_{image.filename}"}
        )

    except Exception as e:
        print(f"❌ 背景去除失败: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"背景去除失败: {str(e)}")

    finally:
        # 清理临时文件
        try:
            if temp_input_path.exists():
                temp_input_path.unlink()
        except:
            pass


@router.get("/health")
async def health_check():
    """健康检查"""
    if REMBG_AVAILABLE:
        return {
            "status": "healthy",
            "service": "background_removal",
            "rembg": "available"
        }
    else:
        return {
            "status": "degraded",
            "service": "background_removal",
            "rembg": "not_installed",
            "message": "背景去除功能不可用。请安装 rembg: pip install rembg"
        }

