import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/kling_generation_service.dart';
import '../config/api_config.dart';
import 'kling_history_detail_screen.dart';

class KlingHistoryScreen extends StatefulWidget {
  const KlingHistoryScreen({super.key});

  @override
  State<KlingHistoryScreen> createState() => _KlingHistoryScreenState();
}

class _KlingHistoryScreenState extends State<KlingHistoryScreen> {
  final _service = KlingGenerationService();
  List<dynamic> _historyItems = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _service.getHistory(
        page: _currentPage,
        pageSize: 20,
        statusFilter: _statusFilter,
      );
      
      setState(() {
        _historyItems = data['items'] ?? [];
        _totalPages = data['total_pages'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteHistory(String petId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteHistory(petId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功')),
        );
        _loadHistory();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 可灵生成历史'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _statusFilter = value;
                _currentPage = 1;
              });
              _loadHistory();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '', child: Text('全部')),
              const PopupMenuItem(value: 'completed', child: Text('已完成')),
              const PopupMenuItem(value: 'processing', child: Text('处理中')),
              const PopupMenuItem(value: 'failed', child: Text('失败')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHistory,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_historyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('暂无生成记录', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('开始生成您的第一个宠物动画吧！', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyItems.length,
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          return FadeInUp(
            delay: Duration(milliseconds: index * 50),
            child: _HistoryCard(
              item: item,
              onTap: () => _navigateToDetail(item['pet_id']),
              onDelete: () => _deleteHistory(item['pet_id']),
            ),
          );
        },
      ),
    );
  }

  void _navigateToDetail(String petId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KlingHistoryDetailScreen(petId: petId),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item['status'] ?? 'unknown';
    final breed = item['breed'] ?? '未知';
    final createdAt = item['created_at_formatted'] ?? '';
    final stats = item['stats'] ?? {};
    final preview = item['preview'] ?? {};
    final thumbnailUrl = preview['thumbnail'];

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 预览图
            if (thumbnailUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: '${ApiConfig.baseUrl}$thumbnailUrl',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.pets, size: 48),
                  ),
                ),
              )
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.pets, size: 48),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          breed,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(context, status),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 时间
                  Text(
                    createdAt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 统计信息
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(context, Icons.videocam, '${stats['video_count'] ?? 0}个视频'),
                      _buildChip(context, Icons.gif, '${stats['gif_count'] ?? 0}个GIF'),
                      if (stats['has_concatenated_video'] == true)
                        _buildChip(context, Icons.movie, '拼接视频', color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('删除'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                      Row(
                        children: [
                          const Text('查看详情'),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
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

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'completed':
        color = Colors.green;
        text = '已完成';
        icon = Icons.check_circle;
        break;
      case 'processing':
        color = Colors.orange;
        text = '处理中';
        icon = Icons.hourglass_top;
        break;
      case 'failed':
        color = Colors.red;
        text = '失败';
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        text = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, IconData icon, String label, {Color? color}) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: chipColor, fontSize: 12)),
        ],
      ),
    );
  }
}

