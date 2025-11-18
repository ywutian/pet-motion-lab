import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/kling_step_service.dart';
import '../../utils/download_helper.dart';
import '../../widgets/base_step_screen.dart';
import '../../widgets/step_info_card.dart';
import '../../widgets/step_action_card.dart';
import '../../widgets/step_status_card.dart';
import '../../widgets/step_result_card.dart';
import '../../widgets/step_next_button.dart';
import '../../theme/app_spacing.dart';
import 'step2_generate_base_image_screen.dart';

class Step1RemoveBackgroundScreen extends BaseStepScreenStateful {
  final String petId;
  final String breed;
  final String color;
  final String species;

  const Step1RemoveBackgroundScreen({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
  }) : super(stepNumber: 1, stepTitle: '步骤1: 去除背景');

  @override
  State<Step1RemoveBackgroundScreen> createState() => _Step1RemoveBackgroundScreenState();
}

class _Step1RemoveBackgroundScreenState extends BaseStepScreenState<Step1RemoveBackgroundScreen> {
  File? _uploadedImage;
  String? _resultImagePath;
  bool _isProcessing = false;
  bool _isDownloading = false;
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
      _statusMessage = '正在使用本地模型去除背景...';
    });

    try {
      final result = await _service.executeStep1(widget.petId);

      setState(() {
        _resultImagePath = result['result'];
        _statusMessage = '背景去除完成！';
        _isProcessing = false;
      });
      showSuccess('背景去除完成！');
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      showError('步骤1失败: $e');
    }
  }

  Future<void> _uploadCustomImage() async {
    if (_uploadedImage == null) {
      showInfo('请先选择图片');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '正在上传自定义图片...';
    });

    try {
      final result = await _service.executeStep1(widget.petId, customFile: _uploadedImage);

      setState(() {
        _resultImagePath = result['result'];
        _statusMessage = '已使用自定义图片！';
        _isProcessing = false;
      });
      showSuccess('已使用自定义图片！');
    } catch (e) {
      setState(() {
        _statusMessage = '上传失败: $e';
        _isProcessing = false;
      });
      showError('上传失败: $e');
    }
  }

  Future<void> _downloadResult() async {
    if (_resultImagePath == null) return;

    setState(() => _isDownloading = true);
    try {
      await DownloadHelper.downloadAndSaveToGallery(
        context: context,
        filePath: _resultImagePath!,
        customFileName: 'step1_result.png',
      );
    } catch (e) {
      showError('下载失败: $e');
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  void _goToNextStep() {
    if (_resultImagePath == null) {
      showInfo('请先完成步骤1');
      return;
    }

    navigateToNextStep(
      Step2GenerateBaseImageScreen(
        petId: widget.petId,
        breed: widget.breed,
        color: widget.color,
        species: widget.species,
        step1Result: _resultImagePath!,
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 步骤说明
        StepInfoCard(
          backgroundColor: colorTheme.light,
          iconColor: colorTheme.dark,
          textColor: colorTheme.dark,
          title: '步骤说明',
          descriptions: const [
            '使用本地rembg模型去除宠物图片背景，生成透明PNG图片。',
            '您也可以上传自己处理好的透明背景图片跳过此步骤。',
          ],
        ),
        buildGap(),

        // 选项1: 自动执行
        StepActionCard(
          icon: Icons.auto_awesome,
          iconColor: colorTheme.dark,
          title: '选项1: 自动执行',
          description: '使用本地模型自动去除背景',
          buttonText: '执行',
          onPressed: _executeStep,
          buttonColor: colorTheme.primary,
          isLoading: _isProcessing,
        ),
        buildGap(height: AppSpacing.lg),

        // 选项2: 上传自定义图片
        _buildUploadSection(),
        buildGap(),

        // 状态消息
        if (_statusMessage.isNotEmpty) ...[
          StepStatusCard(
            message: _statusMessage,
            isProcessing: _isProcessing,
          ),
          buildGap(),
        ],

        // 结果显示
        if (_resultImagePath != null) ...[
          StepResultCard(
            imagePath: _resultImagePath,
            title: '处理结果',
            onDownload: _downloadResult,
            isDownloading: _isDownloading,
          ),
          buildGap(),
        ],

        // 下一步按钮
        StepNextButton(
          text: '下一步: 生成坐姿图片',
          onPressed: _goToNextStep,
          isEnabled: _resultImagePath != null && !_isProcessing,
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusLG,
      ),
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: Colors.orange.shade700),
                AppSpacing.hGapSM,
                const Expanded(
                  child: Text(
                    '选项2: 上传自定义图片',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            AppSpacing.vGapMD,
            const Text('如果您已经有处理好的透明背景图片，可以直接上传'),
            AppSpacing.vGapMD,
            if (_uploadedImage != null) ...[
              ClipRRect(
                borderRadius: AppSpacing.borderRadiusLG,
                child: Image.file(
                  _uploadedImage!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              AppSpacing.vGapMD,
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('选择图片'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.borderRadiusLG,
                      ),
                    ),
                  ),
                ),
                AppSpacing.hGapMD,
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadedImage != null && !_isProcessing ? _uploadCustomImage : null,
                    icon: const Icon(Icons.upload),
                    label: const Text('上传'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.borderRadiusLG,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
