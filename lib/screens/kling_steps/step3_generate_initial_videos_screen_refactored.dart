import 'package:flutter/material.dart';
import '../../services/kling_step_service.dart';
import '../../widgets/base_step_screen.dart';
import '../../widgets/step_info_card.dart';
import '../../widgets/step_action_card.dart';
import '../../widgets/step_status_card.dart';
import '../../widgets/step_next_button.dart';
import '../../widgets/video_list_card.dart';
import 'step4_generate_remaining_videos_screen.dart';

/// 步骤3: 生成初始过渡视频 - 重构版本
class Step3GenerateInitialVideosScreenRefactored extends BaseStepScreenStateful {
  final String petId;
  final String breed;
  final String color;
  final String species;
  final String step2Result;

  const Step3GenerateInitialVideosScreenRefactored({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
    required this.step2Result,
  }) : super(stepNumber: 3, stepTitle: '步骤3: 生成初始过渡视频');

  @override
  State<Step3GenerateInitialVideosScreenRefactored> createState() =>
      _Step3GenerateInitialVideosScreenRefactoredState();
}

class _Step3GenerateInitialVideosScreenRefactoredState
    extends BaseStepScreenState<Step3GenerateInitialVideosScreenRefactored> {
  Map<String, dynamic>? _results;
  bool _isProcessing = false;
  String _statusMessage = '';

  final KlingStepService _service = KlingStepService();

  Future<void> _executeStep() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在生成初始过渡视频（sit→walk, sit→rest, rest→sleep）...';
    });

    try {
      final result = await _service.executeStep3(widget.petId);

      setState(() {
        _results = result;
        _statusMessage = '初始视频生成完成！';
        _isProcessing = false;
      });
      showSuccess('初始视频生成完成！');
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      showError('步骤3失败: $e');
    }
  }

  void _goToNextStep() {
    if (_results == null) {
      showInfo('请先完成步骤3');
      return;
    }

    navigateToNextStep(
      Step4GenerateRemainingVideosScreen(
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
            '生成3个初始过渡视频，并提取最后一帧：',
            '• sit → walk (坐姿到行走)',
            '• sit → rest (坐姿到休息)',
            '• rest → sleep (休息到睡觉)',
            '宠物信息: ${widget.species} - ${widget.breed} - ${widget.color}',
          ],
        ),
        buildGap(),

        // 自动执行
        StepActionCard(
          icon: Icons.auto_awesome,
          iconColor: colorTheme.dark,
          title: '自动执行',
          description: '使用可灵AI图生视频API生成3个初始过渡视频\n⏱️ 预计耗时: 5-10分钟',
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
          text: '下一步: 生成剩余视频',
          onPressed: _goToNextStep,
          isEnabled: _results != null && !_isProcessing,
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    final resultsMap = _results as Map<String, dynamic>?;
    final videos = resultsMap?['videos'] as Map<String, dynamic>? ?? {};
    final firstFrames = resultsMap?['first_frames'] as Map<String, dynamic>? ?? {};
    final lastFrames = resultsMap?['last_frames'] as Map<String, dynamic>? ?? {};

    // 转换为列表格式
    final videoList = videos.values.map((v) => v.toString()).toList();
    final firstFramesMap = Map<String, String>.from(
      firstFrames.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
    final lastFramesMap = Map<String, String>.from(
      lastFrames.map((k, v) => MapEntry(k.toString(), v.toString())),
    );

    return VideoListCard(
      title: '步骤完成',
      videos: videoList,
      firstFrames: firstFramesMap,
      lastFrames: lastFramesMap,
      backgroundColor: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF4CAF50),
    );
  }
}

