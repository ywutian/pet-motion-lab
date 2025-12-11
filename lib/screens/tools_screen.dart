import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_scaffold.dart';
import 'tools/background_removal_tool.dart';
import 'tools/generate_sitting_pose_tool.dart';
import 'tools/image_to_video_tool.dart';
import 'tools/frame_extraction_tool.dart';
import 'tools/frames_to_video_tool.dart';
import 'tools/video_to_gif_tool.dart';
import 'model_test_screen.dart';

/// 工具中心 - 集成所有常用工具
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取屏幕宽度
    final screenWidth = MediaQuery.of(context).size.width;

    // 根据屏幕宽度决定列数
    // 小屏幕（<600）：1列
    // 中等屏幕（600-900）：2列
    // 大屏幕（>900）：3列
    final crossAxisCount = screenWidth < 600 ? 1 : (screenWidth < 900 ? 2 : 3);

    // 根据列数决定是否使用紧凑布局
    final isCompact = crossAxisCount == 1;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('工具中心'),
        centerTitle: true,
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 说明卡片
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: AppSpacing.paddingLG,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      AppSpacing.hGapSM,
                      Text(
                        '工具说明',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapMD,
                  const Text('这里集成了所有常用的独立工具，每个工具都可以单独使用。'),
                  const Text('涵盖从图片处理到视频生成的完整流程！'),
                ],
              ),
            ),
          ),
          AppSpacing.vGapLG,

          // 响应式网格布局
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isCompact ? 3.5 : 0.80,
            children: [
              _buildToolCard(
                context,
                title: '去除背景',
                description: '使用AI自动去除图片背景',
                icon: Icons.content_cut,
                color: Colors.red,
                isCompact: isCompact,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BackgroundRemovalTool(),
                    ),
                  );
                },
              ),
              _buildToolCard(
                context,
                title: '图片生成图片',
                description: '上传图片，根据提示词生成新图片（图生图）',
                icon: Icons.image,
                color: Colors.purple,
                isCompact: isCompact,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GenerateSittingPoseTool(),
                    ),
                  );
                },
              ),
              _buildToolCard(
                context,
                title: '图片生成视频',
                description: '上传一张图片，使用可灵AI生成视频',
                icon: Icons.video_library,
                color: Colors.orange,
                isCompact: isCompact,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ImageToVideoTool(),
                    ),
                  );
                },
              ),
              _buildToolCard(
                context,
                title: '提取视频首尾帧',
                description: '从视频中提取第一帧和最后一帧图片',
                icon: Icons.image_outlined,
                color: Colors.green,
                isCompact: isCompact,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FrameExtractionTool(),
                    ),
                  );
                },
              ),
              _buildToolCard(
                context,
                title: '首尾帧生成视频',
                description: '上传首帧和尾帧图片，生成过渡视频',
                icon: Icons.video_call,
                color: Colors.blue,
                isCompact: isCompact,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FramesToVideoTool(),
                    ),
                  );
                },
              ),
              _buildToolCard(
                context,
                title: '视频转GIF',
                description: '将视频文件转换为GIF动画',
                icon: Icons.gif,
                color: Colors.pink,
                isCompact: isCompact,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VideoToGifTool(),
                    ),
                  );
                },
              ),
              _buildToolCard(
                context,
                title: '模型测试中心',
                description: '测试可灵AI各模型的首尾帧支持情况',
                icon: Icons.science,
                color: Colors.teal,
                isCompact: isCompact,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ModelTestScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isCompact,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: isCompact
              ? _buildCompactLayout(title, description, icon, color)
              : _buildGridLayout(title, description, icon, color),
        ),
      ),
    );
  }

  // 紧凑布局（单列，横向排列）
  Widget _buildCompactLayout(String title, String description, IconData icon, Color color) {
    return Row(
      children: [
        // 工具图标
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(width: 12),

        // 工具信息
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // 箭头
        Icon(Icons.arrow_forward_ios, color: color, size: 18),
      ],
    );
  }

  // 网格布局（多列，纵向排列）
  Widget _buildGridLayout(String title, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 工具图标
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),

          // 工具标题
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // 工具描述
          Flexible(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

