#!/usr/bin/env python3
"""
测试可灵AI所有视频模型是否可用
运行方式:
  cd backend
  python test_kling_models.py
"""

import os
import sys
import time
import base64
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent))

from config import KLING_ACCESS_KEY, KLING_SECRET_KEY, KLING_VIDEO_ACCESS_KEY, KLING_VIDEO_SECRET_KEY
from kling_api_helper import KlingAPI

# 测试图片路径（使用项目中的示例图片）
TEST_IMAGE = Path(__file__).parent.parent / "assets/images/bichon_frise_sit_front.jpg"

# 支持首尾帧的模型配置（仅保留 V2.1+ PRO/Master 模式）
MODELS_TO_TEST = [
    # 模型名称, 模式, 时长, 预计单价
    ("kling-v2-5-turbo", "pro", 5, "$0.35"),   # 推荐：性价比最高
    ("kling-v2-1", "pro", 5, "$0.49"),          # 质量好
    ("kling-v2-1-master", "master", 5, "$1.40"), # 最高质量
]


def test_model(api: KlingAPI, model_name: str, mode: str, duration: int, price: str):
    """测试单个模型"""
    print(f"\n{'='*60}")
    print(f"🧪 测试模型: {model_name}")
    print(f"   模式: {mode}, 时长: {duration}s, 预计单价: {price}")
    print(f"{'='*60}")
    
    try:
        # 读取测试图片
        with open(TEST_IMAGE, "rb") as f:
            image_data = base64.b64encode(f.read()).decode()
        
        # 调用图生视频API
        print(f"📤 发送请求...")
        task_id = api.image_to_video(
            image_base64=image_data,
            prompt="A cute white dog sitting still, slight breathing movement, blinking eyes",
            model_name=model_name,
            mode=mode,
            duration=str(duration)
        )
        
        if task_id:
            print(f"✅ 任务创建成功! task_id: {task_id}")
            print(f"   等待处理中...")
            
            # 等待一小段时间后查询状态
            time.sleep(5)
            
            result = api.query_video_task(task_id)
            status = result.get("task_status", "unknown")
            print(f"   当前状态: {status}")
            
            return {
                "model": model_name,
                "mode": mode,
                "status": "✅ 可用",
                "task_id": task_id,
                "task_status": status,
                "price": price
            }
        else:
            print(f"❌ 任务创建失败")
            return {
                "model": model_name,
                "mode": mode,
                "status": "❌ 失败",
                "error": "无法创建任务",
                "price": price
            }
            
    except Exception as e:
        error_msg = str(e)
        print(f"❌ 测试失败: {error_msg}")
        return {
            "model": model_name,
            "mode": mode,
            "status": "❌ 错误",
            "error": error_msg[:100],
            "price": price
        }


def main():
    print("=" * 70)
    print("🎬 可灵AI视频模型测试工具")
    print("=" * 70)
    
    # 检查API密钥
    access_key = KLING_VIDEO_ACCESS_KEY or KLING_ACCESS_KEY
    secret_key = KLING_VIDEO_SECRET_KEY or KLING_SECRET_KEY
    
    if not access_key or not secret_key:
        print("❌ 未配置API密钥!")
        print("   请设置环境变量: KLING_ACCESS_KEY, KLING_SECRET_KEY")
        sys.exit(1)
    
    print(f"✅ API密钥已配置")
    
    # 检查测试图片
    if not TEST_IMAGE.exists():
        print(f"❌ 测试图片不存在: {TEST_IMAGE}")
        sys.exit(1)
    
    print(f"✅ 测试图片: {TEST_IMAGE}")
    
    # 创建API实例
    api = KlingAPI(
        access_key=KLING_ACCESS_KEY,
        secret_key=KLING_SECRET_KEY,
        video_access_key=KLING_VIDEO_ACCESS_KEY,
        video_secret_key=KLING_VIDEO_SECRET_KEY
    )
    
    # 选择测试模式
    print("\n📋 可测试的模型:")
    for i, (model, mode, duration, price) in enumerate(MODELS_TO_TEST, 1):
        print(f"   {i}. {model} ({mode}, {duration}s) - {price}")
    
    print("\n选择测试模式:")
    print("  1. 测试单个模型 (输入序号)")
    print("  2. 测试所有模型 (输入 'all')")
    print("  3. 只测试最便宜的几个 (输入 'cheap')")
    print("  0. 退出")
    
    choice = input("\n请输入选择: ").strip().lower()
    
    if choice == "0":
        print("退出")
        return
    
    results = []
    
    if choice == "all":
        # 测试所有模型
        print("\n⚠️  警告: 测试所有模型会消耗API额度!")
        confirm = input("确认继续? (y/n): ").strip().lower()
        if confirm != "y":
            print("已取消")
            return
        
        for model, mode, duration, price in MODELS_TO_TEST:
            result = test_model(api, model, mode, duration, price)
            results.append(result)
            time.sleep(2)  # 避免请求过快
    
    elif choice == "cheap":
        # 只测试最便宜的支持首尾帧的模型
        cheap_models = [
            ("kling-v2-5-turbo", "pro", 5, "$0.35"),  # 性价比最高
        ]
        for model, mode, duration, price in cheap_models:
            result = test_model(api, model, mode, duration, price)
            results.append(result)
            time.sleep(2)
    
    elif choice.isdigit():
        idx = int(choice) - 1
        if 0 <= idx < len(MODELS_TO_TEST):
            model, mode, duration, price = MODELS_TO_TEST[idx]
            result = test_model(api, model, mode, duration, price)
            results.append(result)
        else:
            print("无效的选择")
            return
    else:
        print("无效的选择")
        return
    
    # 打印结果汇总
    print("\n")
    print("=" * 70)
    print("📊 测试结果汇总")
    print("=" * 70)
    print(f"{'模型':<25} {'模式':<8} {'单价':<8} {'状态':<10}")
    print("-" * 70)
    
    for r in results:
        model = r.get("model", "")
        mode = r.get("mode", "")
        price = r.get("price", "")
        status = r.get("status", "")
        print(f"{model:<25} {mode:<8} {price:<8} {status:<10}")
        if "error" in r:
            print(f"   └─ 错误: {r['error']}")
    
    print("=" * 70)
    
    # 可用模型推荐
    available = [r for r in results if "✅" in r.get("status", "")]
    if available:
        print("\n💡 推荐使用:")
        cheapest = min(available, key=lambda x: float(x["price"].replace("$", "")))
        print(f"   最便宜可用: {cheapest['model']} ({cheapest['mode']}) - {cheapest['price']}")


if __name__ == "__main__":
    main()

