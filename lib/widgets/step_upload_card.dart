import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive_helper.dart';

/// 步骤上传卡片 - 可复用的上传自定义文件组件
class StepUploadCard extends StatelessWidget {
  final String title;
  final String description;
  final File? selectedFile;
  final VoidCallback onPickFile;
  final VoidCallback? onUpload;
  final bool isProcessing;
  final Color primaryColor;
  final Color secondaryColor;

  const StepUploadCard({
    super.key,
    required this.title,
    required this.description,
    this.selectedFile,
    required this.onPickFile,
    this.onUpload,
    this.isProcessing = false,
    this.primaryColor = Colors.orange,
    this.secondaryColor = const Color(0xFFF57C00),
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
                Icon(Icons.upload_file, color: secondaryColor, size: iconSize),
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
            
            // 显示已选择的文件
            if (selectedFile != null) ...[
              ClipRRect(
                borderRadius: AppSpacing.borderRadiusLG,
                child: Image.file(
                  selectedFile!,
                  height: ResponsiveHelper.responsive(
                    context: context,
                    mobile: 150,
                    tablet: 200,
                    desktop: 250,
                  ),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              AppSpacing.vGapMD,
            ],
            
            // 按钮行
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: isProcessing ? null : onPickFile,
                      icon: Icon(Icons.image, size: iconSize * 0.8),
                      label: Text(
                        selectedFile == null ? '选择文件' : '重新选择',
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
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.borderRadiusLG,
                        ),
                      ),
                    ),
                  ),
                ),
                AppSpacing.hGapMD,
                Expanded(
                  child: SizedBox(
                    height: buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: selectedFile != null && !isProcessing && onUpload != null
                          ? onUpload
                          : null,
                      icon: Icon(Icons.upload, size: iconSize * 0.8),
                      label: Text(
                        '上传',
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
                        backgroundColor: secondaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: AppSpacing.borderRadiusLG,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

