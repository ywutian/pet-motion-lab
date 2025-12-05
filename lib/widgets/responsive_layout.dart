import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// 响应式页面布局 - 自动居中内容并限制最大宽度
class ResponsivePageLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;
  final bool useSafeArea;

  const ResponsivePageLayout({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? Responsive.maxContentWidth(context);
    final effectivePadding = padding ?? Responsive.pagePadding(context);

    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

/// 响应式滚动页面布局
class ResponsiveScrollLayout extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;
  final double? maxWidth;
  final bool useSafeArea;
  final ScrollController? controller;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveScrollLayout({
    super.key,
    required this.children,
    this.padding,
    this.maxWidth,
    this.useSafeArea = true,
    this.controller,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? Responsive.maxContentWidth(context);
    final effectivePadding = padding ?? Responsive.pagePadding(context);

    Widget content = SingleChildScrollView(
      controller: controller,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: Padding(
            padding: effectivePadding,
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        ),
      ),
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

/// 响应式网格布局
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int largeDesktopColumns;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.largeDesktopColumns = 4,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(
      context,
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
      largeDesktop: largeDesktopColumns,
    );

    if (childAspectRatio != null) {
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: childAspectRatio!,
        children: children,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;
        
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

/// 响应式两栏布局 - 桌面端左右分栏，移动端上下排列
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double leftFlex;
  final double rightFlex;
  final double spacing;
  final bool reverseOnMobile;

  const ResponsiveTwoColumn({
    super.key,
    required this.leftChild,
    required this.rightChild,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.spacing = 24,
    this.reverseOnMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex.toInt(), child: leftChild),
          SizedBox(width: spacing),
          Expanded(flex: rightFlex.toInt(), child: rightChild),
        ],
      );
    }

    final children = reverseOnMobile
        ? [rightChild, SizedBox(height: spacing), leftChild]
        : [leftChild, SizedBox(height: spacing), rightChild];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// 响应式卡片 - 自动调整内边距和圆角
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double? elevation;
  final VoidCallback? onTap;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.elevation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? Responsive.cardPadding(context);
    final borderRadius = BorderRadius.circular(
      Responsive.isDesktop(context) ? 20 : 16,
    );

    return Card(
      color: color,
      elevation: elevation,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}

/// 响应式导航 - 桌面端侧边栏，移动端底部导航
class ResponsiveNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget body;

  const ResponsiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (isDesktop) {
      return Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: destinations.map((d) => NavigationRailDestination(
              icon: d.icon,
              selectedIcon: d.selectedIcon,
              label: Text(d.label),
            )).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      ),
    );
  }
}

/// 响应式对话框
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final double? maxWidth;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final effectiveMaxWidth = maxWidth ?? (isDesktop ? 600 : double.infinity);

    if (isDesktop) {
      return Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                ],
                Flexible(child: child),
                if (actions != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // 移动端使用全屏对话框或底部弹窗
    return Scaffold(
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        actions: actions,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

