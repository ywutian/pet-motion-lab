import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'kling_service.dart';

class GenerationService {
  static Future<GenerationResult> generateStatic({
    required File inputFile,
    required String model,
    required String prompt,
    required String resolution,
    String? apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      File outputFile;
      
      if (model.contains('Leonardo')) {
        outputFile = await _generateWithLeonardo(
          inputFile, prompt, resolution, apiKey ?? '',
        );
      } else if (model.contains('Runware')) {
        outputFile = await _generateWithRunware(
          inputFile, prompt, resolution, apiKey ?? '',
        );
      } else {
        outputFile = await _generateMock(inputFile, 'static');
      }
      
      stopwatch.stop();
      
      return GenerationResult(
        outputFile: outputFile,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      return GenerationResult(
        outputFile: inputFile,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: false,
        error: e.toString(),
      );
    }
  }

  static Future<GenerationResult> generateMotion({
    required List<File> inputFiles,
    required String model,
    required String prompt,
    required String resolution,
    required int duration,
    required int fps,
    String? apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      File outputFile;
      
      if (model.contains('Kling')) {
        outputFile = await _generateWithKling(
          inputFiles, prompt, resolution, duration, fps, apiKey ?? '',
        );
      } else if (model.contains('Runware')) {
        outputFile = await _generateVideoWithRunware(
          inputFiles, prompt, resolution, duration, fps, apiKey ?? '',
        );
      } else if (model.contains('AnimateDiff')) {
        outputFile = await _generateWithAnimateDiff(
          inputFiles, prompt, resolution, duration, fps, apiKey ?? '',
        );
      } else {
        outputFile = await _generateMock(inputFiles.first, 'video');
      }
      
      stopwatch.stop();
      
      return GenerationResult(
        outputFile: outputFile,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      return GenerationResult(
        outputFile: inputFiles.first,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: false,
        error: e.toString(),
      );
    }
  }

  static Future<File> _generateMock(File inputFile, String type) async {
    await Future.delayed(const Duration(seconds: 2));
    
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = type == 'video' ? 'mp4' : 'png';
    final outputPath = path.join(tempDir.path, 'gen_$timestamp.$ext');
    
    await inputFile.copy(outputPath);
    return File(outputPath);
  }

  static Future<File> _generateWithLeonardo(
    File input, String prompt, String resolution, String apiKey,
  ) async {
    final dio = Dio();
    
    final formData = FormData.fromMap({
      'prompt': prompt,
      'init_image': await MultipartFile.fromFile(input.path),
      'width': int.parse(resolution.split('x').first),
      'height': int.parse(resolution.split('x').last),
    });
    
    await dio.post(
      'https://cloud.leonardo.ai/api/rest/v1/generations',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer $apiKey'},
      ),
    );
    
    return _generateMock(input, 'static');
  }

  static Future<File> _generateWithRunware(
    File input, String prompt, String resolution, String apiKey,
  ) async {
    return _generateMock(input, 'static');
  }

  static Future<File> _generateWithKling(
    List<File> inputs, String prompt, String resolution, 
    int duration, int fps, String apiKey,
  ) async {
    return await KlingService.generateVideo(
      inputFiles: inputs,
      prompt: prompt,
      resolution: resolution,
      duration: duration,
      fps: fps,
    );
  }

  static Future<File> _generateVideoWithRunware(
    List<File> inputs, String prompt, String resolution,
    int duration, int fps, String apiKey,
  ) async {
    return _generateMock(inputs.first, 'video');
  }

  static Future<File> _generateWithAnimateDiff(
    List<File> inputs, String prompt, String resolution,
    int duration, int fps, String apiKey,
  ) async {
    return _generateMock(inputs.first, 'video');
  }
}

class GenerationResult {
  final File outputFile;
  final int latencyMs;
  final bool success;
  final String? error;

  GenerationResult({
    required this.outputFile,
    required this.latencyMs,
    required this.success,
    this.error,
  });
}

