import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_layout.dart';
import 'tools/background_removal_tool.dart';
import 'tools/generate_sitting_pose_tool.dart';
import 'tools/image_to_video_tool.dart';
import 'tools/frame_extraction_tool.dart';
import 'tools/frames_to_video_tool.dart';
import 'tools/video_to_gif_tool.dart';

/// 工具中心 - 集成所有常用工具
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);
    final spacing = Responsive.spacing(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ 工具中心'),
        centerTitle: !isDesktop,
      ),
      body: ResponsiveScrollLayout(
        padding: Responsive.pagePadding(context),
        maxWidth: 1400,
          children: [
            // 说明卡片
          _buildInfoCard(context, theme),
          SizedBox(height: spacing * 1.5),

          // 工具网格
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            largeDesktopColumns: 3,
            spacing: spacing,
            runSpacing: spacing,
            children: _buildToolCards(context),
          ),
          SizedBox(height: spacing),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, ThemeData theme) {
    final isDesktop = Responsive.isDesktop(context);
    
    return ResponsiveCard(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
            size: Responsive.iconSize(context, base: 28),
          ),
          SizedBox(width: Responsive.spacing(context)),
          Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        Text(
                          '工具说明',
                  style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: isDesktop ? 18 : 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '这里集成了所有常用的独立工具，每个工具都可以单独使用。涵盖从图片处理到视频生成的完整流程！',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
          ),
                  ],
                ),
    );
  }

  List<Widget> _buildToolCards(BuildContext context) {
    final tools = [
      _ToolItem(
                  title: '去除背景',
        description: '使用AI自动去除图片背景，支持多种模型选择',
                  icon: Icons.content_cut,
                  color: Colors.red,
        screen: const BackgroundRemovalTool(),
                ),
      _ToolItem(
                  title: '图片生成图片',
                  description: '上传图片，根据提示词生成新图片（图生图）',
                  icon: Icons.image,
                  color: Colors.purple,
        screen: const GenerateSittingPoseTool(),
                ),
      _ToolItem(
                  title: '图片生成视频',
        description: '上传一张图片，使用可灵AI生成动态视频',
                  icon: Icons.video_library,
                  color: Colors.orange,
        screen: const ImageToVideoTool(),
                ),
      _ToolItem(
                  title: '提取视频首尾帧',
                  description: '从视频中提取第一帧和最后一帧图片',
                  icon: Icons.image_outlined,
                  color: Colors.green,
        screen: const FrameExtractionTool(),
                ),
      _ToolItem(
                  title: '首尾帧生成视频',
        description: '上传首帧和尾帧图片，生成平滑过渡视频',
                  icon: Icons.video_call,
                  color: Colors.blue,
        screen: const FramesToVideoTool(),
                ),
      _ToolItem(
                  title: '视频转GIF',
        description: '将视频文件转换为GIF动画格式',
                  icon: Icons.gif,
                  color: Colors.pink,
        screen: const VideoToGifTool(),
      ),
    ];

    return tools.map((tool) => _buildToolCard(context, tool)).toList();
  }

  Widget _buildToolCard(BuildContext context, _ToolItem tool) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return ResponsiveCard(
                  onTap: () {
                    Navigator.push(
                      context,
          MaterialPageRoute(builder: (context) => tool.screen),
        );
      },
      child: isMobile
          ? _buildCompactToolLayout(context, theme, tool)
          : _buildGridToolLayout(context, theme, tool, isDesktop),
    );
  }

  // 移动端紧凑布局
  Widget _buildCompactToolLayout(BuildContext context, ThemeData theme, _ToolItem tool) {
    return Row(
      children: [
        _buildToolIcon(context, tool, size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tool.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                tool.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios,
          color: tool.color,
          size: 18,
        ),
      ],
    );
  }

  // 桌面端网格布局
  Widget _buildGridToolLayout(BuildContext context, ThemeData theme, _ToolItem tool, bool isDesktop) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        _buildToolIcon(context, tool, size: isDesktop ? 72 : 64),
        SizedBox(height: isDesktop ? 16 : 12),
          Text(
          tool.title,
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 17 : 15,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 8),
        Text(
          tool.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: isDesktop ? 13 : 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tool.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '使用工具',
                style: TextStyle(
                  color: tool.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: tool.color, size: 14),
            ],
            ),
          ),
        ],
    );
  }

  Widget _buildToolIcon(BuildContext context, _ToolItem tool, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tool.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(
        tool.icon,
        color: tool.color,
        size: size * 0.5,
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _ToolItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.screen,
  });
}
