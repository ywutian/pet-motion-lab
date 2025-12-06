import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/cross_platform_file.dart';
import '../providers/settings_provider.dart';

/// 生成配置（从 SettingsProvider 获取）
/// 仅支持首尾帧的模型: kling-v2-5-turbo / kling-v2-1 / kling-v2-1-master
class GenerationConfig {
  final String videoModel;
  final String videoMode;
  final int videoDuration;
  final String imageRemovalMethod;
  final String imageRembgModel;
  final bool gifRemovalEnabled;
  final String gifRemovalMethod;
  final String gifRembgModel;

  const GenerationConfig({
    this.videoModel = 'kling-v2-5-turbo',  // 默认使用性价比最高的模型
    this.videoMode = 'pro',                 // PRO 模式支持首尾帧
    this.videoDuration = 5,
    this.imageRemovalMethod = 'removebg',
    this.imageRembgModel = 'u2net',
    this.gifRemovalEnabled = false,
    this.gifRemovalMethod = 'rembg',
    this.gifRembgModel = 'u2net',
  });

  /// 从 SettingsProvider 创建配置
  factory GenerationConfig.fromSettings(SettingsProvider settings) {
    return GenerationConfig(
      videoModel: settings.videoModel,
      videoMode: settings.videoMode,
      videoDuration: settings.videoDuration,
      imageRemovalMethod: settings.imageRemovalMethod == BackgroundRemovalMethod.rembg 
          ? 'rembg' : 'removebg',
      imageRembgModel: settings.imageRembgModel,
      gifRemovalEnabled: settings.gifRemovalEnabled,
      gifRemovalMethod: settings.gifRemovalMethod == BackgroundRemovalMethod.rembg 
          ? 'rembg' : 'removebg',
      gifRembgModel: settings.gifRembgModel,
    );
  }
}

class KlingGenerationService {
  // 使用统一的 API 配置
  static String get baseUrl => ApiConfig.baseUrl;

  /// 开始生成任务（跨平台版本）
  Future<String> startGeneration({
    required CrossPlatformFile imageFile,
    required String breed,
    required String color,
    required String species,
    String? weight,
    String? birthday,
    GenerationConfig? config,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/generate');
      print('🌐 正在连接: $uri');

      final request = http.MultipartRequest('POST', uri);
      request.fields['breed'] = breed;
      request.fields['color'] = color;
      request.fields['species'] = species;
      if (weight != null && weight.isNotEmpty) {
        request.fields['weight'] = weight;
      }
      if (birthday != null && birthday.isNotEmpty) {
        request.fields['birthday'] = birthday;
      }

      // 添加生成配置
      final cfg = config ?? const GenerationConfig();
      request.fields['video_model'] = cfg.videoModel;
      request.fields['video_mode'] = cfg.videoMode;
      request.fields['video_duration'] = cfg.videoDuration.toString();
      request.fields['image_removal_method'] = cfg.imageRemovalMethod;
      request.fields['image_rembg_model'] = cfg.imageRembgModel;
      request.fields['gif_removal_enabled'] = cfg.gifRemovalEnabled.toString();
      request.fields['gif_removal_method'] = cfg.gifRemovalMethod;
      request.fields['gif_rembg_model'] = cfg.gifRembgModel;

      // 跨平台文件上传
      if (imageFile.bytes != null) {
        // Web或bytes模式
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          imageFile.bytes!,
          filename: imageFile.name,
        ));
      } else if (imageFile.path != null && !kIsWeb) {
        // 原生平台路径模式
        request.files.add(await http.MultipartFile.fromPath('file', imageFile.path!));
      } else {
        throw Exception('无效的文件数据');
      }

      print('📤 发送请求...');
      print('🎬 配置: 模型=${cfg.videoModel}, 模式=${cfg.videoMode}, 时长=${cfg.videoDuration}s');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 收到响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        print('✅ 生成任务已创建: ${data['pet_id']}');
        return data['pet_id'];
      } else {
        print('❌ 生成失败: $responseBody');
        throw Exception('生成失败: $responseBody');
      }
    } catch (e) {
      print('❌ 连接错误: $e');
      rethrow;
    }
  }

  /// 开始生成任务（使用bytes，Web兼容）
  Future<String> startGenerationWithBytes({
    required Uint8List imageBytes,
    required String fileName,
    required String breed,
    required String color,
    required String species,
    String? weight,
    String? birthday,
    GenerationConfig? config,
  }) async {
    return startGeneration(
      imageFile: CrossPlatformFile(
        name: fileName,
        bytes: imageBytes,
      ),
      breed: breed,
      color: color,
      species: species,
      weight: weight,
      birthday: birthday,
      config: config,
    );
  }

  /// 查询生成状态
  Future<Map<String, dynamic>> getStatus(String petId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/status/$petId');
      print('🔍 查询状态: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📊 状态: ${data['status']} - ${data['current_step']}');
        return data;
      } else {
        print('❌ 查询失败: ${response.body}');
        throw Exception('查询状态失败: ${response.body}');
      }
    } catch (e) {
      print('❌ 查询错误: $e');
      rethrow;
    }
  }

  /// 获取生成结果
  Future<Map<String, dynamic>> getResults(String petId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/results/$petId');
      print('📦 获取结果: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 结果获取成功');
        return data;
      } else {
        print('❌ 获取失败: ${response.body}');
        throw Exception('获取结果失败: ${response.body}');
      }
    } catch (e) {
      print('❌ 获取错误: $e');
      rethrow;
    }
  }

  /// 轮询状态（Stream）
  Stream<Map<String, dynamic>> pollStatus(String petId) async* {
    while (true) {
      final status = await getStatus(petId);
      yield status;

      if (status['status'] == 'completed' || status['status'] == 'failed') {
        break;
      }

      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// 删除任务
  Future<void> deleteTask(String petId) async {
    final uri = Uri.parse('$baseUrl/api/kling/task/$petId');
    await http.delete(uri);
  }

  /// 获取历史记录列表
  Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int pageSize = 10,
    String statusFilter = '',
  }) async {
    try {
      var queryParams = '?page=$page&page_size=$pageSize';
      if (statusFilter.isNotEmpty) {
        queryParams += '&status_filter=$statusFilter';
      }

      final uri = Uri.parse('$baseUrl/api/kling/history$queryParams');
      print('📜 获取历史记录: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 获取历史记录成功: ${data['total']}条');
        return data;
      } else {
        print('❌ 获取失败: ${response.body}');
        throw Exception('获取历史记录失败: ${response.body}');
      }
    } catch (e) {
      print('❌ 获取错误: $e');
      rethrow;
    }
  }

  /// 获取历史记录详情
  Future<Map<String, dynamic>> getHistoryDetail(String petId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/history/$petId');
      print('📋 获取详情: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 获取详情成功');
        return data;
      } else {
        print('❌ 获取失败: ${response.body}');
        throw Exception('获取详情失败: ${response.body}');
      }
    } catch (e) {
      print('❌ 获取错误: $e');
      rethrow;
    }
  }

  /// 删除历史记录
  Future<void> deleteHistory(String petId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/history/$petId');
      print('🗑️ 删除记录: $uri');

      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        print('✅ 删除成功');
      } else {
        print('❌ 删除失败: ${response.body}');
        throw Exception('删除失败: ${response.body}');
      }
    } catch (e) {
      print('❌ 删除错误: $e');
      rethrow;
    }
  }

  /// 获取所有下载链接
  Future<Map<String, dynamic>> getDownloadLinks(String petId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/download-all/$petId');
      print('🔗 获取下载链接: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 获取下载链接成功');
        return data;
      } else {
        print('❌ 获取失败: ${response.body}');
        throw Exception('获取下载链接失败: ${response.body}');
      }
    } catch (e) {
      print('❌ 获取错误: $e');
      rethrow;
    }
  }

  /// 获取文件下载URL
  String getDownloadUrl(String relativePath) {
    return '$baseUrl$relativePath';
  }

  /// 获取ZIP下载URL
  String getZipDownloadUrl(String petId, {String include = 'gifs'}) {
    return '$baseUrl/api/kling/download-zip/$petId?include=$include';
  }
}

