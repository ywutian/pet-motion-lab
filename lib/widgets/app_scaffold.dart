import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// 统一的页面骨架，带最大内容宽度和自适应内边距。
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.padding,
    this.scrollable = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final EdgeInsets? padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final maxWidth = ResponsiveSpacing.getMaxContentWidth(context);
    final resolvedPadding = padding ??
        EdgeInsets.symmetric(
          horizontal: ResponsiveSpacing.getResponsivePadding(context),
          vertical: AppSpacing.lg,
        );

    Widget content = Padding(
      padding: resolvedPadding,
      child: scrollable ? SingleChildScrollView(child: body) : body,
    );

    content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );

    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: content),
    );
  }
}




