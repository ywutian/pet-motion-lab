import 'package:flutter_test/flutter_test.dart';
import 'package:pet_motion_lab/services/rembg_service_v2.dart';
import 'package:pet_motion_lab/models/rembg_model.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

void main() {
  
  group('真实裁剪模型测试', () {
    test('测试所有12个模型在8张图片上的表现', () async {
      print('\n🚀 开始真实裁剪模型测试...\n');
      print('=' * 80);
      
      // 测试图片列表
      final testImages = [
        'assets/images/橘猫正面坐.JPG',
        'assets/images/柯基正面坐.JPG',
        'assets/images/金毛正面.JPG',
        'assets/images/萨摩耶正面.JPG',
        'assets/images/比熊侧面.JPG',
        'assets/images/橘猫左侧行走.JPG',
        'assets/images/大金毛正面跑.JPG',
        'assets/images/比熊俯视.JPG',
      ];
      
      // 所有模型类型
      final models = RembgModelType.values;
      
      // 创建输出目录
      final outputDir = Directory('test_results');
      if (await outputDir.exists()) {
        await outputDir.delete(recursive: true);
      }
      await outputDir.create();
      
      final imagesDir = Directory('test_results/images');
      await imagesDir.create();
      
      // 存储测试结果
      final results = <Map<String, dynamic>>[];
      
      int totalTests = testImages.length * models.length;
      int currentTest = 0;
      int successCount = 0;
      int failCount = 0;
      
      print('\n📊 测试配置:');
      print('   图片数量: ${testImages.length}');
      print('   模型数量: ${models.length}');
      print('   总测试数: $totalTests');
      print('=' * 80);
      print('');
      
      // 遍历每张测试图片
      for (int imgIdx = 0; imgIdx < testImages.length; imgIdx++) {
        final imagePath = testImages[imgIdx];
        final imageName = path.basenameWithoutExtension(imagePath);
        
        print('\n📷 测试图片 ${imgIdx + 1}/${testImages.length}: $imageName');
        print('-' * 80);
        
        final inputFile = File(imagePath);
        if (!await inputFile.exists()) {
          print('   ❌ 文件不存在，跳过');
          continue;
        }
        
        // 获取原始图片信息
        final inputBytes = await inputFile.readAsBytes();
        final inputImage = img.decodeImage(inputBytes);
        final inputSize = inputBytes.length / 1024; // KB
        
        if (inputImage == null) {
          print('   ❌ 无法解码图片，跳过');
          continue;
        }
        
        print('   原始尺寸: ${inputImage.width}x${inputImage.height}');
        print('   原始大小: ${inputSize.toStringAsFixed(1)} KB');
        print('');
        
        // 遍历每个模型
        for (int modelIdx = 0; modelIdx < models.length; modelIdx++) {
          final model = models[modelIdx];
          currentTest++;
          
          stdout.write('   🔧 [${currentTest.toString().padLeft(2)}/$totalTests] ${model.displayName.padRight(30)} ');
          
          try {
            // 记录开始时间
            final stopwatch = Stopwatch()..start();
            
            // 使用真实的裁剪模型，指定输出目录为系统临时目录（避免path_provider问题）
            final outputFile = await RembgServiceV2.removeBackground(
              inputFile,
              modelType: model,
              outputDirectory: Directory.systemTemp,
            );
            
            stopwatch.stop();
            final processingTime = stopwatch.elapsedMilliseconds;
            
            // 分析输出文件
            final outputBytes = await outputFile.readAsBytes();
            final outputImage = img.decodeImage(outputBytes);
            final outputSize = outputBytes.length / 1024; // KB
            
            if (outputImage == null) {
              throw Exception('无法解码输出图片');
            }
            
            // 计算透明度比例
            int transparentPixels = 0;
            int totalPixels = outputImage.width * outputImage.height;
            
            for (int y = 0; y < outputImage.height; y++) {
              for (int x = 0; x < outputImage.width; x++) {
                final pixel = outputImage.getPixel(x, y);
                if (pixel.a < 128) {
                  transparentPixels++;
                }
              }
            }
            
            final transparencyRatio = (transparentPixels / totalPixels) * 100;
            
            // 复制输出文件到结果目录
            final resultFileName = '${imageName}_${model.name}.png';
            final resultPath = 'test_results/images/$resultFileName';
            await outputFile.copy(resultPath);
            
            successCount++;
            
            // 记录结果
            final result = {
              'image_name': imageName,
              'model_name': model.name,
              'model_display_name': model.displayName,
              'success': true,
              'processing_time_ms': processingTime,
              'processing_time_s': processingTime / 1000,
              'estimated_time_s': model.estimatedProcessingTime,
              'input_size_kb': inputSize,
              'output_size_kb': outputSize,
              'output_width': outputImage.width,
              'output_height': outputImage.height,
              'transparency_ratio': transparencyRatio,
              'output_file': resultFileName,
            };
            results.add(result);
            
            // 打印简要结果
            print('✅ ${processingTime}ms (${transparencyRatio.toStringAsFixed(1)}% 透明)');
            
          } catch (e) {
            failCount++;
            print('❌ 失败: $e');
            results.add({
              'image_name': imageName,
              'model_name': model.name,
              'model_display_name': model.displayName,
              'success': false,
              'error': e.toString(),
            });
          }
        }
      }
      
      print('\n' + '=' * 80);
      print('📊 生成测试报告...\n');
      
      // 生成统计数据
      final modelStats = <String, Map<String, dynamic>>{};
      
      for (final model in models) {
        final modelResults = results
            .where((r) => r['model_name'] == model.name && r['success'] == true)
            .toList();
        
        if (modelResults.isEmpty) continue;
        
        final times = modelResults.map((r) => r['processing_time_ms'] as int).toList();
        final transparencies = modelResults.map((r) => r['transparency_ratio'] as double).toList();
        final outputSizes = modelResults.map((r) => r['output_size_kb'] as double).toList();
        
        times.sort();
        transparencies.sort();
        outputSizes.sort();
        
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        final minTime = times.first;
        final maxTime = times.last;
        final avgTransparency = transparencies.reduce((a, b) => a + b) / transparencies.length;
        final avgOutputSize = outputSizes.reduce((a, b) => a + b) / outputSizes.length;
        
        modelStats[model.name] = {
          'display_name': model.displayName,
          'total_tests': modelResults.length,
          'success_rate': (modelResults.length / testImages.length) * 100,
          'avg_time_ms': avgTime.toInt(),
          'min_time_ms': minTime,
          'max_time_ms': maxTime,
          'estimated_time_ms': (model.estimatedProcessingTime * 1000).toInt(),
          'avg_transparency': avgTransparency,
          'avg_output_size_kb': avgOutputSize,
        };
      }
      
      final summary = {
        'total_tests': totalTests,
        'successful_tests': successCount,
        'failed_tests': failCount,
        'test_date': DateTime.now().toIso8601String(),
      };
      
      // 保存JSON数据
      final jsonOutput = {
        'summary': summary,
        'model_stats': modelStats,
        'detailed_results': results,
      };
      
      final jsonFile = File('test_results/results.json');
      await jsonFile.writeAsString(JsonEncoder.withIndent('  ').convert(jsonOutput));
      
      print('✅ JSON数据已保存: test_results/results.json\n');
      
      // 生成HTML报告
      await _generateHtmlReport(summary, results, modelStats, testImages);
      
      print('✅ HTML报告已生成: test_results/report.html\n');
      
      // 打印控制台摘要
      _printSummary(modelStats, summary);
      
      print('\n' + '=' * 80);
      print('🎉 测试完成！');
      print('   成功: $successCount / $totalTests');
      print('   失败: $failCount / $totalTests');
      print('=' * 80);
      
      // 验证至少有一些成功的测试
      expect(successCount, greaterThan(0), reason: '应该有至少一次成功的测试');
    }, timeout: Timeout(Duration(minutes: 10)));
  });
}

/// 生成HTML报告
Future<void> _generateHtmlReport(
  Map<String, dynamic> summary,
  List<Map<String, dynamic>> results,
  Map<String, Map<String, dynamic>> modelStats,
  List<String> testImages,
) async {
  final sortedModels = modelStats.entries.toList()
    ..sort((a, b) => (a.value['avg_time_ms'] as int).compareTo(b.value['avg_time_ms'] as int));
  
  final modelRankingRows = sortedModels.asMap().entries.map((entry) {
    final i = entry.key;
    final modelEntry = entry.value;
    final stats = modelEntry.value;
    final rank = i + 1;
    final rankClass = rank <= 3 ? 'rank-$rank' : 'rank-other';
    
    final avgTime = stats['avg_time_ms'];
    final estimatedTime = stats['estimated_time_ms'];
    final accuracy = ((avgTime / estimatedTime) * 100).clamp(0, 200);
    final accuracyLabel = accuracy < 120 ? '优秀' : (accuracy < 150 ? '良好' : '一般');
    
    var badges = '';
    if (avgTime < 1500) badges += '<span class="badge badge-fast">⚡ 极速</span>';
    if (stats['avg_transparency'] > 30) badges += '<span class="badge badge-accurate">🎯 精准</span>';
    if (rank <= 3) badges += '<span class="badge badge-recommended">⭐ 推荐</span>';
    
    return '''
          <tr>
            <td><span class="$rankClass rank">$rank</span></td>
            <td><strong>${stats['display_name']}</strong>$badges</td>
            <td>${avgTime}ms</td>
            <td>${estimatedTime}ms</td>
            <td>$accuracyLabel</td>
            <td>${stats['avg_transparency'].toStringAsFixed(1)}%</td>
            <td>${stats['avg_output_size_kb'].toStringAsFixed(1)} KB</td>
            <td>${stats['success_rate'].toStringAsFixed(0)}%</td>
          </tr>
    ''';
  }).join('\n');
  
  final fastest = sortedModels.first.value;
  
  final sortedByTransparency = modelStats.entries.toList()
    ..sort((a, b) => (b.value['avg_transparency'] as double).compareTo(a.value['avg_transparency'] as double));
  final mostAccurate = sortedByTransparency.first.value;
  
  final balanced = sortedModels[sortedModels.length ~/ 2].value;
  
  // 生成图片画廊
  final imageGroups = <String, List<Map<String, dynamic>>>{};
  for (final result in results) {
    if (result['success'] == true) {
      final imageName = result['image_name'];
      imageGroups.putIfAbsent(imageName, () => []).add(result);
    }
  }
  
  final imageGalleryHtml = imageGroups.entries.map((entry) {
    final imageName = entry.key;
    final group = entry.value;
    
    final imageItems = group.map((result) {
      final time = result['processing_time_ms'];
      final transparency = result['transparency_ratio'].toStringAsFixed(1);
      final size = result['output_size_kb'].toStringAsFixed(1);
      
      return '''
        <div class="image-item">
          <img src="images/${result['output_file']}" alt="${result['model_display_name']}">
          <div class="image-info">
            <h3>${result['model_display_name']}</h3>
            <p>⏱️ 耗时: ${time}ms</p>
            <p>🎯 透明度: $transparency%</p>
            <p>📦 大小: $size KB</p>
          </div>
        </div>
      ''';
    }).join('\n');
    
    return '''
      <h3 style="margin-top: 30px; color: #667eea;">📷 $imageName</h3>
      <div class="image-grid">
        $imageItems
      </div>
    ''';
  }).join('\n');
  
  final html = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>裁剪模型测试报告 - 真实模型</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: #333;
      padding: 20px;
      line-height: 1.6;
    }
    .container {
      max-width: 1400px;
      margin: 0 auto;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      overflow: hidden;
    }
    header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 40px;
      text-align: center;
    }
    h1 { font-size: 2.5em; margin-bottom: 10px; }
    .subtitle { font-size: 1.2em; opacity: 0.9; }
    .summary {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      padding: 30px;
      background: #f8f9fa;
      border-bottom: 2px solid #e9ecef;
    }
    .summary-card {
      background: white;
      padding: 20px;
      border-radius: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      text-align: center;
    }
    .summary-card .number {
      font-size: 2.5em;
      font-weight: bold;
      color: #667eea;
      margin-bottom: 5px;
    }
    .summary-card .label {
      color: #666;
      font-size: 0.9em;
    }
    .content { padding: 40px; }
    h2 {
      font-size: 1.8em;
      margin: 30px 0 20px;
      color: #333;
      border-left: 4px solid #667eea;
      padding-left: 15px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 20px 0;
      background: white;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      border-radius: 8px;
      overflow: hidden;
    }
    th, td {
      padding: 15px;
      text-align: left;
      border-bottom: 1px solid #e9ecef;
    }
    th {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      font-weight: 600;
      text-transform: uppercase;
      font-size: 0.85em;
      letter-spacing: 0.5px;
    }
    tr:hover { background: #f8f9fa; }
    tr:last-child td { border-bottom: none; }
    .rank {
      display: inline-block;
      width: 30px;
      height: 30px;
      line-height: 30px;
      border-radius: 50%;
      text-align: center;
      font-weight: bold;
      color: white;
      font-size: 0.9em;
    }
    .rank-1 { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
    .rank-2 { background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); }
    .rank-3 { background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); }
    .rank-other { background: #95a5a6; }
    .badge {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 12px;
      font-size: 0.85em;
      font-weight: 600;
      margin-left: 8px;
    }
    .badge-fast { background: #d4edda; color: #155724; }
    .badge-accurate { background: #cce5ff; color: #004085; }
    .badge-recommended { background: #fff3cd; color: #856404; }
    .image-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 20px;
      margin: 20px 0;
    }
    .image-item {
      background: white;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      transition: transform 0.2s;
    }
    .image-item:hover {
      transform: translateY(-5px);
      box-shadow: 0 4px 16px rgba(0,0,0,0.2);
    }
    .image-item img {
      width: 100%;
      height: 200px;
      object-fit: cover;
      background: repeating-conic-gradient(#eee 0% 25%, white 0% 50%) 50% / 20px 20px;
    }
    .image-info {
      padding: 15px;
    }
    .image-info h3 {
      font-size: 1em;
      margin-bottom: 10px;
      color: #333;
    }
    .image-info p {
      font-size: 0.85em;
      color: #666;
      margin: 3px 0;
    }
    .model-comparison {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin: 20px 0;
    }
    .model-card {
      background: white;
      border-radius: 12px;
      padding: 20px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      border-top: 4px solid #667eea;
    }
    .model-card h3 {
      color: #667eea;
      margin-bottom: 15px;
      font-size: 1.2em;
    }
    .metric {
      display: flex;
      justify-content: space-between;
      padding: 8px 0;
      border-bottom: 1px dashed #e9ecef;
    }
    .metric:last-child { border-bottom: none; }
    .metric-label { color: #666; font-size: 0.9em; }
    .metric-value { font-weight: 600; color: #333; }
    footer {
      background: #2c3e50;
      color: white;
      text-align: center;
      padding: 20px;
      font-size: 0.9em;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>🎨 裁剪模型测试报告</h1>
      <p class="subtitle">12个真实模型 × 8张图片 = ${summary['total_tests']}次测试</p>
      <p class="subtitle" style="margin-top: 10px; font-size: 0.9em;">生成时间: ${DateTime.now().toString().split('.')[0]}</p>
      <p class="subtitle" style="margin-top: 5px; font-size: 0.85em; opacity: 0.8;">✅ 使用真实裁剪算法</p>
    </header>
    
    <div class="summary">
      <div class="summary-card">
        <div class="number">${summary['total_tests']}</div>
        <div class="label">总测试数</div>
      </div>
      <div class="summary-card">
        <div class="number">${summary['successful_tests']}</div>
        <div class="label">成功测试</div>
      </div>
      <div class="summary-card">
        <div class="number">${summary['failed_tests']}</div>
        <div class="label">失败测试</div>
      </div>
      <div class="summary-card">
        <div class="number">${((summary['successful_tests'] / summary['total_tests']) * 100).toStringAsFixed(1)}%</div>
        <div class="label">成功率</div>
      </div>
    </div>
    
    <div class="content">
      <h2>📊 模型性能排名</h2>
      <table>
        <thead>
          <tr>
            <th>排名</th>
            <th>模型名称</th>
            <th>平均耗时</th>
            <th>预估耗时</th>
            <th>准确度</th>
            <th>平均透明度</th>
            <th>输出大小</th>
            <th>成功率</th>
          </tr>
        </thead>
        <tbody>
$modelRankingRows
        </tbody>
      </table>
      
      <h2>🏆 推荐模型</h2>
      <div class="model-comparison">
        <div class="model-card">
          <h3>⚡ 速度之王</h3>
          <div class="metric">
            <span class="metric-label">模型</span>
            <span class="metric-value">${fastest['display_name']}</span>
          </div>
          <div class="metric">
            <span class="metric-label">平均耗时</span>
            <span class="metric-value">${fastest['avg_time_ms']}ms</span>
          </div>
          <div class="metric">
            <span class="metric-label">适用场景</span>
            <span class="metric-value">批量处理</span>
          </div>
        </div>
        
        <div class="model-card">
          <h3>🎯 精度之星</h3>
          <div class="metric">
            <span class="metric-label">模型</span>
            <span class="metric-value">${mostAccurate['display_name']}</span>
          </div>
          <div class="metric">
            <span class="metric-label">透明度</span>
            <span class="metric-value">${mostAccurate['avg_transparency'].toStringAsFixed(1)}%</span>
          </div>
          <div class="metric">
            <span class="metric-label">适用场景</span>
            <span class="metric-value">专业摄影</span>
          </div>
        </div>
        
        <div class="model-card">
          <h3>⚖️ 平衡之选</h3>
          <div class="metric">
            <span class="metric-label">模型</span>
            <span class="metric-value">${balanced['display_name']}</span>
          </div>
          <div class="metric">
            <span class="metric-label">平均耗时</span>
            <span class="metric-value">${balanced['avg_time_ms']}ms</span>
          </div>
          <div class="metric">
            <span class="metric-label">适用场景</span>
            <span class="metric-value">日常使用</span>
          </div>
        </div>
      </div>
      
      <h2>🖼️ 测试结果展示</h2>
$imageGalleryHtml
      
    </div>
    
    <footer>
      <p>Pet Motion Lab - 裁剪模型测试系统</p>
      <p>© 2024 All Rights Reserved</p>
    </footer>
  </div>
</body>
</html>
''';
  
  final htmlFile = File('test_results/report.html');
  await htmlFile.writeAsString(html);
}

/// 打印控制台摘要
void _printSummary(Map<String, Map<String, dynamic>> modelStats, Map<String, dynamic> summary) {
  print('\n📊 测试摘要');
  print('=' * 80);
  
  // 速度排名
  final sortedBySpeed = modelStats.entries.toList()
    ..sort((a, b) => (a.value['avg_time_ms'] as int).compareTo(b.value['avg_time_ms'] as int));
  
  print('\n⚡ 速度排名 (TOP 5):');
  print('-' * 80);
  for (int i = 0; i < 5 && i < sortedBySpeed.length; i++) {
    final entry = sortedBySpeed[i];
    final stats = entry.value;
    final medal = i == 0 ? '🥇' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : '  '));
    print('$medal ${(i + 1).toString().padLeft(2)}. ${stats['display_name'].toString().padRight(30)} ${stats['avg_time_ms'].toString().padLeft(5)}ms');
  }
  
  // 精度排名
  final sortedByTransparency = modelStats.entries.toList()
    ..sort((a, b) => (b.value['avg_transparency'] as double).compareTo(a.value['avg_transparency'] as double));
  
  print('\n🎯 精度排名 (TOP 5):');
  print('-' * 80);
  for (int i = 0; i < 5 && i < sortedByTransparency.length; i++) {
    final entry = sortedByTransparency[i];
    final stats = entry.value;
    final medal = i == 0 ? '🥇' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : '  '));
    print('$medal ${(i + 1).toString().padLeft(2)}. ${stats['display_name'].toString().padRight(30)} ${stats['avg_transparency'].toStringAsFixed(1).padLeft(6)}%');
  }
  
  print('\n💡 推荐建议:');
  print('-' * 80);
  print('   🏃 追求速度: ${sortedBySpeed.first.value['display_name']}');
  print('   🎨 追求精度: ${sortedByTransparency.first.value['display_name']}');
  print('   ⚖️  平衡选择: ${sortedBySpeed[sortedBySpeed.length ~/ 2].value['display_name']}');
}

