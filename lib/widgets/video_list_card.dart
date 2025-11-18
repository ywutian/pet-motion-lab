import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive_helper.dart';
import '../utils/download_helper.dart';

/// 视频列表卡片 - 显示视频列表和下载按钮
class VideoListCard extends StatelessWidget {
  final String title;
  final List<String> videos;
  final Map<String, String>? firstFrames;
  final Map<String, String>? lastFrames;
  final Color backgroundColor;
  final Color iconColor;
  final int? maxDisplay;

  const VideoListCard({
    super.key,
    required this.title,
    required this.videos,
    this.firstFrames,
    this.lastFrames,
    this.backgroundColor = const Color(0xFFE8F5E9),
    this.iconColor = const Color(0xFF4CAF50),
    this.maxDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final displayVideos = maxDisplay != null && videos.length > maxDisplay!
        ? videos.take(maxDisplay!).toList()
        : videos;
    final remaining = maxDisplay != null && videos.length > maxDisplay!
        ? videos.length - maxDisplay!
        : 0;

    return Card(
      color: backgroundColor,
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
                Icon(Icons.check_circle, color: iconColor),
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
            Text('生成了 ${videos.length} 个视频'),
            AppSpacing.vGapMD,

            // 视频列表
            if (displayVideos.isNotEmpty) ...[
              const Text('视频:', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              ...displayVideos.map((video) => _buildVideoItem(context, video)),
            ],

            // 显示剩余数量
            if (remaining > 0) ...[
              AppSpacing.vGapSM,
              Text(
                '... 还有 $remaining 个视频',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoItem(BuildContext context, String videoPath) {
    // 从路径中提取视频名称
    final videoName = videoPath.split('/').last.replaceAll('.mp4', '');
    final firstFramePath = firstFrames?[videoName];
    final lastFramePath = lastFrames?[videoName];

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.paddingMD,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频名称
            Text(
              videoName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            AppSpacing.vGapSM,

            // 视频下载按钮
            _buildDownloadRow(
              context,
              icon: Icons.video_library,
              label: '视频:',
              filePath: videoPath,
              fileName: '$videoName.mp4',
              buttonColor: Colors.blue,
            ),

            // 首帧下载按钮
            if (firstFramePath != null) ...[
              AppSpacing.vGapSM,
              _buildDownloadRow(
                context,
                icon: Icons.image,
                label: '首帧:',
                filePath: firstFramePath,
                fileName: '${videoName}_first_frame.png',
                buttonColor: Colors.green,
                isVideo: false,
              ),
            ],

            // 尾帧下载按钮
            if (lastFramePath != null) ...[
              AppSpacing.vGapSM,
              _buildDownloadRow(
                context,
                icon: Icons.image,
                label: '尾帧:',
                filePath: lastFramePath,
                fileName: '${videoName}_last_frame.png',
                buttonColor: Colors.orange,
                isVideo: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String filePath,
    required String fileName,
    required Color buttonColor,
    bool isVideo = true,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16),
        AppSpacing.hGapXS,
        Text(label, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () async {
            if (isVideo) {
              await DownloadHelper.downloadVideoAndSaveToGallery(
                context: context,
                filePath: filePath,
                customFileName: fileName,
              );
            } else {
              await DownloadHelper.downloadAndSaveToGallery(
                context: context,
                filePath: filePath,
                customFileName: fileName,
              );
            }
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text('下载', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}

