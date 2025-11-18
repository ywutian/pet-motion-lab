import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class KlingService {
  static const String _baseUrl = 'https://api-beijing.klingai.com';
  static const String _accessKey = 'ARNETYRNbTm8KDpKHrpBBF4NT8TRfAKt';
  static const String _secretKey = 'HnPMANpdakffkTYgft9EfrerB8bhgpLR';

  /// 生成签名
  static String _generateSignature(String timestamp) {
    final message = _accessKey + timestamp;
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return base64Encode(digest.bytes);
  }

  /// 获取认证头
  static Map<String, String> _getAuthHeaders() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = _generateSignature(timestamp);
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessKey:$signature:$timestamp',
    };
  }

  /// 上传图片并获取图片URL
  static Future<String> _uploadImage(File imageFile) async {
    try {
      final dio = Dio();
      final headers = _getAuthHeaders();
      
      // 移除Content-Type，让Dio自动设置multipart/form-data
      headers.remove('Content-Type');
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
      });

      final response = await dio.post(
        '$_baseUrl/v1/files/upload',
        data: formData,
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data.containsKey('url')) {
          return data['url'] as String;
        } else if (data is Map && data.containsKey('data') && data['data'] is Map) {
          final dataMap = data['data'] as Map;
          if (dataMap.containsKey('url')) {
            return dataMap['url'] as String;
          }
        }
      }
      
      throw Exception('上传图片失败: ${response.statusCode} - ${response.data}');
    } catch (e) {
      throw Exception('上传图片时出错: $e');
    }
  }

  /// 创建视频生成任务
  static Future<String> _createVideoGenerationTask({
    required String imageUrl,
    required String prompt,
    required String aspectRatio,
    required int duration,
  }) async {
    try {
      final dio = Dio();
      final headers = _getAuthHeaders();

      final payload = {
        'image_url': imageUrl,
        'prompt': prompt,
        'aspect_ratio': aspectRatio,
        'duration': duration,
      };

      final response = await dio.post(
        '$_baseUrl/v1/videos/generations',
        data: jsonEncode(payload),
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        String? taskId;
        
        if (data is Map) {
          if (data.containsKey('task_id')) {
            taskId = data['task_id'] as String?;
          } else if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map;
            taskId = dataMap['task_id'] as String?;
          } else if (data.containsKey('id')) {
            taskId = data['id'] as String?;
          }
        }
        
        if (taskId != null) {
          return taskId;
        }
      }
      
      throw Exception('创建视频生成任务失败: ${response.statusCode} - ${response.data}');
    } catch (e) {
      throw Exception('创建视频生成任务时出错: $e');
    }
  }

  /// 查询任务状态
  static Future<Map<String, dynamic>> _queryTaskStatus(String taskId) async {
    try {
      final dio = Dio();
      final headers = _getAuthHeaders();

      final response = await dio.get(
        '$_baseUrl/v1/videos/generations/$taskId',
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      
      throw Exception('查询任务状态失败: ${response.statusCode} - ${response.data}');
    } catch (e) {
      throw Exception('查询任务状态时出错: $e');
    }
  }

  /// 下载视频文件
  static Future<File> _downloadVideo(String videoUrl, String outputPath) async {
    try {
      final dio = Dio();
      await dio.download(videoUrl, outputPath);
      return File(outputPath);
    } catch (e) {
      throw Exception('下载视频时出错: $e');
    }
  }

  /// 将分辨率转换为宽高比
  static String _resolutionToAspectRatio(String resolution) {
    final parts = resolution.split('x');
    if (parts.length != 2) return '16:9';
    
    final width = int.tryParse(parts[0]) ?? 16;
    final height = int.tryParse(parts[1]) ?? 9;
    
    // 计算最大公约数
    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    final divisor = gcd(width, height);
    
    return '${width ~/ divisor}:${height ~/ divisor}';
  }

  /// 生成视频
  /// 
  /// [inputFiles] 输入图片文件列表（通常只需要第一张）
  /// [prompt] 提示词
  /// [resolution] 分辨率，格式如 "1920x1080"
  /// [duration] 视频时长（秒）
  /// [fps] 帧率（可灵AI可能不支持自定义fps，但保留参数）
  static Future<File> generateVideo({
    required List<File> inputFiles,
    required String prompt,
    required String resolution,
    required int duration,
    required int fps,
  }) async {
    if (inputFiles.isEmpty) {
      throw Exception('至少需要一张输入图片');
    }

    final inputFile = inputFiles.first;
    
    try {
      // 1. 上传图片
      print('正在上传图片到可灵AI...');
      final imageUrl = await _uploadImage(inputFile);
      print('图片上传成功: $imageUrl');

      // 2. 创建视频生成任务
      print('正在创建视频生成任务...');
      final aspectRatio = _resolutionToAspectRatio(resolution);
      final taskId = await _createVideoGenerationTask(
        imageUrl: imageUrl,
        prompt: prompt,
        aspectRatio: aspectRatio,
        duration: duration,
      );
      print('任务创建成功，任务ID: $taskId');

      // 3. 轮询任务状态
      print('正在等待视频生成...');
      String? videoUrl;
      String status = 'pending';
      int maxRetries = 60; // 最多等待5分钟（每5秒查询一次）
      int retryCount = 0;

      while (retryCount < maxRetries && status != 'completed' && status != 'success') {
        await Future.delayed(const Duration(seconds: 5));
        retryCount++;

        final taskData = await _queryTaskStatus(taskId);
        status = taskData['status']?.toString().toLowerCase() ?? 'unknown';
        
        print('任务状态: $status (第 $retryCount 次查询)');

        if (status == 'completed' || status == 'success') {
          // 提取视频URL
          if (taskData.containsKey('video_url')) {
            videoUrl = taskData['video_url'] as String?;
          } else if (taskData.containsKey('data') && taskData['data'] is Map) {
            final dataMap = taskData['data'] as Map;
            videoUrl = dataMap['video_url'] as String?;
            if (videoUrl == null && dataMap.containsKey('url')) {
              videoUrl = dataMap['url'] as String?;
            }
          } else if (taskData.containsKey('url')) {
            videoUrl = taskData['url'] as String?;
          }
          
          if (videoUrl != null) {
            break;
          }
        } else if (status == 'failed' || status == 'error') {
          throw Exception('视频生成失败: ${taskData['message'] ?? '未知错误'}');
        }
      }

      if (videoUrl == null) {
        throw Exception('视频生成超时或未获取到视频URL');
      }

      print('视频生成完成，开始下载: $videoUrl');

      // 4. 下载视频
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(tempDir.path, 'kling_$timestamp.mp4');
      
      final outputFile = await _downloadVideo(videoUrl, outputPath);
      print('视频下载完成: ${outputFile.path}');

      return outputFile;
    } catch (e) {
      throw Exception('可灵AI视频生成失败: $e');
    }
  }

  /// 图片生成视频（简化版）
  Future<String> imageToVideo({
    required String imagePath,
    required String prompt,
  }) async {
    final file = await generateVideo(
      inputFiles: [File(imagePath)],
      prompt: prompt,
      resolution: '1920x1080',
      duration: 5,
      fps: 24,
    );
    return file.path;
  }

  /// 生成坐姿图片（使用图生图功能）
  Future<String> generateSittingPoseImage({
    required String imagePath,
    required String prompt,
  }) async {
    // 可灵AI的图生图功能，生成坐姿图片
    final file = await generateVideo(
      inputFiles: [File(imagePath)],
      prompt: prompt,
      resolution: '1920x1080',
      duration: 5,
      fps: 24,
    );
    return file.path;
  }

  /// 首尾帧生成过渡视频
  Future<String> generateTransitionVideo({
    required String startImagePath,
    required String endImagePath,
  }) async {
    // 使用首帧生成视频，提示词中包含过渡到尾帧的描述
    final file = await generateVideo(
      inputFiles: [File(startImagePath)],
      prompt: '平滑过渡到目标姿态',
      resolution: '1920x1080',
      duration: 5,
      fps: 24,
    );
    return file.path;
  }

  /// 测试API连接
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final dio = Dio();
      final headers = _getAuthHeaders();

      // 尝试调用一个简单的API端点来测试连接
      final response = await dio.get(
        '$_baseUrl/v1/status',
        options: Options(
          headers: headers,
        ),
      );

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'data': response.data,
      };
    } catch (e) {
      // 如果status端点不存在，尝试其他方式测试
      return {
        'success': false,
        'error': e.toString(),
        'message': 'API连接测试失败，但服务可能仍然可用',
      };
    }
  }
}




