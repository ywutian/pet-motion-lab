import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/step_colors.dart';
import '../utils/responsive_helper.dart';

/// 步骤下一步按钮 - 可复用组件
class StepNextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final IconData icon;

  const StepNextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isEnabled = true,
    this.icon = Icons.arrow_forward,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);
    final iconSize = ResponsiveHelper.getResponsiveIconSize(context);

    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(icon, size: iconSize * 0.9),
        label: Text(
          text,
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
        style: ElevatedButton.styleFrom(
          backgroundColor: StepColors.success,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusLG,
          ),
        ),
      ),
    );
  }
}

