import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/kling_step_service.dart';
import '../../providers/settings_provider.dart';
import 'step1_remove_background_screen.dart';

class StepInitScreen extends StatefulWidget {
  const StepInitScreen({super.key});

  @override
  State<StepInitScreen> createState() => _StepInitScreenState();
}

class _StepInitScreenState extends State<StepInitScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  String _species = '猫';
  bool _isInitializing = false;

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

  Future<void> _initializeTask() async {
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

    setState(() {
      _isInitializing = true;
    });

    try {
      final service = KlingStepService();
      final result = await service.initTask(
        _selectedImage!,
        _breedController.text,
        _colorController.text,
        _species,
      );

      final petId = result['pet_id'];

      // 保存宠物信息到缓存
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await settings.savePetInfo(
        _breedController.text,
        _colorController.text,
        _species,
      );

      if (mounted) {
        // 导航到步骤1
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Step1RemoveBackgroundScreen(
              petId: petId,
              breed: _breedController.text,
              color: _colorController.text,
              species: _species,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 分步生成模式'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 说明卡片
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.deepPurple.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '分步生成流程',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('每个步骤都是独立的页面，您可以：'),
                    const SizedBox(height: 8),
                    const Text('✅ 查看每个步骤的详细说明'),
                    const Text('✅ 选择自动执行或上传自定义文件'),
                    const Text('✅ 下载每个步骤的结果'),
                    const Text('✅ 如果某步失败，可以重新执行'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 上传图片
            _buildImageSection(),
            const SizedBox(height: 24),

            // 宠物信息
            _buildPetInfoSection(),
            const SizedBox(height: 32),

            // 开始按钮
            ElevatedButton.icon(
              onPressed: _isInitializing ? null : _initializeTask,
              icon: _isInitializing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rocket_launch),
              label: Text(_isInitializing ? '正在初始化...' : '🚀 开始分步生成'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _isInitializing ? null : _pickImage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: _selectedImage == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('点击上传宠物图片', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_selectedImage!, fit: BoxFit.contain),
                ),
        ),
      ),
    );
  }

  Widget _buildPetInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('宠物信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _breedController,
              decoration: const InputDecoration(
                labelText: '品种',
                hintText: '例如：布偶猫',
                border: OutlineInputBorder(),
              ),
              enabled: !_isInitializing,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: '颜色',
                hintText: '例如：蓝色',
                border: OutlineInputBorder(),
              ),
              enabled: !_isInitializing,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _species,
              decoration: const InputDecoration(
                labelText: '物种',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '猫', child: Text('猫')),
                DropdownMenuItem(value: '犬', child: Text('犬')),
              ],
              onChanged: _isInitializing
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _species = value;
                        });
                      }
                    },
            ),
          ],
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

