import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class VideoTrimmingService {
  // 使用统一的 API 配置
  static String get baseUrl => ApiConfig.baseUrl;

  /// 获取视频信息
  static Future<VideoInfo> getVideoInfo(File videoFile) async {
    final uri = Uri.parse('$baseUrl/api/video/info');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));

    print('🌐 获取视频信息: $uri');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      print('✅ 获取视频信息成功');
      final data = json.decode(responseBody);
      return VideoInfo.fromJson(data['info']);
    } else {
      print('❌ 获取视频信息失败: ${response.statusCode}');
      throw Exception('获取视频信息失败: $responseBody');
    }
  }

  /// 裁剪视频
  static Future<File> trimVideo({
    required File videoFile,
    required int startFrame,
    int? endFrame,
  }) async {
    final uri = Uri.parse('$baseUrl/api/video/trim');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    request.fields['start_frame'] = startFrame.toString();
    if (endFrame != null) {
      request.fields['end_frame'] = endFrame.toString();
    }

    print('🌐 裁剪视频: $uri');
    print('   起始帧: $startFrame');
    print('   结束帧: ${endFrame ?? "最后一帧"}');

    final response = await request.send();

    if (response.statusCode == 200) {
      print('✅ 视频裁剪成功');

      // 保存裁剪后的视频
      final bytes = await response.stream.toBytes();
      print('📦 接收到 ${bytes.length} 字节数据');

      final tempDir = Directory.systemTemp;
      final outputFile = File('${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await outputFile.writeAsBytes(bytes);

      print('✅ 裁剪后的视频已保存到临时目录');
      print('📁 路径: ${outputFile.path}');
      print('📊 文件大小: ${await outputFile.length()} 字节');
      print('📂 临时目录: ${tempDir.path}');

      return outputFile;
    } else {
      final responseBody = await response.stream.bytesToString();
      print('❌ 视频裁剪失败: ${response.statusCode}');
      throw Exception('视频裁剪失败: $responseBody');
    }
  }

  /// 提取视频的首帧或尾帧
  static Future<File> extractFrame({
    required File videoFile,
    required String frameType, // "first" 或 "last"
  }) async {
    print('🌐 提取视频帧: $baseUrl/api/video/extract-frame');
    print('   类型: $frameType');

    final uri = Uri.parse('$baseUrl/api/video/extract-frame');
    final request = http.MultipartRequest('POST', uri);

    // 添加视频文件
    request.files.add(
      await http.MultipartFile.fromPath('video', videoFile.path),
    );

    // 添加帧类型
    request.fields['frame_type'] = frameType;

    final response = await request.send();

    if (response.statusCode == 200) {
      print('✅ 帧提取成功');

      // 保存图片
      final bytes = await response.stream.toBytes();
      print('📦 接收到 ${bytes.length} 字节数据');

      final tempDir = Directory.systemTemp;
      final outputFile = File('${tempDir.path}/${frameType}_frame_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await outputFile.writeAsBytes(bytes);

      print('✅ 图片已保存到临时目录');
      print('📁 路径: ${outputFile.path}');
      print('📊 文件大小: ${await outputFile.length()} 字节');

      return outputFile;
    } else {
      final responseBody = await response.stream.bytesToString();
      print('❌ 帧提取失败: ${response.statusCode}');
      throw Exception('帧提取失败: $responseBody');
    }
  }
}

/// 视频信息模型
class VideoInfo {
  final double fps;
  final int width;
  final int height;
  final int totalFrames;
  final double duration;

  VideoInfo({
    required this.fps,
    required this.width,
    required this.height,
    required this.totalFrames,
    required this.duration,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      fps: (json['fps'] as num).toDouble(),
      width: json['width'] as int,
      height: json['height'] as int,
      totalFrames: json['total_frames'] as int,
      duration: (json['duration'] as num).toDouble(),
    );
  }

  String get durationFormatted {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

