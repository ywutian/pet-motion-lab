import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive_helper.dart';

/// 图片选择卡片 - 用于上传图片的可复用组件
class ImagePickerCard extends StatelessWidget {
  final File? selectedImage;
  final VoidCallback onTap;
  final bool isEnabled;
  final String? label;
  final double? height;

  const ImagePickerCard({
    super.key,
    this.selectedImage,
    required this.onTap,
    this.isEnabled = true,
    this.label,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = height ?? ResponsiveHelper.getResponsiveImageHeight(context);
    final iconSize = ResponsiveHelper.getResponsiveIconSize(context) * 2;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
      ),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: AppSpacing.borderRadiusLG,
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderRadiusLG,
            border: Border.all(
              color: Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: selectedImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: iconSize,
                      color: Colors.grey.shade400,
                    ),
                    AppSpacing.vGapLG,
                    Text(
                      label ?? '点击上传图片',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          mobile: 16,
                          tablet: 18,
                          desktop: 20,
                        ),
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: AppSpacing.borderRadiusLG,
                  child: Image.file(
                    selectedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
        ),
      ),
    );
  }
}

