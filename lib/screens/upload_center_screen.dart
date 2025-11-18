import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:animate_do/animate_do.dart';
import '../models/upload_image.dart';
import '../services/purity_detector.dart';
import '../widgets/image_card.dart';
import '../utils/responsive.dart';
import 'generation_config_screen.dart';

class UploadCenterScreen extends StatefulWidget {
  const UploadCenterScreen({super.key});

  @override
  State<UploadCenterScreen> createState() => _UploadCenterScreenState();
}

class _UploadCenterScreenState extends State<UploadCenterScreen> {
  final List<UploadImage> _uploadedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _pickImages() async {
    if (_uploadedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多上传5张图片')),
      );
      return;
    }

    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    final remainingSlots = 5 - _uploadedImages.length;
    final imagesToProcess = images.take(remainingSlots).toList();

    setState(() => _isProcessing = true);

    for (var xFile in imagesToProcess) {
      final file = File(xFile.path);
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final uploadImage = UploadImage(
        id: id,
        file: file,
        species: '',
        pose: '',
        angle: '',
      );

      setState(() {
        _uploadedImages.add(uploadImage);
      });

      // 检测原图纯净度
      _detectPurity(uploadImage);
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _detectPurity(UploadImage image) async {
    try {
      final purity = await PurityDetector.detect(image.file);
      
      final index = _uploadedImages.indexWhere((img) => img.id == image.id);
      if (index != -1) {
        setState(() {
          _uploadedImages[index] = image.copyWith(originalPS: purity.ps);
        });
      }
    } catch (e) {
      debugPrint('检测纯净度失败: $e');
    }
  }

  void _removeImage(String id) {
    setState(() {
      _uploadedImages.removeWhere((img) => img.id == id);
    });
  }

  void _updateImage(UploadImage image) {
    final index = _uploadedImages.indexWhere((img) => img.id == image.id);
    if (index != -1) {
      setState(() {
        _uploadedImages[index] = image;
      });
    }
  }

  void _proceedToGeneration() {
    if (_uploadedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少上传一张图片')),
      );
      return;
    }

    final hasEmptyFields = _uploadedImages.any(
      (img) => img.species.isEmpty || img.pose.isEmpty || img.angle.isEmpty,
    );

    if (hasEmptyFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请完善所有图片的标签信息')),
      );
      return;
    }

    // 检查是否有未裁剪的图片
    final hasUncutImages = _uploadedImages.any((img) => img.cutFilePath == null);

    if (hasUncutImages) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text(
            '检测到有图片还未裁剪主体。\n\n'
            '建议先裁剪主体去除背景，这样生成的3D卡通效果会更好。\n\n'
            '是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回裁剪'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GenerationConfigScreen(
                      uploadedImages: _uploadedImages,
                    ),
                  ),
                );
              },
              child: const Text('继续'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerationConfigScreen(
          uploadedImages: _uploadedImages,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.horizontalPadding(context);

    return Scaffold(
      floatingActionButton: _uploadedImages.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _isProcessing ? null : _proceedToGeneration,
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('进入生成配置'),
            ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: const Text('🐾 上传中心'),
            actions: [
              if (_uploadedImages.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () {
                    setState(() => _uploadedImages.clear());
                  },
                  tooltip: '清空所有',
                ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              0,
              padding.right,
              MediaQuery.of(context).padding.bottom + 96,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeInDown(child: _buildUploadArea(theme)),
                const SizedBox(height: 24),
                if (_uploadedImages.isNotEmpty) ...[
                  _buildUploadedHeader(theme),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;
                      final crossAxisSpacing = isWide ? 16.0 : 0.0;
                      final itemWidth = isWide
                          ? (constraints.maxWidth - crossAxisSpacing) / 2
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: crossAxisSpacing,
                        runSpacing: 16,
                        children: _uploadedImages.map((image) {
                          return FadeInUp(
                            child: SizedBox(
                              width: itemWidth,
                              child: ImageCard(
                                image: image,
                                onUpdate: _updateImage,
                                onRemove: () => _removeImage(image.id),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryChips(theme),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;
        
        return InkWell(
          onTap: _isProcessing ? null : _pickImages,
          borderRadius: BorderRadius.circular(16),
          child: DottedBorder(
            borderType: BorderType.RRect,
            radius: const Radius.circular(16),
            dashPattern: const [8, 4],
            strokeWidth: 2,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(isNarrow ? 24 : 48),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: isNarrow ? 48 : 64,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: isNarrow ? 12 : 16),
                  Text(
                    '点击上传图片',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isNarrow ? 18 : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isNarrow ? 4 : 8),
                  Text(
                    '支持上传1-5张图片，JPG/PNG格式',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: isNarrow ? 12 : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isProcessing) ...[
                    SizedBox(height: isNarrow ? 12 : 16),
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadedHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已上传图片',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '当前共 ${_uploadedImages.length} 张，最多可上传 5 张',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: _uploadedImages.length >= 5 ? null : _pickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('继续添加'),
        ),
      ],
    );
  }

  Widget _buildSummaryChips(ThemeData theme) {
    final completed = _uploadedImages.where((img) => img.originalPS != null).length;
    final avgPs = _uploadedImages
        .where((img) => img.originalPS != null)
        .map((img) => img.originalPS!)
        .fold<double>(0, (a, b) => a + b);
    final avgValue = completed == 0 ? 0 : avgPs / completed;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        Chip(
          avatar: const Icon(Icons.auto_awesome, size: 16),
          label: Text('已检测纯净度 $completed/${_uploadedImages.length}'),
        ),
        Chip(
          avatar: const Icon(Icons.speed, size: 16),
          label: Text('平均PS ${avgValue.toStringAsFixed(1)}'),
        ),
        Chip(
          avatar: const Icon(Icons.layers, size: 16),
          label: Text('组合模板候选 ${_uploadedImages.length >= 3 ? '已满足' : '建议≥3张'}'),
        ),
      ],
    );
  }
}

