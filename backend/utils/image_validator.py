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
    def validate_pet_content(file_path: str) -> Tuple[bool, Optional[str], Dict]:
        """
        验证图片是否包含宠物（可选功能，需要AI模型）

        注意：这个功能需要额外的依赖和模型，目前返回占位符
        未来可以集成：
        - 百度AI、阿里云、腾讯云的图像识别API
        - 本地YOLO/ResNet等模型

        Args:
            file_path: 文件路径

        Returns:
            (是否通过, 错误/警告信息, 检测结果)
        """
        # TODO: 集成AI内容检测
        # 目前返回通过，不做内容检测
        return True, None, {
            'detected': None,
            'confidence': None,
            'message': '内容检测功能尚未启用'
        }

    @classmethod
    def validate_all(cls, file_path: str, strict_mode: bool = False) -> Dict:
        """
        执行所有验证检查

        Args:
            file_path: 文件路径
            strict_mode: 严格模式（质量警告也会导致验证失败）

        Returns:
            验证结果字典
        """
        result = {
            'valid': True,
            'errors': [],
            'warnings': [],
            'metrics': {}
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

        # 5. 宠物内容检测（可选）
        is_valid, msg, detection_result = cls.validate_pet_content(file_path)
        result['metrics']['pet_detection'] = detection_result
        if not is_valid:
            result['warnings'].append({
                'code': 'PET_DETECTION_WARNING',
                'message': msg or '未检测到宠物，请确保图片包含清晰的宠物'
            })

        return result


# 便捷函数
def validate_image(file_path: str, strict_mode: bool = False) -> Dict:
    """
    验证图片的便捷函数

    Args:
        file_path: 图片文件路径
        strict_mode: 是否启用严格模式

    Returns:
        验证结果字典
    """
    return ImageValidator.validate_all(file_path, strict_mode)
