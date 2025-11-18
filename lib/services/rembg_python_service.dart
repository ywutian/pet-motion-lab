import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

/// Rembg Python 服务包装器
/// 调用 Python rembg 库进行背景移除
class RembgPythonService {
  /// 可用的模型列表（对应 rembg 支持的模型）
  static const List<String> availableModels = [
    'u2net',              // 通用模型
    'u2netp',             // 轻量级模型
    'u2net_human_seg',     // 人像分割
    'silueta',             // 高精度模型
    'isnet-general-use',   // IS-Net 通用
    'isnet-anime',         // IS-Net 动漫
    'birefnet-general',    // BiRefNet 通用
    'birefnet-general-lite', // BiRefNet 轻量
    'birefnet-portrait',   // BiRefNet 人像
    'birefnet-dis',        // BiRefNet DIS
  ];

  /// Python 脚本路径
  static String get _pythonScriptPath {
    final scriptDir = Directory.current.path;
    return path.join(scriptDir, 'scripts', 'rembg_service.py');
  }

  /// 检查 Python 和 rembg 是否可用
  static Future<bool> checkAvailability() async {
    try {
      final result = await Process.run(
        'python3',
        ['-c', 'import rembg; print("OK")'],
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 移除背景
  /// 
  /// [inputFile] 输入图片文件
  /// [outputPath] 输出图片路径（可选，默认在临时目录）
  /// [model] 模型名称，默认为 'u2net'
  /// 
  /// 返回处理后的文件路径
  static Future<File> removeBackground(
    File inputFile, {
    String? outputPath,
    String model = 'u2net',
  }) async {
    // 验证模型
    if (!availableModels.contains(model)) {
      throw ArgumentError('不支持的模型: $model. 可用模型: ${availableModels.join(", ")}');
    }

    // 检查输入文件
    if (!await inputFile.exists()) {
      throw FileSystemException('输入文件不存在', inputFile.path);
    }

    // 生成输出路径
    final outputFile = outputPath != null
        ? File(outputPath)
        : File(path.join(
            Directory.systemTemp.path,
            'rembg_${model}_${DateTime.now().millisecondsSinceEpoch}.png',
          ));

    // 确保输出目录存在
    await outputFile.parent.create(recursive: true);

    // 调用 Python 脚本
    final scriptFile = File(_pythonScriptPath);
    if (!await scriptFile.exists()) {
      throw FileSystemException(
        'Python 脚本不存在',
        _pythonScriptPath,
      );
    }

    final result = await Process.run(
      'python3',
      [
        scriptFile.path,
        inputFile.path,
        outputFile.path,
        model,
      ],
    );

    if (result.exitCode != 0) {
      throw Exception('Python 脚本执行失败: ${result.stderr}');
    }

    // 解析 JSON 输出
    try {
      final output = result.stdout.toString().trim();
      final jsonResult = jsonDecode(output) as Map<String, dynamic>;

      if (jsonResult['success'] != true) {
        throw Exception('背景移除失败: ${jsonResult['error']}');
      }

      // 验证输出文件
      if (!await outputFile.exists()) {
        throw FileSystemException('输出文件未创建', outputFile.path);
      }

      return outputFile;
    } catch (e) {
      if (e is FormatException) {
        throw Exception('无法解析 Python 脚本输出: ${result.stdout}');
      }
      rethrow;
    }
  }

  /// 批量处理图片
  static Future<List<File>> removeBackgroundBatch(
    List<File> inputFiles, {
    String? outputDir,
    String model = 'u2net',
    void Function(int current, int total, String fileName)? onProgress,
  }) async {
    final results = <File>[];
    final outputDirectory = outputDir != null
        ? Directory(outputDir)
        : Directory(path.join(Directory.systemTemp.path, 'rembg_batch'));

    await outputDirectory.create(recursive: true);

    for (int i = 0; i < inputFiles.length; i++) {
      final inputFile = inputFiles[i];
      onProgress?.call(i + 1, inputFiles.length, path.basename(inputFile.path));

      try {
        final outputFile = File(path.join(
          outputDirectory.path,
          '${path.basenameWithoutExtension(inputFile.path)}_${model}.png',
        ));

        final result = await removeBackground(
          inputFile,
          outputPath: outputFile.path,
          model: model,
        );

        results.add(result);
      } catch (e) {
        // 记录错误但继续处理其他文件
        print('处理 ${inputFile.path} 时出错: $e');
      }
    }

    return results;
  }
}


