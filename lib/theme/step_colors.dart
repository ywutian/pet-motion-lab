import 'package:flutter/material.dart';

/// 步骤页面的颜色主题配置
class StepColors {
  // 初始化页面
  static const Color initPrimary = Color(0xFF673AB7); // 深紫色
  static const Color initLight = Color(0xFFEDE7F6);
  static const Color initDark = Color(0xFF512DA8);

  // 步骤1: 去除背景
  static const Color step1Primary = Color(0xFF2196F3); // 蓝色
  static const Color step1Light = Color(0xFFE3F2FD);
  static const Color step1Dark = Color(0xFF1976D2);

  // 步骤2: 生成坐姿
  static const Color step2Primary = Color(0xFF9C27B0); // 紫色
  static const Color step2Light = Color(0xFFF3E5F5);
  static const Color step2Dark = Color(0xFF7B1FA2);

  // 步骤3: 初始视频
  static const Color step3Primary = Color(0xFFFF9800); // 橙色
  static const Color step3Light = Color(0xFFFFF3E0);
  static const Color step3Dark = Color(0xFFF57C00);

  // 步骤4: 剩余视频
  static const Color step4Primary = Color(0xFF00BCD4); // 青色
  static const Color step4Light = Color(0xFFE0F7FA);
  static const Color step4Dark = Color(0xFF0097A7);

  // 步骤5: 循环视频
  static const Color step5Primary = Color(0xFF3F51B5); // 靛蓝色
  static const Color step5Light = Color(0xFFE8EAF6);
  static const Color step5Dark = Color(0xFF303F9F);

  // 步骤6: 转换GIF
  static const Color step6Primary = Color(0xFFE91E63); // 粉色
  static const Color step6Light = Color(0xFFFCE4EC);
  static const Color step6Dark = Color(0xFFC2185B);

  // 通用颜色
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  /// 根据步骤编号获取主题颜色
  static StepColorTheme getThemeForStep(int stepNumber) {
    switch (stepNumber) {
      case 0:
        return StepColorTheme(
          primary: initPrimary,
          light: initLight,
          dark: initDark,
        );
      case 1:
        return StepColorTheme(
          primary: step1Primary,
          light: step1Light,
          dark: step1Dark,
        );
      case 2:
        return StepColorTheme(
          primary: step2Primary,
          light: step2Light,
          dark: step2Dark,
        );
      case 3:
        return StepColorTheme(
          primary: step3Primary,
          light: step3Light,
          dark: step3Dark,
        );
      case 4:
        return StepColorTheme(
          primary: step4Primary,
          light: step4Light,
          dark: step4Dark,
        );
      case 5:
        return StepColorTheme(
          primary: step5Primary,
          light: step5Light,
          dark: step5Dark,
        );
      case 6:
        return StepColorTheme(
          primary: step6Primary,
          light: step6Light,
          dark: step6Dark,
        );
      default:
        return StepColorTheme(
          primary: initPrimary,
          light: initLight,
          dark: initDark,
        );
    }
  }
}

/// 步骤颜色主题
class StepColorTheme {
  final Color primary;
  final Color light;
  final Color dark;

  const StepColorTheme({
    required this.primary,
    required this.light,
    required this.dark,
  });
}

