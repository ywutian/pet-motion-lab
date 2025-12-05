import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../services/background_removal_service.dart';
import '../../services/tool_history_service.dart';
import '../../models/tool_history_item.dart';
import '../../utils/responsive.dart';
import '../../widgets/responsive_layout.dart';

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
    final isDesktop = Responsive.isDesktop(context);
    final spacing = Responsive.spacing(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ 去除背景'),
        centerTitle: !isDesktop,
      ),
      body: ResponsiveScrollLayout(
        padding: Responsive.pagePadding(context),
        maxWidth: 1000,
        children: [
          // 说明卡片
          _buildInfoCard(theme),
          SizedBox(height: spacing),

          // 桌面端使用两栏布局
          if (isDesktop && (_originalImage != null || _processedImage != null))
            _buildDesktopLayout(theme, spacing)
          else
            _buildMobileLayout(theme, spacing),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return ResponsiveCard(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '上传图片，AI自动去除背景，保存透明背景的PNG图片',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, double spacing) {
    return ResponsiveTwoColumn(
      spacing: spacing * 2,
      leftChild: _buildOriginalImageSection(theme, spacing),
      rightChild: _buildProcessedImageSection(theme, spacing),
    );
  }

  Widget _buildMobileLayout(ThemeData theme, double spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 选择图片按钮
        _buildUploadButton(theme),
        SizedBox(height: spacing),

        // 原图预览
        if (_originalImage != null) ...[
          _buildImageCard(
            theme: theme,
            title: '原图',
            image: _originalImage!,
            showCheckerboard: false,
          ),
          SizedBox(height: spacing),

          // 去除背景按钮
          _buildRemoveBackgroundButton(theme),
          SizedBox(height: spacing),
        ],

        // 处理后的图片
        if (_processedImage != null) ...[
          _buildImageCard(
            theme: theme,
            title: '去除背景后',
            image: _processedImage!,
            showCheckerboard: true,
          ),
          SizedBox(height: spacing),

          // 保存按钮
          _buildSaveButton(theme),
        ],
      ],
    );
  }

  Widget _buildOriginalImageSection(ThemeData theme, double spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUploadButton(theme),
        if (_originalImage != null) ...[
          SizedBox(height: spacing),
          _buildImageCard(
            theme: theme,
            title: '原图',
            image: _originalImage!,
            showCheckerboard: false,
            height: 350,
          ),
          SizedBox(height: spacing),
          _buildRemoveBackgroundButton(theme),
        ],
      ],
    );
  }

  Widget _buildProcessedImageSection(ThemeData theme, double spacing) {
    if (_processedImage == null) {
      return ResponsiveCard(
        child: SizedBox(
          height: 350,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 64,
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '处理结果将显示在这里',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImageCard(
          theme: theme,
          title: '去除背景后',
          image: _processedImage!,
          showCheckerboard: true,
          height: 350,
        ),
        SizedBox(height: spacing),
        _buildSaveButton(theme),
      ],
    );
  }

  Widget _buildUploadButton(ThemeData theme) {
    final isDesktop = Responsive.isDesktop(context);
    
    return FilledButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.upload_file),
      label: Text(_originalImage == null ? '选择图片' : '更换图片'),
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 20 : 16),
        textStyle: TextStyle(
          fontSize: isDesktop ? 16 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRemoveBackgroundButton(ThemeData theme) {
    final isDesktop = Responsive.isDesktop(context);
    
    return FilledButton.icon(
      onPressed: _isProcessing ? null : _removeBackground,
      icon: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.content_cut),
      label: Text(_isProcessing ? '处理中...' : '去除背景'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 20 : 16),
        textStyle: TextStyle(
          fontSize: isDesktop ? 16 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    final isDesktop = Responsive.isDesktop(context);
    
    return FilledButton.icon(
      onPressed: _saveToGallery,
      icon: const Icon(Icons.save),
      label: const Text('保存到相册'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 20 : 16),
        textStyle: TextStyle(
          fontSize: isDesktop ? 16 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImageCard({
    required ThemeData theme,
    required String title,
    required File image,
    required bool showCheckerboard,
    double? height,
  }) {
    final isDesktop = Responsive.isDesktop(context);
    final effectiveHeight = height ?? (isDesktop ? 300.0 : 220.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ResponsiveCard(
          padding: EdgeInsets.zero,
          child: Container(
            height: effectiveHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: showCheckerboard ? null : theme.colorScheme.surfaceContainerHighest,
              // 棋盘格背景，显示透明效果
              image: showCheckerboard
                  ? const DecorationImage(
                      image: AssetImage('assets/images/checkerboard.png'),
                      repeat: ImageRepeat.repeat,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: showCheckerboard ? Colors.grey.shade200 : null,
                child: Center(
                  child: Image.file(
                    image,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
