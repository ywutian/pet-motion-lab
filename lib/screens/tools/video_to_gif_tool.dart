import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:uuid/uuid.dart';
import '../../services/kling_tools_service.dart';
import '../../services/tool_history_service.dart';
import '../../models/tool_history_item.dart';
import '../../widgets/app_scaffold.dart';
import '../../theme/app_spacing.dart';

/// 视频转GIF工具
class VideoToGifTool extends StatefulWidget {
  const VideoToGifTool({super.key});

  @override
  State<VideoToGifTool> createState() => _VideoToGifToolState();
}

class _VideoToGifToolState extends State<VideoToGifTool> {
  final ImagePicker _picker = ImagePicker();
  final KlingToolsService _klingService = KlingToolsService();
  final ToolHistoryService _historyService = ToolHistoryService();

  File? _selectedVideo;
  File? _generatedGif;
  bool _isConverting = false;

  // 转换参数
  int _fpsReduction = 2; // 帧率缩减倍数
  int _maxWidth = 480; // GIF最大宽度

  @override
  void initState() {
    super.initState();
  }

  // 选择视频
  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideo = File(video.path);
        _generatedGif = null;
      });
    }
  }

  // 转换为GIF
  Future<void> _convertToGif() async {
    if (_selectedVideo == null) return;

    setState(() => _isConverting = true);

    try {
      final result = await _klingService.convertVideoToGif(
        _selectedVideo!.path,
        fpsReduction: _fpsReduction,
        maxWidth: _maxWidth,
      );

      setState(() {
        _generatedGif = File(result.path);
        _isConverting = false;
      });

      // 保存到历史记录
      await _historyService.addHistoryItem(ToolHistoryItem(
        id: const Uuid().v4(),
        toolType: ToolType.videoToGif,
        resultPath: result.path,
        createdAt: DateTime.now(),
        metadata: {
          'fpsReduction': _fpsReduction,
          'maxWidth': _maxWidth,
          'originalVideo': _selectedVideo!.path,
        },
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ GIF转换成功！')),
        );
      }
    } catch (e) {
      setState(() => _isConverting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ GIF转换失败: $e')),
        );
      }
    }
  }

  // 保存到相册
  Future<void> _saveToGallery() async {
    if (_generatedGif == null) return;

    try {
      await Gal.putImage(_generatedGif!.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ GIF已保存到相册！')),
        );
      }
    } catch (e) {
      print('❌ 保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      appBar: AppBar(title: const Text('视频转GIF'), centerTitle: true),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  AppSpacing.hGapSM,
                  const Expanded(child: Text('上传一个视频文件，将其转换为GIF动画')),
                ],
              ),
            ),
          ),
            AppSpacing.vGapLG,

            // 转换参数设置
            Card(
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚙️ 转换参数', style: TextStyle(fontWeight: FontWeight.bold)),
                    AppSpacing.vGapMD,

                    // 帧率缩减
                    Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text('帧率缩减：'),
                        ),
                        Expanded(
                          flex: 3,
                          child: DropdownButton<int>(
                            value: _fpsReduction,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('无缩减（文件较大）')),
                              DropdownMenuItem(value: 2, child: Text('2倍（推荐）')),
                              DropdownMenuItem(value: 3, child: Text('3倍（文件较小）')),
                              DropdownMenuItem(value: 4, child: Text('4倍（文件很小）')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _fpsReduction = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vGapSM,

                    // 最大宽度
                    Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text('最大宽度：'),
                        ),
                        Expanded(
                          flex: 3,
                          child: DropdownButton<int>(
                            value: _maxWidth,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 320, child: Text('320px（小）')),
                              DropdownMenuItem(value: 480, child: Text('480px（推荐）')),
                              DropdownMenuItem(value: 640, child: Text('640px（中）')),
                              DropdownMenuItem(value: 800, child: Text('800px（大）')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _maxWidth = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vGapSM,
                    Text(
                      '💡 提示：帧率缩减和宽度越小，GIF文件越小',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
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

            // 视频预览
            if (_selectedVideo != null) ...[
              const Text('选择的视频：', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Card(
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Row(
                    children: [
                      const Icon(Icons.video_file, size: 48, color: Colors.blue),
                      AppSpacing.hGapMD,
                      Expanded(
                        child: Text(
                          _selectedVideo!.path.split('/').last,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.vGapLG,

              // 转换按钮
              ElevatedButton.icon(
                onPressed: _isConverting ? null : _convertToGif,
                icon: _isConverting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gif),
                label: Text(_isConverting ? '转换中...' : '转换为GIF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              AppSpacing.vGapLG,
            ],

            // 生成的GIF
            if (_generatedGif != null) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 48),
                      AppSpacing.vGapSM,
                      Text(
                        '✅ GIF转换成功！',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      AppSpacing.vGapSM,
                      Text(
                        '路径: ${_generatedGif!.path}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      AppSpacing.vGapMD,
                      Image.file(_generatedGif!, height: 200, fit: BoxFit.contain),
                    ],
                  ),
                ),
              ),
              AppSpacing.vGapLG,

              // 保存按钮
              ElevatedButton.icon(
                onPressed: _saveToGallery,
                icon: const Icon(Icons.save),
                label: const Text('保存到相册'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
        ],
      ),
    );
  }
}


