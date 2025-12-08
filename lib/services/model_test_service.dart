import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';

/// 模型测试服务 - 用于测试可灵AI各种模型的可用性和首尾帧支持
class ModelTestService {
  static String get baseUrl => ApiConfig.baseUrl;

  /// 获取所有可用的模型列表
  static Future<Map<String, dynamic>?> getAvailableModels() async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/model-test/models');
      print('📋 获取模型列表: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 获取模型列表成功');
        return data;
      } else {
        print('❌ 获取模型列表失败: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 获取模型列表错误: $e');
      return null;
    }
  }

  /// 测试视频模型
  /// 
  /// [imageFile] 测试图片 (XFile对象，支持Web和原生平台)
  /// [modelName] 模型名称
  /// [mode] 生成模式
  /// [testTailImage] 是否测试首尾帧功能
  /// [tailImageFile] 尾帧图片 (可选)
  static Future<Map<String, dynamic>?> testVideoModel({
    required XFile imageFile,
    required String modelName,
    required String mode,
    bool testTailImage = true,
    XFile? tailImageFile,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/model-test/test-video-model');
      print('🧪 测试视频模型: $modelName ($mode)');

      final request = http.MultipartRequest('POST', uri);
      
      // 添加表单字段
      request.fields['model_name'] = modelName;
      request.fields['mode'] = mode;
      request.fields['test_tail_image'] = testTailImage.toString();

      // 添加首帧图片 - 跨平台支持
      final imageBytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: imageFile.name,
      ));
      print('📎 首帧图片: ${imageFile.name} (${imageBytes.length} bytes)');

      // 添加尾帧图片（如果有）
      if (tailImageFile != null) {
        final tailBytes = await tailImageFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'tail_file',
          tailBytes,
          filename: tailImageFile.name,
        ));
        print('📎 尾帧图片: ${tailImageFile.name} (${tailBytes.length} bytes)');
      }

      print('📤 发送测试请求...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 收到响应: ${response.statusCode}');

      final data = json.decode(responseBody);
      
      if (response.statusCode == 200) {
        print('✅ 测试请求成功: $data');
        return data;
      } else {
        print('❌ 测试请求失败: $data');
        return data;
      }
    } catch (e) {
      print('❌ 测试错误: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 测试图片模型
  static Future<Map<String, dynamic>?> testImageModel({
    required XFile imageFile,
    required String modelName,
    String prompt = 'A cute pet in cartoon style',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/model-test/test-image-model');
      print('🧪 测试图片模型: $modelName');

      final request = http.MultipartRequest('POST', uri);
      
      request.fields['model_name'] = modelName;
      request.fields['prompt'] = prompt;

      // 跨平台支持 - 使用bytes
      final imageBytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: imageFile.name,
      ));
      print('📎 图片: ${imageFile.name} (${imageBytes.length} bytes)');

      print('📤 发送测试请求...');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 收到响应: ${response.statusCode}');

      final data = json.decode(responseBody);
      
      if (response.statusCode == 200) {
        print('✅ 测试成功: $data');
        return data;
      } else {
        print('❌ 测试失败: $data');
        return data;
      }
    } catch (e) {
      print('❌ 测试错误: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 查询任务状态
  static Future<Map<String, dynamic>?> getTaskStatus(String taskId, {String taskType = 'video'}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/model-test/task-status/$taskId?task_type=$taskType');
      print('🔍 查询任务状态: $taskId');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 任务状态: ${data['status']}');
        return data;
      } else {
        print('❌ 查询失败: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 查询错误: $e');
      return null;
    }
  }
}
