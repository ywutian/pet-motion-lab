#!/usr/bin/env python3
"""
AI图片检查器测试脚本
测试 Gemini 2.0 Flash 的图片分析功能
"""

import os
import sys
from pathlib import Path

# 添加项目路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / "backend"))

# 导入配置
from backend.config import GOOGLE_API_KEY, ENABLE_AI_IMAGE_CHECK

def test_ai_checker():
    """测试AI内容检查器"""
    print("=" * 60)
    print("AI图片检查器测试")
    print("=" * 60)

    # 检查配置
    print("\n1. 检查配置:")
    print(f"   ENABLE_AI_IMAGE_CHECK: {ENABLE_AI_IMAGE_CHECK}")
    print(f"   GOOGLE_API_KEY: {'已设置' if GOOGLE_API_KEY else '未设置'}")

    if not GOOGLE_API_KEY:
        print("\n❌ 错误: 未设置 GOOGLE_API_KEY 环境变量")
        print("   请设置环境变量: export GOOGLE_API_KEY='your-api-key'")
        return False

    # 导入AI检查器
    print("\n2. 导入AI检查模块:")
    try:
        from backend.utils.ai_content_checker import AIContentChecker, check_image_with_ai
        print("   ✅ AI检查模块导入成功")
    except ImportError as e:
        print(f"   ❌ 导入失败: {e}")
        print("\n   请安装依赖: pip install google-generativeai pillow")
        return False

    # 导入图片验证器
    print("\n3. 导入图片验证模块:")
    try:
        from backend.utils.image_validator import validate_image
        print("   ✅ 图片验证模块导入成功")
    except ImportError as e:
        print(f"   ❌ 导入失败: {e}")
        return False

    # 测试AI检查器初始化
    print("\n4. 测试AI检查器初始化:")
    try:
        checker = AIContentChecker(api_key=GOOGLE_API_KEY)
        print("   ✅ AI检查器初始化成功")
        print(f"   模型: {checker.model._model_name}")
    except Exception as e:
        print(f"   ❌ 初始化失败: {e}")
        return False

    # 检查是否有测试图片
    print("\n5. 查找测���图片:")
    test_image_dirs = [
        project_root / "test_images",
        project_root / "backend" / "test_images",
        Path.home() / "Pictures",
    ]

    test_image = None
    for test_dir in test_image_dirs:
        if test_dir.exists():
            for ext in ['.jpg', '.jpeg', '.png']:
                images = list(test_dir.glob(f"*{ext}"))
                if images:
                    test_image = images[0]
                    break
            if test_image:
                break

    if not test_image:
        print("   ⚠️ 未找到测试图片")
        print("   请将测试图片放到以下任一目录:")
        for test_dir in test_image_dirs:
            print(f"      - {test_dir}")
        print("\n   或者手动指定测试图片路径:")
        print("   python backend/test_ai_checker.py <图片路径>")
        return True  # 配置测试通过，只是没有图片

    print(f"   ✅ 找到测试图片: {test_image}")

    # 测试AI分析
    print("\n6. 测试AI图片分析:")
    try:
        import json
        result = check_image_with_ai(str(test_image), api_key=GOOGLE_API_KEY)

        if "error" in result:
            print(f"   ❌ 分析失败: {result['error']}")
            return False

        print("   ✅ AI分析成功")
        print(f"\n   分析结果:")

        # 提取关键信息
        content_safety = result.get('content_safety', {})
        pet_detection = result.get('pet_detection', {})
        pose_analysis = result.get('pose_analysis', {})
        background_quality = result.get('background_quality', {})
        feature_completeness = result.get('feature_completeness', {})
        overall = result.get('overall_assessment', {})

        print(f"   - 内容安全: {'✅ 安全' if content_safety.get('safe') else '❌ 不安全'}")
        print(f"   - 宠物检测: {'✅ 检测到' if pet_detection.get('detected') else '❌ 未检测到'}")
        if pet_detection.get('detected'):
            print(f"     • 物种: {pet_detection.get('species', 'unknown')}")
            print(f"     • 置信度: {pet_detection.get('confidence', 0):.2%}")
            print(f"     • 数量: {pet_detection.get('count', 0)}")

        print(f"   - 姿势分析:")
        print(f"     • 姿势: {pose_analysis.get('posture', 'unknown')}")
        print(f"     • 是否坐姿: {'✅ 是' if pose_analysis.get('is_sitting') else '❌ 否'}")
        print(f"     • 清晰度: {pose_analysis.get('clarity', 0):.2%}")

        print(f"   - 背景质量:")
        print(f"     • 类型: {background_quality.get('type', 'unknown')}")
        print(f"     • 是否干净: {'✅ 是' if background_quality.get('is_clean') else '❌ 否'}")
        print(f"     • 去除难度: {background_quality.get('removal_difficulty', 'unknown')}")

        print(f"   - 特征完整性:")
        print(f"     • 完整度: {feature_completeness.get('completeness_score', 0):.2%}")
        print(f"     • 可见特征: {', '.join(feature_completeness.get('visible_features', []))}")

        print(f"   - 整体评估:")
        print(f"     • 适合生成: {'✅ 是' if overall.get('suitable_for_generation') else '❌ 否'}")
        print(f"     • 置信度: {overall.get('confidence_score', 0):.2%}")
        print(f"     • 严重程度: {overall.get('severity_level', 'unknown')}")
        print(f"     • 总结: {overall.get('summary', '')}")

        # 保存完整结果
        result_file = project_root / "backend" / "test_ai_result.json"
        with open(result_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        print(f"\n   💾 完整结果已保存到: {result_file}")

    except Exception as e:
        print(f"   ❌ 分析失败: {e}")
        import traceback
        traceback.print_exc()
        return False

    # 测试集成验证
    print("\n7. 测试集成图片验证:")
    try:
        validation_result = validate_image(
            file_path=str(test_image),
            strict_mode=False,
            enable_ai_check=True,
            google_api_key=GOOGLE_API_KEY
        )

        print(f"   ✅ 验证完成")
        print(f"   - 是否通过: {'✅ 是' if validation_result['valid'] else '❌ 否'}")
        print(f"   - 严重程度: {validation_result.get('severity_level', 'unknown')}")
        print(f"   - 错误数量: {len(validation_result.get('errors', []))}")
        print(f"   - 警告数量: {len(validation_result.get('warnings', []))}")

        if validation_result.get('errors'):
            print("\n   错误:")
            for error in validation_result['errors']:
                print(f"      • [{error.get('code')}] {error.get('message')}")

        if validation_result.get('warnings'):
            print("\n   警告:")
            for warning in validation_result['warnings']:
                print(f"      • [{warning.get('code')}] {warning.get('message')}")

    except Exception as e:
        print(f"   ❌ 验证失败: {e}")
        import traceback
        traceback.print_exc()
        return False

    print("\n" + "=" * 60)
    print("✅ 所有测试通过！")
    print("=" * 60)
    return True


if __name__ == "__main__":
    # 如果提供了命令行参数，使用指定的图片
    if len(sys.argv) > 1:
        test_image_path = sys.argv[1]
        if not os.path.exists(test_image_path):
            print(f"❌ 图片文件不存在: {test_image_path}")
            sys.exit(1)

        print(f"使用指定的测试图片: {test_image_path}")

        from backend.utils.ai_content_checker import check_image_with_ai
        from backend.config import GOOGLE_API_KEY
        import json

        result = check_image_with_ai(test_image_path, api_key=GOOGLE_API_KEY)
        print("\n" + "=" * 60)
        print("AI分析结果:")
        print("=" * 60)
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        # 运行完整测试
        success = test_ai_checker()
        sys.exit(0 if success else 1)
