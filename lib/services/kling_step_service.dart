import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class KlingStepService {
  // 使用统一的 API 配置
  static String get baseUrl => ApiConfig.baseUrl;

  /// 初始化任务
  Future<Map<String, dynamic>> initTask(
    File imageFile,
    String breed,
    String color,
    String species,
  ) async {
    final uri = Uri.parse('$baseUrl/api/kling/init');
    final request = http.MultipartRequest('POST', uri);
    
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    request.fields['breed'] = breed;
    request.fields['color'] = color;
    request.fields['species'] = species;

    print('🌐 初始化任务: $uri');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      print('✅ 任务初始化成功');
      return json.decode(responseBody);
    } else {
      print('❌ 初始化失败: ${response.statusCode}');
      throw Exception('初始化失败: $responseBody');
    }
  }

  /// 执行步骤1: 去除背景
  Future<Map<String, dynamic>> executeStep1(String petId, {File? customFile}) async {
    return await _executeStep(petId, 1, customFile: customFile);
  }

  /// 执行步骤2: 生成基础图片
  Future<Map<String, dynamic>> executeStep2(String petId, {File? customFile}) async {
    return await _executeStep(petId, 2, customFile: customFile);
  }

  /// 执行步骤3: 生成初始视频（异步，需要轮询状态）
  Future<Map<String, dynamic>> executeStep3(String petId, {File? customFile}) async {
    // 启动步骤3
    final startResult = await _executeStep(petId, 3, customFile: customFile);

    // 如果返回processing状态，开始轮询
    if (startResult['status'] == 'processing') {
      print('🔄 步骤3已启动，开始轮询状态...');
      return await _pollStep3Status(petId);
    }

    return startResult;
  }

  /// 轮询步骤3的状态
  Future<Map<String, dynamic>> _pollStep3Status(String petId) async {
    final uri = Uri.parse('$baseUrl/api/kling/step3/status/$petId');
    int retryCount = 0;
    const maxRetries = 120; // 最多轮询120次（20分钟）
    const pollInterval = Duration(seconds: 10);

    while (retryCount < maxRetries) {
      await Future.delayed(pollInterval);
      retryCount++;

      try {
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final status = data['status'];

          print('🔄 步骤3状态查询 #$retryCount: $status - ${data['message']}');

          if (status == 'step3_completed') {
            print('✅ 步骤3完成');
            return data;
          } else if (status == 'failed') {
            throw Exception('步骤3失败: ${data['message']}');
          }
          // 继续轮询
        } else {
          print('⚠️ 状态查询失败: ${response.statusCode}');
        }
      } catch (e) {
        print('⚠️ 轮询错误: $e');
      }
    }

    throw Exception('步骤3超时（20分钟）');
  }

  /// 执行步骤4: 生成剩余视频
  Future<Map<String, dynamic>> executeStep4(String petId) async {
    return await _executeStep(petId, 4);
  }

  /// 执行步骤5: 生成循环视频
  Future<Map<String, dynamic>> executeStep5(String petId) async {
    return await _executeStep(petId, 5);
  }

  /// 执行步骤6: 转换为GIF
  Future<Map<String, dynamic>> executeStep6(String petId) async {
    return await _executeStep(petId, 6);
  }

  /// 通用步骤执行方法
  Future<Map<String, dynamic>> _executeStep(String petId, int step, {File? customFile}) async {
    final uri = Uri.parse('$baseUrl/api/kling/step$step/$petId');

    print('🌐 执行步骤$step: $uri');

    if (customFile != null) {
      // 上传自定义文件
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', customFile.path));

      print('📤 上传自定义文件: ${customFile.path}');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        print('✅ 步骤$step完成（使用自定义文件）');
        return json.decode(responseBody);
      } else {
        print('❌ 步骤$step失败: ${response.statusCode}');
        throw Exception('步骤$step失败: $responseBody');
      }
    } else {
      // 自动执行
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('✅ 步骤$step完成');
        return json.decode(response.body);
      } else {
        print('❌ 步骤$step失败: ${response.statusCode} - ${response.body}');
        throw Exception('步骤$step失败: ${response.body}');
      }
    }
  }

  /// 获取任务状态
  Future<Map<String, dynamic>> getStatus(String petId) async {
    final uri = Uri.parse('$baseUrl/api/kling/status/$petId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('获取状态失败: ${response.body}');
    }
  }

  /// 获取所有下载链接
  Future<Map<String, dynamic>> getAllDownloadLinks(String petId) async {
    final uri = Uri.parse('$baseUrl/api/kling/download-all/$petId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('获取下载链接失败: ${response.body}');
    }
  }

  /// 下载文件
  Future<File> downloadFile(String petId, String fileType, String filename, String savePath) async {
    final uri = Uri.parse('$baseUrl/api/kling/download/$petId/$fileType/$filename');
    
    print('📥 下载文件: $uri');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
      print('✅ 文件已保存: $savePath');
      return file;
    } else {
      print('❌ 下载失败: ${response.statusCode}');
      throw Exception('下载失败: ${response.body}');
    }
  }

  /// 从视频中提取首尾帧
  Future<Map<String, dynamic>> extractFramesFromVideo(
    File videoFile,
    String petId,
  ) async {
    final uri = Uri.parse('$baseUrl/api/kling/extract-frames');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('file', videoFile.path));
    request.fields['pet_id'] = petId;

    print('🌐 提取视频帧: $uri');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      print('✅ 帧提取成功');
      return json.decode(responseBody);
    } else {
      print('❌ 提取失败: ${response.statusCode}');
      throw Exception('提取失败: $responseBody');
    }
  }
}

