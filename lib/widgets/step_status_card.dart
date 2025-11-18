import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/step_colors.dart';
import '../utils/responsive_helper.dart';

/// 步骤状态卡片 - 显示处理状态
class StepStatusCard extends StatelessWidget {
  final String message;
  final bool isProcessing;
  final bool isError;

  const StepStatusCard({
    super.key,
    required this.message,
    this.isProcessing = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color iconColor;
    IconData icon;

    if (isError) {
      backgroundColor = StepColors.errorLight;
      iconColor = StepColors.error;
      icon = Icons.error;
    } else if (isProcessing) {
      backgroundColor = StepColors.warningLight;
      iconColor = StepColors.warning;
      icon = Icons.hourglass_empty;
    } else {
      backgroundColor = StepColors.successLight;
      iconColor = StepColors.success;
      icon = Icons.check_circle;
    }

    final iconSize = ResponsiveHelper.getResponsiveIconSize(context);

    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
      ),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Row(
          children: [
            if (isProcessing)
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            else
              Icon(icon, color: iconColor, size: iconSize),
            AppSpacing.hGapMD,
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                    context,
                    mobile: 14,
                    tablet: 15,
                    desktop: 16,
                  ),
                  color: iconColor.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

