import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/upload_image.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/rembg_model_provider.dart';
import '../services/generation_service.dart';
import '../services/purity_detector.dart';
import '../services/cutting_service.dart';
import '../utils/responsive.dart';
import 'task_detail_screen.dart';

class GenerationConfigScreen extends StatefulWidget {
  final List<UploadImage> uploadedImages;

  const GenerationConfigScreen({
    super.key,
    required this.uploadedImages,
  });

  @override
  State<GenerationConfigScreen> createState() => _GenerationConfigScreenState();
}

class _GenerationConfigScreenState extends State<GenerationConfigScreen> {
  final _templateController = TextEditingController();
  final _promptController = TextEditingController();
  
  bool _generateStatic = true;
  bool _generateMotion = false;
  bool _cutAfterUpload = false;
  bool _cutAfterGenerate = false;
  
  String? _selectedStaticModel;
  String? _selectedMotionModel;
  String? _selectedCuttingTool;
  String _resolution = '1080x1080';
  int _duration = 5;
  int _fps = 24;
  
  bool _isGenerating = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _selectedStaticModel = settings.defaultStaticModel;
    _selectedMotionModel = settings.defaultMotionModel;
    _selectedCuttingTool = settings.defaultCuttingTool;
    _resolution = settings.defaultResolution;
    _duration = settings.defaultDuration;
    _fps = settings.defaultFps;
    _cutAfterUpload = settings.autoCut;
    
    _templateController.text = 'custom_${DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now())}';
    _promptController.text = '卡通3D宠物，纯白背景，高质量渲染';
  }

  @override
  void dispose() {
    _templateController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    if (!_generateStatic && !_generateMotion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一种生成模式')),
      );
      return;
    }

    final taskProvider = context.read<TaskProvider>();

    setState(() {
      _isGenerating = true;
      _progress = 0;
    });

    try {
      final task = await _performGeneration();
      
      await taskProvider.saveTask(task);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(taskId: task.taskId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<Task> _performGeneration() async {
    final settings = context.read<SettingsProvider>();
    final modelProvider = context.read<RembgModelProvider>();
    final taskId = const Uuid().v4();
    final List<ImageData> imageDataList = [];
    final List<String> staticOutputs = [];
    final List<String> videoOutputs = [];

    int totalSteps = widget.uploadedImages.length;
    if (_generateStatic) totalSteps += widget.uploadedImages.length;
    if (_generateMotion) totalSteps += 1;
    int currentStep = 0;

    for (var uploadImage in widget.uploadedImages) {
      final stages = <Stage>[];
      
      var currentFile = uploadImage.file;
      var originalPurity = await PurityDetector.detect(currentFile);
      stages.add(Stage(
        stage: 'original',
        purity: originalPurity,
        ts: DateTime.now(),
      ));

      setState(() => _progress = ++currentStep / totalSteps);

      if (_cutAfterUpload) {
        final cutResult = await CuttingService.cutImage(
          inputFile: currentFile,
          tool: _selectedCuttingTool!,
          apiKey: settings.clipdropApiKey,
          modelType: _selectedCuttingTool == 'rembg_local' 
              ? modelProvider.selectedModel 
              : null,
        );
        
        if (cutResult.success) {
          currentFile = cutResult.outputFile;
          final cutPurity = await PurityDetector.detect(currentFile);
          stages.add(Stage(
            stage: 'postCut@upload',
            purity: cutPurity,
            ts: DateTime.now(),
            cut: CutInfo(
              tool: _selectedCuttingTool!,
              latencyMs: cutResult.latencyMs,
              fileOut: currentFile.path,
            ),
            deltaPs: cutPurity.ps - originalPurity.ps,
          ));
        }
      }

      if (_generateStatic) {
        final genResult = await GenerationService.generateStatic(
          inputFile: currentFile,
          model: _selectedStaticModel!,
          prompt: _promptController.text,
          resolution: _resolution,
          apiKey: settings.leonardoApiKey,
        );
        
        setState(() => _progress = ++currentStep / totalSteps);
        
        if (genResult.success) {
          staticOutputs.add(genResult.outputFile.path);
          currentFile = genResult.outputFile;
          
          final genPurity = await PurityDetector.detect(currentFile);
          stages.add(Stage(
            stage: 'postGen',
            purity: genPurity,
            ts: DateTime.now(),
          ));

          if (_cutAfterGenerate) {
            final cutResult = await CuttingService.cutImage(
              inputFile: currentFile,
              tool: _selectedCuttingTool!,
              apiKey: settings.clipdropApiKey,
              modelType: _selectedCuttingTool == 'rembg_local' 
                  ? modelProvider.selectedModel 
                  : null,
            );
            
            if (cutResult.success) {
              currentFile = cutResult.outputFile;
              final cutPurity = await PurityDetector.detect(currentFile);
              stages.add(Stage(
                stage: 'postCut@generate',
                purity: cutPurity,
                ts: DateTime.now(),
                cut: CutInfo(
                  tool: _selectedCuttingTool!,
                  latencyMs: cutResult.latencyMs,
                  fileOut: currentFile.path,
                ),
                deltaPs: cutPurity.ps - genPurity.ps,
              ));
            }
          }
        }
      }

      imageDataList.add(ImageData(
        id: uploadImage.id,
        pose: uploadImage.pose,
        angle: uploadImage.angle,
        fileIn: uploadImage.file.path,
        stages: stages,
        species: uploadImage.species,
        tag: uploadImage.tag.isNotEmpty ? uploadImage.tag : null,
        staticPrompt: uploadImage.staticPrompt.isNotEmpty 
            ? uploadImage.staticPrompt 
            : _promptController.text,
        motionPrompt: uploadImage.motionPrompt.isNotEmpty 
            ? uploadImage.motionPrompt 
            : _promptController.text,
      ));
    }

    if (_generateMotion) {
      final inputFiles = widget.uploadedImages.map((img) => img.file).toList();
      final motionResult = await GenerationService.generateMotion(
        inputFiles: inputFiles,
        model: _selectedMotionModel!,
        prompt: _promptController.text,
        resolution: _resolution,
        duration: _duration,
        fps: _fps,
        apiKey: settings.klingApiKey,
      );
      
      setState(() => _progress = ++currentStep / totalSteps);
      
      if (motionResult.success) {
        videoOutputs.add(motionResult.outputFile.path);
      }
    }

    return Task(
      taskId: taskId,
      comboTemplate: _templateController.text,
      species: widget.uploadedImages
          .map((img) => img.species)
          .toSet()
          .toList(),
      generation: Generation(
        staticModel: _selectedStaticModel ?? '',
        motionModel: _selectedMotionModel ?? '',
        resolution: _resolution,
        duration: _duration,
        fps: _fps,
        prompt: _promptController.text,
      ),
      cutting: Cutting(
        mode: _getCuttingMode(),
        autoTool: true,
      ),
      images: imageDataList,
      outputs: Outputs(
        statics: staticOutputs,
        videos: videoOutputs,
        gifs: [],
      ),
      status: 'completed',
      createdAt: DateTime.now(),
    );
  }

  String _getCuttingMode() {
    if (_cutAfterUpload && _cutAfterGenerate) return 'doubleCut';
    if (_cutAfterUpload) return 'cutAfterUpload';
    if (_cutAfterGenerate) return 'cutAfterGenerate';
    return 'noCut';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('生成配置'),
      ),
      body: Stack(
        children: [
          _isGenerating ? _buildGeneratingUI() : _buildConfigUI(theme),
          if (!_isGenerating)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _startGeneration,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始生成'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGeneratingUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 32),
            Text(
              '正在生成中...',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigUI(ThemeData theme) {
    final padding = Responsive.horizontalPadding(context);
    final isDesktop = Responsive.isDesktop(context);
    final cardWidth = isDesktop ? Responsive.cardWidth(context) : double.infinity;
    final horizontalSpacing = isDesktop ? 16.0 : 0.0;

    final sections = <Widget>[
      _buildSectionCard(
        width: cardWidth,
        title: '组合模板',
        subtitle: '为此次实验命名，便于历史对比与导出报告',
        child: TextField(
          controller: _templateController,
          decoration: const InputDecoration(
            hintText: '如 custom_2025_静态对比',
          ),
        ),
      ),
      _buildSectionCard(
        width: cardWidth,
        title: '生成模式',
        subtitle: '可同时生成静态图与动态图，也可以单独测试',
        child: Column(
          children: [
            _buildSwitchRow(
              title: '生成静态图',
              subtitle: '针对每张输入图输出高质量静态结果',
              value: _generateStatic,
              onChanged: (value) => _generateStatic = value,
            ),
            const SizedBox(height: 12),
            _buildSwitchRow(
              title: '生成动态图',
              subtitle: '根据上传顺序生成动作视频或过渡动画',
              value: _generateMotion,
              onChanged: (value) => _generateMotion = value,
            ),
            if (!_generateStatic && !_generateMotion)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildInfoChip(
                  icon: Icons.info_outline,
                  label: '至少选择一种生成模式才能继续',
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
      if (_generateStatic)
        _buildSectionCard(
          width: cardWidth,
          title: '静态模型',
          subtitle: '选择静态图生成引擎与默认输出配置',
          child: _buildDropdown<String>(
            label: '静态模型',
            value: _selectedStaticModel,
            entries: const [
              DropdownMenuEntry(value: 'Leonardo.ai-v2', label: 'Leonardo.ai v2'),
              DropdownMenuEntry(value: 'Runware', label: 'Runware'),
              DropdownMenuEntry(value: 'Mock', label: '模拟模型'),
            ],
            onSelected: (value) => _selectedStaticModel = value ?? _selectedStaticModel,
          ),
        ),
      if (_generateMotion)
        _buildSectionCard(
          width: cardWidth,
          title: '动态模型',
          subtitle: '生成视频/过渡动画时使用的模型与参数',
          child: Column(
            children: [
              _buildDropdown<String>(
                label: '动态模型',
                value: _selectedMotionModel,
                entries: const [
                  DropdownMenuEntry(value: 'KlingAI-v1.6', label: 'Kling AI v1.6'),
                  DropdownMenuEntry(value: 'Runware', label: 'Runware'),
                  DropdownMenuEntry(value: 'AnimateDiff', label: 'AnimateDiff'),
                  DropdownMenuEntry(value: 'Mock', label: '模拟模型'),
                ],
                onSelected: (value) => _selectedMotionModel = value ?? _selectedMotionModel,
              ),
              const SizedBox(height: 16),
              _buildDropdown<String>(
                label: '输出分辨率',
                value: _resolution,
                entries: const [
                  DropdownMenuEntry(value: '512x512', label: '512 × 512'),
                  DropdownMenuEntry(value: '1024x1024', label: '1024 × 1024'),
                  DropdownMenuEntry(value: '1080x1080', label: '1080 × 1080'),
                  DropdownMenuEntry(value: '1920x1080', label: '1920 × 1080'),
                ],
                onSelected: (value) => _resolution = value ?? _resolution,
              ),
              const SizedBox(height: 16),
              _buildSlider(
                title: '视频时长',
                value: _duration.toDouble(),
                min: 3,
                max: 10,
                divisions: 7,
                unit: '秒',
                onChanged: (value) => _duration = value.toInt(),
              ),
              const SizedBox(height: 12),
              _buildDropdown<int>(
                label: '帧率 (FPS)',
                value: _fps,
                entries: const [
                  DropdownMenuEntry(value: 24, label: '24 FPS'),
                  DropdownMenuEntry(value: 30, label: '30 FPS'),
                  DropdownMenuEntry(value: 60, label: '60 FPS'),
                ],
                onSelected: (value) => _fps = value ?? _fps,
              ),
            ],
          ),
        ),
      _buildSectionCard(
        width: cardWidth,
        title: '全局提示词',
        subtitle: '为所有图片与视频提供默认 Prompt，可在图片层面单独覆盖',
        child: TextField(
          controller: _promptController,
          maxLines: 4,
          decoration: const InputDecoration(
            alignLabelWithHint: true,
            hintText: '输入生成提示词，支持中英文并会自动记录到历史中',
          ),
        ),
      ),
      _buildSectionCard(
        width: cardWidth,
        title: '裁剪与纯净度',
        subtitle: '选择默认裁剪工具，并设置上传/生成阶段是否自动裁剪',
        child: Column(
          children: [
            _buildDropdown<String>(
              label: '裁剪工具',
              value: _selectedCuttingTool,
              entries: const [
                DropdownMenuEntry(value: 'rembg_local', label: '本地算法 (免费)'),
                DropdownMenuEntry(value: 'clipdrop', label: 'Clipdrop API'),
              ],
              onSelected: (value) => _selectedCuttingTool = value ?? _selectedCuttingTool,
            ),
            const SizedBox(height: 16),
            _buildSwitchRow(
              title: '上传后自动裁剪',
              subtitle: '上传完成后立即清理背景并检测纯净度',
              value: _cutAfterUpload,
              onChanged: (value) => _cutAfterUpload = value,
            ),
            const SizedBox(height: 12),
            _buildSwitchRow(
              title: '生成后自动裁剪',
              subtitle: '生成静态图后再次裁剪对比纯净度提升',
              value: _cutAfterGenerate,
              onChanged: (value) => _cutAfterGenerate = value,
            ),
          ],
        ),
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        padding.left,
        16,
        padding.right,
        MediaQuery.of(context).padding.bottom + 120,
      ),
      child: Wrap(
        spacing: horizontalSpacing,
        runSpacing: 16,
        children: sections,
      ),
    );
  }

  Widget _buildSectionCard({
    required double width,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (selected) => setState(() => onChanged(selected)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuEntry<T>> entries,
    required ValueChanged<T?> onSelected,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<T>(
          width: constraints.maxWidth,
          initialSelection: value,
          label: Text(label),
          dropdownMenuEntries: entries,
          onSelected: (selection) => setState(() => onSelected(selection)),
          menuHeight: 240,
        );
      },
    );
  }

  Widget _buildSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            Chip(
              label: Text('${value.toStringAsFixed(0)} $unit'),
            ),
          ],
        ),
        Slider.adaptive(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toStringAsFixed(0)}$unit',
          onChanged: (selected) => setState(() => onChanged(selected)),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 16, color: color ?? theme.colorScheme.primary),
      label: Text(label),
      side: BorderSide(color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.4)),
      backgroundColor: (color ?? theme.colorScheme.primary).withValues(alpha: 0.08),
      labelStyle: TextStyle(color: color ?? theme.colorScheme.primary),
    );
  }
}

