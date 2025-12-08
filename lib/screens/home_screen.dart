import 'package:flutter/material.dart';
import 'kling_generation_screen.dart';
import 'kling_history_screen.dart';
import 'kling_history_detail_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';
import '../services/kling_generation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _hasCheckedPendingTasks = false;

  final List<Widget> _screens = const [
    KlingGenerationScreen(key: PageStorageKey('kling_screen')),
    ToolsScreen(key: PageStorageKey('tools_screen')),
    KlingHistoryScreen(key: PageStorageKey('kling_history_screen')),
    SettingsScreen(key: PageStorageKey('settings_screen')),
  ];

  @override
  void initState() {
    super.initState();
    // 延迟检查，确保界面已构建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingTasks();
    });
  }

  /// 检查是否有正在进行的任务
  Future<void> _checkPendingTasks() async {
    if (_hasCheckedPendingTasks) return;
    _hasCheckedPendingTasks = true;

    try {
      final service = KlingGenerationService();
      final pendingTasks = await service.getPendingTasks();

      if (pendingTasks.isNotEmpty && mounted) {
        _showPendingTasksDialog(pendingTasks);
      }
    } catch (e) {
      debugPrint('检查正在进行的任务失败: $e');
    }
  }

  /// 显示正在进行任务的提示框
  void _showPendingTasksDialog(List<Map<String, dynamic>> tasks) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.pending_actions, color: Colors.orange),
            const SizedBox(width: 8),
            Text('发现 ${tasks.length} 个正在生成的任务'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('以下任务正在后台生成中：'),
              const SizedBox(height: 12),
              ...tasks.take(5).map((task) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${task['breed'] ?? '未知'} · ${task['progress'] ?? 0}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      task['message'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )),
              if (tasks.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '还有 ${tasks.length - 5} 个任务...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后查看'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              if (tasks.length == 1) {
                // 只有一个任务，直接跳转到详情
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KlingHistoryDetailScreen(
                      petId: tasks.first['pet_id'],
                    ),
                  ),
                );
              } else {
                // 多个任务，跳转到历史列表
                setState(() => _currentIndex = 2);
              }
            },
            icon: const Icon(Icons.visibility),
            label: const Text('查看进度'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _screens[_currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding + 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            height: 72,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: '可灵AI',
              ),
              NavigationDestination(
                icon: Icon(Icons.build_outlined),
                selectedIcon: Icon(Icons.build),
                label: '工具',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: '历史',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
