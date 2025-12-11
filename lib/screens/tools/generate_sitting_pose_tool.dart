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

/// 图片生成图片工具（图生图）
class GenerateSittingPoseTool extends StatefulWidget {
  const GenerateSittingPoseTool({super.key});

  @override
  State<GenerateSittingPoseTool> createState() => _GenerateSittingPoseToolState();
}

class _GenerateSittingPoseToolState extends State<GenerateSittingPoseTool> {
  final ImagePicker _picker = ImagePicker();
  final KlingToolsService _klingService = KlingToolsService();
  final ToolHistoryService _historyService = ToolHistoryService();

  File? _selectedImage;
  File? _generatedImage;
  bool _isGenerating = false;

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();

  String _selectedSpecies = '犬'; // 默认选择犬

  // 预设提示词模板（v3.0新版格式）
  final Map<String, String> _presetPromptTemplates = {
    '坐姿': '保持原图{breed}的外观特征，{style}，纯白色背景，坐姿，抬头四处张望，镜头正对{species}的正前方。',
    '行走': '保持原图{breed}的外观特征，{style}，纯白色背景，四脚着地自然行走，前后脚交替移动，镜头正对{species}的正前方。',
    '睡觉': '保持原图{breed}的外观特征，{style}，纯白色背景，趴着睡觉，头放下，闭眼，打呼噜，鼻子有气体呼入呼出，镜头正对{species}的正前方。',
    '休息': '保持原图{breed}的外观特征，{style}，纯白色背景，趴卧，肚子贴地，头抬起，眼睛睁开，镜头正对{species}的正前方。',
  };

  // 负向提示词模板
  final Map<String, String> _negativePromptTemplates = {
    '坐姿': '写实照片感，摄影质感，模糊，噪点，变形，多余肢体，站立，行走，奔跑',
    '行走': '写实照片感，摄影质感，模糊，噪点，变形，多余肢体，跳跃，小跑，奔跑，四脚同时离地',
    '睡觉': '写实照片感，摄影质感，模糊，噪点，变形，多余肢体，站立，行走，奔跑',
    '休息': '写实照片感，摄影质感，模糊，噪点，变形，多余肢体，站立，行走，奔跑',
  };

  String _currentPose = '坐姿';
  String _currentNegativePrompt = '';

  @override
  void initState() {
    super.initState();
    // 设置默认值
    _breedController.text = '柯基';
    _updatePromptFromTemplate('坐姿');
  }

  @override
  void dispose() {
    _promptController.dispose();
    _breedController.dispose();
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

  // 根据模板和用户输入生成提示词
  void _updatePromptFromTemplate(String pose) {
    final template = _presetPromptTemplates[pose]!;
    final breed = _breedController.text.trim();

    String prompt = template;
    prompt = prompt.replaceAll('{breed}', breed.isEmpty ? '宠物' : breed);
    prompt = prompt.replaceAll('{species}', _selectedSpecies);
    prompt = prompt.replaceAll('{style}', _getStyle());

    setState(() {
      _promptController.text = prompt;
      _currentPose = pose;
      _currentNegativePrompt = _negativePromptTemplates[pose] ?? '';
    });
  }

  // 更新当前提示词（如果是预设的）
  void _updateCurrentPrompt() {
    final currentPrompt = _promptController.text;
    // 检查是否是预设提示词
    for (var entry in _presetPromptTemplates.entries) {
      if (currentPrompt.contains('坐在地上') ||
          currentPrompt.contains('往前走') ||
          currentPrompt.contains('在睡觉') ||
          currentPrompt.contains('趴在地上')) {
        _updatePromptFromTemplate(entry.key);
        break;
      }
    }
  }

  // 选择图片
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _generatedImage = null;
      });
    }
  }

  // 生成图片
  Future<void> _generateImage() async {
    if (_selectedImage == null) return;

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 请填写提示词')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 调用可灵AI生成图片
      final result = await _klingService.imageToImage(
        imageFile: _selectedImage!,
        prompt: prompt,
        negativePrompt: _currentNegativePrompt,
      );

      setState(() {
        _generatedImage = result;
        _isGenerating = false;
      });

      // 保存到历史记录
      await _historyService.addHistoryItem(ToolHistoryItem(
        id: const Uuid().v4(),
        toolType: ToolType.imageToImage,
        resultPath: result.path,
        createdAt: DateTime.now(),
        metadata: {
          'species': _selectedSpecies,
          'breed': _breedController.text.trim(),
          'prompt': prompt,
        },
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 图片生成成功！')),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 生成失败: $e')),
        );
      }
    }
  }

  // 保存到相册
  Future<void> _saveToGallery() async {
    if (_generatedImage == null) return;

    try {
      // Gal 会自动处理权限请求，直接保存即可
      await Gal.putImage(_generatedImage!.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 图片已保存到相册！')),
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
      appBar: AppBar(title: const Text('图片生成图片')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
            child: Padding(
              padding: AppSpacing.paddingMD,
              child: Text('上传一张图片，使用可灵AI根据提示词生成新图片（图生图）', style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
            ),
          ),
          AppSpacing.vGapLG,
          FilledButton.icon(onPressed: _pickImage, icon: const Icon(Icons.upload_file), label: const Text('选择图片')),
            AppSpacing.vGapLG,

            // 图片预览
            if (_selectedImage != null) ...[
              const Text('选择的图片：', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Image.file(_selectedImage!, fit: BoxFit.contain),
                ),
              ),
              AppSpacing.vGapLG,

              // 宠物信息输入
              const Text('宠物信息：', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Row(
                children: [
                  // 物种选择
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedSpecies,
                      decoration: const InputDecoration(
                        labelText: '物种',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: '犬', child: Text('🐕 犬')),
                        DropdownMenuItem(value: '猫', child: Text('🐱 猫')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSpecies = value;
                          });
                          _updateCurrentPrompt();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 品种输入
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _breedController,
                      decoration: const InputDecoration(
                        labelText: '品种',
                        hintText: '例如：柯基',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _updateCurrentPrompt();
                      },
                    ),
                  ),
                ],
              ),
              AppSpacing.vGapLG,

              // 预设提示词快捷按钮
              const Text('快速选择姿势：', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetPromptTemplates.entries.map((entry) {
                  return ElevatedButton(
                    onPressed: () {
                      _updatePromptFromTemplate(entry.key);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade100,
                      foregroundColor: Colors.purple.shade700,
                    ),
                    child: Text(entry.key),
                  );
                }).toList(),
              ),
              AppSpacing.vGapLG,

              // 提示词输入
              TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '提示词',
                  hintText: '描述你想要生成的图片...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                  helperText: '可以使用预设提示词，也可以自定义',
                ),
              ),
              AppSpacing.vGapLG,

              // 生成按钮
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateImage,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isGenerating ? '生成中...' : '生成图片'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              AppSpacing.vGapLG,
            ],

            // 生成的图片
            if (_generatedImage != null) ...[
              const Text('生成的图片：', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Image.file(_generatedImage!, fit: BoxFit.contain),
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

