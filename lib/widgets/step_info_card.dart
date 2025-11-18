import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive_helper.dart';

/// 步骤说明卡片 - 可复用组件
class StepInfoCard extends StatelessWidget {
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;
  final String title;
  final List<String> descriptions;

  const StepInfoCard({
    super.key,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    this.icon = Icons.info_outline,
    required this.title,
    required this.descriptions,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobile: 18,
      tablet: 20,
      desktop: 22,
    );

    final iconSize = ResponsiveHelper.getResponsiveIconSize(context);

    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
      ),
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: iconSize),
                AppSpacing.hGapSM,
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.vGapMD,
            ...descriptions.map((desc) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                desc,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                    context,
                    mobile: 14,
                    tablet: 15,
                    desktop: 16,
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

