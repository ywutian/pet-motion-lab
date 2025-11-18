import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:gal/gal.dart';
import '../models/tool_history_item.dart';
import '../services/tool_history_service.dart';
import '../theme/app_spacing.dart';

class ToolHistoryScreen extends StatefulWidget {
  const ToolHistoryScreen({super.key});

  @override
  State<ToolHistoryScreen> createState() => _ToolHistoryScreenState();
}

class _ToolHistoryScreenState extends State<ToolHistoryScreen> {
  final ToolHistoryService _historyService = ToolHistoryService();
  Map<ToolType, List<ToolHistoryItem>> _groupedHistory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final grouped = await _historyService.getHistoryGroupedByType();
    setState(() {
      _groupedHistory = grouped;
      _isLoading = false;
    });
  }

  Future<void> _deleteItem(String id) async {
    await _historyService.deleteHistoryItem(id);
    _loadHistory();
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要清空所有历史记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearHistory();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗂️ 工具历史记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllHistory,
            tooltip: '清空所有历史',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedHistory.values.every((list) => list.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.outline),
                      AppSpacing.vGapLG,
                      Text('暂无历史记录', style: Theme.of(context).textTheme.titleLarge),
                      AppSpacing.vGapSM,
                      Text('使用工具生成内容后会自动保存到这里',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: ToolType.values.map((type) {
                      final items = _groupedHistory[type] ?? [];
                      if (items.isEmpty) return const SizedBox.shrink();
                      return _buildToolSection(type, items);
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildToolSection(ToolType type, List<ToolHistoryItem> items) {
    final firstItem = items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(firstItem.toolIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(firstItem.toolName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${items.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildHistoryCard(items[index]),
        ),
        AppSpacing.vGapXL,
      ],
    );
  }

  Widget _buildHistoryCard(ToolHistoryItem item) {
    final file = File(item.resultPath);
    final exists = file.existsSync();
    return GestureDetector(
      onTap: exists ? () => _showDetailDialog(item) : () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文件不存在')));
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: exists
                      ? (item.isImage
                          ? Image.file(file, fit: BoxFit.cover)
                          : Stack(fit: StackFit.expand, children: [
                              Container(color: Colors.black,
                                child: const Icon(Icons.play_circle_outline, size: 48, color: Colors.white))]))
                      : Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image, size: 48)),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('MM/dd HH:mm').format(item.createdAt),
                        style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (item.metadata['breed'] != null)
                        Text(item.metadata['breed'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            // 下载按钮
            if (exists)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _downloadToGallery(item),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.download, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 下载到相册
  Future<void> _downloadToGallery(ToolHistoryItem item) async {
    try {
      final file = File(item.resultPath);
      if (!file.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ 文件不存在')),
          );
        }
        return;
      }

      if (item.isImage) {
        await Gal.putImage(item.resultPath);
      } else {
        await Gal.putVideo(item.resultPath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已保存到相册')),
        );
      }
    } catch (e) {
      print('❌ 下载失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 下载失败: $e')),
        );
      }
    }
  }

  void _showDetailDialog(ToolHistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item.isImage)
              Image.file(File(item.resultPath), fit: BoxFit.contain)
            else
              Container(height: 300, color: Colors.black,
                child: const Center(child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.toolIcon} ${item.toolName}', style: Theme.of(context).textTheme.titleLarge),
                  AppSpacing.vGapSM,
                  Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(item.createdAt),
                    style: Theme.of(context).textTheme.bodyMedium),
                  if (item.metadata.isNotEmpty) ...[
                    AppSpacing.vGapSM,
                    ...item.metadata.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${entry.key}: ${entry.value}', style: Theme.of(context).textTheme.bodySmall))),
                  ],
                  AppSpacing.vGapLG,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () { Navigator.pop(context); _deleteItem(item.id); },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('删除', style: TextStyle(color: Colors.red))),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () { Navigator.pop(context); _downloadToGallery(item); },
                        icon: const Icon(Icons.download),
                        label: const Text('下载')),
                      const SizedBox(width: 8),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
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
}

