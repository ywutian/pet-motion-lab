import 'package:flutter/material.dart';

/// 应用间距常量
class AppSpacing {
  // 基础间距单位
  static const double unit = 4.0;

  // 常用间距
  static const double xs = unit; // 4
  static const double sm = unit * 2; // 8
  static const double md = unit * 3; // 12
  static const double lg = unit * 4; // 16
  static const double xl = unit * 5; // 20
  static const double xxl = unit * 6; // 24
  static const double xxxl = unit * 8; // 32

  // 边距
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  static const EdgeInsets paddingXXL = EdgeInsets.all(xxl);
  static const EdgeInsets paddingXXXL = EdgeInsets.all(xxxl);

  // 水平边距
  static const EdgeInsets horizontalXS = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSM = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMD = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLG = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXL = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets horizontalXXL = EdgeInsets.symmetric(horizontal: xxl);

  // 垂直边距
  static const EdgeInsets verticalXS = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSM = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMD = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLG = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXL = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets verticalXXL = EdgeInsets.symmetric(vertical: xxl);

  // 圆角
  static const double radiusXS = xs;
  static const double radiusSM = sm;
  static const double radiusMD = md;
  static const double radiusLG = lg;
  static const double radiusXL = xl;
  static const double radiusXXL = xxl;

  // BorderRadius
  static BorderRadius borderRadiusXS = BorderRadius.circular(radiusXS);
  static BorderRadius borderRadiusSM = BorderRadius.circular(radiusSM);
  static BorderRadius borderRadiusMD = BorderRadius.circular(radiusMD);
  static BorderRadius borderRadiusLG = BorderRadius.circular(radiusLG);
  static BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);
  static BorderRadius borderRadiusXXL = BorderRadius.circular(radiusXXL);

  // 间隔盒子
  static const SizedBox gapXS = SizedBox(width: xs, height: xs);
  static const SizedBox gapSM = SizedBox(width: sm, height: sm);
  static const SizedBox gapMD = SizedBox(width: md, height: md);
  static const SizedBox gapLG = SizedBox(width: lg, height: lg);
  static const SizedBox gapXL = SizedBox(width: xl, height: xl);
  static const SizedBox gapXXL = SizedBox(width: xxl, height: xxl);
  static const SizedBox gapXXXL = SizedBox(width: xxxl, height: xxxl);

  // 水平间隔
  static const SizedBox hGapXS = SizedBox(width: xs);
  static const SizedBox hGapSM = SizedBox(width: sm);
  static const SizedBox hGapMD = SizedBox(width: md);
  static const SizedBox hGapLG = SizedBox(width: lg);
  static const SizedBox hGapXL = SizedBox(width: xl);
  static const SizedBox hGapXXL = SizedBox(width: xxl);

  // 垂直间隔
  static const SizedBox vGapXS = SizedBox(height: xs);
  static const SizedBox vGapSM = SizedBox(height: sm);
  static const SizedBox vGapMD = SizedBox(height: md);
  static const SizedBox vGapLG = SizedBox(height: lg);
  static const SizedBox vGapXL = SizedBox(height: xl);
  static const SizedBox vGapXXL = SizedBox(height: xxl);
  static const SizedBox vGapXXXL = SizedBox(height: xxxl);
}

/// 响应式间距
class ResponsiveSpacing {
  /// 根据屏幕宽度获取响应式间距
  static double getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return AppSpacing.lg; // 手机
    } else if (width < 1200) {
      return AppSpacing.xxl; // 平板
    } else {
      return AppSpacing.xxxl; // 桌面
    }
  }

  /// 根据屏幕宽度获取响应式卡片间距
  static double getResponsiveCardSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return AppSpacing.lg;
    } else if (width < 1200) {
      return AppSpacing.xl;
    } else {
      return AppSpacing.xxl;
    }
  }

  /// 根据屏幕宽度获取响应式内容最大宽度
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return width; // 手机全宽
    } else if (width < 1200) {
      return 800; // 平板限制宽度
    } else {
      return 1000; // 桌面限制宽度
    }
  }
}

