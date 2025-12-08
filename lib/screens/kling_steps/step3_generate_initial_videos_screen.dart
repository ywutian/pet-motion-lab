import 'package:flutter/material.dart';
import '../../services/kling_step_service.dart';
import '../../utils/download_helper.dart';
import 'step4_generate_remaining_videos_screen.dart';

class Step3GenerateInitialVideosScreen extends StatefulWidget {
  final String petId;
  final String breed;
  final String color;
  final String species;
  final String step2Result;

  const Step3GenerateInitialVideosScreen({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
    required this.step2Result,
  });

  @override
  State<Step3GenerateInitialVideosScreen> createState() => _Step3GenerateInitialVideosScreenState();
}

class _Step3GenerateInitialVideosScreenState extends State<Step3GenerateInitialVideosScreen> {
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
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('步骤3失败: $e')),
        );
      }
    }
  }

  void _goToNextStep() {
    if (_results == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完成步骤3')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step4GenerateRemainingVideosScreen(
          petId: widget.petId,
          breed: widget.breed,
          color: widget.color,
          species: widget.species,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('步骤3: 生成初始过渡视频'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 步骤说明
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '步骤说明',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('生成3个初始过渡视频，并提取最后一帧：'),
                    const SizedBox(height: 8),
                    const Text('• sit → walk (坐姿到行走)'),
                    const Text('• sit → rest (坐姿到休息)'),
                    const Text('• rest → sleep (休息到睡觉)'),
                    const SizedBox(height: 8),
                    Text('宠物信息: ${widget.species} - ${widget.breed} - ${widget.color}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 自动执行
            _buildAutoExecuteSection(),
            const SizedBox(height: 24),

            // 结果显示
            if (_results != null) _buildResultSection(),
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
              onPressed: _results != null && !_isProcessing ? _goToNextStep : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('下一步: 生成剩余视频'),
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
                Icon(Icons.auto_awesome, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  '自动执行',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('使用可灵AI图生视频API生成3个初始过渡视频'),
            const SizedBox(height: 8),
            const Text('⏱️ 预计耗时: 5-10分钟', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _executeStep,
              icon: const Icon(Icons.play_arrow),
              label: const Text('执行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    final videos = _results?['videos'] as Map<String, dynamic>? ?? {};
    final firstFrames = _results?['first_frames'] as Map<String, dynamic>? ?? {};
    final lastFrames = _results?['last_frames'] as Map<String, dynamic>? ?? {};

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
            Text('生成了 ${videos.length} 个视频'),
            const SizedBox(height: 12),

            // 视频列表
            if (videos.isNotEmpty) ...[
              const Text('视频:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...videos.entries.map((entry) {
                final transitionName = entry.key;
                final videoPath = entry.value.toString();
                final firstFramePath = firstFrames[transitionName]?.toString();
                final lastFramePath = lastFrames[transitionName]?.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 视频名称
                        Text(
                          transitionName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 视频下载按钮
                        Row(
                          children: [
                            const Icon(Icons.video_library, size: 16),
                            const SizedBox(width: 4),
                            const Text('视频:', style: TextStyle(fontSize: 12)),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await DownloadHelper.downloadVideoAndSaveToGallery(
                                  context: context,
                                  filePath: videoPath,
                                  customFileName: '$transitionName.mp4',
                                );
                              },
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('下载', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 首帧下载按钮
                        if (firstFramePath != null)
                          Row(
                            children: [
                              const Icon(Icons.image, size: 16),
                              const SizedBox(width: 4),
                              const Text('首帧:', style: TextStyle(fontSize: 12)),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await DownloadHelper.downloadAndSaveToGallery(
                                    context: context,
                                    filePath: firstFramePath,
                                    customFileName: '${transitionName}_first_frame.png',
                                  );
                                },
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('下载', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),

                        // 尾帧下载按钮
                        if (lastFramePath != null)
                          Row(
                            children: [
                              const Icon(Icons.image, size: 16),
                              const SizedBox(width: 4),
                              const Text('尾帧:', style: TextStyle(fontSize: 12)),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await DownloadHelper.downloadAndSaveToGallery(
                                    context: context,
                                    filePath: lastFramePath,
                                    customFileName: '${transitionName}_last_frame.png',
                                  );
                                },
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('下载', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}


