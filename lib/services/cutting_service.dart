import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'rembg_service.dart';
import 'rembg_service_v2.dart';
import '../models/rembg_model.dart';

class CuttingService {
  static const String clipdropApiUrl = 'https://clipdrop-api.co/remove-background/v1';
  
  static Future<CutResult> cutImage({
    required File inputFile,
    required String tool,
    String? apiKey,
    RembgModelType? modelType,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    File outputFile;
    
    try {
      if (tool == 'rembg_local') {
        outputFile = await _cutWithLocal(inputFile, modelType: modelType);
      } else if (tool == 'clipdrop') {
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('Clipdrop API Key未设置');
        }
        outputFile = await _cutWithClipdrop(inputFile, apiKey);
      } else {
        throw Exception('不支持的裁剪工具: $tool');
      }
      
      stopwatch.stop();
      
      return CutResult(
        outputFile: outputFile,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      return CutResult(
        outputFile: inputFile,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: false,
        error: e.toString(),
      );
    }
  }

  static Future<File> _cutWithLocal(
    File inputFile, {
    RembgModelType? modelType,
  }) async {
    // 如果指定了模型类型，使用 V2 服务
    if (modelType != null) {
      return await RembgServiceV2.removeBackground(
        inputFile,
        modelType: modelType,
      );
    }
    // 否则使用默认服务
    return await RembgService.removeBackground(inputFile);
  }

  static Future<File> _cutWithClipdrop(File inputFile, String apiKey) async {
    final dio = Dio();
    
    final formData = FormData.fromMap({
      'image_file': await MultipartFile.fromFile(inputFile.path),
    });
    
    final response = await dio.post(
      clipdropApiUrl,
      data: formData,
      options: Options(
        headers: {
          'x-api-key': apiKey,
        },
        responseType: ResponseType.bytes,
      ),
    );
    
    final tempDir = await getTemporaryDirectory();
    final outputPath = path.join(
      tempDir.path,
      'cut_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(response.data);
    
    return outputFile;
  }
}

class CutResult {
  final File outputFile;
  final int latencyMs;
  final bool success;
  final String? error;

  CutResult({
    required this.outputFile,
    required this.latencyMs,
    required this.success,
    this.error,
  });
}

