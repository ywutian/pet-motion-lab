import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class KlingGenerationService {
  // 使用统一的 API 配置
  static String get baseUrl => ApiConfig.baseUrl;

  /// 开始生成任务
  Future<String> startGeneration({
    required File imageFile,
    required String breed,
    required String color,
    required String species,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/kling/generate');
      print('🌐 正在连接: $uri');

      final request = http.MultipartRequest('POST', uri);
      request.fields['breed'] = breed;
      request.fields['color'] = color;
      request.fields['species'] = species;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      print('📤 发送请求...');
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
}

