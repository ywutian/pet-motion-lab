import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:uuid/uuid.dart';
import '../../services/kling_tools_service.dart';
import '../../services/tool_history_service.dart';
import '../../models/tool_history_item.dart';
import '../../theme/app_spacing.dart';

/// 首尾帧生成视频工具
class FramesToVideoTool extends StatefulWidget {
  const FramesToVideoTool({super.key});

  @override
  State<FramesToVideoTool> createState() => _FramesToVideoToolState();
}

class _FramesToVideoToolState extends State<FramesToVideoTool> {
  final ImagePicker _picker = ImagePicker();
  final KlingToolsService _klingService = KlingToolsService();
  final ToolHistoryService _historyService = ToolHistoryService();

  File? _firstFrame;
  File? _lastFrame;
  File? _generatedVideo;
  bool _isGenerating = false;

  final TextEditingController _breedController = TextEditingController();
  String _selectedSpecies = '犬'; // 默认选择犬
  String _firstFramePose = 'walk'; // 首帧姿势
  String _lastFramePose = 'sit'; // 尾帧姿势

  // 过渡提示词模板
  final Map<String, String> _transitionPrompts = {
    'sit2walk': '卡通3D{breed}，背景是纯白色0x000000，宠物起立，然后往前走，镜头面对{species}的正前方。',
    'sit2sleep': '卡通3D{breed}，背景是纯白色0x000000，宠物趴下，然后睡觉，镜头面对{species}的正前方。',
    'sit2rest': '卡通3D{breed}，背景是纯白色0x000000，宠物趴下，然后休息（趴下但是睁着眼睛），镜头面对{species}的正前方。',
    'walk2sit': '卡通3D{breed}，背景是纯白色0x000000，宠物往前走，然后坐下，镜头面对{species}的正前方。',
    'walk2sleep': '卡通3D{breed}，背景是纯白色0x000000，宠物往前走，然后睡觉，镜头面对{species}的正前方。',
    'walk2rest': '卡通3D{breed}，背景是纯白色0x000000，宠物往前走，然后休息，镜头面对{species}的正前方。',
    'sleep2walk': '卡通3D{breed}，背景是纯白色0x000000，宠物睁眼，然后起立，往前走，镜头面对{species}的正前方。',
    'sleep2rest': '卡通3D{breed}，背景是纯白色0x000000，宠物睁眼，四处张望，镜头面对{species}的正前方。',
    'sleep2sit': '卡通3D{breed}，背景是纯白色0x000000，宠物睁眼，然后坐起来，镜头面对{species}的正前方。',
    'rest2sit': '卡通3D{breed}，背景是纯白色0x000000，宠物起立，然后坐下，镜头面对{species}的正前方。',
    'rest2walk': '卡通3D{breed}，背景是纯白色0x000000，宠物起立，然后往前走，镜头面对{species}的正前方。',
    'rest2sleep': '卡通3D{breed}，背景是纯白色0x000000，宠物闭眼睡觉，在打呼噜，有气体呼入呼出，镜头面对{species}的正前方。',
    // 相同姿势的循环动作
    'walk': '卡通3D{breed}，背景是纯白色0x000000，宠物往前走，自然流畅的动作，镜头面对{species}的正前方。',
    'rest': '卡通3D{breed}，背景是纯白色0x000000，宠物趴着休息，四处张望，镜头面对{species}的正前方。',
    'sit': '卡通3D{breed}，背景是纯白色0x000000，宠物坐着，四处张望，镜头面对{species}的正前方。',
    'sleep': '卡通3D{breed}，背景是纯白色0x000000，宠物睡觉，打呼噜，有气体呼入呼出，镜头面对{species}的正前方。',
  };

  @override
  void initState() {
    super.initState();
    _breedController.text = '柯基';
  }

  @override
  void dispose() {
    _breedController.dispose();
    super.dispose();
  }

  // 生成提示词
  String _generatePrompt() {
    final breed = _breedController.text.trim();
    final breedText = breed.isEmpty ? '宠物品种' : breed;

    String key;
    if (_firstFramePose == _lastFramePose) {
      // 相同姿势，使用循环动作
      key = _firstFramePose;
    } else {
      // 不同姿势，使用过渡动作
      key = '${_firstFramePose}2${_lastFramePose}';
    }

    final template = _transitionPrompts[key] ?? '平滑过渡到目标姿态，自然流畅的动画效果';
    return template
        .replaceAll('{breed}', breedText)
        .replaceAll('{species}', _selectedSpecies);
  }

  // 选择首帧
  Future<void> _pickFirstFrame() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _firstFrame = File(image.path);
        _generatedVideo = null;
      });
    }
  }

  // 选择尾帧
  Future<void> _pickLastFrame() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _lastFrame = File(image.path);
        _generatedVideo = null;
      });
    }
  }

  // 生成视频
  Future<void> _generateVideo() async {
    if (_firstFrame == null || _lastFrame == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 请先选择首帧和尾帧')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final result = await _klingService.framesToVideo(
        firstFrame: _firstFrame!,
        lastFrame: _lastFrame!,
      );

      setState(() {
        _generatedVideo = result;
        _isGenerating = false;
      });

      // 保存到历史记录
      final prompt = _generatePrompt();
      await _historyService.addHistoryItem(ToolHistoryItem(
        id: const Uuid().v4(),
        toolType: ToolType.framesToVideo,
        resultPath: result.path,
        createdAt: DateTime.now(),
        metadata: {
          'species': _selectedSpecies,
          'breed': _breedController.text.trim(),
          'firstFramePose': _firstFramePose,
          'lastFramePose': _lastFramePose,
          'prompt': prompt,
        },
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 过渡视频生成成功！')),
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

  // 获取姿势名称
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 首尾帧生成视频'),
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
                  '上传首帧和尾帧图片，使用可灵AI生成平滑过渡视频',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ),
            AppSpacing.vGapLG,

            // 宠物信息输入
            Card(
              child: Padding(
                padding: AppSpacing.paddingMD,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🐾 宠物信息',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    AppSpacing.vGapMD,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 物种选择
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('物种', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedSpecies,
                                decoration: const InputDecoration(
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
                                    setState(() => _selectedSpecies = value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 品种输入
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('品种', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _breedController,
                                decoration: const InputDecoration(
                                  hintText: '例如：柯基',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.vGapLG,

            // 选择首帧
            ElevatedButton.icon(
              onPressed: _pickFirstFrame,
              icon: const Icon(Icons.first_page),
              label: Text(_firstFrame == null ? '选择首帧' : '✅ 已选择首帧'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _firstFrame == null ? null : Colors.blue,
                foregroundColor: _firstFrame == null ? null : Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            AppSpacing.vGapMD,

            // 首帧预览和姿势选择
            if (_firstFrame != null) ...[
              const Text('首帧：', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Image.file(_firstFrame!, height: 150, fit: BoxFit.contain),
              AppSpacing.vGapMD,
              // 首帧姿势选择
              const Text('首帧姿势：', style: TextStyle(fontSize: 12, color: Colors.grey)),
              AppSpacing.vGapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPoseChip('walk', '行走', _firstFramePose == 'walk', (selected) {
                    if (selected) setState(() => _firstFramePose = 'walk');
                  }),
                  _buildPoseChip('sit', '坐姿', _firstFramePose == 'sit', (selected) {
                    if (selected) setState(() => _firstFramePose = 'sit');
                  }),
                  _buildPoseChip('rest', '休息', _firstFramePose == 'rest', (selected) {
                    if (selected) setState(() => _firstFramePose = 'rest');
                  }),
                  _buildPoseChip('sleep', '睡觉', _firstFramePose == 'sleep', (selected) {
                    if (selected) setState(() => _firstFramePose = 'sleep');
                  }),
                ],
              ),
              AppSpacing.vGapLG,
            ],

            // 选择尾帧
            ElevatedButton.icon(
              onPressed: _pickLastFrame,
              icon: const Icon(Icons.last_page),
              label: Text(_lastFrame == null ? '选择尾帧' : '✅ 已选择尾帧'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _lastFrame == null ? null : Colors.purple,
                foregroundColor: _lastFrame == null ? null : Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            AppSpacing.vGapMD,

            // 尾帧预览和姿势选择
            if (_lastFrame != null) ...[
              const Text('尾帧：', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Image.file(_lastFrame!, height: 150, fit: BoxFit.contain),
              AppSpacing.vGapMD,
              // 尾帧姿势选择
              const Text('尾帧姿势：', style: TextStyle(fontSize: 12, color: Colors.grey)),
              AppSpacing.vGapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPoseChip('walk', '行走', _lastFramePose == 'walk', (selected) {
                    if (selected) setState(() => _lastFramePose = 'walk');
                  }),
                  _buildPoseChip('sit', '坐姿', _lastFramePose == 'sit', (selected) {
                    if (selected) setState(() => _lastFramePose = 'sit');
                  }),
                  _buildPoseChip('rest', '休息', _lastFramePose == 'rest', (selected) {
                    if (selected) setState(() => _lastFramePose = 'rest');
                  }),
                  _buildPoseChip('sleep', '睡觉', _lastFramePose == 'sleep', (selected) {
                    if (selected) setState(() => _lastFramePose = 'sleep');
                  }),
                ],
              ),
              AppSpacing.vGapLG,
            ],

            // 显示生成的提示词
            if (_firstFrame != null && _lastFrame != null) ...[
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: AppSpacing.paddingMD,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 20),
                          AppSpacing.hGapSM,
                          Text(
                            '生成的提示词',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.vGapSM,
                      Text(
                        _generatePrompt(),
                        style: const TextStyle(fontSize: 14),
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
                    ],
                  ),
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
                    : const Icon(Icons.video_call),
                label: Text(_isGenerating ? '生成中...' : '生成过渡视频'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                        '✅ 过渡视频生成成功！',
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
      ),
    );
  }
}

