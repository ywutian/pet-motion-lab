import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../services/kling_generation_service.dart';
import '../providers/settings_provider.dart';
import '../models/cross_platform_file.dart';
import '../utils/file_picker_helper.dart';
import 'kling_result_screen.dart';
import 'step_selector_screen.dart';

class KlingGenerationScreen extends StatefulWidget {
  const KlingGenerationScreen({super.key});

  @override
  State<KlingGenerationScreen> createState() => _KlingGenerationScreenState();
}

class _KlingGenerationScreenState extends State<KlingGenerationScreen> {
  CrossPlatformFile? _selectedImage;
  Uint8List? _imageBytes; // 用于预览

  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  String _species = '猫';

  bool _isGenerating = false;
  double _progress = 0.0;
  String _statusMessage = '';

  // 分步确认模式
  bool _stepConfirmMode = false;
  String _lastStep = '';

  // 多模型对比模式
  bool _multiModelMode = false;
  final List<Map<String, dynamic>> _multiModelTasks = [];

  // 可用模型列表
  static const List<Map<String, String>> _availableModels = [
    {'model_name': 'kling-v2-5-turbo', 'mode': 'pro', 'label': 'V2.5 Turbo'},
    {'model_name': 'kling-v2-1', 'mode': 'pro', 'label': 'V2.1 Pro'},
    {'model_name': 'kling-v1-5', 'mode': 'pro', 'label': 'V1.5 Pro'},
    {'model_name': 'kling-v1-6', 'mode': 'pro', 'label': 'V1.6 Pro'},
  ];

  @override
  void initState() {
    super.initState();
    // 从缓存加载宠物信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _breedController.text = settings.lastPetBreed.isEmpty ? '布偶猫' : settings.lastPetBreed;
      _colorController.text = settings.lastPetColor.isEmpty ? '蓝色' : settings.lastPetColor;
      _weightController.text = settings.lastPetWeight;
      _birthdayController.text = settings.lastPetBirthday;
      setState(() {
        _species = settings.lastPetSpecies.isEmpty ? '猫' : settings.lastPetSpecies;
      });
    });
  }

  Future<void> _pickImage() async {
    final file = await FilePickerHelper.pickImage();
    if (file != null) {
      setState(() {
        _selectedImage = file;
        _imageBytes = file.bytes;
      });
    }
  }

  /// 验证输入
  bool _validateInput() {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先上传宠物图片')),
      );
      return false;
    }
    if (_breedController.text.isEmpty || _colorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写品种和颜色')),
      );
      return false;
    }
    return true;
  }

  /// 普通生成
  Future<void> _startGeneration() async {
    if (!_validateInput()) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.savePetInfo(
      _breedController.text, _colorController.text, _species,
      weight: _weightController.text, birthday: _birthdayController.text,
    );

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _statusMessage = '正在上传图片...';
      _stepConfirmMode = false;
    });

    try {
      final service = KlingGenerationService();
      final petId = await service.startGeneration(
        imageFile: _selectedImage!,
        breed: _breedController.text,
        color: _colorController.text,
        species: _species,
        weight: _weightController.text,
        birthday: _birthdayController.text,
      );

      await for (final status in service.pollStatus(petId)) {
        setState(() {
          _progress = status['progress'] / 100.0;
          _statusMessage = status['message'];
        });

        if (status['status'] == 'completed') {
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => KlingResultScreen(petId: petId),
            ));
          }
          break;
        } else if (status['status'] == 'failed') {
          throw Exception(status['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// 分步确认生成
  Future<void> _startStepConfirmGeneration() async {
    if (!_validateInput()) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.savePetInfo(
      _breedController.text, _colorController.text, _species,
      weight: _weightController.text, birthday: _birthdayController.text,
    );

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _statusMessage = '正在上传图片...';
      _stepConfirmMode = true;
      _lastStep = '';
    });

    try {
      final service = KlingGenerationService();
      final petId = await service.startGeneration(
        imageFile: _selectedImage!,
        breed: _breedController.text,
        color: _colorController.text,
        species: _species,
        weight: _weightController.text,
        birthday: _birthdayController.text,
      );

      await for (final status in service.pollStatus(petId)) {
        final currentStep = status['current_step']?.toString() ?? '';

        setState(() {
          _progress = status['progress'] / 100.0;
          _statusMessage = status['message'];
        });

        // 检测步骤变化，弹窗确认
        if (currentStep.isNotEmpty && currentStep != _lastStep && currentStep != 'init') {
          _lastStep = currentStep;

          if (mounted) {
            final shouldContinue = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: Text('步骤完成: $currentStep'),
                content: Text('${status['message']}\n\n是否继续下一步？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消生成'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('继续'),
                  ),
                ],
              ),
            );

            if (shouldContinue != true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已取消生成')),
                );
              }
              break;
            }
          }
        }

        if (status['status'] == 'completed') {
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => KlingResultScreen(petId: petId),
            ));
          }
          break;
        } else if (status['status'] == 'failed') {
          throw Exception(status['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// 多模型对比生成
  Future<void> _startMultiModelGeneration() async {
    if (!_validateInput()) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.savePetInfo(
      _breedController.text, _colorController.text, _species,
      weight: _weightController.text, birthday: _birthdayController.text,
    );

    setState(() {
      _isGenerating = true;
      _multiModelMode = true;
      _multiModelTasks.clear();
      _statusMessage = '正在启动4个模型对比测试...';
    });

    try {
      final service = KlingGenerationService();

      // 启动4个模型的任务
      for (final model in _availableModels) {
        final petId = await service.startGeneration(
          imageFile: _selectedImage!,
          breed: _breedController.text,
          color: _colorController.text,
          species: _species,
          weight: _weightController.text,
          birthday: _birthdayController.text,
          videoModelName: model['model_name'],
          videoModelMode: model['mode'],
        );

        _multiModelTasks.add({
          'petId': petId,
          'model': model['label'],
          'status': 'processing',
          'progress': 0,
          'message': '启动中...',
        });
      }

      setState(() {
        _statusMessage = '已启动 ${_multiModelTasks.length} 个任务，正在并行生成...';
      });

      // 并行轮询所有任务
      bool allCompleted = false;
      while (!allCompleted && mounted) {
        allCompleted = true;

        for (int i = 0; i < _multiModelTasks.length; i++) {
          final task = _multiModelTasks[i];
          if (task['status'] == 'completed' || task['status'] == 'failed') continue;

          allCompleted = false;
          final status = await service.getStatus(task['petId']);

          setState(() {
            _multiModelTasks[i]['status'] = status['status'];
            _multiModelTasks[i]['progress'] = status['progress'];
            _multiModelTasks[i]['message'] = status['message'];
          });
        }

        // 计算总进度
        final totalProgress = _multiModelTasks.fold<int>(
          0, (sum, t) => sum + (t['progress'] as int));
        setState(() {
          _progress = totalProgress / (_multiModelTasks.length * 100);
          _statusMessage = _multiModelTasks.map((t) =>
            '${t['model']}: ${t['progress']}%').join(' | ');
        });

        if (!allCompleted) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      // 显示结果对比
      if (mounted) {
        _showMultiModelResults();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('多模型测试失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _multiModelMode = false;
        });
      }
    }
  }

  /// 显示多模型对比结果
  void _showMultiModelResults() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎯 多模型对比完成'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _multiModelTasks.map((task) => ListTile(
              leading: Icon(
                task['status'] == 'completed' ? Icons.check_circle : Icons.error,
                color: task['status'] == 'completed' ? Colors.green : Colors.red,
              ),
              title: Text(task['model']),
              subtitle: Text(task['message']),
              trailing: task['status'] == 'completed'
                ? TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => KlingResultScreen(petId: task['petId']),
                      ));
                    },
                    child: const Text('查看'),
                  )
                : null,
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 可灵AI宠物动画生成'),
        elevation: 0,
        actions: [
          // 步骤选择器按钮
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StepSelectorScreen(),
                ),
              );
            },
            icon: const Icon(Icons.grid_view),
            tooltip: '选择步骤',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上传图片区域
            _buildImageUploadSection(),
            const SizedBox(height: 32),

            // 配置区域
            _buildConfigSection(),
            const SizedBox(height: 32),

            // 生成按钮
            _buildGenerateButton(),

            // 进度显示
            if (_isGenerating) ...[
              const SizedBox(height: 32),
              _buildProgressSection(),
            ],

          ],
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return FadeInDown(
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: _isGenerating ? null : _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: _selectedImage == null
                ? _buildUploadPlaceholder()
                : _buildImagePreview(),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 80,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        Text(
          '点击上传宠物图片',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '支持 JPG、PNG 格式',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _imageBytes != null
              ? Image.memory(
                  _imageBytes!,
                  fit: BoxFit.cover,
                )
              : const Center(child: CircularProgressIndicator()),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filled(
            onPressed: _isGenerating ? null : () {
              setState(() {
                _selectedImage = null;
                _imageBytes = null;
              });
            },
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigSection() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '宠物信息',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              // 品种
              TextField(
                controller: _breedController,
                enabled: !_isGenerating,
                decoration: const InputDecoration(
                  labelText: '品种',
                  hintText: '如：布偶猫、金毛犬',
                  prefixIcon: Icon(Icons.pets),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 颜色
              TextField(
                controller: _colorController,
                enabled: !_isGenerating,
                decoration: const InputDecoration(
                  labelText: '颜色',
                  hintText: '如：蓝色、金色',
                  prefixIcon: Icon(Icons.palette),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 物种
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '猫', label: Text('猫'), icon: Icon(Icons.pets)),
                  ButtonSegment(value: '犬', label: Text('犬'), icon: Icon(Icons.pets)),
                ],
                selected: {_species},
                onSelectionChanged: _isGenerating ? null : (Set<String> newSelection) {
                  setState(() {
                    _species = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 重量
              TextField(
                controller: _weightController,
                enabled: !_isGenerating,
                decoration: const InputDecoration(
                  labelText: '重量（可选）',
                  hintText: '如：5kg、3.5kg',
                  prefixIcon: Icon(Icons.monitor_weight),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 生日
              TextField(
                controller: _birthdayController,
                enabled: !_isGenerating,
                decoration: const InputDecoration(
                  labelText: '生日（可选）',
                  hintText: '如：2020-01-01',
                  prefixIcon: Icon(Icons.cake),
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  if (_isGenerating) return;
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _birthdayController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
                readOnly: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Column(
        children: [
          // 主按钮：一键生成
          FilledButton.icon(
            onPressed: _isGenerating ? null : _startGeneration,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('一键生成'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          // 两个小按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _startStepConfirmGeneration,
                  icon: const Icon(Icons.playlist_play, size: 18),
                  label: const Text('分步确认'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _startMultiModelGeneration,
                  icon: const Icon(Icons.compare_arrows, size: 18),
                  label: const Text('多模型对比'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return FadeIn(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _breedController.dispose();
    _colorController.dispose();
    _weightController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }
}

