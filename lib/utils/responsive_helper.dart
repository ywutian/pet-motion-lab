import 'package:flutter/material.dart';

/// 响应式布局辅助类
class ResponsiveHelper {
  /// 屏幕断点
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;

  /// 判断是否为手机
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// 判断是否为平板
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// 判断是否为桌面
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// 获取设备类型
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// 根据设备类型返回不同的值
  static T responsive<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// 获取响应式列数
  static int getResponsiveColumns(BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    return responsive(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// 获取响应式字体大小
  static double getResponsiveFontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsive(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// 获取响应式图片高度
  static double getResponsiveImageHeight(BuildContext context) {
    return responsive(
      context: context,
      mobile: 200,
      tablet: 300,
      desktop: 400,
    );
  }

  /// 获取响应式按钮高度
  static double getResponsiveButtonHeight(BuildContext context) {
    return responsive(
      context: context,
      mobile: 48,
      tablet: 52,
      desktop: 56,
    );
  }

  /// 获取响应式图标大小
  static double getResponsiveIconSize(BuildContext context) {
    return responsive(
      context: context,
      mobile: 24,
      tablet: 28,
      desktop: 32,
    );
  }
}

/// 设备类型枚举
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// 响应式布局构建器
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);
    return builder(context, deviceType);
  }
}

/// 响应式容器 - 自动限制最大宽度并居中
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final defaultMaxWidth = ResponsiveHelper.responsive<double>(
      context: context,
      mobile: double.infinity,
      tablet: 800.0,
      desktop: 1000.0,
    );

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? defaultMaxWidth,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

