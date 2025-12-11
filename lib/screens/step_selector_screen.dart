import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_scaffold.dart';
import '../theme/app_spacing.dart';
import 'kling_steps/step_init_screen_refactored.dart';
import 'kling_steps/step1_remove_background_screen.dart';
import 'kling_steps/step2_generate_base_image_screen_refactored.dart';
import 'kling_steps/step3_generate_initial_videos_screen_refactored.dart';
import 'kling_steps/step4_generate_remaining_videos_screen_refactored.dart';
import 'kling_steps/step5_generate_loop_videos_screen_refactored.dart';
import 'kling_steps/step6_convert_to_gifs_screen_refactored.dart';

/// 步骤选择界面 - 可以直接跳转到任意步骤
class StepSelectorScreen extends StatefulWidget {
  const StepSelectorScreen({super.key});

  @override
  State<StepSelectorScreen> createState() => _StepSelectorScreenState();
}

class _StepSelectorScreenState extends State<StepSelectorScreen> {
  final TextEditingController _petIdController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  String _species = '猫';

  // 上传的文件
  File? _uploadedImageForStep2; // 步骤2需要的去背景图片
  File? _uploadedImageForStep3; // 步骤3需要的坐姿图片

  final ImagePicker _picker = ImagePicker();

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
    _petIdController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  // 上传图片
  Future<void> _pickImageForStep(int stepNumber) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (stepNumber == 2) {
          _uploadedImageForStep2 = File(image.path);
        } else if (stepNumber == 3) {
          _uploadedImageForStep3 = File(image.path);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 已选择图片用于步骤$stepNumber')),
      );
    }
  }

  void _goToStep(int stepNumber) {
    final petId = _petIdController.text.trim();
    final breed = _breedController.text.trim();
    final color = _colorController.text.trim();

    // 步骤0不需要petId
    if (stepNumber == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StepInitScreenRefactored(),
        ),
      );
      return;
    }

    // 步骤1不需要petId
    if (stepNumber == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Step1RemoveBackgroundScreen(
            petId: petId.isEmpty ? 'temp_${DateTime.now().millisecondsSinceEpoch}' : petId,
            breed: breed,
            color: color,
            species: _species,
          ),
        ),
      );
      return;
    }

    // 其他步骤需要petId
    if (petId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 请输入Pet ID（步骤2-6需要）')),
      );
      return;
    }

    if (breed.isEmpty || color.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 请填写品种和颜色')),
      );
      return;
    }

    Widget screen;
    switch (stepNumber) {
      case 2:
        // 步骤2需要上传去背景图片
        if (_uploadedImageForStep2 == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ 请先上传去背景图片（步骤2需要）')),
          );
          return;
        }
        // 使用上传的图片路径作为step1Result
        screen = Step2GenerateBaseImageScreenRefactored(
          petId: petId,
          breed: breed,
          color: color,
          species: _species,
          step1Result: _uploadedImageForStep2!.path,
        );
        break;
      case 3:
        // 步骤3需要上传坐姿图片
        if (_uploadedImageForStep3 == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ 请先上传坐姿图片（步骤3需要）')),
          );
          return;
        }
        // 使用上传的图片路径作为step2Result
        screen = Step3GenerateInitialVideosScreenRefactored(
          petId: petId,
          breed: breed,
          color: color,
          species: _species,
          step2Result: _uploadedImageForStep3!.path,
        );
        break;
      case 4:
        screen = Step4GenerateRemainingVideosScreenRefactored(
          petId: petId,
          breed: breed,
          color: color,
          species: _species,
        );
        break;
      case 5:
        screen = Step5GenerateLoopVideosScreenRefactored(
          petId: petId,
          breed: breed,
          color: color,
          species: _species,
        );
        break;
      case 6:
        screen = Step6ConvertToGifsScreenRefactored(
          petId: petId,
          breed: breed,
          color: color,
          species: _species,
        );
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      appBar: AppBar(title: const Text('选择步骤'), centerTitle: true),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(theme),
          AppSpacing.vGapLG,
          _buildPetInfoCard(theme),
          AppSpacing.vGapLG,
          _buildUploadCard(theme),
          AppSpacing.vGapLG,
          Text('选择要进入的步骤', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          AppSpacing.vGapMD,
          _buildStepCard(stepNumber: 0, title: '初始化', description: '上传宠物图片，填写信息', icon: Icons.upload_file, color: theme.colorScheme.tertiary, needsPetId: false),
          AppSpacing.vGapMD,
          _buildStepCard(stepNumber: 1, title: '去除背景', description: '使用AI去除图片背景', icon: Icons.content_cut, color: Colors.red, needsPetId: false),
          AppSpacing.vGapMD,
          _buildStepCard(stepNumber: 2, title: '生成基础坐姿图片', description: '使用可灵AI生成标准坐姿', icon: Icons.image, color: Colors.orange, needsPetId: true, needsUpload: true, uploadLabel: '需要上传去背景图片'),
          AppSpacing.vGapMD,
          _buildStepCard(stepNumber: 3, title: '生成初始过渡视频', description: '生成3个初始过渡视频', icon: Icons.video_library, color: Colors.green, needsPetId: true, needsUpload: true, uploadLabel: '需要上传坐姿图片'),
          AppSpacing.vGapMD,
          _buildStepCard(stepNumber: 4, title: '生成剩余过渡视频', description: '生成9个剩余过渡视频', icon: Icons.video_collection, color: Colors.blue, needsPetId: true),
          AppSpacing.vGapMD,
          _buildStepCard(stepNumber: 5, title: '生成循环视频', description: '生成4个循环视频', icon: Icons.loop, color: Colors.indigo, needsPetId: true),
          AppSpacing.vGapMD,
          _buildStepCard(stepNumber: 6, title: '转换为GIF', description: '将所有视频转换为GIF', icon: Icons.gif, color: Colors.pink, needsPetId: true),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary),
              AppSpacing.hGapSM,
              Text('使用说明', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ]),
            AppSpacing.vGapSM,
            const Text('• 步骤0-1：不需要Pet ID，可以直接进入'),
            const Text('• 步骤2-6：需要Pet ID（从步骤0获取）'),
            const Text('• 步骤2-3：需要上传对应的图片'),
          ],
        ),
      ),
    );
  }

  Widget _buildPetInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('宠物信息', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.vGapMD,
            TextField(controller: _petIdController, decoration: const InputDecoration(labelText: 'Pet ID（步骤2-6需要）', hintText: '例如：pet_1234567890', prefixIcon: Icon(Icons.fingerprint))),
            AppSpacing.vGapMD,
            DropdownButtonFormField<String>(
              value: _species,
              decoration: const InputDecoration(labelText: '物种', prefixIcon: Icon(Icons.pets)),
              items: const [DropdownMenuItem(value: '猫', child: Text('猫')), DropdownMenuItem(value: '狗', child: Text('狗'))],
              onChanged: (v) { if (v != null) setState(() => _species = v); },
            ),
            AppSpacing.vGapMD,
            TextField(controller: _breedController, decoration: const InputDecoration(labelText: '品种', hintText: '例如：布偶猫', prefixIcon: Icon(Icons.category))),
            AppSpacing.vGapMD,
            TextField(controller: _colorController, decoration: const InputDecoration(labelText: '颜色', hintText: '例如：蓝色', prefixIcon: Icon(Icons.palette))),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.upload_file, color: theme.colorScheme.secondary),
              AppSpacing.hGapSM,
              Text('上传图片（可选）', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
            ]),
            AppSpacing.vGapSM,
            const Text('如果你已经有处理好的图片，可以直接上传：'),
            AppSpacing.vGapMD,
            OutlinedButton.icon(
              onPressed: () => _pickImageForStep(2),
              icon: const Icon(Icons.image),
              label: Text(_uploadedImageForStep2 == null ? '上传去背景图片（步骤2用）' : '✅ 已选择'),
            ),
            AppSpacing.vGapSM,
            OutlinedButton.icon(
              onPressed: () => _pickImageForStep(3),
              icon: const Icon(Icons.image),
              label: Text(_uploadedImageForStep3 == null ? '上传坐姿图片（步骤3用）' : '✅ 已选择'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool needsPetId,
    bool needsUpload = false,
    String? uploadLabel,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () => _goToStep(stepNumber),
        borderRadius: AppSpacing.borderRadiusLG,
        child: Padding(
          padding: AppSpacing.paddingMD,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: AppSpacing.borderRadiusMD),
                child: Icon(icon, color: color, size: 26),
              ),
              AppSpacing.hGapMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('步骤$stepNumber', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                      if (needsPetId) ...[
                        AppSpacing.hGapSM,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(4)),
                          child: Text('需要Pet ID', style: TextStyle(fontSize: 10, color: theme.colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                    AppSpacing.vGapXS,
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    if (needsUpload && uploadLabel != null) ...[
                      AppSpacing.vGapXS,
                      Row(children: [
                        Icon(Icons.upload, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(uploadLabel, style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
                      ]),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

