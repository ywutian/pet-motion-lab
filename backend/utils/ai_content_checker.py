#!/usr/bin/env python3
"""
AI内容审核模块
使用 Google Gemini 2.0 Flash 检查图片内容
包括: 内容安全、宠物检测、姿势识别、背景质量、特征完整性
"""

import os
import json
from typing import Dict, Optional
from pathlib import Path

try:
    import google.generativeai as genai
    GENAI_AVAILABLE = True
except ImportError:
    GENAI_AVAILABLE = False
    print("⚠️ 警告: google-generativeai 未安装，AI内容检查功能将不可用")
    print("   安装命令: pip install google-generativeai")


class AIContentChecker:
    """AI内容检查器 (基于 Google Gemini 2.0 Flash)"""

    def __init__(self, api_key: Optional[str] = None):
        """
        初始化AI内容检查器

        Args:
            api_key: Google API密钥 (如果不提供则从环境变量读取)
        """
        if not GENAI_AVAILABLE:
            raise ImportError(
                "google-generativeai 未安装。请运行: pip install google-generativeai"
            )

        self.api_key = api_key or os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError(
                "未找到 Google API 密钥。请设置环境变量 GOOGLE_API_KEY 或传入 api_key 参数"
            )

        # 配置 Gemini
        genai.configure(api_key=self.api_key)

        # 使用 Gemini 2.5 Flash-Lite (免费配额更高: 15 RPM, 1000 RPD)
        self.model = genai.GenerativeModel('gemini-2.5-flash-lite')

    def _create_analysis_prompt(self) -> str:
        """创建分析提示词"""
        return """请对这张宠物图片进行全面分析，严格以JSON格式返回结果，不要包含任何其他文字或markdown标记。

分析维度：

1. **内容安全** (content_safety):
   - 是否包含不良内容（色情/暴力/血腥/虐待动物等违法内容）
   - safe: true/false
   - issues: [] 具体问题列表，如果safe为true则为空数组

2. **宠物检测** (pet_detection):
   - 是否包含宠物（猫或狗）
   - detected: true/false
   - species: "cat"/"dog"/null (猫/狗/未检测到)
   - confidence: 0.0-1.0 (检测置信度)
   - count: 整数 (宠物数量，理想情况应该是1只)

3. **宠物姿势分析** (pose_analysis):
   - posture: "sitting"(坐姿)/"standing"(站姿)/"lying"(躺姿)/"walking"(行走)/"playing"(玩耍)/"other"(其他)
   - is_sitting: true/false (是否为坐姿，坐姿最适合生成)
   - clarity: 0.0-1.0 (姿势清晰度)
   - description: 姿势详细描述
   - suggestions: [] 改进建议数组

4. **背景质量** (background_quality):
   - type: "solid"(纯色)/"simple"(简单)/"medium"(中等)/"complex"(复杂)/"cluttered"(杂乱)
   - is_clean: true/false (背景是否干净)
   - removal_difficulty: "easy"/"medium"/"hard" (背景去除难度)
   - has_distractions: true/false (是否有干扰物)
   - description: 背景详细描述
   - suggestions: [] 改进建议数组

5. **宠物特征完整性** (feature_completeness):
   - completeness_score: 0.0-1.0 (特征完整度评分)
   - visible_features: [] 可见特征列表 (如: "face", "ears", "eyes", "nose", "mouth", "body", "legs", "tail", "paws")
   - missing_features: [] 缺失或不清晰的特征
   - occlusions: [] 遮挡物列表（如果有）
   - angle_quality: "frontal"(正面)/"side"(侧面)/"three-quarter"(四分之三)/"back"(背面)/"top"(俯视)
   - lighting_quality: "excellent"/"good"/"fair"/"poor" (光照质量)
   - focus_quality: "sharp"/"acceptable"/"blurry" (对焦质量)
   - suggestions: [] 改进建议数组

6. **整体评估** (overall_assessment):
   - suitable_for_generation: true/false (是否适合用于生成)
   - confidence_score: 0.0-1.0 (总体置信度)
   - severity_level: "pass"(通过)/"warning"(警告)/"error"(严重问题，不可用)
   - primary_issues: [] 主要问题列表
   - summary: 总体评价的简短总结
   - recommendations: [] 具体改进建议列表

返回示例：
{
  "content_safety": {
    "safe": true,
    "issues": []
  },
  "pet_detection": {
    "detected": true,
    "species": "dog",
    "confidence": 0.95,
    "count": 1
  },
  "pose_analysis": {
    "posture": "sitting",
    "is_sitting": true,
    "clarity": 0.9,
    "description": "宠物正面坐姿，姿态端正",
    "suggestions": []
  },
  "background_quality": {
    "type": "simple",
    "is_clean": true,
    "removal_difficulty": "easy",
    "has_distractions": false,
    "description": "白色简洁背景",
    "suggestions": []
  },
  "feature_completeness": {
    "completeness_score": 0.95,
    "visible_features": ["face", "ears", "eyes", "nose", "body", "legs"],
    "missing_features": [],
    "occlusions": [],
    "angle_quality": "frontal",
    "lighting_quality": "good",
    "focus_quality": "sharp",
    "suggestions": []
  },
  "overall_assessment": {
    "suitable_for_generation": true,
    "confidence_score": 0.92,
    "severity_level": "pass",
    "primary_issues": [],
    "summary": "图片质量优秀，非常适合用于生成宠物动画",
    "recommendations": []
  }
}

请严格按照上述JSON格式返回，不要添加任何markdown代码块标记（如```json），直接返回纯JSON。"""

    def analyze_image(self, image_path: str) -> Dict:
        """
        使用 Gemini AI 分析图片内容

        Args:
            image_path: 图片路径

        Returns:
            分析结果字典
        """
        try:
            from PIL import Image

            # 检查图片是否存在
            if not os.path.exists(image_path):
                return self._create_error_result(f"图片文件不存在: {image_path}")

            # 打开图片
            try:
                img = Image.open(image_path)
            except Exception as e:
                return self._create_error_result(f"无法打开图片: {str(e)}")

            # 创建分析提示词
            prompt = self._create_analysis_prompt()

            # 调用 Gemini API
            try:
                response = self.model.generate_content(
                    [prompt, img],
                    generation_config=genai.types.GenerationConfig(
                        temperature=0.1,  # 降低温度以获得更稳定的结果
                    )
                )
            except Exception as e:
                return self._create_error_result(f"Gemini API 调用失败: {str(e)}")

            # 提取并解析JSON结果
            result_text = response.text.strip()

            # 移除可能的markdown代码块标记
            if result_text.startswith("```json"):
                result_text = result_text[7:]
            elif result_text.startswith("```"):
                result_text = result_text[3:]

            if result_text.endswith("```"):
                result_text = result_text[:-3]

            result_text = result_text.strip()

            # 解析JSON
            try:
                analysis_result = json.loads(result_text)
            except json.JSONDecodeError as e:
                return self._create_error_result(
                    f"JSON解析失败: {str(e)}\n原始响应: {result_text[:500]}"
                )

            # 验证必要字段
            required_keys = [
                "content_safety",
                "pet_detection",
                "pose_analysis",
                "background_quality",
                "feature_completeness",
                "overall_assessment"
            ]

            missing_keys = [key for key in required_keys if key not in analysis_result]
            if missing_keys:
                return self._create_error_result(
                    f"AI返回结果缺少必要字段: {', '.join(missing_keys)}"
                )

            return analysis_result

        except Exception as e:
            return self._create_error_result(f"分析过程发生未知错误: {str(e)}")

    def _create_error_result(self, error_message: str) -> Dict:
        """创建错误结果"""
        return {
            "error": error_message,
            "content_safety": {
                "safe": False,
                "issues": ["分析失败"]
            },
            "pet_detection": {
                "detected": False,
                "species": None,
                "confidence": 0.0,
                "count": 0
            },
            "pose_analysis": {
                "posture": "unknown",
                "is_sitting": False,
                "clarity": 0.0,
                "description": "无法分析",
                "suggestions": []
            },
            "background_quality": {
                "type": "unknown",
                "is_clean": False,
                "removal_difficulty": "hard",
                "has_distractions": True,
                "description": "无法分析",
                "suggestions": []
            },
            "feature_completeness": {
                "completeness_score": 0.0,
                "visible_features": [],
                "missing_features": [],
                "occlusions": [],
                "angle_quality": "unknown",
                "lighting_quality": "poor",
                "focus_quality": "blurry",
                "suggestions": []
            },
            "overall_assessment": {
                "suitable_for_generation": False,
                "confidence_score": 0.0,
                "severity_level": "error",
                "primary_issues": [error_message],
                "summary": f"分析失败: {error_message}",
                "recommendations": ["请检查图片文件并重试"]
            }
        }


def check_image_with_ai(
    image_path: str,
    api_key: Optional[str] = None
) -> Dict:
    """
    使用 AI 检查图片内容的便捷函数

    Args:
        image_path: 图片路径
        api_key: Google API密钥 (可选，默认从环境变量读取)

    Returns:
        分析结果字典
    """
    try:
        checker = AIContentChecker(api_key=api_key)
        return checker.analyze_image(image_path)
    except Exception as e:
        return {
            "error": f"初始化AI检查器失败: {str(e)}",
            "overall_assessment": {
                "suitable_for_generation": False,
                "severity_level": "error",
                "summary": f"AI功能不可用: {str(e)}"
            }
        }


def analyze_pet_features(
    image_path: str,
    api_key: Optional[str] = None
) -> Dict:
    """
    使用 Gemini AI 分析宠物特征，用于生成更精确的prompt
    
    Args:
        image_path: 图片路径
        api_key: Google API密钥 (可选)
    
    Returns:
        宠物特征分析结果，包含:
        - species: 物种 (cat/dog)
        - breed: 品种名称
        - breed_confidence: 品种识别置信度
        - color: 主色调
        - color_pattern: 颜色图案 (solid/tabby/spotted/bicolor等)
        - fur_type: 毛发类型 (short/medium/long/curly)
        - fur_texture: 毛发质感描述
        - body_size: 体型 (small/medium/large)
        - special_markings: 特殊标记列表
        - ear_type: 耳朵类型
        - eye_color: 眼睛颜色
        - prompt_suggestions: 建议的prompt关键词
    """
    if not GENAI_AVAILABLE:
        return {"error": "google-generativeai 未安装"}
    
    try:
        from PIL import Image
        
        _api_key = api_key or os.getenv("GOOGLE_API_KEY")
        if not _api_key:
            return {"error": "未找到 Google API 密钥"}
        
        genai.configure(api_key=_api_key)
        model = genai.GenerativeModel('gemini-2.5-flash-lite')
        
        if not os.path.exists(image_path):
            return {"error": f"图片文件不存在: {image_path}"}
        
        img = Image.open(image_path)
        
        prompt = """请仔细分析这张宠物图片的特征，严格以JSON格式返回，用于生成AI动画。

分析以下特征：

1. **物种和品种**:
   - species: "cat" 或 "dog"
   - breed: 品种名称（中文，如"金毛"、"橘猫"、"英国短毛猫"、"柯基"等）
   - breed_confidence: 0.0-1.0 品种识别置信度
   - breed_alternative: 如果不确定，给出可能的替代品种

2. **颜色特征**:
   - primary_color: 主色调（中文，如"金黄色"、"橘色"、"纯白色"、"蓝灰色"）
   - secondary_color: 次要颜色（如果有）
   - color_pattern: 颜色图案类型
     - "solid" 纯色
     - "tabby" 虎斑/条纹
     - "spotted" 斑点
     - "bicolor" 双色
     - "tricolor" 三花
     - "pointed" 重点色
     - "tuxedo" 燕尾服
   - color_description: 颜色的详细描述（中文）

3. **毛发特征**:
   - fur_length: "short"(短毛) / "medium"(中长毛) / "long"(长毛)
   - fur_texture: 毛发质感描述（中文，如"蓬松柔软"、"光滑顺滑"、"卷曲蓬松"）
   - fur_density: "thin"(稀疏) / "normal"(正常) / "thick"(浓密)

4. **体型特征**:
   - body_size: "small"(小型) / "medium"(中型) / "large"(大型)
   - body_shape: 体型描述（中文，如"圆润"、"修长"、"健壮"）

5. **面部和其他特征**:
   - ear_type: 耳朵类型（中文，如"直立三角耳"、"垂耳"、"圆耳"）
   - eye_color: 眼睛颜色（中文）
   - special_markings: 特殊标记列表（如["白色胸毛", "白爪", "额头M字纹"]）
   - distinctive_features: 其他显著特征

6. **Prompt建议**:
   - style_suggestion: 建议的风格（"cartoon"卡通 / "disney_realistic"迪士尼写实 / "realistic"写实）
   - prompt_keywords: 建议加入prompt的关键词列表（中文）
   - avoid_keywords: 建议避免的描述（中文）

返回示例：
{
  "species": "cat",
  "breed": "橘猫",
  "breed_confidence": 0.85,
  "breed_alternative": "中华田园猫",
  "primary_color": "橘色",
  "secondary_color": "白色",
  "color_pattern": "tabby",
  "color_description": "橘色虎斑底色，带有深色条纹，胸部和爪子为白色",
  "fur_length": "short",
  "fur_texture": "短毛光滑",
  "fur_density": "normal",
  "body_size": "medium",
  "body_shape": "圆润健壮",
  "ear_type": "圆耳",
  "eye_color": "金黄色",
  "special_markings": ["白色胸毛", "白爪", "虎斑条纹"],
  "distinctive_features": "脸部有M字纹，尾巴有环状条纹",
  "style_suggestion": "disney_realistic",
  "prompt_keywords": ["橘色虎斑", "白色胸毛", "圆润体型", "金黄色眼睛"],
  "avoid_keywords": ["纯色", "长毛"]
}

请严格返回纯JSON，不要添加markdown标记。"""

        response = model.generate_content(
            [prompt, img],
            generation_config=genai.types.GenerationConfig(temperature=0.1)
        )
        
        result_text = response.text.strip()
        
        # 移除可能的markdown标记
        if result_text.startswith("```json"):
            result_text = result_text[7:]
        elif result_text.startswith("```"):
            result_text = result_text[3:]
        if result_text.endswith("```"):
            result_text = result_text[:-3]
        result_text = result_text.strip()
        
        try:
            return json.loads(result_text)
        except json.JSONDecodeError as e:
            return {"error": f"JSON解析失败: {str(e)}", "raw_response": result_text[:500]}
            
    except Exception as e:
        return {"error": f"分析失败: {str(e)}"}


# 示例用法和测试
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("用法: python ai_content_checker.py <图片路径>")
        sys.exit(1)

    image_path = sys.argv[1]

    print(f"正在使用 Gemini 2.0 Flash 分析图片: {image_path}")
    print("=" * 60)

    result = check_image_with_ai(image_path)

    print(json.dumps(result, indent=2, ensure_ascii=False))

    # 打印关键信息
    print("\n" + "=" * 60)
    print("关键信息:")
    print(f"  内容安全: {'✅ 安全' if result.get('content_safety', {}).get('safe') else '❌ 不安全'}")
    print(f"  宠物检测: {'✅ 检测到' if result.get('pet_detection', {}).get('detected') else '❌ 未检测到'}")
    print(f"  是否坐姿: {'✅ 是' if result.get('pose_analysis', {}).get('is_sitting') else '❌ 否'}")
    print(f"  背景干净: {'✅ 是' if result.get('background_quality', {}).get('is_clean') else '❌ 否'}")
    print(f"  适合生成: {'✅ 是' if result.get('overall_assessment', {}).get('suitable_for_generation') else '❌ 否'}")
    print(f"  严重程度: {result.get('overall_assessment', {}).get('severity_level', 'unknown')}")
