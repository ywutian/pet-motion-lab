import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/kling_step_service.dart';
import '../../utils/download_helper.dart';
import 'step3_generate_initial_videos_screen.dart';

class Step2GenerateBaseImageScreen extends StatefulWidget {
  final String petId;
  final String breed;
  final String color;
  final String species;
  final String step1Result;

  const Step2GenerateBaseImageScreen({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
    required this.step1Result,
  });

  @override
  State<Step2GenerateBaseImageScreen> createState() => _Step2GenerateBaseImageScreenState();
}

class _Step2GenerateBaseImageScreenState extends State<Step2GenerateBaseImageScreen> {
  File? _uploadedImage;
  String? _resultImagePath;
  bool _isProcessing = false;
  String _statusMessage = '';

  final ImagePicker _picker = ImagePicker();
  final KlingStepService _service = KlingStepService();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _uploadedImage = File(image.path);
      });
    }
  }

  Future<void> _executeStep() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在使用可灵AI生成坐姿图片...';
    });

    try {
      final result = await _service.executeStep2(widget.petId);
      
      setState(() {
        _resultImagePath = result['result'];
        _statusMessage = '坐姿图片生成完成！';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('步骤2失败: $e')),
        );
      }
    }
  }

  Future<void> _uploadCustomImage() async {
    if (_uploadedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择图片')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '正在上传自定义坐姿图片...';
    });

    try {
      final result = await _service.executeStep2(widget.petId, customFile: _uploadedImage);
      
      setState(() {
        _resultImagePath = result['result'];
        _statusMessage = '已使用自定义坐姿图片！';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '上传失败: $e';
        _isProcessing = false;
      });
    }
  }

  void _goToNextStep() {
    if (_resultImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完成步骤2')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step3GenerateInitialVideosScreen(
          petId: widget.petId,
          breed: widget.breed,
          color: widget.color,
          species: widget.species,
          step2Result: _resultImagePath!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('步骤2: 生成坐姿图片'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 步骤说明
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '步骤说明',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('使用可灵AI kling-v2模型，基于透明背景图片生成卡通3D风格的坐姿图片。'),
                    const SizedBox(height: 8),
                    Text('宠物信息: ${widget.species} - ${widget.breed} - ${widget.color}'),
                    const SizedBox(height: 8),
                    const Text('您也可以上传自己准备好的坐姿图片跳过此步骤。'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 选项1: 自动执行
            _buildAutoExecuteSection(),
            const SizedBox(height: 16),

            // 选项2: 上传自定义图片
            _buildUploadSection(),
            const SizedBox(height: 24),

            // 结果显示
            if (_resultImagePath != null) _buildResultSection(),
            const SizedBox(height: 24),

            // 状态消息
            if (_statusMessage.isNotEmpty)
              Card(
                color: _isProcessing ? Colors.orange.shade50 : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (_isProcessing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_statusMessage)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // 下一步按钮
            ElevatedButton.icon(
              onPressed: _resultImagePath != null && !_isProcessing ? _goToNextStep : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('下一步: 生成初始视频'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoExecuteSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  '选项1: 自动执行',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('使用可灵AI kling-v2模型自动生成坐姿图片'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _executeStep,
              icon: const Icon(Icons.play_arrow),
              label: const Text('执行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  '选项2: 上传自定义图片',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('如果您已经有准备好的坐姿图片，可以直接上传'),
            const SizedBox(height: 12),
            if (_uploadedImage != null)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_uploadedImage!, fit: BoxFit.contain),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('选择图片'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                if (_uploadedImage != null)
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _uploadCustomImage,
                    icon: const Icon(Icons.upload),
                    label: const Text('上传'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  '步骤完成',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('结果路径: $_resultImagePath'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await DownloadHelper.downloadAndSaveToGallery(
                  context: context,
                  filePath: _resultImagePath!,
                  customFileName: 'sit_${DateTime.now().millisecondsSinceEpoch}.png',
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('保存到相册'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

