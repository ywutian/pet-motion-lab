import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'kling_generation_screen.dart';
import 'kling_history_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    KlingGenerationScreen(key: PageStorageKey('kling_screen')),
    ToolsScreen(key: PageStorageKey('tools_screen')),
    KlingHistoryScreen(key: PageStorageKey('kling_history_screen')),
    SettingsScreen(key: PageStorageKey('settings_screen')),
  ];

  final List<NavigationDestination> _destinations = const [
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
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isLargeDesktop = Responsive.isLargeDesktop(context);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // 桌面端显示侧边导航栏
            if (isDesktop) _buildNavigationRail(isLargeDesktop),
            if (isDesktop) const VerticalDivider(width: 1),
            
            // 主内容区域
            Expanded(
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
          ],
        ),
      ),
      // 移动端显示底部导航栏
      bottomNavigationBar: isDesktop ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildNavigationRail(bool extended) {
    final theme = Theme.of(context);
    
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() => _currentIndex = index);
      },
      extended: extended,
      minExtendedWidth: 200,
      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      backgroundColor: theme.colorScheme.surface,
      leading: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 16,
          horizontal: extended ? 16 : 8,
        ),
        child: extended
            ? Row(
                children: [
                  Icon(
                    Icons.pets,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pet Motion',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              )
            : Icon(
                Icons.pets,
                color: theme.colorScheme.primary,
                size: 32,
              ),
      ),
      destinations: _destinations.map((d) => NavigationRailDestination(
        icon: d.icon,
        selectedIcon: d.selectedIcon,
        label: Text(d.label),
      )).toList(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          height: 72,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: _destinations,
        ),
      ),
    );
  }
}
