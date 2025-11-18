import 'package:flutter/material.dart';
import '../../services/kling_step_service.dart';
import '../../widgets/base_step_screen.dart';
import '../../widgets/step_info_card.dart';
import '../../widgets/step_action_card.dart';
import '../../widgets/step_status_card.dart';
import '../../theme/app_spacing.dart';
import '../../utils/responsive_helper.dart';
import '../kling_result_screen.dart';

/// 步骤6: 转换为GIF - 重构版本
class Step6ConvertToGifsScreenRefactored extends BaseStepScreenStateful {
  final String petId;
  final String breed;
  final String color;
  final String species;

  const Step6ConvertToGifsScreenRefactored({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
  }) : super(stepNumber: 6, stepTitle: '步骤6: 转换为GIF');

  @override
  State<Step6ConvertToGifsScreenRefactored> createState() =>
      _Step6ConvertToGifsScreenRefactoredState();
}

class _Step6ConvertToGifsScreenRefactoredState
    extends BaseStepScreenState<Step6ConvertToGifsScreenRefactored> {
  Map<String, dynamic>? _results;
  bool _isProcessing = false;
  String _statusMessage = '';

  final KlingStepService _service = KlingStepService();

  Future<void> _executeStep() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在将所有视频转换为GIF...';
    });

    try {
      final result = await _service.executeStep6(widget.petId);

      setState(() {
        _results = result;
        _statusMessage = 'GIF转换完成！所有步骤已完成！';
        _isProcessing = false;
      });
      showSuccess('GIF转换完成！所有步骤已完成！');
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      showError('步骤6失败: $e');
    }
  }

  void _viewResults() {
    navigateToNextStep(
      KlingResultScreen(petId: widget.petId),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 步骤说明
        StepInfoCard(
          backgroundColor: colorTheme.light,
          iconColor: colorTheme.dark,
          textColor: colorTheme.dark,
          title: '步骤说明',
          descriptions: [
            '将所有16个视频转换为GIF格式：',
            '• 12个过渡视频 → 12个GIF',
            '• 4个循环视频 → 4个GIF',
            '',
            '这是最后一步！完成后即可查看所有结果。',
            '宠物信息: ${widget.species} - ${widget.breed} - ${widget.color}',
          ],
        ),
        buildGap(),

        // 自动执行
        StepActionCard(
          icon: Icons.auto_awesome,
          iconColor: colorTheme.dark,
          title: '自动执行',
          description: '将所有视频转换为GIF格式\n⏱️ 预计耗时: 3-5分钟',
          buttonText: '执行',
          onPressed: _executeStep,
          buttonColor: colorTheme.primary,
          isLoading: _isProcessing,
        ),
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
        if (_results != null) ...[
          _buildResultSection(),
          buildGap(),
        ],

        // 查看结果按钮
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: _results != null && !_isProcessing ? _viewResults : null,
            icon: const Icon(Icons.visibility),
            label: Text(
              '查看所有结果',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(
                  context,
                  mobile: 16,
                  tablet: 17,
                  desktop: 18,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
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

  Widget _buildResultSection() {
    final gifs = _results?['gifs'] as List<dynamic>? ?? [];
    final gifList = gifs.map((g) => g.toString()).toList();

    return Card(
      color: const Color(0xFFE8F5E9),
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
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                AppSpacing.hGapSM,
                const Expanded(
                  child: Text(
                    '🎉 所有步骤完成！',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            AppSpacing.vGapMD,
            Text('生成了 ${gifs.length} 个GIF文件'),
            AppSpacing.vGapSM,
            const Text('✅ 4个基础图片'),
            const Text('✅ 12个过渡视频'),
            const Text('✅ 4个循环视频'),
            const Text('✅ 16个GIF动画'),
            AppSpacing.vGapMD,
            if (gifList.isNotEmpty) ...[
              const Text('GIF文件:', style: TextStyle(fontWeight: FontWeight.bold)),
              AppSpacing.vGapSM,
              Text('共 ${gifList.length} 个GIF文件已生成'),
            ],
          ],
        ),
      ),
    );
  }
}

