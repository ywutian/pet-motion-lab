import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../services/kling_generation_service.dart';
import '../providers/settings_provider.dart';
import '../utils/download_helper.dart';
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
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  String _species = '猫';

  bool _isGenerating = false;
  double _progress = 0.0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    // 从缓存加载宠物信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _breedController.text = settings.lastPetBreed.isEmpty ? '布偶猫' : settings.lastPetBreed;
      _colorController.text = settings.lastPetColor.isEmpty ? '蓝色' : settings.lastPetColor;
      setState(() {
        _species = settings.lastPetSpecies.isEmpty ? '猫' : settings.lastPetSpecies;
      });
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
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
    );

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _statusMessage = '正在上传图片...';
    });

    try {
      final service = KlingGenerationService();

      // 开始生成
      final petId = await service.startGeneration(
        imageFile: _selectedImage!,
        breed: _breedController.text,
        color: _colorController.text,
        species: _species,
      );

      // 轮询状态
      await for (final status in service.pollStatus(petId)) {
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
          // 分步模式按钮
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

            // 临时下载按钮
            const SizedBox(height: 16),
            _buildTempDownloadButton(),

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
          child: Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filled(
            onPressed: _isGenerating ? null : () {
              setState(() {
                _selectedImage = null;
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: FilledButton.icon(
        onPressed: _isGenerating ? null : _startGeneration,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('开始生成'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
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

  Widget _buildTempDownloadButton() {
    return FadeInUp(
      child: Card(
        elevation: 2,
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.download, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '临时下载：sit2walk 视频',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await DownloadHelper.downloadVideoAndSaveToGallery(
                    context: context,
                    filePath: 'output/kling_pipeline/pet_1763429522/videos/sit2walk.mp4',
                    customFileName: 'sit2walk_${DateTime.now().millisecondsSinceEpoch}.mp4',
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('下载到相册'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
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
    super.dispose();
  }
}

