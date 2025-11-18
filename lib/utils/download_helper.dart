import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class DownloadHelper {
  /// 获取后端URL（使用统一的 API 配置）
  static String get baseUrl => ApiConfig.baseUrl;

  /// 将后端路径转换为下载URL
  /// 例如:
  /// - backend/output/kling_pipeline/pet_123/base_images/sit.png
  ///   转换为: http://10.0.0.229:8002/api/kling/download/pet_123/base_images/sit.png
  /// - output/kling_pipeline/pet_123/transparent.png
  ///   转换为: http://10.0.0.229:8002/api/kling/download/pet_123/transparent.png
  static String _convertToDownloadUrl(String filePath) {
    // 如果已经是URL，直接返回
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }

    // 解析路径，提取 pet_id, file_type, filename
    // 路径格式1: backend/output/kling_pipeline/pet_xxx/file_type/filename
    // 路径格式2: output/kling_pipeline/pet_xxx/filename (没有file_type目录)

    final parts = filePath.split('/');

    // 找到 pet_id (以 pet_ 开头的部分)
    String? petId;
    int petIdIndex = -1;
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].startsWith('pet_')) {
        petId = parts[i];
        petIdIndex = i;
        break;
      }
    }

    if (petId == null || petIdIndex == -1) {
      // 如果无法解析，尝试作为本地文件
      return filePath;
    }

    // 检查是否有足够的部分
    if (petIdIndex + 1 >= parts.length) {
      return filePath;
    }

    // 获取 pet_id 后面的所有部分
    final remainingParts = parts.sublist(petIdIndex + 1);

    // 如果只有一个部分（文件名），直接使用
    // 例如: pet_123/transparent.png
    if (remainingParts.length == 1) {
      final filename = remainingParts[0];
      return '$baseUrl/api/kling/download/$petId/$filename';
    }

    // 如果有多个部分，第一个是file_type，其余是filename
    // 例如: pet_123/base_images/sit.png
    final fileType = remainingParts[0];
    final filename = remainingParts.sublist(1).join('/');

    // 构建下载URL
    return '$baseUrl/api/kling/download/$petId/$fileType/$filename';
  }

  /// 下载文件到本地并保存到相册
  static Future<void> downloadAndSaveToGallery({
    required BuildContext context,
    required String filePath,
    String? customFileName,
  }) async {
    try {
      // 显示加载对话框
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在下载...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      File fileToSave;

      // 将后端路径转换为下载URL
      final downloadUrl = _convertToDownloadUrl(filePath);

      print('📥 原始路径: $filePath');
      print('📥 下载URL: $downloadUrl');

      // 判断是本地文件还是URL
      if (downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://')) {
        // 从URL下载
        fileToSave = await _downloadFromUrl(downloadUrl, customFileName);
      } else {
        // 本地文件
        fileToSave = File(downloadUrl);
        if (!await fileToSave.exists()) {
          throw Exception('文件不存在: $downloadUrl');
        }
      }

      // 保存到相册
      await Gal.putImage(fileToSave.path, album: 'Pet Motion Lab');

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 显示成功消息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('已保存到相册: ${path.basename(fileToSave.path)}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 显示错误消息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('下载失败: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// 下载视频文件到本地并保存到相册
  static Future<void> downloadVideoAndSaveToGallery({
    required BuildContext context,
    required String filePath,
    String? customFileName,
  }) async {
    try {
      // 显示加载对话框
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在下载视频...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      File fileToSave;

      // 将后端路径转换为下载URL
      final downloadUrl = _convertToDownloadUrl(filePath);

      print('📥 原始路径: $filePath');
      print('📥 下载URL: $downloadUrl');

      // 判断是本地文件还是URL
      if (downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://')) {
        // 从URL下载
        fileToSave = await _downloadFromUrl(downloadUrl, customFileName);
      } else {
        // 本地文件
        fileToSave = File(downloadUrl);
        if (!await fileToSave.exists()) {
          throw Exception('文件不存在: $downloadUrl');
        }
      }

      // 保存到相册
      await Gal.putVideo(fileToSave.path, album: 'Pet Motion Lab');

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 显示成功消息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('视频已保存到相册: ${path.basename(fileToSave.path)}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 显示错误消息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('下载视频失败: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// 从URL下载文件
  static Future<File> _downloadFromUrl(String url, String? customFileName) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('下载失败: HTTP ${response.statusCode}');
    }

    // 获取临时目录
    final tempDir = await getTemporaryDirectory();

    // 生成文件名
    String fileName;
    if (customFileName != null) {
      fileName = customFileName;
    } else {
      // 从URL提取文件名
      fileName = path.basename(Uri.parse(url).path);
      if (fileName.isEmpty) {
        fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    // 保存文件
    final filePath = path.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    return file;
  }

  /// 仅下载到本地（不保存到相册）
  static Future<File> downloadToLocal({
    required String filePath,
    String? customFileName,
  }) async {
    // 将后端路径转换为下载URL
    final downloadUrl = _convertToDownloadUrl(filePath);

    if (downloadUrl.startsWith('http://') || downloadUrl.startsWith('https://')) {
      return await _downloadFromUrl(downloadUrl, customFileName);
    } else {
      final file = File(downloadUrl);
      if (!await file.exists()) {
        throw Exception('文件不存在: $downloadUrl');
      }
      return file;
    }
  }
}


