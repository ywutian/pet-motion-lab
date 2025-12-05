import 'package:flutter/widgets.dart';

/// 响应式断点
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1600;
}

/// 响应式工具类
class Responsive {
  const Responsive._();

  /// 获取屏幕宽度
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  
  /// 获取屏幕高度
  static double height(BuildContext context) => MediaQuery.of(context).size.height;

  /// 是否为移动端 (<600px)
  static bool isMobile(BuildContext context) => width(context) < Breakpoints.mobile;

  /// 是否为平板 (600-900px)
  static bool isTablet(BuildContext context) {
    final w = width(context);
    return w >= Breakpoints.mobile && w < Breakpoints.tablet;
  }

  /// 是否为桌面端 (>=900px)
  static bool isDesktop(BuildContext context) => width(context) >= Breakpoints.tablet;

  /// 是否为大屏桌面 (>=1200px)
  static bool isLargeDesktop(BuildContext context) => width(context) >= Breakpoints.desktop;

  /// 是否为超大屏 (>=1600px)
  static bool isExtraLargeDesktop(BuildContext context) => width(context) >= Breakpoints.largeDesktop;

  /// 获取设备类型
  static DeviceType getDeviceType(BuildContext context) {
    final w = width(context);
    if (w < Breakpoints.mobile) return DeviceType.mobile;
    if (w < Breakpoints.tablet) return DeviceType.tablet;
    if (w < Breakpoints.desktop) return DeviceType.desktop;
    return DeviceType.largeDesktop;
  }

  /// 水平内边距（响应式）
  static EdgeInsets horizontalPadding(BuildContext context) {
    final w = width(context);
    if (w >= Breakpoints.largeDesktop) {
      return const EdgeInsets.symmetric(horizontal: 80);
    }
    if (w >= Breakpoints.desktop) {
      return const EdgeInsets.symmetric(horizontal: 64);
    }
    if (w >= Breakpoints.tablet) {
      return const EdgeInsets.symmetric(horizontal: 48);
    }
    if (w >= Breakpoints.mobile) {
      return const EdgeInsets.symmetric(horizontal: 32);
    }
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  /// 页面内边距（响应式）
  static EdgeInsets pagePadding(BuildContext context) {
    final w = width(context);
    if (w >= Breakpoints.largeDesktop) {
      return const EdgeInsets.all(48);
    }
    if (w >= Breakpoints.desktop) {
      return const EdgeInsets.all(32);
    }
    if (w >= Breakpoints.tablet) {
      return const EdgeInsets.all(24);
    }
    return const EdgeInsets.all(16);
  }

  /// 卡片内边距（响应式）
  static EdgeInsets cardPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.all(24);
    }
    if (isTablet(context)) {
      return const EdgeInsets.all(20);
    }
    return const EdgeInsets.all(16);
  }

  /// 网格列数（响应式）
  static int gridColumns(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3, int largeDesktop = 4}) {
    final w = width(context);
    if (w >= Breakpoints.largeDesktop) return largeDesktop;
    if (w >= Breakpoints.desktop) return desktop;
    if (w >= Breakpoints.tablet) return tablet;
    if (w >= Breakpoints.mobile) return tablet;
    return mobile;
  }

  /// 卡片宽度（响应式）
  static double cardWidth(BuildContext context, {int columns = 2, double spacing = 16}) {
    if (!isDesktop(context)) return double.infinity;
    final totalWidth = width(context) - horizontalPadding(context).horizontal;
    return (totalWidth - (columns - 1) * spacing) / columns;
  }

  /// 内容最大宽度（响应式）
  static double maxContentWidth(BuildContext context) {
    final w = width(context);
    if (w >= Breakpoints.largeDesktop) return 1400;
    if (w >= Breakpoints.desktop) return 1200;
    if (w >= Breakpoints.tablet) return 900;
    return double.infinity;
  }

  /// 字体大小缩放（响应式）
  static double fontScale(BuildContext context) {
    final w = width(context);
    if (w >= Breakpoints.largeDesktop) return 1.15;
    if (w >= Breakpoints.desktop) return 1.1;
    if (w >= Breakpoints.tablet) return 1.05;
    return 1.0;
  }

  /// 图标大小（响应式）
  static double iconSize(BuildContext context, {double base = 24}) {
    return base * fontScale(context);
  }

  /// 间距大小（响应式）
  static double spacing(BuildContext context, {double base = 16}) {
    final w = width(context);
    if (w >= Breakpoints.desktop) return base * 1.5;
    if (w >= Breakpoints.tablet) return base * 1.25;
    return base;
  }

  /// 根据设备类型返回不同的值
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    final type = getDeviceType(context);
    switch (type) {
      case DeviceType.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }
}

/// 设备类型枚举
enum DeviceType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

/// 响应式布局构建器
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, Responsive.getDeviceType(context));
      },
    );
  }
}

/// 响应式可见性组件
class ResponsiveVisibility extends StatelessWidget {
  final Widget child;
  final bool visibleOnMobile;
  final bool visibleOnTablet;
  final bool visibleOnDesktop;
  final Widget? replacement;

  const ResponsiveVisibility({
    super.key,
    required this.child,
    this.visibleOnMobile = true,
    this.visibleOnTablet = true,
    this.visibleOnDesktop = true,
    this.replacement,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = Responsive.getDeviceType(context);
    bool isVisible;
    
    switch (deviceType) {
      case DeviceType.mobile:
        isVisible = visibleOnMobile;
        break;
      case DeviceType.tablet:
        isVisible = visibleOnTablet;
        break;
      case DeviceType.desktop:
      case DeviceType.largeDesktop:
        isVisible = visibleOnDesktop;
        break;
    }

    if (isVisible) {
      return child;
    }
    return replacement ?? const SizedBox.shrink();
  }
}
