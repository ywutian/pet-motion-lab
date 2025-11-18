import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/video_trimming_service.dart';
import '../../services/tool_history_service.dart';
import '../../models/tool_history_item.dart';
import '../../theme/app_spacing.dart';

/// 提取视频首尾帧工具
class FrameExtractionTool extends StatefulWidget {
  const FrameExtractionTool({super.key});

  @override
  State<FrameExtractionTool> createState() => _FrameExtractionToolState();
}

class _FrameExtractionToolState extends State<FrameExtractionTool> {
  final ImagePicker _picker = ImagePicker();
  final VideoTrimmingService _service = VideoTrimmingService();
  final ToolHistoryService _historyService = ToolHistoryService();

  File? _selectedVideo;
  bool _isExtracting = false;

  // 选择视频
  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideo = File(video.path);
      });
    }
  }

  // 提取首帧
  Future<void> _extractFirstFrame() async {
    if (_selectedVideo == null) return;

    setState(() => _isExtracting = true);

    try {
      final frameFile = await VideoTrimmingService.extractFrame(
        videoFile: _selectedVideo!,
        frameType: 'first',
      );

      // 复制到永久目录
      final directory = await getApplicationDocumentsDirectory();
      final framesDir = Directory('${directory.path}/frames');
      await framesDir.create(recursive: true);
      final permanentPath = '${framesDir.path}/first_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await frameFile.copy(permanentPath);

      // 自动保存到相册
      await _saveToGallery(frameFile.path);

      // 保存到历史记录
      await _historyService.addHistoryItem(ToolHistoryItem(
        id: const Uuid().v4(),
        toolType: ToolType.frameExtraction,
        resultPath: permanentPath,
        createdAt: DateTime.now(),
        metadata: {
          'frameType': '首帧',
        },
      ));

      // 删除临时文件
      await frameFile.delete();

      setState(() => _isExtracting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 首帧已保存到相册！')),
        );
      }
    } catch (e) {
      setState(() => _isExtracting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 提取失败: $e')),
        );
      }
    }
  }

  // 提取尾帧
  Future<void> _extractLastFrame() async {
    if (_selectedVideo == null) return;

    setState(() => _isExtracting = true);

    try {
      final frameFile = await VideoTrimmingService.extractFrame(
        videoFile: _selectedVideo!,
        frameType: 'last',
      );

      // 复制到永久目录
      final directory = await getApplicationDocumentsDirectory();
      final framesDir = Directory('${directory.path}/frames');
      await framesDir.create(recursive: true);
      final permanentPath = '${framesDir.path}/last_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await frameFile.copy(permanentPath);

      // 自动保存到相册
      await _saveToGallery(frameFile.path);

      // 保存到历史记录
      await _historyService.addHistoryItem(ToolHistoryItem(
        id: const Uuid().v4(),
        toolType: ToolType.frameExtraction,
        resultPath: permanentPath,
        createdAt: DateTime.now(),
        metadata: {
          'frameType': '尾帧',
        },
      ));

      // 删除临时文件
      await frameFile.delete();

      setState(() => _isExtracting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 尾帧已保存到相册！')),
        );
      }
    } catch (e) {
      setState(() => _isExtracting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 提取失败: $e')),
        );
      }
    }
  }

  // 保存到相册
  Future<void> _saveToGallery(String imagePath) async {
    // Gal 会自动处理权限请求，直接保存即可
    await Gal.putImage(imagePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 提取视频首尾帧'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 说明
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: Text(
                  '从视频中提取第一帧和最后一帧，自动保存到相册',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ),
            AppSpacing.vGapLG,

            // 选择视频按钮
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('选择视频'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            AppSpacing.vGapLG,

            // 视频信息
            if (_selectedVideo != null) ...[
              Card(
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '已选择视频',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      AppSpacing.vGapSM,
                      Text(
                        _selectedVideo!.path.split('/').last,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.vGapLG,

              // 提取按钮
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExtracting ? null : _extractFirstFrame,
                      icon: _isExtracting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.first_page),
                      label: const Text('保存首帧'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  AppSpacing.hGapMD,
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExtracting ? null : _extractLastFrame,
                      icon: _isExtracting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.last_page),
                      label: const Text('保存尾帧'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

