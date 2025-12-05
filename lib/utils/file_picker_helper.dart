import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cross_platform_file.dart';

/// 跨平台文件选择帮助类
class FilePickerHelper {
  static final ImagePicker _imagePicker = ImagePicker();

  /// 选择图片（跨平台）
  static Future<CrossPlatformFile?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      if (kIsWeb) {
        // Web平台使用file_picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true, // Web必须获取bytes
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          return CrossPlatformFile(
            name: file.name,
            bytes: file.bytes,
            size: file.size,
            mimeType: _getMimeType(file.name),
          );
        }
      } else {
        // 原生平台使用image_picker
        final XFile? xFile = await _imagePicker.pickImage(source: source);
        if (xFile != null) {
          final bytes = await xFile.readAsBytes();
          return CrossPlatformFile(
            name: xFile.name,
            bytes: bytes,
            path: xFile.path,
            mimeType: xFile.mimeType,
          );
        }
      }
    } catch (e) {
      print('❌ 选择图片失败: $e');
    }
    return null;
  }

  /// 选择多个图片（跨平台）
  static Future<List<CrossPlatformFile>> pickMultipleImages() async {
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
          withData: true,
        );

        if (result != null) {
          return result.files.map((file) => CrossPlatformFile(
            name: file.name,
            bytes: file.bytes,
            size: file.size,
            mimeType: _getMimeType(file.name),
          )).toList();
        }
      } else {
        final List<XFile> xFiles = await _imagePicker.pickMultiImage();
        final List<CrossPlatformFile> files = [];
        for (final xFile in xFiles) {
          final bytes = await xFile.readAsBytes();
          files.add(CrossPlatformFile(
            name: xFile.name,
            bytes: bytes,
            path: xFile.path,
            mimeType: xFile.mimeType,
          ));
        }
        return files;
      }
    } catch (e) {
      print('❌ 选择多个图片失败: $e');
    }
    return [];
  }

  /// 选择视频（跨平台）
  static Future<CrossPlatformFile?> pickVideo() async {
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          return CrossPlatformFile(
            name: file.name,
            bytes: file.bytes,
            size: file.size,
            mimeType: _getMimeType(file.name),
          );
        }
      } else {
        final XFile? xFile = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (xFile != null) {
          final bytes = await xFile.readAsBytes();
          return CrossPlatformFile(
            name: xFile.name,
            bytes: bytes,
            path: xFile.path,
            mimeType: xFile.mimeType,
          );
        }
      }
    } catch (e) {
      print('❌ 选择视频失败: $e');
    }
    return null;
  }

  /// 选择任意文件（跨平台）
  static Future<CrossPlatformFile?> pickFile({
    List<String>? allowedExtensions,
    FileType type = FileType.any,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : type,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: kIsWeb, // Web必须获取bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;
        
        // 原生平台如果没有bytes，需要读取
        if (bytes == null && file.path != null && !kIsWeb) {
          // 这里需要原生平台特定的读取逻辑
          // 由调用方处理
        }
        
        return CrossPlatformFile(
          name: file.name,
          bytes: bytes,
          path: file.path,
          size: file.size,
          mimeType: _getMimeType(file.name),
        );
      }
    } catch (e) {
      print('❌ 选择文件失败: $e');
    }
    return null;
  }

  /// 根据文件名获取MIME类型
  static String? _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'webm':
        return 'video/webm';
      default:
        return null;
    }
  }
}

