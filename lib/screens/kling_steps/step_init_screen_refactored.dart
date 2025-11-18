import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/kling_step_service.dart';
import '../../widgets/base_step_screen.dart';
import '../../widgets/step_info_card.dart';
import '../../widgets/image_picker_card.dart';
import '../../widgets/form_input_card.dart';
import '../../theme/app_spacing.dart';

import '../../utils/responsive_helper.dart';
import 'step1_remove_background_screen.dart';

/// 初始化页面 - 重构版本
class StepInitScreenRefactored extends BaseStepScreenStateful {
  const StepInitScreenRefactored({super.key})
      : super(stepNumber: 0, stepTitle: '分步生成 - 初始化');

  @override
  State<StepInitScreenRefactored> createState() => _StepInitScreenRefactoredState();
}

class _StepInitScreenRefactoredState extends BaseStepScreenState<StepInitScreenRefactored> {
  File? _selectedImage;
  bool _isInitializing = false;

  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _speciesController = TextEditingController(text: 'cat');

  final ImagePicker _picker = ImagePicker();
  final KlingStepService _service = KlingStepService();

  @override
  void dispose() {
    _breedController.dispose();
    _colorController.dispose();
    _speciesController.dispose();
    super.dispose();
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
    // 验证输入
    if (_selectedImage == null) {
      showInfo('请先上传宠物图片');
      return;
    }

    if (_breedController.text.trim().isEmpty) {
      showInfo('请输入宠物品种');
      return;
    }

    if (_colorController.text.trim().isEmpty) {
      showInfo('请输入宠物颜色');
      return;
    }

    setState(() => _isInitializing = true);

    try {
      final result = await _service.initTask(
        _selectedImage!,
        _breedController.text.trim(),
        _colorController.text.trim(),
        _speciesController.text.trim(),
      );

      final petId = result['pet_id'];
      showSuccess('任务初始化成功！');

      // 导航到步骤1
      if (mounted) {
        navigateToNextStep(
          Step1RemoveBackgroundScreen(
            petId: petId,
            breed: _breedController.text.trim(),
            color: _colorController.text.trim(),
            species: _speciesController.text.trim(),
          ),
        );
      }
    } catch (e) {
      showError('初始化失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 说明卡片
        StepInfoCard(
          backgroundColor: colorTheme.light,
          iconColor: colorTheme.dark,
          textColor: colorTheme.dark,
          title: '分步生成流程',
          descriptions: const [
            '每个步骤都是独立的页面，您可以：',
            '✅ 查看每个步骤的详细说明',
            '✅ 选择自动执行或上传自定义文件',
            '✅ 下载每个步骤的结果',
            '✅ 如果某步失败，可以重新执行',
          ],
        ),
        buildGap(),

        // 上传图片
        ImagePickerCard(
          selectedImage: _selectedImage,
          onTap: _pickImage,
          isEnabled: !_isInitializing,
          label: '点击上传宠物图片',
        ),
        buildGap(),

        // 宠物信息表单
        FormInputCard(
          title: '宠物信息',
          icon: Icons.pets,
          iconColor: colorTheme.primary,
          children: [
            ResponsiveTextField(
              controller: _breedController,
              labelText: '品种',
              hintText: '例如: 橘猫、金毛',
              prefixIcon: Icons.category,
              enabled: !_isInitializing,
            ),
            AppSpacing.vGapLG,
            ResponsiveTextField(
              controller: _colorController,
              labelText: '颜色',
              hintText: '例如: 橘色、白色',
              prefixIcon: Icons.palette,
              enabled: !_isInitializing,
            ),
            AppSpacing.vGapLG,
            ResponsiveTextField(
              controller: _speciesController,
              labelText: '物种',
              hintText: 'cat 或 dog',
              prefixIcon: Icons.pets,
              enabled: !_isInitializing,
            ),
          ],
        ),
        buildGap(),

        // 开始按钮
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: _isInitializing ? null : _initializeTask,
            icon: _isInitializing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.rocket_launch),
            label: Text(
              _isInitializing ? '正在初始化...' : '🚀 开始分步生成',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 18,
                  tablet: 19,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[600],
              shape: RoundedRectangleBorder(
                borderRadius: AppSpacing.borderRadiusLG,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

