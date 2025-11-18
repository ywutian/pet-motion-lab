import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/step_colors.dart';
import '../utils/responsive_helper.dart';

/// 步骤结果卡片 - 显示结果图片/视频
class StepResultCard extends StatelessWidget {
  final String? imagePath;
  final String? videoPath;
  final String title;
  final VoidCallback? onDownload;
  final bool isDownloading;

  const StepResultCard({
    super.key,
    this.imagePath,
    this.videoPath,
    this.title = '处理结果',
    this.onDownload,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasResult = imagePath != null || videoPath != null;
    if (!hasResult) return const SizedBox.shrink();

    final imageHeight = ResponsiveHelper.getResponsiveImageHeight(context);
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);

    return Card(
      color: StepColors.successLight,
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
                Icon(
                  Icons.check_circle,
                  color: StepColors.success,
                  size: ResponsiveHelper.getResponsiveIconSize(context),
                ),
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
                      color: StepColors.success,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.vGapLG,
            if (imagePath != null)
              ClipRRect(
                borderRadius: AppSpacing.borderRadiusLG,
                child: Image.network(
                  imagePath!,
                  height: imageHeight,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: imageHeight,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.error, size: 48),
                      ),
                    );
                  },
                ),
              ),
            if (videoPath != null)
              Container(
                height: imageHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: AppSpacing.borderRadiusLG,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_library,
                        size: ResponsiveHelper.getResponsiveIconSize(context) * 2,
                        color: Colors.grey[600],
                      ),
                      AppSpacing.vGapSM,
                      Text(
                        '视频已生成',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            if (onDownload != null) ...[
              AppSpacing.vGapLG,
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: isDownloading ? null : onDownload,
                  icon: isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(isDownloading ? '下载中...' : '下载到相册'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StepColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.borderRadiusLG,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

