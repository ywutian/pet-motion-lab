#!/usr/bin/env python3
"""
背景去除 API 端点（使用 Remove.bg API）
"""

from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path
import uuid
import shutil
import tempfile
import os
import requests

router = APIRouter(prefix="/api/background", tags=["background"])

# Remove.bg API 配置（从环境变量读取，不要硬编码密钥！）
REMOVE_BG_API_KEY = os.getenv("REMOVE_BG_API_KEY", "")
REMOVE_BG_API_URL = "https://api.remove.bg/v1.0/removebg"

if not REMOVE_BG_API_KEY or REMOVE_BG_API_KEY == "your_api_key_here":
    print("⚠️  警告: 未设置 Remove.bg API Key (REMOVE_BG_API_KEY)")
else:
    print(f"✅ Remove.bg API Key 已配置")

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
    去除图片背景（使用 Remove.bg API）

    Args:
        image: 输入图片

    Returns:
        透明背景的PNG图片
    """
    if not REMOVE_BG_API_KEY or REMOVE_BG_API_KEY == "your_api_key_here":
        raise HTTPException(
            status_code=503,
            detail="背景去除功能不可用。请设置 REMOVE_BG_API_KEY 环境变量"
        )

    temp_output_path = None

    try:
        print(f"📤 收到图片: {image.filename}")
        print(f"🔧 调用 Remove.bg API...")

        # 读取图片内容
        image_data = await image.read()

        # 调用 Remove.bg API
        response = requests.post(
            REMOVE_BG_API_URL,
            files={'image_file': image_data},
            data={'size': 'auto'},  # 自动选择最佳尺寸
            headers={'X-Api-Key': REMOVE_BG_API_KEY},
            timeout=30
        )

        if response.status_code == 200:
            # 保存结果
            temp_id = str(uuid.uuid4())
            temp_output_path = TEMP_DIR / f"{temp_id}_output.png"

            with open(temp_output_path, 'wb') as f:
                f.write(response.content)

            print(f"✅ 背景去除完成")

            # 返回结果
            return FileResponse(
                temp_output_path,
                media_type="image/png",
                filename=f"no_bg_{image.filename}",
                headers={"Content-Disposition": f"attachment; filename=no_bg_{image.filename}"}
            )
        else:
            error_msg = response.json() if response.headers.get('content-type') == 'application/json' else response.text
            print(f"❌ Remove.bg API 错误: {response.status_code} - {error_msg}")
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Remove.bg API 错误: {error_msg}"
            )

    except requests.exceptions.Timeout:
        print(f"❌ Remove.bg API 超时")
        raise HTTPException(status_code=504, detail="背景去除超时，请稍后重试")

    except requests.exceptions.RequestException as e:
        print(f"❌ 网络错误: {e}")
        raise HTTPException(status_code=500, detail=f"网络错误: {str(e)}")

    except Exception as e:
        print(f"❌ 背景去除失败: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"背景去除失败: {str(e)}")

    finally:
        # 清理临时文件（延迟删除，确保文件已发送）
        pass


@router.get("/health")
async def health_check():
    """健康检查"""
    if REMOVE_BG_API_KEY and REMOVE_BG_API_KEY != "your_api_key_here":
        return {
            "status": "healthy",
            "service": "background_removal",
            "provider": "remove.bg",
            "api_configured": True
        }
    else:
        return {
            "status": "degraded",
            "service": "background_removal",
            "provider": "remove.bg",
            "api_configured": False,
            "message": "背景去除功能不可用。请设置 REMOVE_BG_API_KEY 环境变量"
        }


@router.get("/quota")
async def check_quota():
    """
    查询 Remove.bg API 剩余额度

    Returns:
        剩余调用次数等信息
    """
    if not REMOVE_BG_API_KEY or REMOVE_BG_API_KEY == "your_api_key_here":
        raise HTTPException(
            status_code=503,
            detail="Remove.bg API Key 未配置"
        )

    try:
        # 调用 Remove.bg API 获取账户信息
        response = requests.get(
            "https://api.remove.bg/v1.0/account",
            headers={'X-Api-Key': REMOVE_BG_API_KEY},
            timeout=10
        )

        if response.status_code == 200:
            data = response.json()
            return {
                "status": "success",
                "data": data
            }
        else:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"无法获取额度信息: {response.text}"
            )

    except Exception as e:
        print(f"❌ 查询额度失败: {e}")
        raise HTTPException(status_code=500, detail=f"查询额度失败: {str(e)}")

