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

/// 图片生成视频工具
class ImageToVideoTool extends StatefulWidget {
  const ImageToVideoTool({super.key});

  @override
  State<ImageToVideoTool> createState() => _ImageToVideoToolState();
}

class _ImageToVideoToolState extends State<ImageToVideoTool> {
  final ImagePicker _picker = ImagePicker();
  final KlingToolsService _klingService = KlingToolsService();
  final ToolHistoryService _historyService = ToolHistoryService();

  File? _selectedImage;
  File? _generatedVideo;
  bool _isGenerating = false;

  // 宠物信息
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  String _selectedSpecies = '犬'; // 默认选择犬
  String _firstFramePose = 'walk'; // 首帧姿势（图片中的动作）
  String _lastFramePose = 'walk'; // 尾帧姿势（目标动作）

  // 过渡提示词模板（v3.0新版格式）
  final Map<String, String> _transitionPrompts = {
    // 过渡动作
    'sit2walk': '保持原图{breed}的外观特征，{style}，纯白色背景，从坐姿站起，然后自然行走，前后脚交替移动，镜头正对{species}的正前方。',
    'sit2sleep': '保持原图{breed}的外观特征，{style}，纯白色背景，从坐姿趴下，头放下，闭眼打呼噜，镜头正对{species}的正前方。',
    'sit2rest': '保持原图{breed}的外观特征，{style}，纯白色背景，从坐姿向前趴下，肚子贴地，头抬起眼睛睁开，镜头正对{species}的正前方。',
    'walk2sit': '保持原图{breed}的外观特征，{style}，纯白色背景，行走减速停下，后腿弯曲坐下，镜头正对{species}的正前方。',
    'walk2sleep': '保持原图{breed}的外观特征，{style}，纯白色背景，行走减速停下，趴下，闭眼打呼噜，镜头正对{species}的正前方。',
    'walk2rest': '保持原图{breed}的外观特征，{style}，纯白色背景，行走减速停下，向前趴下，头抬起，镜头正对{species}的正前方。',
    'sleep2walk': '保持原图{breed}的外观特征，{style}，纯白色背景，睁眼，站起，然后自然行走，前后脚交替移动，镜头正对{species}的正前方。',
    'sleep2rest': '保持原图{breed}的外观特征，{style}，纯白色背景，睁眼，头抬起，保持趴卧，镜头正对{species}的正前方。',
    'sleep2sit': '保持原图{breed}的外观特征，{style}，纯白色背景，睁眼，撑起身体，后腿弯曲坐下，镜头正对{species}的正前方。',
    'rest2sit': '保持原图{breed}的外观特征，{style}，纯白色背景，从趴卧撑起身体，后腿弯曲坐下，镜头正对{species}的正前方。',
    'rest2walk': '保持原图{breed}的外观特征，{style}，纯白色背景，从趴卧站起，然后自然行走，前后脚交替移动，镜头正对{species}的正前方。',
    'rest2sleep': '保持原图{breed}的外观特征，{style}，纯白色背景，保持趴卧，头慢慢放下，闭眼打呼噜，镜头正对{species}的正前方。',
    // 循环动作
    'walk': '保持原图{breed}的外观特征，{style}，纯白色背景，四脚着地自然行走，前后脚交替移动，镜头正对{species}的正前方。',
    'rest': '保持原图{breed}的外观特征，{style}，纯白色背景，趴卧，肚子贴地，头抬起，眼睛睁开，镜头正对{species}的正前方。',
    'sit': '保持原图{breed}的外观特征，{style}，纯白色背景，坐姿，抬头四处张望，镜头正对{species}的正前方。',
    'sleep': '保持原图{breed}的外观特征，{style}，纯白色背景，趴着睡觉，头放下，闭眼，打呼噜，鼻子有气体呼入呼出，镜头正对{species}的正前方。',
  };

  // 负向提示词
  String _currentNegativePrompt = '';

  String _getNegativePrompt(String key) {
    if (key.contains('walk')) {
      return '写实照片感，摄影质感，模糊，噪点，变形，多余肢体，跳跃，小跑，奔跑，四脚同时离地';
    }
    return '写实照片感，摄影质感，模糊，噪点，变形，多余肢体，站立，行走，奔跑';
  }

  @override
  void initState() {
    super.initState();
    _updatePrompt();
  }

  @override
  void dispose() {
    _breedController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  // 根据物种获取风格
  String _getStyle() {
    if (_selectedSpecies == '犬') {
      return '3D卡通动画风格，色彩鲜艳明亮，卡通化柔和阴影';
    } else {
      return '迪士尼3D动画风格，温暖明亮色调，柔和艺术化光影';
    }
  }

  // 更新提示词
  void _updatePrompt() {
    final breed = _breedController.text.trim();
    final breedText = breed.isEmpty ? '宠物' : breed;

    String key;
    if (_firstFramePose == _lastFramePose) {
      // 相同姿势，使用循环动作
      key = _firstFramePose;
    } else {
      // 不同姿势，使用过渡动作
      key = '${_firstFramePose}2${_lastFramePose}';
    }

    final template = _transitionPrompts[key] ?? '自然流畅的动画效果';
    final prompt = template
        .replaceAll('{breed}', breedText)
        .replaceAll('{species}', _selectedSpecies)
        .replaceAll('{style}', _getStyle());

    _promptController.text = prompt;
    _currentNegativePrompt = _getNegativePrompt(key);
  }

  // 生成提示词（用于向后兼容）
  String _generatePrompt() {
    return _promptController.text;
  }

  // 获取姿势中文名称
  String _getPoseName(String pose) {
    switch (pose) {
      case 'walk':
        return '行走';
      case 'sit':
        return '坐姿';
      case 'rest':
        return '休息';
      case 'sleep':
        return '睡觉';
      default:
        return pose;
    }
  }

  // 选择图片
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _generatedVideo = null;
      });
    }
  }

  // 生成视频
  Future<void> _generateVideo() async {
    if (_selectedImage == null) return;

    final prompt = _generatePrompt();

    setState(() => _isGenerating = true);

    try {
      final result = await _klingService.imageToVideo(
        imageFile: _selectedImage!,
        prompt: prompt,
        negativePrompt: _currentNegativePrompt,
      );

      setState(() {
        _generatedVideo = result;
        _isGenerating = false;
      });

      // 保存到历史记录
      await _historyService.addHistoryItem(ToolHistoryItem(
        id: const Uuid().v4(),
        toolType: ToolType.imageToVideo,
        resultPath: result.path,
        createdAt: DateTime.now(),
        metadata: {
          'species': _selectedSpecies,
          'breed': _breedController.text.trim(),
          'firstFramePose': _firstFramePose,
          'lastFramePose': _lastFramePose,
          'animationType': _firstFramePose == _lastFramePose ? 'loop' : 'transition',
          'prompt': prompt,
        },
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 视频生成成功！')),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 视频生成失败: $e')),
        );
      }
    }
  }

  // 保存到相册
  Future<void> _saveToGallery() async {
    if (_generatedVideo == null) return;

    try {
      // Gal 会自动处理权限请求，直接保存即可
      await Gal.putVideo(_generatedVideo!.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 视频已保存到相册！')),
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

  // 构建姿势选择芯片
  Widget _buildPoseChip(String value, String label, bool selected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      appBar: AppBar(title: const Text('图片生成视频')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Text('上传一张图片，使用可灵AI生成5秒循环视频', style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
            ),
          ),
          AppSpacing.vGapLG,
          Card(
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('宠物信息', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  AppSpacing.vGapMD,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedSpecies,
                          decoration: const InputDecoration(labelText: '物种', isDense: true),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: '犬', child: Text('犬')),
                            DropdownMenuItem(value: '猫', child: Text('猫')),
                          ],
                          onChanged: (v) { if (v != null) { setState(() { _selectedSpecies = v; _updatePrompt(); }); } },
                        ),
                      ),
                      AppSpacing.hGapMD,
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _breedController,
                          decoration: const InputDecoration(labelText: '品种', hintText: '例如：柯基', isDense: true),
                          onChanged: (_) => setState(() => _updatePrompt()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.vGapLG,
          FilledButton.icon(onPressed: _pickImage, icon: const Icon(Icons.upload_file), label: const Text('选择图片')),
            AppSpacing.vGapLG,

            // 图片预览和姿势选择
            if (_selectedImage != null) ...[
              const Text('选择的图片：', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Image.file(_selectedImage!, height: 200, fit: BoxFit.contain),
              AppSpacing.vGapLG,

              // 首帧姿势选择（图片中的动作）
              const Text('图片中的动作（首帧）：', style: TextStyle(fontSize: 12, color: Colors.grey)),
              AppSpacing.vGapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPoseChip('walk', '行走', _firstFramePose == 'walk', (selected) {
                    if (selected) {
                      setState(() {
                        _firstFramePose = 'walk';
                        _updatePrompt();
                      });
                    }
                  }),
                  _buildPoseChip('sit', '坐姿', _firstFramePose == 'sit', (selected) {
                    if (selected) {
                      setState(() {
                        _firstFramePose = 'sit';
                        _updatePrompt();
                      });
                    }
                  }),
                  _buildPoseChip('rest', '休息', _firstFramePose == 'rest', (selected) {
                    if (selected) {
                      setState(() {
                        _firstFramePose = 'rest';
                        _updatePrompt();
                      });
                    }
                  }),
                  _buildPoseChip('sleep', '睡觉', _firstFramePose == 'sleep', (selected) {
                    if (selected) {
                      setState(() {
                        _firstFramePose = 'sleep';
                        _updatePrompt();
                      });
                    }
                  }),
                ],
              ),
              AppSpacing.vGapLG,

              // 尾帧姿势选择（目标动作）
              const Text('目标动作（尾帧）：', style: TextStyle(fontSize: 12, color: Colors.grey)),
              AppSpacing.vGapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPoseChip('walk', '行走', _lastFramePose == 'walk', (selected) {
                    if (selected) {
                      setState(() {
                        _lastFramePose = 'walk';
                        _updatePrompt();
                      });
                    }
                  }),
                  _buildPoseChip('sit', '坐姿', _lastFramePose == 'sit', (selected) {
                    if (selected) {
                      setState(() {
                        _lastFramePose = 'sit';
                        _updatePrompt();
                      });
                    }
                  }),
                  _buildPoseChip('rest', '休息', _lastFramePose == 'rest', (selected) {
                    if (selected) {
                      setState(() {
                        _lastFramePose = 'rest';
                        _updatePrompt();
                      });
                    }
                  }),
                  _buildPoseChip('sleep', '睡觉', _lastFramePose == 'sleep', (selected) {
                    if (selected) {
                      setState(() {
                        _lastFramePose = 'sleep';
                        _updatePrompt();
                      });
                    }
                  }),
                ],
              ),
              AppSpacing.vGapLG,

              // 提示词编辑
              const Text('提示词：', style: TextStyle(fontSize: 12, color: Colors.grey)),
              AppSpacing.vGapSM,
              TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '描述你想要生成的视频...',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                  helperText: '💡 提示：可以使用预设姿势自动生成，也可以自定义编辑',
                  helperMaxLines: 2,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '重新生成提示词',
                    onPressed: () {
                      setState(() {
                        _updatePrompt();
                      });
                    },
                  ),
                ),
              ),
              AppSpacing.vGapSM,
              Text(
                _firstFramePose == _lastFramePose
                    ? '🔄 循环动画：${_getPoseName(_firstFramePose)}'
                    : '➡️ 过渡动画：${_getPoseName(_firstFramePose)} → ${_getPoseName(_lastFramePose)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              AppSpacing.vGapLG,

              // 生成视频按钮
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateVideo,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_library),
                label: Text(_isGenerating ? '生成中...' : '生成视频'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              AppSpacing.vGapLG,
            ],

            // 生成的视频
            if (_generatedVideo != null) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 48),
                      AppSpacing.vGapSM,
                      Text(
                        '✅ 视频生成成功！',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      AppSpacing.vGapSM,
                      Text(
                        '路径: ${_generatedVideo!.path}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
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

