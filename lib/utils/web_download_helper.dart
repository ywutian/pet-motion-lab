import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

/// Web兼容的下载帮助类
class WebDownloadHelper {
  static String get baseUrl => ApiConfig.baseUrl;

  /// 将后端路径转换为下载URL
  static String convertToDownloadUrl(String filePath) {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }

    final parts = filePath.split('/');
    String? petId;
    int petIdIndex = -1;
    
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].startsWith('pet_')) {
        petId = parts[i];
        petIdIndex = i;
        break;
      }
    }

    if (petId == null || petIdIndex == -1 || petIdIndex + 1 >= parts.length) {
      return filePath;
    }

    final remainingParts = parts.sublist(petIdIndex + 1);

    if (remainingParts.length == 1) {
      final filename = remainingParts[0];
      return '$baseUrl/api/kling/download/$petId/$filename';
    }

    final fileType = remainingParts[0];
    final filename = remainingParts.sublist(1).join('/');
    return '$baseUrl/api/kling/download/$petId/$fileType/$filename';
  }

  /// 在新标签页打开下载链接（Web兼容）
  static Future<void> downloadFile({
    required BuildContext context,
    required String filePath,
    String? customFileName,
  }) async {
    try {
      final url = convertToDownloadUrl(filePath);
      
      if (kIsWeb) {
        // Web平台：在新标签页打开
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, webOnlyWindowName: '_blank');
        } else {
          throw Exception('无法打开链接: $url');
        }
      } else {
        // 原生平台：使用url_launcher
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('无法打开链接: $url');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.download, color: Colors.white),
                SizedBox(width: 12),
                Text('已开始下载'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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
          ),
        );
      }
    }
  }

  /// 下载视频
  static Future<void> downloadVideo({
    required BuildContext context,
    required String filePath,
    String? customFileName,
  }) async {
    await downloadFile(
      context: context,
      filePath: filePath,
      customFileName: customFileName,
    );
  }
}

