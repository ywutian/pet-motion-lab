import 'package:flutter/material.dart';
import '../../services/kling_step_service.dart';
import '../../widgets/base_step_screen.dart';
import '../../widgets/step_info_card.dart';
import '../../widgets/step_action_card.dart';
import '../../widgets/step_status_card.dart';
import '../../widgets/step_next_button.dart';
import '../../widgets/video_list_card.dart';
import 'step6_convert_to_gifs_screen.dart';

/// 步骤5: 生成循环视频 - 重构版本
class Step5GenerateLoopVideosScreenRefactored extends BaseStepScreenStateful {
  final String petId;
  final String breed;
  final String color;
  final String species;

  const Step5GenerateLoopVideosScreenRefactored({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
  }) : super(stepNumber: 5, stepTitle: '步骤5: 生成循环视频');

  @override
  State<Step5GenerateLoopVideosScreenRefactored> createState() =>
      _Step5GenerateLoopVideosScreenRefactoredState();
}

class _Step5GenerateLoopVideosScreenRefactoredState
    extends BaseStepScreenState<Step5GenerateLoopVideosScreenRefactored> {
  Map<String, dynamic>? _results;
  bool _isProcessing = false;
  String _statusMessage = '';

  final KlingStepService _service = KlingStepService();

  Future<void> _executeStep() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在生成4个循环视频...';
    });

    try {
      final result = await _service.executeStep5(widget.petId);

      setState(() {
        _results = result;
        _statusMessage = '循环视频生成完成！';
        _isProcessing = false;
      });
      showSuccess('循环视频生成完成！');
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      showError('步骤5失败: $e');
    }
  }

  void _goToNextStep() {
    if (_results == null) {
      showInfo('请先完成步骤5');
      return;
    }

    navigateToNextStep(
      Step6ConvertToGifsScreen(
        petId: widget.petId,
        breed: widget.breed,
        color: widget.color,
        species: widget.species,
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
          descriptions: [
            '生成4个循环视频，每个姿态一个：',
            '• sit_loop (坐姿循环)',
            '• walk_loop (行走循环)',
            '• rest_loop (休息循环)',
            '• sleep_loop (睡觉循环)',
            '宠物信息: ${widget.species} - ${widget.breed} - ${widget.color}',
          ],
        ),
        buildGap(),

        // 自动执行
        StepActionCard(
          icon: Icons.auto_awesome,
          iconColor: colorTheme.dark,
          title: '自动执行',
          description: '使用可灵AI图生视频API生成4个循环视频\n⏱️ 预计耗时: 8-12分钟',
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

        // 下一步按钮
        StepNextButton(
          text: '下一步: 转换为GIF',
          onPressed: _goToNextStep,
          isEnabled: _results != null && !_isProcessing,
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    final videos = _results?['videos'] as List<dynamic>? ?? [];
    final videoList = videos.map((v) => v.toString()).toList();

    return VideoListCard(
      title: '步骤完成',
      videos: videoList,
      backgroundColor: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF4CAF50),
    );
  }
}

