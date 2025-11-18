import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';

class ExportService {
  static Future<File> exportTask(Task task) async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory(path.join(tempDir.path, 'export_${task.taskId}'));
    
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create(recursive: true);

    final reportContent = _generateMarkdownReport(task);
    final reportFile = File(path.join(exportDir.path, 'report.md'));
    await reportFile.writeAsString(reportContent);

    final imagesDir = Directory(path.join(exportDir.path, 'images'));
    await imagesDir.create();
    
    for (var i = 0; i < task.images.length; i++) {
      final image = task.images[i];
      final sourceFile = File(image.fileIn);
      
      if (await sourceFile.exists()) {
        final targetPath = path.join(
          imagesDir.path,
          'input_${i + 1}_${image.pose}_${image.angle}${path.extension(sourceFile.path)}',
        );
        await sourceFile.copy(targetPath);
      }
    }

    final outputsDir = Directory(path.join(exportDir.path, 'outputs'));
    await outputsDir.create();
    
    for (var i = 0; i < task.outputs.statics.length; i++) {
      final outputPath = task.outputs.statics[i];
      final sourceFile = File(outputPath);
      
      if (await sourceFile.exists()) {
        final targetPath = path.join(
          outputsDir.path,
          'static_${i + 1}${path.extension(sourceFile.path)}',
        );
        await sourceFile.copy(targetPath);
      }
    }
    
    for (var i = 0; i < task.outputs.videos.length; i++) {
      final outputPath = task.outputs.videos[i];
      final sourceFile = File(outputPath);
      
      if (await sourceFile.exists()) {
        final targetPath = path.join(
          outputsDir.path,
          'video_${i + 1}${path.extension(sourceFile.path)}',
        );
        await sourceFile.copy(targetPath);
      }
    }

    final zipPath = path.join(
      tempDir.path,
      'report_${task.taskId}_${DateTime.now().millisecondsSinceEpoch}.zip',
    );
    
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addDirectory(exportDir);
    encoder.close();

    await exportDir.delete(recursive: true);

    return File(zipPath);
  }

  static String _generateMarkdownReport(Task task) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buffer = StringBuffer();

    buffer.writeln('# 🐾 Pet Motion Test Report\n');
    buffer.writeln('**Task ID:** ${task.taskId}');
    buffer.writeln('**Combination:** ${task.comboTemplate}');
    buffer.writeln('**Static Model:** ${task.generation.staticModel}');
    buffer.writeln('**Motion Model:** ${task.generation.motionModel}');
    buffer.writeln('**Cut Mode:** ${task.cutting.mode}');
    buffer.writeln('**Created:** ${dateFormat.format(task.createdAt)}');
    buffer.writeln('**Status:** ${task.status}\n');
    buffer.writeln('---\n');

    buffer.writeln('## 🧩 Upload Summary\n');
    buffer.writeln('| File | Species | Pose | Angle | PS(Original) | PS(Final) |');
    buffer.writeln('|------|---------|------|-------|--------------|-----------|');
    
    for (var image in task.images) {
      final originalPS = image.stages.first.purity.ps.toStringAsFixed(1);
      final finalPS = image.stages.last.purity.ps.toStringAsFixed(1);
      final fileName = path.basename(image.fileIn);
      
      buffer.writeln(
        '| $fileName | ${image.species ?? '-'} | ${image.pose} | ${image.angle} | $originalPS | $finalPS |',
      );
    }
    buffer.writeln();

    buffer.writeln('## 📝 Prompt Configuration\n');
    for (var i = 0; i < task.images.length; i++) {
      final image = task.images[i];
      buffer.writeln('### Image ${i + 1}: ${image.pose} - ${image.angle}\n');
      
      if (image.staticPrompt != null && image.staticPrompt!.isNotEmpty) {
        buffer.writeln('**Static Prompt:**');
        buffer.writeln('```');
        buffer.writeln(image.staticPrompt);
        buffer.writeln('```\n');
      }
      
      if (image.motionPrompt != null && image.motionPrompt!.isNotEmpty) {
        buffer.writeln('**Motion Prompt:**');
        buffer.writeln('```');
        buffer.writeln(image.motionPrompt);
        buffer.writeln('```\n');
      }
    }
    buffer.writeln();

    buffer.writeln('## ✂️ Cutting Analysis\n');
    
    final allCuttingStages = <Stage>[];
    for (var image in task.images) {
      allCuttingStages.addAll(image.stages.where((s) => s.cut != null));
    }
    
    if (allCuttingStages.isNotEmpty) {
      buffer.writeln('| Stage | Tool | Latency(ms) | ΔPS | Output |');
      buffer.writeln('|-------|------|-------------|-----|---------|');
      
      for (var stage in allCuttingStages) {
        final deltaPS = stage.deltaPs != null 
            ? '+${stage.deltaPs!.toStringAsFixed(1)}' 
            : '-';
        final outputName = path.basename(stage.cut!.fileOut);
        
        buffer.writeln(
          '| ${stage.stage} | ${stage.cut!.tool} | ${stage.cut!.latencyMs} | $deltaPS | $outputName |',
        );
      }
      buffer.writeln();
    } else {
      buffer.writeln('No cutting performed.\n');
    }

    buffer.writeln('## 🎨 Model Summary\n');
    buffer.writeln('| Type | Model | Resolution | Duration | FPS |');
    buffer.writeln('|------|--------|-------------|----------|-----|');
    buffer.writeln(
      '| Static | ${task.generation.staticModel} | ${task.generation.resolution} | - | - |',
    );
    if (task.generation.motionModel.isNotEmpty) {
      buffer.writeln(
        '| Motion | ${task.generation.motionModel} | ${task.generation.resolution} | ${task.generation.duration}s | ${task.generation.fps} |',
      );
    }
    buffer.writeln();

    buffer.writeln('**Prompt:**');
    buffer.writeln('```');
    buffer.writeln(task.generation.prompt);
    buffer.writeln('```\n');

    buffer.writeln('## 🧠 Purity Improvement\n');
    buffer.writeln('**Average PS Increase:** +${task.getAveragePSImprovement().toStringAsFixed(1)}');
    buffer.writeln('**Final Average PS:** ${task.getAveragePS().toStringAsFixed(1)}\n');

    buffer.writeln('### Detailed Stage Data\n');
    
    for (var i = 0; i < task.images.length; i++) {
      final image = task.images[i];
      buffer.writeln('#### Image ${i + 1}: ${image.pose} - ${image.angle}\n');
      buffer.writeln('| Stage | PS | BV | EC | Tool |');
      buffer.writeln('|-------|----|----|----| -----|');
      
      for (var stage in image.stages) {
        buffer.writeln(
          '| ${stage.stage} | ${stage.purity.ps.toStringAsFixed(1)} | ${stage.purity.bv.toStringAsFixed(1)} | ${stage.purity.ec.toStringAsFixed(2)} | ${stage.purity.tool} |',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('## 📊 Output Files\n');
    
    if (task.outputs.statics.isNotEmpty) {
      buffer.writeln('**Static Images (${task.outputs.statics.length}):**');
      for (var i = 0; i < task.outputs.statics.length; i++) {
        buffer.writeln('- `outputs/static_${i + 1}.png`');
      }
      buffer.writeln();
    }
    
    if (task.outputs.videos.isNotEmpty) {
      buffer.writeln('**Videos (${task.outputs.videos.length}):**');
      for (var i = 0; i < task.outputs.videos.length; i++) {
        buffer.writeln('- `outputs/video_${i + 1}.mp4`');
      }
      buffer.writeln();
    }

    buffer.writeln('---\n');
    buffer.writeln('*Generated by Pet Motion Lab*');

    return buffer.toString();
  }
}

