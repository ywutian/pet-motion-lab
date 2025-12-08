import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../services/export_service.dart';
import '../utils/responsive.dart';

class TaskDetailScreen extends StatelessWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final task = taskProvider.getTask(taskId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务详情')),
        body: const Center(child: Text('任务不存在')),
      );
    }

    final horizontalPadding = Responsive.horizontalPadding(context).left;

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportReport(context, task),
            tooltip: '导出报告',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteTask(context, task),
            tooltip: '删除任务',
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          MediaQuery.of(context).padding.bottom + 32,
        ),
        children: [
          _buildHeader(context, task),
          const SizedBox(height: 24),
          _buildImagesSection(context, task),
          const SizedBox(height: 24),
          _buildPurityChart(context, task),
          const SizedBox(height: 24),
          _buildModelInfo(context, task),
          const SizedBox(height: 24),
          _buildCuttingInfo(context, task),
          const SizedBox(height: 24),
          _buildOutputsSection(context, task),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.comboTemplate,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.status == 'completed' ? '✅ 已完成' : task.status,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'ID: ${task.taskId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '创建时间: ${dateFormat.format(task.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatChip(
                  theme,
                  '图片数量',
                  '${task.images.length}',
                  Icons.image,
                ),
                _buildStatChip(
                  theme,
                  '平均纯净度',
                  task.getAveragePS().toStringAsFixed(1),
                  Icons.auto_awesome,
                ),
                if (task.getAveragePSImprovement() > 0)
                  _buildStatChip(
                    theme,
                    'PS提升',
                    '+${task.getAveragePSImprovement().toStringAsFixed(1)}',
                    Icons.trending_up,
                    color: Colors.green,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
    ThemeData theme,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final chipColor = color ?? theme.colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: chipColor.withValues(alpha: 0.8),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: chipColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection(BuildContext context, Task task) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📸 上传图片详情',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...task.images.map((image) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildImageDetail(context, image),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDetail(BuildContext context, ImageData image) {
    final theme = Theme.of(context);
    final file = File(image.fileIn);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (file.existsSync())
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(file, fit: BoxFit.cover),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(image.species ?? ''),
                      avatar: const Icon(Icons.pets, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(image.pose),
                      avatar: const Icon(Icons.accessibility_new, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(image.angle),
                      avatar: const Icon(Icons.camera_alt, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...image.stages.map((stage) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildStageRow(theme, stage),
                )),
                if (image.staticPrompt != null && image.staticPrompt!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '静态Prompt:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    image.staticPrompt!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (image.motionPrompt != null && image.motionPrompt!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '动态Prompt:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    image.motionPrompt!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageRow(ThemeData theme, Stage stage) {
    String stageLabel = '';
    IconData icon = Icons.circle;
    
    switch (stage.stage) {
      case 'original':
        stageLabel = '原始';
        icon = Icons.upload_file;
        break;
      case 'postCut@upload':
        stageLabel = '上传后裁剪';
        icon = Icons.content_cut;
        break;
      case 'postGen':
        stageLabel = '生成后';
        icon = Icons.auto_awesome;
        break;
      case 'postCut@generate':
        stageLabel = '生成后裁剪';
        icon = Icons.content_cut;
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            stageLabel,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getPSColor(stage.purity.ps).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'PS: ${stage.purity.ps.toStringAsFixed(1)}',
            style: TextStyle(
              color: _getPSColor(stage.purity.ps),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        if (stage.deltaPs != null && stage.deltaPs! > 0) ...[
          const SizedBox(width: 4),
          Text(
            '+${stage.deltaPs!.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPurityChart(BuildContext context, Task task) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 纯净度变化曲线',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final stages = ['原始', '上传裁剪', '生成', '生成裁剪'];
                          if (value.toInt() < stages.length) {
                            return Text(
                              stages[value.toInt()],
                              style: theme.textTheme.bodySmall,
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: task.images.map((image) {
                    return LineChartBarData(
                      spots: image.stages.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.purity.ps,
                        );
                      }).toList(),
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    );
                  }).toList(),
                  minY: 0,
                  maxY: 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelInfo(BuildContext context, Task task) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🤖 模型配置',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(theme, '静态模型', task.generation.staticModel),
            _buildInfoRow(theme, '动态模型', task.generation.motionModel),
            _buildInfoRow(theme, '分辨率', task.generation.resolution),
            _buildInfoRow(theme, '时长', '${task.generation.duration}秒'),
            _buildInfoRow(theme, 'FPS', '${task.generation.fps}'),
            const Divider(),
            Text(
              '提示词:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.generation.prompt,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuttingInfo(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final cuttingStages = <Stage>[];
    
    for (var image in task.images) {
      cuttingStages.addAll(
        image.stages.where((s) => s.cut != null),
      );
    }

    if (cuttingStages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✂️ 裁剪记录',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  children: [
                    _buildTableCell(theme, '阶段', isHeader: true),
                    _buildTableCell(theme, '工具', isHeader: true),
                    _buildTableCell(theme, '耗时', isHeader: true),
                    _buildTableCell(theme, 'ΔPS', isHeader: true),
                  ],
                ),
                ...cuttingStages.map((stage) {
                  return TableRow(
                    children: [
                      _buildTableCell(theme, stage.stage),
                      _buildTableCell(theme, stage.cut!.tool),
                      _buildTableCell(theme, '${stage.cut!.latencyMs}ms'),
                      _buildTableCell(
                        theme,
                        stage.deltaPs != null
                            ? '+${stage.deltaPs!.toStringAsFixed(1)}'
                            : '-',
                        color: Colors.green,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(
    ThemeData theme,
    String text, {
    bool isHeader = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: isHeader
            ? theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              )
            : theme.textTheme.bodySmall?.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOutputsSection(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final hasOutputs = task.outputs.statics.isNotEmpty ||
        task.outputs.videos.isNotEmpty ||
        task.outputs.gifs.isNotEmpty;

    if (!hasOutputs) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎨 生成结果',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (task.outputs.statics.isNotEmpty) ...[
              Text('静态图 (${task.outputs.statics.length})'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: task.outputs.statics.map((path) {
                  final file = File(path);
                  if (file.existsSync()) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
              ),
            ],
            if (task.outputs.videos.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('动态视频 (${task.outputs.videos.length})'),
              const SizedBox(height: 8),
              ...task.outputs.videos.map((path) => Text(
                path.split('/').last,
                style: theme.textTheme.bodySmall,
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPSColor(double ps) {
    if (ps >= 85) return Colors.green;
    if (ps >= 70) return Colors.orange;
    return Colors.red;
  }

  Future<void> _exportReport(BuildContext context, Task task) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await ExportService.exportTask(task);
      
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('报告已导出: ${result.path}'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(BuildContext context, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个任务吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<TaskProvider>().deleteTask(task.taskId);
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('任务已删除')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }
}

