import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../services/kling_generation_service.dart';
import '../providers/settings_provider.dart';
import '../models/cross_platform_file.dart';
import '../utils/file_picker_helper.dart';
import '../utils/responsive.dart';
import '../widgets/responsive_layout.dart';
import 'kling_result_screen.dart';
import 'kling_step_by_step_screen.dart';
import 'kling_steps/step_init_screen.dart';
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
  
  // 用于取消轮询
  bool _shouldStopPolling = false;
  
  // 正在进行的任务（用于恢复）
  String? _processingPetId;

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
      
      // 检查是否有正在进行的任务
      _checkProcessingTask();
    });
  }
  
  /// 检查后端是否有正在进行的任务
  Future<void> _checkProcessingTask() async {
    try {
      final service = KlingGenerationService();
      final history = await service.getHistory(
        page: 1,
        pageSize: 1,
        statusFilter: 'processing',
      );
      
      final items = history['items'] as List? ?? [];
      if (items.isNotEmpty && mounted) {
        final task = items[0];
        _processingPetId = task['pet_id'];
        _showResumeDialog(task);
      }
    } catch (e) {
      debugPrint('检查进行中任务失败: $e');
    }
  }
  
  /// 显示恢复任务对话框
  void _showResumeDialog(Map<String, dynamic> task) {
    final breed = task['breed'] ?? '未知';
    final progress = task['progress'] ?? 0;
    final message = task['message'] ?? '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('发现未完成的任务'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('品种: $breed'),
            const SizedBox(height: 8),
            Text('进度: $progress%'),
            const SizedBox(height: 8),
            Text('状态: $message', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processingPetId = null;
            },
            child: const Text('忽略，开始新任务'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeTask(task['pet_id']);
            },
            child: const Text('继续查看进度'),
          ),
        ],
      ),
    );
  }
  
  /// 恢复查看任务进度
  Future<void> _resumeTask(String petId) async {
    setState(() {
      _isGenerating = true;
      _statusMessage = '正在恢复任务...';
    });
    
    try {
      final service = KlingGenerationService();
      
      // 开始轮询状态
      _shouldStopPolling = false;
      await for (final status in service.pollStatus(petId)) {
        if (_shouldStopPolling || !mounted) {
          debugPrint('🛑 停止轮询: shouldStop=$_shouldStopPolling, mounted=$mounted');
          break;
        }
        
        setState(() {
          _progress = status['progress'] / 100.0;
          _statusMessage = status['message'];
        });

        if (status['status'] == 'completed') {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KlingResultScreen(petId: petId),
              ),
            );
          }
          break;
        } else if (status['status'] == 'failed') {
          throw Exception(status['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复任务失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _processingPetId = null;
        });
      }
    }
  }

  @override
  void dispose() {
    // 停止轮询
    _shouldStopPolling = true;
    _breedController.dispose();
    _colorController.dispose();
    _weightController.dispose();
    _birthdayController.dispose();
    super.dispose();
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

  Future<void> _startGeneration() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先上传宠物图片')),
      );
      return;
    }

    if (_breedController.text.isEmpty || _colorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写品种和颜色')),
      );
      return;
    }

    // 保存宠物信息到缓存
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.savePetInfo(
      _breedController.text,
      _colorController.text,
      _species,
      weight: _weightController.text,
      birthday: _birthdayController.text,
    );

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _statusMessage = '正在上传图片...';
    });

    try {
      final service = KlingGenerationService();
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      // 从设置中获取生成配置
      final config = GenerationConfig.fromSettings(settings);

      // 开始生成（跨平台）
      final petId = await service.startGeneration(
        imageFile: _selectedImage!,
        breed: _breedController.text,
        color: _colorController.text,
        species: _species,
        weight: _weightController.text,
        birthday: _birthdayController.text,
        config: config,
      );

      // 轮询状态
      _shouldStopPolling = false;
      await for (final status in service.pollStatus(petId)) {
        // 检查是否应该停止轮询（页面已离开）
        if (_shouldStopPolling || !mounted) {
          debugPrint('🛑 停止轮询: shouldStop=$_shouldStopPolling, mounted=$mounted');
          break;
        }
        
        setState(() {
          _progress = status['progress'] / 100.0;
          _statusMessage = status['message'];
        });

        if (status['status'] == 'completed') {
          // 生成完成，跳转到结果页面
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KlingResultScreen(petId: petId),
              ),
            );
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
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final spacing = Responsive.spacing(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 可灵AI宠物动画生成'),
        elevation: 0,
        centerTitle: !isDesktop,
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
          // 分步模式按钮
          if (isDesktop)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StepInitScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.stairs),
              label: const Text('分步模式'),
            )
          else
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StepInitScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.stairs),
              tooltip: '分步模式',
            ),
        ],
      ),
      body: ResponsiveScrollLayout(
        padding: Responsive.pagePadding(context),
        maxWidth: 1200,
        children: [
          // 桌面端使用两栏布局
          if (isDesktop)
            _buildDesktopLayout(spacing)
          else
            _buildMobileLayout(spacing),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(double spacing) {
    return ResponsiveTwoColumn(
      leftFlex: 1,
      rightFlex: 1,
      spacing: spacing * 2,
      leftChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImageUploadSection(),
        ],
      ),
      rightChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConfigSection(),
          SizedBox(height: spacing),
          _buildGenerateButton(),
          if (_isGenerating) ...[
            SizedBox(height: spacing),
            _buildProgressSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileLayout(double spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImageUploadSection(),
        SizedBox(height: spacing * 1.5),
        _buildConfigSection(),
        SizedBox(height: spacing * 1.5),
        _buildGenerateButton(),
        if (_isGenerating) ...[
          SizedBox(height: spacing * 1.5),
          _buildProgressSection(),
        ],
      ],
    );
  }

  Widget _buildImageUploadSection() {
    final isDesktop = Responsive.isDesktop(context);
    final height = isDesktop ? 400.0 : 280.0;

    return FadeInDown(
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: _isGenerating ? null : _pickImage,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
    final isDesktop = Responsive.isDesktop(context);
    final iconSize = isDesktop ? 100.0 : 72.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: iconSize,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        Text(
          '点击上传宠物图片',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: isDesktop ? 22 : 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '支持 JPG、PNG 格式',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isGenerating ? null : _pickImage,
            icon: const Icon(Icons.folder_open),
            label: const Text('选择文件'),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview() {
    final theme = Theme.of(context);
    
    return Stack(
      children: [
        // 背景容器
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: _imageBytes != null
                  ? Center(
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain, // 完整显示图片，不裁切
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        // 关闭按钮
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
        // 重新选择按钮
        Positioned(
          bottom: 8,
          right: 8,
          child: FilledButton.tonalIcon(
            onPressed: _isGenerating ? null : _pickImage,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新选择'),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigSection() {
    final isDesktop = Responsive.isDesktop(context);
    final padding = Responsive.cardPadding(context);

    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '宠物信息',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: isDesktop ? 22 : 18,
                ),
              ),
              SizedBox(height: isDesktop ? 24 : 16),

              // 桌面端使用两列布局
              if (isDesktop)
                _buildDesktopFormFields()
              else
                _buildMobileFormFields(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFormFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _breedController,
                enabled: !_isGenerating,
                decoration: const InputDecoration(
                  labelText: '品种',
                  hintText: '如：布偶猫、金毛犬',
                  prefixIcon: Icon(Icons.pets),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _colorController,
                enabled: !_isGenerating,
                decoration: const InputDecoration(
                  labelText: '颜色',
                  hintText: '如：蓝色、金色',
                  prefixIcon: Icon(Icons.palette),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
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
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightController,
                enabled: !_isGenerating,
                decoration: const InputDecoration(
                  labelText: '重量（可选）',
                  hintText: '如：5kg',
                  prefixIcon: Icon(Icons.monitor_weight),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _birthdayController,
                enabled: !_isGenerating,
                decoration: const InputDecoration(
                  labelText: '生日（可选）',
                  hintText: '如：2020-01-01',
                  prefixIcon: Icon(Icons.cake),
                  border: OutlineInputBorder(),
                ),
                onTap: () => _selectBirthday(),
                readOnly: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFormFields() {
    return Column(
      children: [
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
        TextField(
          controller: _birthdayController,
          enabled: !_isGenerating,
          decoration: const InputDecoration(
            labelText: '生日（可选）',
            hintText: '如：2020-01-01',
            prefixIcon: Icon(Icons.cake),
            border: OutlineInputBorder(),
          ),
          onTap: () => _selectBirthday(),
          readOnly: true,
        ),
      ],
    );
  }

  Future<void> _selectBirthday() async {
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
  }

  Widget _buildGenerateButton() {
    final isDesktop = Responsive.isDesktop(context);

    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: FilledButton.icon(
        onPressed: _isGenerating ? null : _startGeneration,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('开始生成'),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 24 : 18),
          textStyle: TextStyle(
            fontSize: isDesktop ? 20 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final isDesktop = Responsive.isDesktop(context);

    return FadeIn(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: Responsive.cardPadding(context),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _progress,
                minHeight: isDesktop ? 10 : 8,
                borderRadius: BorderRadius.circular(5),
              ),
              SizedBox(height: isDesktop ? 20 : 16),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: isDesktop ? 16 : 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: isDesktop ? 28 : 24,
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
