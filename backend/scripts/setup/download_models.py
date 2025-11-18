#!/usr/bin/env python3
"""
下载 Flux 最佳模型组合
"""

from huggingface_hub import snapshot_download, login
import os
from pathlib import Path

def download_models():
    # 使用 token 登录
    token = "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"
    try:
        login(token=token, add_to_git_credential=False)
        print("✅ HuggingFace 登录成功！")
    except Exception as e:
        print(f"⚠️ 登录警告: {e}")

    print("🏆 开始下载最佳模型组合...")
    print("📊 总大小约: 40 GB")
    print("⏱️  预计时间: 2-4 小时（取决于网速）")
    print()
    
    # 创建目录
    models_dir = Path("models")
    models_dir.mkdir(exist_ok=True)
    
    models = [
        {
            "name": "Flux.1-dev 基础模型",
            "repo_id": "black-forest-labs/FLUX.1-dev",
            "local_dir": "models/flux/flux-dev",
            "size": "~23 GB",
        },
        {
            "name": "IP-Adapter for Flux",
            "repo_id": "InstantX/FLUX.1-dev-IP-Adapter",
            "local_dir": "models/ip_adapter/flux",
            "size": "~5 GB",
        },
        {
            "name": "ControlNet Union for Flux",
            "repo_id": "InstantX/FLUX.1-dev-Controlnet-Union",
            "local_dir": "models/controlnet/flux-union",
            "size": "~6.5 GB",
        },
        {
            "name": "3D Cartoon LoRA",
            "repo_id": "alvdansen/flux-koda",
            "local_dir": "models/lora/flux-3d",
            "size": "~500 MB",
        },
    ]
    
    for i, model in enumerate(models, 1):
        print("=" * 70)
        print(f"📦 {i}/4 下载 {model['name']} ({model['size']})")
        print("=" * 70)
        
        try:
            snapshot_download(
                repo_id=model["repo_id"],
                local_dir=model["local_dir"],
                local_dir_use_symlinks=False,
                resume_download=True,
            )
            print(f"✅ {model['name']} 下载完成！\n")
        except Exception as e:
            print(f"❌ {model['name']} 下载失败: {e}\n")
            continue
    
    print("=" * 70)
    print("✅ 所有模型下载完成！")
    print("=" * 70)
    print("📊 总大小: ~40 GB")
    print("📁 模型位置: backend/models/")
    print()
    print("🎯 下一步: 运行 python verify_setup.py 验证安装")

if __name__ == "__main__":
    download_models()

