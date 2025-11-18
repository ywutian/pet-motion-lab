import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive_helper.dart';

/// 步骤操作卡片 - 可复用组件（自动执行或上传）
class StepActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onPressed;
  final Color buttonColor;
  final bool isLoading;

  const StepActionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
    required this.buttonColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);
    final iconSize = ResponsiveHelper.getResponsiveIconSize(context);

    return Card(
      elevation: 2,
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
                      fontSize: ResponsiveHelper.getResponsiveFontSize(
                        context,
                        mobile: 16,
                        tablet: 17,
                        desktop: 18,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.vGapMD,
            Text(
              description,
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
            AppSpacing.vGapMD,
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onPressed,
                icon: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        buttonText.contains('执行') ? Icons.play_arrow : Icons.upload,
                        size: iconSize * 0.8,
                      ),
                label: Text(
                  buttonText,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 15,
                      tablet: 16,
                      desktop: 17,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.borderRadiusLG,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

