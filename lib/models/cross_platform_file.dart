import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// 跨平台文件模型，支持Web和原生平台
class CrossPlatformFile {
  /// 文件名
  final String name;
  
  /// 文件字节数据（Web必需，原生可选）
  final Uint8List? bytes;
  
  /// 文件路径（仅原生平台）
  final String? path;
  
  /// MIME类型
  final String? mimeType;
  
  /// 文件大小
  final int? size;

  CrossPlatformFile({
    required this.name,
    this.bytes,
    this.path,
    this.mimeType,
    this.size,
  });

  /// 是否有有效的文件数据
  bool get hasData => bytes != null || path != null;
  
  /// 是否是Web文件（只有bytes没有path）
  bool get isWebFile => kIsWeb || (bytes != null && path == null);
  
  /// 获取文件扩展名
  String get extension {
    final dotIndex = name.lastIndexOf('.');
    return dotIndex != -1 ? name.substring(dotIndex + 1).toLowerCase() : '';
  }
  
  /// 是否是图片
  bool get isImage {
    final ext = extension;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }
  
  /// 是否是视频
  bool get isVideo {
    final ext = extension;
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  }
}

