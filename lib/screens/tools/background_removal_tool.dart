import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:uuid/uuid.dart';
import '../../services/background_removal_service.dart';
import '../../services/tool_history_service.dart';
import '../../models/tool_history_item.dart';
import '../../widgets/app_scaffold.dart';
import '../../theme/app_spacing.dart';

/// 去除背景工具
class BackgroundRemovalTool extends StatefulWidget {
  const BackgroundRemovalTool({super.key});

  @override
  State<BackgroundRemovalTool> createState() => _BackgroundRemovalToolState();
}

class _BackgroundRemovalToolState extends State<BackgroundRemovalTool> {
  final ImagePicker _picker = ImagePicker();
  final BackgroundRemovalService _service = BackgroundRemovalService();
  final ToolHistoryService _historyService = ToolHistoryService();

  File? _originalImage;
  File? _processedImage;
  bool _isProcessing = false;

  // 选择图片
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _originalImage = File(image.path);
        _processedImage = null;
      });
    }
  }

  // 去除背景
  Future<void> _removeBackground() async {
    if (_originalImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _service.removeBackground(_originalImage!);
      setState(() {
        _processedImage = result;
        _isProcessing = false;
      });

      // 保存到历史记录
      await _historyService.addHistoryItem(ToolHistoryItem(
        id: const Uuid().v4(),
        toolType: ToolType.backgroundRemoval,
        resultPath: result.path,
        createdAt: DateTime.now(),
        metadata: {},
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 背景去除成功！')),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 背景去除失败: $e')),
        );
      }
    }
  }

  // 保存到相册
  Future<void> _saveToGallery() async {
    if (_processedImage == null) return;

    try {
      // Gal 会自动处理权限请求，直接保存即可
      await Gal.putImage(_processedImage!.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已保存到相册！')),
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
      appBar: AppBar(title: const Text('去除背景')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Text('上传图片，自动去除背景，保存透明背景的PNG图片', style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
            ),
          ),
          AppSpacing.vGapLG,
          FilledButton.icon(onPressed: _pickImage, icon: const Icon(Icons.upload_file), label: const Text('选择图片')),
          AppSpacing.vGapLG,
          if (_originalImage != null) ...[
            Text('原图：', style: theme.textTheme.titleSmall),
            AppSpacing.vGapSM,
            ClipRRect(borderRadius: AppSpacing.borderRadiusMD, child: Image.file(_originalImage!, height: 200, fit: BoxFit.contain)),
            AppSpacing.vGapLG,
            FilledButton.icon(
              onPressed: _isProcessing ? null : _removeBackground,
              icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.content_cut),
              label: Text(_isProcessing ? '处理中...' : '去除背景'),
            ),
            AppSpacing.vGapLG,
          ],
          if (_processedImage != null) ...[
            Text('去除背景后：', style: theme.textTheme.titleSmall),
            AppSpacing.vGapSM,
            Container(
              height: 200,
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: AppSpacing.borderRadiusMD),
              child: Center(child: Image.file(_processedImage!, fit: BoxFit.contain)),
            ),
            AppSpacing.vGapLG,
            FilledButton.icon(onPressed: _saveToGallery, icon: const Icon(Icons.save), label: const Text('保存到相册')),
          ],
        ],
      ),
    );
  }
}


