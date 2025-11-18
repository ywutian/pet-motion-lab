import 'package:flutter/material.dart';
import '../../services/kling_step_service.dart';
import '../../widgets/base_step_screen.dart';
import '../../widgets/step_info_card.dart';
import '../../widgets/step_action_card.dart';
import '../../widgets/step_status_card.dart';
import '../../widgets/step_next_button.dart';
import '../../widgets/video_list_card.dart';
import 'step5_generate_loop_videos_screen.dart';

/// 步骤4: 生成剩余过渡视频 - 重构版本
class Step4GenerateRemainingVideosScreenRefactored extends BaseStepScreenStateful {
  final String petId;
  final String breed;
  final String color;
  final String species;

  const Step4GenerateRemainingVideosScreenRefactored({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
  }) : super(stepNumber: 4, stepTitle: '步骤4: 生成剩余过渡视频');

  @override
  State<Step4GenerateRemainingVideosScreenRefactored> createState() =>
      _Step4GenerateRemainingVideosScreenRefactoredState();
}

class _Step4GenerateRemainingVideosScreenRefactoredState
    extends BaseStepScreenState<Step4GenerateRemainingVideosScreenRefactored> {
  Map<String, dynamic>? _results;
  bool _isProcessing = false;
  String _statusMessage = '';

  final KlingStepService _service = KlingStepService();

  Future<void> _executeStep() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在生成剩余9个过渡视频...';
    });

    try {
      final result = await _service.executeStep4(widget.petId);

      setState(() {
        _results = result;
        _statusMessage = '剩余视频生成完成！';
        _isProcessing = false;
      });
      showSuccess('剩余视频生成完成！');
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      showError('步骤4失败: $e');
    }
  }

  void _goToNextStep() {
    if (_results == null) {
      showInfo('请先完成步骤4');
      return;
    }

    navigateToNextStep(
      Step5GenerateLoopVideosScreen(
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
            '生成剩余9个过渡视频，连接所有4个姿态：',
            '• walk → sit, walk → rest, walk → sleep',
            '• rest → sit, rest → walk',
            '• sleep → sit, sleep → walk, sleep → rest',
            '宠物信息: ${widget.species} - ${widget.breed} - ${widget.color}',
          ],
        ),
        buildGap(),

        // 自动执行
        StepActionCard(
          icon: Icons.auto_awesome,
          iconColor: colorTheme.dark,
          title: '自动执行',
          description: '使用可灵AI图生视频API生成9个剩余过渡视频\n⏱️ 预计耗时: 15-20分钟',
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
          text: '下一步: 生成循环视频',
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
      maxDisplay: 5,
    );
  }
}

