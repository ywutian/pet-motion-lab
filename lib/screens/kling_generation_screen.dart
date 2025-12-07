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
  
  // 阶段控制：等待确认坐姿图
  bool _waitingForSitConfirmation = false;
  String? _sitImageUrl;  // 坐姿图 URL
  
  // 生成模式：true = 分阶段（先确认坐姿图），false = 一次性生成
  bool _useStepByStepMode = true;

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

        // 如果是从文件系统恢复的状态，说明任务已经完成
        if (status['from_filesystem'] == true) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KlingResultScreen(petId: petId),
              ),
            );
          }
          break;
        }
        
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
      _waitingForSitConfirmation = false;
      _sitImageUrl = null;
    });

    // 根据模式选择不同的生成流程
    if (_useStepByStepMode) {
      await _startStepByStepGeneration();
    } else {
      await _startFullGeneration();
    }
  }

  /// 分阶段生成：先生成坐姿图，确认后再继续
  Future<void> _startStepByStepGeneration() async {
    try {
      final service = KlingGenerationService();
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final config = GenerationConfig.fromSettings(settings);

      // 阶段1：只生成坐姿图片
      final petId = await service.startSitGeneration(
        imageFile: _selectedImage!,
        breed: _breedController.text,
        color: _colorController.text,
        species: _species,
        weight: _weightController.text,
        birthday: _birthdayController.text,
        config: config,
      );

      _processingPetId = petId;

      // 轮询状态，直到坐姿图生成完成
      _shouldStopPolling = false;
      await for (final status in service.pollStatus(petId, stopOnWaiting: true)) {
        if (_shouldStopPolling || !mounted) {
          debugPrint('🛑 停止轮询: shouldStop=$_shouldStopPolling, mounted=$mounted');
          break;
        }
        
        setState(() {
          _progress = status['progress'] / 100.0;
          _statusMessage = status['message'];
        });

        // 坐姿图生成完成，等待确认
        if (status['status'] == 'waiting_confirmation') {
          if (mounted) {
            setState(() {
              _waitingForSitConfirmation = true;
              _sitImageUrl = '${KlingGenerationService.baseUrl}/api/kling/download/$petId/base_images/sit.png';
            });
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
        setState(() {
          _isGenerating = false;
          _waitingForSitConfirmation = false;
        });
      }
    }
  }

  /// 一次性生成：直接生成全部内容
  Future<void> _startFullGeneration() async {
    try {
      final service = KlingGenerationService();
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final config = GenerationConfig.fromSettings(settings);

      // 直接开始完整生成
      final petId = await service.startGeneration(
        imageFile: _selectedImage!,
        breed: _breedController.text,
        color: _colorController.text,
        species: _species,
        weight: _weightController.text,
        birthday: _birthdayController.text,
        config: config,
      );

      _processingPetId = petId;

      // 轮询状态直到完成
      _shouldStopPolling = false;
      await for (final status in service.pollStatus(petId)) {
        if (_shouldStopPolling || !mounted) {
          break;
        }
        
        setState(() {
          _progress = status['progress'] / 100.0;
          _statusMessage = status['message'];
        });

        if (status['from_filesystem'] == true || status['status'] == 'completed') {
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
          _processingPetId = null;
        });
      }
    }
  }

  /// 确认坐姿图并继续生成视频
  Future<void> _confirmAndContinue() async {
    if (_processingPetId == null) return;

    setState(() {
      _waitingForSitConfirmation = false;
      _statusMessage = '继续生成视频中...';
    });

    try {
      final service = KlingGenerationService();
      
      // 调用继续生成 API
      await service.continueGeneration(_processingPetId!);

      // 继续轮询直到完成
      _shouldStopPolling = false;
      await for (final status in service.pollStatus(_processingPetId!)) {
        if (_shouldStopPolling || !mounted) {
          break;
        }
        
        setState(() {
          _progress = status['progress'] / 100.0;
          _statusMessage = status['message'];
        });

        if (status['from_filesystem'] == true || status['status'] == 'completed') {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KlingResultScreen(petId: _processingPetId!),
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
          SnackBar(content: Text('继续生成失败: $e')),
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

  /// 取消当前任务
  Future<void> _cancelGeneration() async {
    _shouldStopPolling = true;
    
    if (_processingPetId != null) {
      try {
        final service = KlingGenerationService();
        await service.deleteTask(_processingPetId!);
      } catch (e) {
        debugPrint('删除任务失败: $e');
      }
    }
    
    setState(() {
      _isGenerating = false;
      _waitingForSitConfirmation = false;
      _processingPetId = null;
      _sitImageUrl = null;
    });
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
    final theme = Theme.of(context);

    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 生成模式选择
          Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 16,
                vertical: isDesktop ? 12 : 8,
              ),
              child: Row(
                children: [
                  Icon(
                    _useStepByStepMode ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    color: theme.colorScheme.primary,
                    size: isDesktop ? 24 : 20,
                  ),
                  SizedBox(width: isDesktop ? 12 : 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _useStepByStepMode ? '分阶段生成' : '一次性生成',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: isDesktop ? 16 : 14,
                          ),
                        ),
                        Text(
                          _useStepByStepMode 
                              ? '先生成坐姿图确认后再继续' 
                              : '直接生成全部内容',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: isDesktop ? 13 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useStepByStepMode,
                    onChanged: _isGenerating ? null : (value) {
                      setState(() {
                        _useStepByStepMode = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: isDesktop ? 16 : 12),
          
          // 生成按钮
          FilledButton.icon(
            onPressed: _isGenerating ? null : _startGeneration,
            icon: const Icon(Icons.auto_awesome),
            label: Text(_useStepByStepMode ? '开始生成（分阶段）' : '开始生成'),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 24 : 18),
              textStyle: TextStyle(
                fontSize: isDesktop ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final isDesktop = Responsive.isDesktop(context);

    // 如果在等待确认坐姿图
    if (_waitingForSitConfirmation && _sitImageUrl != null) {
      return _buildSitConfirmationSection();
    }

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

  /// 坐姿图确认界面
  Widget _buildSitConfirmationSection() {
    final isDesktop = Responsive.isDesktop(context);
    final theme = Theme.of(context);

    return FadeIn(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: Responsive.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                    size: isDesktop ? 32 : 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '坐姿图生成完成，请确认',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 22 : 18,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: isDesktop ? 24 : 16),
              
              // 坐姿图预览
              Container(
                height: isDesktop ? 400 : 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _sitImageUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '图片加载失败',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              SizedBox(height: isDesktop ? 24 : 16),
              
              // 提示文字
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '请检查坐姿图是否正确（姿势、背景颜色等），确认后将继续生成所有视频',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isDesktop ? 24 : 16),
              
              // 操作按钮
              Row(
                children: [
                  // 取消按钮
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelGeneration,
                      icon: const Icon(Icons.close),
                      label: const Text('取消'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 16 : 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 确认继续按钮
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _confirmAndContinue,
                      icon: const Icon(Icons.check),
                      label: const Text('确认，继续生成视频'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 16 : 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
