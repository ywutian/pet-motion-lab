import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/step_colors.dart';
import '../utils/responsive_helper.dart';

/// 步骤页面基类 - 提供统一的布局和样式
abstract class BaseStepScreen extends StatelessWidget {
  /// 步骤编号 (0=初始化, 1-6=步骤1-6)
  final int stepNumber;

  /// 步骤标题
  final String stepTitle;

  const BaseStepScreen({
    super.key,
    required this.stepNumber,
    required this.stepTitle,
  });

  /// 获取步骤颜色主题
  StepColorTheme get colorTheme => StepColors.getThemeForStep(stepNumber);

  /// 构建页面内容 - 子类必须实现
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(stepTitle),
        backgroundColor: colorTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ResponsiveContainer(
        padding: EdgeInsets.all(
          ResponsiveSpacing.getResponsivePadding(context),
        ),
        child: SingleChildScrollView(
          child: buildContent(context),
        ),
      ),
    );
  }
}

/// 带状态的步骤页面基类
abstract class BaseStepScreenStateful extends StatefulWidget {
  /// 步骤编号 (0=初始化, 1-6=步骤1-6)
  final int stepNumber;

  /// 步骤标题
  final String stepTitle;

  const BaseStepScreenStateful({
    super.key,
    required this.stepNumber,
    required this.stepTitle,
  });
}

/// 带状态的步骤页面State基类
abstract class BaseStepScreenState<T extends BaseStepScreenStateful> extends State<T> {
  /// 获取步骤颜色主题
  StepColorTheme get colorTheme => StepColors.getThemeForStep(widget.stepNumber);

  /// 构建页面内容 - 子类必须实现
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stepTitle),
        backgroundColor: colorTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ResponsiveContainer(
        padding: EdgeInsets.all(
          ResponsiveSpacing.getResponsivePadding(context),
        ),
        child: SingleChildScrollView(
          child: buildContent(context),
        ),
      ),
    );
  }

  /// 显示错误消息
  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: StepColors.error,
      ),
    );
  }

  /// 显示成功消息
  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: StepColors.success,
      ),
    );
  }

  /// 显示信息消息
  void showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: StepColors.info,
      ),
    );
  }

  /// 导航到下一个步骤
  void navigateToNextStep(Widget nextScreen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  /// 返回上一页
  void goBack() {
    Navigator.pop(context);
  }

  /// 构建间隔
  Widget buildGap({double? height}) {
    return SizedBox(
      height: height ?? ResponsiveSpacing.getResponsiveCardSpacing(context),
    );
  }
}

