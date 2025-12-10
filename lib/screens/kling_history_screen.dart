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

class _KlingHistoryScreenState extends State<KlingHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _service = KlingGenerationService();
  late TabController _tabController;
  
  // 普通历史记录
  List<dynamic> _historyItems = [];
  // 多模型对比分组
  List<dynamic> _groupedComparisons = [];
  // 可用的模型列表
  List<String> _availableModels = [];
  
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  String _statusFilter = '';
  String _modelFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadHistory();
      }
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final groupMode = _tabController.index == 1 ? 'comparison' : '';
      
      final data = await _service.getHistory(
        page: _currentPage,
        pageSize: 20,
        statusFilter: _statusFilter,
        modelFilter: _modelFilter,
        groupMode: groupMode,
      );
      
      setState(() {
        _historyItems = data['items'] ?? [];
        _groupedComparisons = data['grouped_comparisons'] ?? [];
        _totalPages = data['total_pages'] ?? 1;
        
        // 更新可用模型列表
        final models = data['available_models'];
        if (models != null) {
          _availableModels = List<String>.from(models);
        }
        
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
        }
        _loadHistory();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 可灵生成历史'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: '全部记录'),
            Tab(icon: Icon(Icons.compare), text: '模型对比'),
          ],
        ),
        actions: [
          // 视频模型筛选
          PopupMenuButton<String>(
            icon: Badge(
              isLabelVisible: _modelFilter.isNotEmpty,
              child: const Icon(Icons.smart_display),
            ),
            tooltip: '按模型筛选',
            onSelected: (value) {
              setState(() {
                _modelFilter = value;
                _currentPage = 1;
              });
              _loadHistory();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '',
                child: Row(
                  children: [
                    Icon(
                      Icons.all_inclusive,
                      color: _modelFilter.isEmpty ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '全部模型',
                      style: TextStyle(
                        fontWeight: _modelFilter.isEmpty ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ..._availableModels.map((model) => PopupMenuItem(
                value: model,
                child: Row(
                  children: [
                    _buildModelIcon(model),
                    const SizedBox(width: 8),
                    Text(
                      _getModelDisplayName(model),
                      style: TextStyle(
                        fontWeight: _modelFilter == model ? FontWeight.bold : null,
                      ),
                    ),
                    if (_modelFilter == model) ...[
                      const Spacer(),
                      Icon(Icons.check, color: theme.colorScheme.primary, size: 18),
                    ],
                  ],
                ),
              )),
            ],
          ),
          // 状态筛选
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '按状态筛选',
            onSelected: (value) {
              setState(() {
                _statusFilter = value;
                _currentPage = 1;
              });
              _loadHistory();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '', child: Text('全部状态')),
              const PopupMenuItem(value: 'completed', child: Text('✅ 已完成')),
              const PopupMenuItem(value: 'processing', child: Text('⏳ 处理中')),
              const PopupMenuItem(value: 'failed', child: Text('❌ 失败')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选状态提示
          if (_modelFilter.isNotEmpty || _statusFilter.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '筛选: ${_modelFilter.isNotEmpty ? _getModelDisplayName(_modelFilter) : ""}${_modelFilter.isNotEmpty && _statusFilter.isNotEmpty ? " · " : ""}${_statusFilter.isNotEmpty ? _getStatusText(_statusFilter) : ""}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _modelFilter = '';
                        _statusFilter = '';
                      });
                      _loadHistory();
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('清除'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          // 主体内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllHistoryTab(),
                _buildComparisonTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed': return '已完成';
      case 'processing': return '处理中';
      case 'failed': return '失败';
      default: return status;
    }
  }

  Widget _buildModelIcon(String modelName) {
    Color color;
    if (modelName.contains('v2-5') || modelName.contains('v2.5')) {
      color = Colors.purple;
    } else if (modelName.contains('v2-1') || modelName.contains('v2.1')) {
      color = Colors.blue;
    } else if (modelName.contains('v1-6') || modelName.contains('v1.6')) {
      color = Colors.teal;
    } else if (modelName.contains('v1-5') || modelName.contains('v1.5')) {
      color = Colors.orange;
    } else {
      color = Colors.grey;
    }
    return Icon(Icons.smart_display, color: color, size: 20);
  }

  String _getModelDisplayName(String modelName) {
    if (modelName.contains('v2-5') || modelName.contains('v2.5')) {
      return 'V2.5 Turbo';
    } else if (modelName.contains('v2-1') || modelName.contains('v2.1')) {
      return 'V2.1';
    } else if (modelName.contains('v1-6') || modelName.contains('v1.6')) {
      return 'V1.6';
    } else if (modelName.contains('v1-5') || modelName.contains('v1.5')) {
      return 'V1.5';
    } else if (modelName.contains('master')) {
      return 'V2.1 Master';
    }
    return modelName.replaceAll('kling-', '').toUpperCase();
  }

  Widget _buildAllHistoryTab() {
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

  Widget _buildComparisonTab() {
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

    if (_groupedComparisons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('暂无多模型对比记录', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              '使用多模型测试功能后，可以在这里对比不同模型的生成效果',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groupedComparisons.length,
        itemBuilder: (context, index) {
          final comparison = _groupedComparisons[index];
          return FadeInUp(
            delay: Duration(milliseconds: index * 50),
            child: _ComparisonCard(
              comparison: comparison,
              onTapModel: (petId) => _navigateToDetail(petId),
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

/// 单条历史记录卡片
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
    final isMultiModel = item['is_multi_model'] == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 预览图
            Stack(
              children: [
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
                // 多模型对比标记
                if (isMultiModel)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.compare, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '多模型对比',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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

                  // 视频模型标签（显眼位置）
                  if (item['video_model_name'] != null && item['video_model_name'].toString().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: _buildModelBadge(context, item['video_model_name'], item['video_model_mode']),
                    ),

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
                      const Row(
                        children: [
                          Text('查看详情'),
                          Icon(Icons.chevron_right),
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

  /// 视频模型徽章（显眼标记）
  Widget _buildModelBadge(BuildContext context, String modelName, String? mode) {
    // 根据模型名称选择颜色
    Color badgeColor;
    String displayName;
    
    if (modelName.contains('v2-5') || modelName.contains('v2.5')) {
      badgeColor = Colors.purple;
      displayName = 'V2.5 Turbo';
    } else if (modelName.contains('v2-1') || modelName.contains('v2.1')) {
      badgeColor = Colors.blue;
      displayName = 'V2.1';
    } else if (modelName.contains('v1-6') || modelName.contains('v1.6')) {
      badgeColor = Colors.teal;
      displayName = 'V1.6';
    } else if (modelName.contains('v1-5') || modelName.contains('v1.5')) {
      badgeColor = Colors.orange;
      displayName = 'V1.5';
    } else if (modelName.contains('master')) {
      badgeColor = Colors.amber;
      displayName = 'V2.1 Master';
    } else {
      badgeColor = Colors.grey;
      displayName = modelName.replaceAll('kling-', '').toUpperCase();
    }

    final modeText = mode?.isNotEmpty == true ? ' ($mode)' : '';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [badgeColor.withOpacity(0.8), badgeColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.smart_display, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '🎬 $displayName$modeText',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 多模型对比分组卡片
class _ComparisonCard extends StatelessWidget {
  final Map<String, dynamic> comparison;
  final Function(String petId) onTapModel;

  const _ComparisonCard({
    required this.comparison,
    required this.onTapModel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breed = comparison['breed'] ?? '未知';
    final createdAt = comparison['created_at_formatted'] ?? '';
    final models = List<Map<String, dynamic>>.from(comparison['models'] ?? []);
    final preview = comparison['preview'] ?? {};
    final thumbnailUrl = preview['thumbnail'];

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：预览图 + 基本信息
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.1),
                  Colors.purple.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                // 预览图
                if (thumbnailUrl != null)
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CachedNetworkImage(
                      imageUrl: '${ApiConfig.baseUrl}$thumbnailUrl',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.pets, size: 32),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.pets, size: 32),
                  ),
                const SizedBox(width: 16),
                // 信息
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.compare, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    '模型对比',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          breed,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          createdAt,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '共 ${models.length} 个模型',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 模型列表
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '生成结果',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                ...models.map((model) => _buildModelResultTile(context, model)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelResultTile(BuildContext context, Map<String, dynamic> model) {
    final theme = Theme.of(context);
    final modelName = model['video_model_name'] ?? '未知';
    final mode = model['video_model_mode'] ?? '';
    final status = model['status'] ?? 'unknown';
    final petId = model['pet_id'] ?? '';
    final stats = model['stats'] ?? {};
    
    // 获取模型颜色
    Color modelColor;
    String displayName;
    
    if (modelName.contains('v2-5') || modelName.contains('v2.5')) {
      modelColor = Colors.purple;
      displayName = 'V2.5 Turbo';
    } else if (modelName.contains('v2-1') || modelName.contains('v2.1')) {
      modelColor = Colors.blue;
      displayName = 'V2.1';
    } else if (modelName.contains('v1-6') || modelName.contains('v1.6')) {
      modelColor = Colors.teal;
      displayName = 'V1.6';
    } else if (modelName.contains('v1-5') || modelName.contains('v1.5')) {
      modelColor = Colors.orange;
      displayName = 'V1.5';
    } else {
      modelColor = Colors.grey;
      displayName = modelName.replaceAll('kling-', '').toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: modelColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onTapModel(petId),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 模型图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: modelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.smart_display, color: modelColor, size: 24),
                ),
                const SizedBox(width: 12),
                // 模型信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: modelColor,
                            ),
                          ),
                          if (mode.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '($mode)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildMiniStat(Icons.videocam, '${stats['video_count'] ?? 0}'),
                          const SizedBox(width: 8),
                          _buildMiniStat(Icons.gif, '${stats['gif_count'] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
                // 状态
                _buildStatusChip(status),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'completed':
        color = Colors.green;
        text = '完成';
        icon = Icons.check_circle;
        break;
      case 'processing':
        color = Colors.orange;
        text = '进行中';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
