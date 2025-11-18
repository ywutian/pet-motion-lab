import 'dart:io';
import 'package:pet_motion_lab/services/kling_service.dart';

/// 可灵AI API测试辅助类
class KlingTestHelper {
  /// 测试API连接
  static Future<void> testConnection() async {
    print('=== 测试可灵AI API连接 ===');
    try {
      final result = await KlingService.testConnection();
      print('连接测试结果:');
      print('  成功: ${result['success']}');
      if (result.containsKey('statusCode')) {
        print('  状态码: ${result['statusCode']}');
      }
      if (result.containsKey('data')) {
        print('  数据: ${result['data']}');
      }
      if (result.containsKey('error')) {
        print('  错误: ${result['error']}');
      }
      if (result.containsKey('message')) {
        print('  消息: ${result['message']}');
      }
    } catch (e) {
      print('❌ 连接测试失败: $e');
    }
    print('');
  }

  /// 测试视频生成（需要提供图片文件路径）
  static Future<void> testVideoGeneration({
    required String imagePath,
    String prompt = '一只可爱的小猫在玩耍',
    String resolution = '1920x1080',
    int duration = 5,
  }) async {
    print('=== 测试可灵AI视频生成 ===');
    
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      print('❌ 图片文件不存在: $imagePath');
      return;
    }

    print('输入图片: $imagePath');
    print('提示词: $prompt');
    print('分辨率: $resolution');
    print('时长: $duration秒');
    print('');

    try {
      print('开始生成视频...');
      final outputFile = await KlingService.generateVideo(
        inputFiles: [imageFile],
        prompt: prompt,
        resolution: resolution,
        duration: duration,
        fps: 24,
      );

      print('✅ 视频生成成功!');
      print('输出文件: ${outputFile.path}');
      final fileSize = await outputFile.length();
      print('文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('文件是否存在: ${await outputFile.exists()}');
    } catch (e) {
      print('❌ 视频生成失败: $e');
      print('');
      print('可能的原因:');
      print('1. API密钥无效');
      print('2. 网络连接问题');
      print('3. API端点不正确');
      print('4. 图片格式不支持');
      print('5. API参数不正确');
    }
    print('');
  }

  /// 运行完整测试套件
  static Future<void> runFullTest({String? testImagePath}) async {
    print('═══════════════════════════════════════');
    print('   可灵AI API 完整测试套件');
    print('═══════════════════════════════════════');
    print('');

    // 测试1: 连接测试
    await testConnection();

    // 测试2: 视频生成测试（如果提供了测试图片）
    if (testImagePath != null) {
      await testVideoGeneration(imagePath: testImagePath);
    } else {
      print('⚠️  跳过视频生成测试（未提供测试图片路径）');
      print('   使用方法: KlingTestHelper.runFullTest(testImagePath: "path/to/image.jpg")');
      print('');
    }

    print('═══════════════════════════════════════');
    print('   测试完成');
    print('═══════════════════════════════════════');
  }
}

