import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

class BackgroundRemovalService {
  // 使用统一的 API 配置
  static String get baseUrl => ApiConfig.baseUrl;

  /// 去除图片背景
  Future<File> removeBackground(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/api/background/remove');
      print('🌐 正在连接: $uri');

      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      print('📤 发送图片...');
      final response = await request.send();

      print('📥 收到响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 保存结果到临时文件
        final bytes = await response.stream.toBytes();
        final tempDir = await getTemporaryDirectory();
        final outputFile = File('${tempDir.path}/no_bg_${DateTime.now().millisecondsSinceEpoch}.png');
        await outputFile.writeAsBytes(bytes);

        print('✅ 背景去除成功: ${outputFile.path}');
        return outputFile;
      } else {
        final responseBody = await response.stream.bytesToString();
        print('❌ 背景去除失败: $responseBody');
        throw Exception('背景去除失败: $responseBody');
      }
    } catch (e) {
      print('❌ 连接错误: $e');
      rethrow;
    }
  }

  /// 检查服务是否可用
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/api/background/health');
      final response = await http.get(uri);
      return response.statusCode == 200;
    } catch (e) {
      print('❌ 健康检查失败: $e');
      return false;
    }
  }
}

