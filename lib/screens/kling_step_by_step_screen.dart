import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../services/kling_step_service.dart';
import '../providers/settings_provider.dart';

class KlingStepByStepScreen extends StatefulWidget {
  const KlingStepByStepScreen({super.key});

  @override
  State<KlingStepByStepScreen> createState() => _KlingStepByStepScreenState();
}

class _KlingStepByStepScreenState extends State<KlingStepByStepScreen> {
  final KlingStepService _service = KlingStepService();
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  String _species = '猫';
  
  File? _selectedImage;
  String? _petId;
  int _currentStep = 0;
  bool _isProcessing = false;
  
  Map<String, dynamic>? _stepResults;

  @override
  void initState() {
    super.initState();
    // 加载缓存的宠物信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _breedController.text = settings.lastPetBreed.isEmpty ? '布偶猫' : settings.lastPetBreed;
      _colorController.text = settings.lastPetColor.isEmpty ? '蓝色' : settings.lastPetColor;
      setState(() {
        _species = settings.lastPetSpecies.isEmpty ? '猫' : settings.lastPetSpecies;
      });
    });
  }

  @override
  void dispose() {
    _breedController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _petId = null;
        _currentStep = 0;
        _stepResults = null;
      });
    }
  }

  Future<void> _initTask() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择宠物图片')),
      );
      return;
    }

    if (_breedController.text.isEmpty || _colorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写品种和颜色')),
      );
      return;
    }

    setState(() { _isProcessing = true; });

    try {
      // 保存宠物信息
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await settings.savePetInfo(
        _breedController.text,
        _colorController.text,
        _species,
      );

      final result = await _service.initTask(
        _selectedImage!,
        _breedController.text,
        _colorController.text,
        _species,
      );

      setState(() {
        _petId = result['pet_id'];
        _currentStep = 0;
        _stepResults = {};
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 任务已创建，可以开始执行步骤'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 初始化失败: $e')),
        );
      }
    } finally {
      setState(() { _isProcessing = false; });
    }
  }

  Future<void> _executeStep(int step, {File? customFile}) async {
    if (_petId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先初始化任务')),
      );
      return;
    }

    setState(() { _isProcessing = true; });

    try {
      dynamic result;
      switch (step) {
        case 1:
          result = await _service.executeStep1(_petId!, customFile: customFile);
          break;
        case 2:
          result = await _service.executeStep2(_petId!, customFile: customFile);
          break;
        case 3:
          result = await _service.executeStep3(_petId!, customFile: customFile);
          break;
        case 4:
          result = await _service.executeStep4(_petId!);
          break;
        case 5:
          result = await _service.executeStep5(_petId!);
          break;
        case 6:
          result = await _service.executeStep6(_petId!);
          break;
      }

      setState(() {
        if (_currentStep < step) {
          _currentStep = step;
        }
        _stepResults![step.toString()] = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 步骤$step完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 步骤$step失败: $e')),
        );
      }
    } finally {
      setState(() { _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分步生成'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 图片选择
            _buildImagePicker(),
            const SizedBox(height: 24),

            // 宠物信息
            _buildPetInfo(),
            const SizedBox(height: 24),

            // 初始化按钮
            _buildInitButton(),
            const SizedBox(height: 24),

            // 步骤列表
            if (_petId != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              _buildStepsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Card(
      child: InkWell(
        onTap: _pickImage,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[100],
          ),
          child: _selectedImage == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('点击选择宠物图片', style: TextStyle(color: Colors.grey)),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }

  Widget _buildPetInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '宠物信息',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _breedController,
              decoration: const InputDecoration(
                labelText: '品种',
                hintText: '例如：布偶猫',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: '颜色',
                hintText: '例如：蓝色',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
              onChanged: (value) {
                if (value != null) {
                  setState(() { _species = value; });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isProcessing
              ? [Colors.grey, Colors.grey[400]!]
              : [Colors.orange[600]!, Colors.orange[400]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isProcessing
            ? null
            : [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _initTask,
        icon: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.rocket_launch, size: 28),
        label: Text(
          _isProcessing ? '初始化中...' : '🚀 初始化任务',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStepsList() {
    final steps = [
      {'num': 1, 'title': '去除背景', 'icon': Icons.content_cut},
      {'num': 2, 'title': '生成基础坐姿图片', 'icon': Icons.image},
      {'num': 3, 'title': '生成初始过渡视频', 'icon': Icons.video_library},
      {'num': 4, 'title': '生成剩余过渡视频', 'icon': Icons.video_collection},
      {'num': 5, 'title': '生成循环视频', 'icon': Icons.loop},
      {'num': 6, 'title': '转换为GIF', 'icon': Icons.gif},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.stairs, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                '执行步骤',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '已完成 $_currentStep/6',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...steps.map((step) => _buildStepCard(
          step['num'] as int,
          step['title'] as String,
          step['icon'] as IconData,
        )),
      ],
    );
  }

  Widget _buildStepCard(int stepNum, String title, IconData icon) {
    final isCompleted = _currentStep >= stepNum;
    final canExecute = !_isProcessing;
    final canUpload = stepNum <= 3;  // 步骤1-3可以上传自定义文件

    return Card(
      elevation: isCompleted ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted ? Colors.green : Colors.grey[300]!,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                // 状态图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.white, size: 32)
                      : Icon(icon, color: Colors.grey[600], size: 28),
                ),
                const SizedBox(width: 16),
                // 标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '步骤 $stepNum',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 提示信息
            if (canUpload && !isCompleted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '可以点击"执行"自动处理，或点击"上传"使用自定义文件',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 操作按钮
            const SizedBox(height: 16),
            if (_isProcessing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('处理中...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              Row(
                children: [
                  // 执行按钮
                  if (canExecute)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _executeStep(stepNum),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('执行'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                  // 上传按钮
                  if (canUpload && canExecute) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _uploadCustomFile(stepNum),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('上传'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.orange, width: 2),
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ],

                  // 下载按钮
                  if (isCompleted) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showDownloadDialog(stepNum),
                        icon: const Icon(Icons.download),
                        label: const Text('下载'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadCustomFile(int stepNum) async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认上传'),
          content: Text('上传自定义文件将跳过步骤$stepNum的自动执行，直接使用您的文件。确认吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _executeStep(stepNum, customFile: File(file.path));
      }
    }
  }

  void _showDownloadDialog(int stepNum) {
    // TODO: 实现下载对话框
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('步骤$stepNum的下载功能即将实现')),
    );
  }
}

