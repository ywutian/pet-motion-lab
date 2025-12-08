import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

/// 可灵AI工具服务 - 调用后端API
class KlingToolsService {
  // 使用统一的 API 配置
  static String get baseUrl => ApiConfig.baseUrl;

  /// 图生图 - 上传图片，根据提示词生成新图片
  Future<File> imageToImage({
    required File imageFile,
    required String prompt,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/tools/image-to-image');
      print('🌐 正在连接: $uri');
      print('  提示词: $prompt');

      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      request.fields['prompt'] = prompt;

      print('📤 发送图片...');
      final response = await request.send();

      print('📥 收到响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 保存结果到临时文件
        final bytes = await response.stream.toBytes();
        final tempDir = await getTemporaryDirectory();
        final outputFile = File('${tempDir.path}/img2img_${DateTime.now().millisecondsSinceEpoch}.png');
        await outputFile.writeAsBytes(bytes);

        print('✅ 图生图成功: ${outputFile.path}');
        return outputFile;
      } else {
        final responseBody = await response.stream.bytesToString();
        print('❌ 图生图失败: $responseBody');
        throw Exception('图生图失败: $responseBody');
      }
    } catch (e) {
      print('❌ 连接错误: $e');
      rethrow;
    }
  }

  /// 图生视频 - 上传图片，根据提示词生成视频
  Future<File> imageToVideo({
    required File imageFile,
    required String prompt,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/tools/image-to-video');
      print('🌐 正在连接: $uri');
      print('  提示词: $prompt');

      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      request.fields['prompt'] = prompt;

      print('📤 发送图片...');
      final response = await request.send();

      print('📥 收到响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 保存结果到临时文件
        final bytes = await response.stream.toBytes();
        final tempDir = await getTemporaryDirectory();
        final outputFile = File('${tempDir.path}/img2vid_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await outputFile.writeAsBytes(bytes);

        print('✅ 图生视频成功: ${outputFile.path}');
        return outputFile;
      } else {
        final responseBody = await response.stream.bytesToString();
        print('❌ 图生视频失败: $responseBody');
        throw Exception('图生视频失败: $responseBody');
      }
    } catch (e) {
      print('❌ 连接错误: $e');
      rethrow;
    }
  }

  /// 首尾帧生成过渡视频
  Future<File> framesToVideo({
    required File firstFrame,
    required File lastFrame,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/tools/frames-to-video');
      print('🌐 正在连接: $uri');

      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('first_frame', firstFrame.path));
      request.files.add(await http.MultipartFile.fromPath('last_frame', lastFrame.path));

      print('📤 发送首尾帧...');
      final response = await request.send();

      print('📥 收到响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 保存结果到临时文件
        final bytes = await response.stream.toBytes();
        final tempDir = await getTemporaryDirectory();
        final outputFile = File('${tempDir.path}/transition_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await outputFile.writeAsBytes(bytes);

        print('✅ 过渡视频生成成功: ${outputFile.path}');
        return outputFile;
      } else {
        final responseBody = await response.stream.bytesToString();
        print('❌ 过渡视频生成失败: $responseBody');
        throw Exception('过渡视频生成失败: $responseBody');
      }
    } catch (e) {
      print('❌ 连接错误: $e');
      rethrow;
    }
  }

  /// 视频转GIF - 将视频转换为GIF动画
  Future<File> convertVideoToGif(
    String videoPath, {
    int fpsReduction = 2,
    int maxWidth = 480,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/tools/video-to-gif');
      print('🌐 正在连接: $uri');
      print('  视频路径: $videoPath');
      print('  帧率缩减: ${fpsReduction}x');
      print('  最大宽度: ${maxWidth}px');

      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', videoPath));
      request.fields['fps_reduction'] = fpsReduction.toString();
      request.fields['max_width'] = maxWidth.toString();

      print('📤 发送视频...');
      final response = await request.send();

      print('📥 收到响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 保存结果到临时文件
        final bytes = await response.stream.toBytes();
        final tempDir = await getTemporaryDirectory();
        final outputFile = File('${tempDir.path}/video2gif_${DateTime.now().millisecondsSinceEpoch}.gif');
        await outputFile.writeAsBytes(bytes);

        print('✅ 视频转GIF成功: ${outputFile.path}');
        return outputFile;
      } else {
        final responseBody = await response.stream.bytesToString();
        print('❌ 视频转GIF失败: $responseBody');
        throw Exception('视频转GIF失败: $responseBody');
      }
    } catch (e) {
      print('❌ 视频转GIF异常: $e');
      rethrow;
    }
  }

  /// 检查服务是否可用
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri);
      return response.statusCode == 200;
    } catch (e) {
      print('❌ 健康检查失败: $e');
      return false;
    }
  }
}

