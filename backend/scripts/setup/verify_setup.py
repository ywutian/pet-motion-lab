import torch
import os
from pathlib import Path

def check_file_size(path):
    """获取文件或目录大小（GB）"""
    if os.path.isfile(path):
        return os.path.getsize(path) / (1024**3)
    elif os.path.isdir(path):
        total = 0
        for dirpath, dirnames, filenames in os.walk(path):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                if os.path.exists(fp):
                    total += os.path.getsize(fp)
        return total / (1024**3)
    return 0

def verify_setup():
    print("🔍 验证最佳模型配置...\n")
    
    # 1. 检查 PyTorch
    print(f"✅ PyTorch 版本: {torch.__version__}")
    
    # 2. 检查设备
    if torch.backends.mps.is_available():
        print("✅ Mac MPS (GPU) 可用")
        try:
            allocated = torch.mps.driver_allocated_memory() / (1024**3)
            print(f"   GPU 已分配内存: {allocated:.2f} GB")
        except:
            print("   GPU 内存信息不可用")
    elif torch.cuda.is_available():
        print("✅ CUDA (GPU) 可用")
        print(f"   GPU: {torch.cuda.get_device_name(0)}")
        print(f"   GPU 内存: {torch.cuda.get_device_properties(0).total_memory / (1024**3):.2f} GB")
    else:
        print("⚠️ 只有 CPU 可用")
    
    # 3. 检查模型文件
    print("\n📦 检查模型文件:\n")
    
    models = {
        "Flux.1-dev": "models/flux/flux-dev",
        "IP-Adapter (Flux)": "models/ip_adapter/flux",
        "ControlNet Union": "models/controlnet/flux-union",
        "3D Cartoon LoRA": "models/lora/flux-3d",
    }
    
    total_size = 0
    all_exist = True
    
    for name, path in models.items():
        if os.path.exists(path):
            size = check_file_size(path)
            total_size += size
            status = "✅" if size > 0.1 else "⚠️"
            print(f"  {status} {name:<25} ({size:.2f} GB)")
        else:
            print(f"  ❌ {name:<25} (未找到)")
            all_exist = False
    
    print(f"\n📊 总大小: {total_size:.2f} GB")
    
    # 4. 检查依赖
    print("\n📚 检查 Python 依赖:\n")
    
    dependencies = [
        ("torch", "PyTorch"),
        ("diffusers", "Diffusers"),
        ("transformers", "Transformers"),
        ("accelerate", "Accelerate"),
        ("safetensors", "SafeTensors"),
        ("PIL", "Pillow"),
        ("fastapi", "FastAPI"),
        ("huggingface_hub", "HuggingFace Hub"),
    ]
    
    deps_ok = True
    for module, name in dependencies:
        try:
            __import__(module)
            print(f"  ✅ {name}")
        except ImportError:
            print(f"  ❌ {name} (未安装)")
            deps_ok = False
            all_exist = False
    
    # 5. 总结
    print("\n" + "="*60)
    if all_exist and deps_ok:
        print("✅ 所有检查通过！可以开始使用。")
        print("\n🎯 下一步: 运行示例代码测试生成")
    else:
        print("❌ 有缺失项，请先完成下载和安装。")
        if not deps_ok:
            print("\n💡 安装依赖: pip install -r requirements.txt")
        if not all_exist:
            print("💡 下载模型: ./download_best_models.sh")
    print("="*60)

if __name__ == "__main__":
    verify_setup()

