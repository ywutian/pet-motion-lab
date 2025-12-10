"""
图片验证工具模块
用于验证用户上传的图片是否符合系统要求
"""

import os
import imghdr
from pathlib import Path
from typing import Dict, Tuple, Optional
from PIL import Image
import magic  # python-magic库用于检测MIME类型


class ImageValidationError(Exception):
    """图片验证失败异常"""
    def __init__(self, message: str, error_code: str):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)


class ImageValidator:
    """图片验证器"""

    # 配置常量
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
    MIN_FILE_SIZE = 1024  # 1KB
    ALLOWED_FORMATS = {'JPEG', 'PNG', 'JPG', 'WEBP'}
    ALLOWED_MIME_TYPES = {
        'image/jpeg',
        'image/png',
        'image/webp'
    }
    MIN_WIDTH = 256
    MIN_HEIGHT = 256
    MAX_WIDTH = 4096
    MAX_HEIGHT = 4096
    MIN_ASPECT_RATIO = 0.5  # 最小宽高比（宽/高）
    MAX_ASPECT_RATIO = 2.0  # 最大宽高比

    @staticmethod
    def validate_file_size(file_path: str) -> Tuple[bool, Optional[str]]:
        """
        验证文件大小

        Args:
            file_path: 文件路径

        Returns:
            (是否通过, 错误信息)
        """
        file_size = os.path.getsize(file_path)

        if file_size < ImageValidator.MIN_FILE_SIZE:
            return False, f"文件太小（{file_size} bytes），最小需要 {ImageValidator.MIN_FILE_SIZE} bytes"

        if file_size > ImageValidator.MAX_FILE_SIZE:
            size_mb = file_size / (1024 * 1024)
            max_mb = ImageValidator.MAX_FILE_SIZE / (1024 * 1024)
            return False, f"文件过大（{size_mb:.2f}MB），最大允许 {max_mb}MB"

        return True, None

    @staticmethod
    def validate_file_type(file_path: str) -> Tuple[bool, Optional[str]]:
        """
        验证文件类型（通过文件头和MIME类型）

        Args:
            file_path: 文件路径

        Returns:
            (是否通过, 错误信息)
        """
        # 方法1: 通过文件头检测
        img_type = imghdr.what(file_path)
        if img_type is None:
            return False, "无法识别的文件格式，请上传有效的图片文件"

        if img_type.upper() not in ImageValidator.ALLOWED_FORMATS:
            return False, f"不支持的图片格式: {img_type}。仅支持 {', '.join(ImageValidator.ALLOWED_FORMATS)}"

        # 方法2: 通过MIME类型检测（需要python-magic库）
        try:
            mime = magic.Magic(mime=True)
            mime_type = mime.from_file(file_path)

            if mime_type not in ImageValidator.ALLOWED_MIME_TYPES:
                return False, f"不支持的MIME类型: {mime_type}"
        except Exception as e:
            # 如果python-magic不可用，跳过MIME检测
            print(f"警告: MIME类型检测失败: {e}")

        return True, None

    @staticmethod
    def validate_image_content(file_path: str) -> Tuple[bool, Optional[str]]:
        """
        验证图片内容（尺寸、格式等）

        Args:
            file_path: 文件路径

        Returns:
            (是否通过, 错误信息)
        """
        try:
            with Image.open(file_path) as img:
                # 检查是否可以正常打开
                img.verify()

            # 重新打开图片以获取详细信息（verify后图片对象不可用）
            with Image.open(file_path) as img:
                width, height = img.size

                # 检查最小尺寸
                if width < ImageValidator.MIN_WIDTH or height < ImageValidator.MIN_HEIGHT:
                    return False, f"图片尺寸过小（{width}x{height}），最小需要 {ImageValidator.MIN_WIDTH}x{ImageValidator.MIN_HEIGHT}"

                # 检查最大尺寸
                if width > ImageValidator.MAX_WIDTH or height > ImageValidator.MAX_HEIGHT:
                    return False, f"图片尺寸过大（{width}x{height}），最大允许 {ImageValidator.MAX_WIDTH}x{ImageValidator.MAX_HEIGHT}"

                # 检查宽高比
                aspect_ratio = width / height
                if aspect_ratio < ImageValidator.MIN_ASPECT_RATIO or aspect_ratio > ImageValidator.MAX_ASPECT_RATIO:
                    return False, f"图片宽高比不合适（{aspect_ratio:.2f}），建议使用接近正方形的图片"

                # 检查图片模式
                if img.mode not in ['RGB', 'RGBA', 'L']:
                    return False, f"不支持的图片颜色模式: {img.mode}，请使用RGB或RGBA格式"

                # 检查是否损坏
                try:
                    img.load()
                except Exception as e:
                    return False, f"图片文件可能已损坏: {str(e)}"

        except Exception as e:
            return False, f"无法打开图片文件: {str(e)}"

        return True, None

    @staticmethod
    def validate_image_quality(file_path: str) -> Tuple[bool, Optional[str], Dict]:
        """
        评估图片质量

        Args:
            file_path: 文件路径

        Returns:
            (是否通过, 警告信息, 质量指标)
        """
        warnings = []
        metrics = {}

        try:
            with Image.open(file_path) as img:
                width, height = img.size
                metrics['width'] = width
                metrics['height'] = height
                metrics['aspect_ratio'] = width / height

                # 计算总像素数
                total_pixels = width * height
                metrics['total_pixels'] = total_pixels

                # 建议最小像素数（512x512 = 262,144）
                recommended_pixels = 512 * 512
                if total_pixels < recommended_pixels:
                    warnings.append(f"图片分辨率较低（{width}x{height}），建议至少 512x512 以获得更好的生成效果")

                # 检查图片清晰度（通过计算边缘强度的方差）
                try:
                    import numpy as np
                    from PIL import ImageFilter

                    # 转换为灰度图
                    gray_img = img.convert('L')

                    # 应用边缘检测
                    edges = gray_img.filter(ImageFilter.FIND_EDGES)

                    # 计算边缘强度的方差（作为清晰度指标）
                    edge_array = np.array(edges)
                    sharpness = np.var(edge_array)
                    metrics['sharpness'] = float(sharpness)

                    # 如果清晰度过低，添加警告
                    if sharpness < 100:  # 阈值可调整
                        warnings.append(f"图片可能较模糊（清晰度: {sharpness:.1f}），建议使用更清晰的照片")

                except ImportError:
                    # 如果numpy不可用，跳过清晰度检测
                    metrics['sharpness'] = None
                except Exception as e:
                    print(f"清晰度检测失败: {e}")
                    metrics['sharpness'] = None

        except Exception as e:
            return False, f"质量检测失败: {str(e)}", {}

        warning_msg = "; ".join(warnings) if warnings else None
        return True, warning_msg, metrics

    @staticmethod
    def validate_pet_content(file_path: str, enable_ai_check: bool = False, google_api_key: str = None) -> Tuple[bool, Optional[str], Dict]:
        """
        验证图片是否包含宠物（可选AI检测）

        Args:
            file_path: 文件路径
            enable_ai_check: 是否启用AI检测（需要Google API Key）
            google_api_key: Google API密钥（可选，默认从环境变量读取）

        Returns:
            (是否通过, 错误/警告信息, 检测结果)
        """
        if not enable_ai_check:
            # 不启用AI检测，直接返回通过
            return True, None, {
                'detected': None,
                'confidence': None,
                'message': 'AI内容检测未启用'
            }

        # 尝试导入AI检查模块
        try:
            from .ai_content_checker import check_image_with_ai
        except ImportError:
            return True, "AI检查模块导入失败，跳过AI检测", {
                'detected': None,
                'confidence': None,
                'message': 'AI模块不可用'
            }

        # 执行AI检查
        try:
            ai_result = check_image_with_ai(file_path, api_key=google_api_key)

            # 提取检测结果
            pet_detection = ai_result.get('pet_detection', {})
            detected = pet_detection.get('detected', False)
            confidence = pet_detection.get('confidence', 0.0)

            detection_result = {
                'detected': detected,
                'species': pet_detection.get('species'),
                'confidence': confidence,
                'count': pet_detection.get('count', 0),
                'ai_result': ai_result  # 保存完整的AI分析结果
            }

            # 如果未检测到宠物，返回警告
            if not detected:
                return False, "未检测到宠物，请确保图片中包含清晰的猫或狗", detection_result

            # 如果检测到多只宠物，返回警告
            if pet_detection.get('count', 1) > 1:
                return False, f"检测到{pet_detection.get('count')}只宠物，建议图片中只包含一只宠物", detection_result

            return True, None, detection_result

        except Exception as e:
            # AI检查失败不应阻止用户上传，返回警告
            return True, f"AI检测失败: {str(e)}", {
                'detected': None,
                'confidence': None,
                'error': str(e)
            }

    @classmethod
    def validate_all(
        cls,
        file_path: str,
        strict_mode: bool = False,
        enable_ai_check: bool = False,
        google_api_key: str = None
    ) -> Dict:
        """
        执行所有验证检查（包括可选的AI检查）

        Args:
            file_path: 文件路径
            strict_mode: 严格模式（质量警告也会导致验证失败）
            enable_ai_check: 是否启用AI内容检查
            google_api_key: Google API密钥（用于AI检查）

        Returns:
            验证结果字典，包含分级的严重程度
        """
        result = {
            'valid': True,
            'errors': [],
            'warnings': [],
            'metrics': {},
            'severity_level': 'pass'  # pass/warning/error
        }

        # 1. 文件大小验证
        is_valid, error_msg = cls.validate_file_size(file_path)
        if not is_valid:
            result['valid'] = False
            result['errors'].append({
                'code': 'FILE_SIZE_ERROR',
                'message': error_msg
            })
            return result  # 文件大小不符合，直接返回

        # 2. 文件类型验证
        is_valid, error_msg = cls.validate_file_type(file_path)
        if not is_valid:
            result['valid'] = False
            result['errors'].append({
                'code': 'FILE_TYPE_ERROR',
                'message': error_msg
            })
            return result  # 文件类型不符合，直接返回

        # 3. 图片内容验证（尺寸、格式等）
        is_valid, error_msg = cls.validate_image_content(file_path)
        if not is_valid:
            result['valid'] = False
            result['errors'].append({
                'code': 'IMAGE_CONTENT_ERROR',
                'message': error_msg
            })
            return result

        # 4. 图片质量评估
        is_valid, warning_msg, metrics = cls.validate_image_quality(file_path)
        if not is_valid:
            result['valid'] = False
            result['errors'].append({
                'code': 'IMAGE_QUALITY_ERROR',
                'message': warning_msg
            })
        elif warning_msg:
            result['warnings'].append({
                'code': 'IMAGE_QUALITY_WARNING',
                'message': warning_msg
            })
            if strict_mode:
                result['valid'] = False

        result['metrics'].update(metrics)

        # 5. AI内容检测（可选，包含宠物检测、姿势分析、背景质量等）
        if enable_ai_check:
            is_valid, msg, detection_result = cls.validate_pet_content(
                file_path,
                enable_ai_check=True,
                google_api_key=google_api_key
            )
            result['metrics']['ai_analysis'] = detection_result

            # 提取AI分析结果
            ai_result = detection_result.get('ai_result', {})
            overall_assessment = ai_result.get('overall_assessment', {})
            severity = overall_assessment.get('severity_level', 'pass')

            # 更新整体严重程度
            if severity == 'error':
                result['severity_level'] = 'error'
            elif severity == 'warning' and result['severity_level'] == 'pass':
                result['severity_level'] = 'warning'

            # 处理AI检测结果
            if not is_valid:
                # 未通过基础宠物检测
                result['errors'].append({
                    'code': 'AI_PET_DETECTION_FAILED',
                    'message': msg,
                    'severity': 'error'
                })
                result['valid'] = False
                result['severity_level'] = 'error'

            # 添加AI分析的详细问题和建议
            if ai_result:
                # 内容安全检查
                content_safety = ai_result.get('content_safety', {})
                if not content_safety.get('safe', True):
                    result['errors'].append({
                        'code': 'CONTENT_SAFETY_VIOLATION',
                        'message': '图片包含不良内容: ' + ', '.join(content_safety.get('issues', [])),
                        'severity': 'error'
                    })
                    result['valid'] = False
                    result['severity_level'] = 'error'

                # 姿势分析
                pose_analysis = ai_result.get('pose_analysis', {})
                if not pose_analysis.get('is_sitting', False):
                    result['warnings'].append({
                        'code': 'NON_SITTING_POSE',
                        'message': f"宠物姿势为{pose_analysis.get('posture', 'unknown')}，推荐使用坐姿图片以获得最佳生成效果",
                        'severity': 'warning',
                        'suggestions': pose_analysis.get('suggestions', [])
                    })
                    if result['severity_level'] == 'pass':
                        result['severity_level'] = 'warning'

                # 背景质量
                background_quality = ai_result.get('background_quality', {})
                if not background_quality.get('is_clean', True):
                    difficulty = background_quality.get('removal_difficulty', 'unknown')
                    if difficulty == 'hard':
                        result['warnings'].append({
                            'code': 'COMPLEX_BACKGROUND',
                            'message': f"背景复杂({background_quality.get('type', 'unknown')})，可能难以完全去除",
                            'severity': 'warning',
                            'suggestions': background_quality.get('suggestions', [])
                        })
                        if result['severity_level'] == 'pass':
                            result['severity_level'] = 'warning'

                # 特征完整性
                feature_completeness = ai_result.get('feature_completeness', {})
                completeness_score = feature_completeness.get('completeness_score', 1.0)
                if completeness_score < 0.7:
                    result['warnings'].append({
                        'code': 'INCOMPLETE_FEATURES',
                        'message': f"宠物特征不完整(完整度: {completeness_score:.0%})，可能影响生成质量",
                        'severity': 'warning',
                        'missing_features': feature_completeness.get('missing_features', []),
                        'suggestions': feature_completeness.get('suggestions', [])
                    })
                    if result['severity_level'] == 'pass':
                        result['severity_level'] = 'warning'

                # 添加AI的总体建议
                recommendations = overall_assessment.get('recommendations', [])
                if recommendations:
                    result['metrics']['ai_recommendations'] = recommendations

        else:
            # 不启用AI检测，使用旧的简单检测
            is_valid, msg, detection_result = cls.validate_pet_content(file_path, enable_ai_check=False)
            result['metrics']['pet_detection'] = detection_result

        return result


# 便捷函数
def validate_image(
    file_path: str,
    strict_mode: bool = False,
    enable_ai_check: bool = False,
    google_api_key: str = None
) -> Dict:
    """
    验证图片的便捷函数

    Args:
        file_path: 图片文件路径
        strict_mode: 是否启用严格模式
        enable_ai_check: 是否启用AI内容检查
        google_api_key: Google API密钥

    Returns:
        验证结果字典，包含：
        - valid: bool - 是否通过验证
        - errors: List[Dict] - 错���列表
        - warnings: List[Dict] - 警告列表
        - metrics: Dict - 检测指标
        - severity_level: str - 严重程度 (pass/warning/error)
    """
    return ImageValidator.validate_all(
        file_path,
        strict_mode=strict_mode,
        enable_ai_check=enable_ai_check,
        google_api_key=google_api_key
    )
