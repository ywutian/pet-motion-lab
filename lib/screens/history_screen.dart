import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:io';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import 'task_detail_screen.dart';
import '../utils/responsive.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('📊 历史记录'),
          ),
          Consumer<TaskProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (provider.tasks.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无历史记录',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final horizontal = Responsive.horizontalPadding(context).left;
              final bottomPadding = MediaQuery.of(context).padding.bottom + 24;
              final isDesktop = Responsive.isDesktop(context);

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottomPadding),
                sliver: isDesktop
                    ? SliverGrid( 
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final task = provider.tasks[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 40),
                              child: TaskCard(task: task),
                            );
                          },
                          childCount: provider.tasks.length,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.7,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final task = provider.tasks[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 50),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: TaskCard(task: task),
                              ),
                            );
                          },
                          childCount: provider.tasks.length,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(taskId: task.taskId),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.images.isNotEmpty && task.images.first.stages.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildThumbnail(),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.comboTemplate,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(theme),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateFormat.format(task.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        theme,
                        Icons.image,
                        '${task.images.length}张图片',
                      ),
                      if (task.species.isNotEmpty)
                        _buildInfoChip(
                          theme,
                          Icons.pets,
                          task.species.join(', '),
                        ),
                      _buildInfoChip(
                        theme,
                        Icons.auto_awesome,
                        'PS ${task.getAveragePS().toStringAsFixed(1)}',
                      ),
                      if (task.getAveragePSImprovement() > 0)
                        _buildInfoChip(
                          theme,
                          Icons.trending_up,
                          '+${task.getAveragePSImprovement().toStringAsFixed(1)}',
                          color: Colors.green,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '静态: ${task.generation.staticModel}',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (task.generation.motionModel.isNotEmpty)
                              Text(
                                '动态: ${task.generation.motionModel}',
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final firstImage = task.images.first;
    final file = File(firstImage.fileIn);
    
    if (file.existsSync()) {
      return Container(
        color: Colors.grey[200],
        child: Image.file(
          file,
          fit: BoxFit.contain, // 完整显示图片
        ),
      );
    }
    
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 48),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final color = task.status == 'completed' ? Colors.green : Colors.orange;
    final text = task.status == 'completed' ? '已完成' : task.status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    ThemeData theme,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color ?? theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

