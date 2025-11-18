import 'package:flutter/material.dart';
import '../../services/kling_step_service.dart';
import '../../utils/download_helper.dart';
import 'step5_generate_loop_videos_screen.dart';

class Step4GenerateRemainingVideosScreen extends StatefulWidget {
  final String petId;
  final String breed;
  final String color;
  final String species;

  const Step4GenerateRemainingVideosScreen({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
  });

  @override
  State<Step4GenerateRemainingVideosScreen> createState() => _Step4GenerateRemainingVideosScreenState();
}

class _Step4GenerateRemainingVideosScreenState extends State<Step4GenerateRemainingVideosScreen> {
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
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('步骤4失败: $e')),
        );
      }
    }
  }

  void _goToNextStep() {
    if (_results == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完成步骤4')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step5GenerateLoopVideosScreen(
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
        title: const Text('步骤4: 生成剩余过渡视频'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 步骤说明
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '步骤说明',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('生成剩余9个过渡视频，连接所有4个姿态：'),
                    const SizedBox(height: 8),
                    const Text('• walk → sit, walk → rest, walk → sleep'),
                    const Text('• rest → sit, rest → walk'),
                    const Text('• sleep → sit, sleep → walk, sleep → rest'),
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
              label: const Text('下一步: 生成循环视频'),
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
                Icon(Icons.auto_awesome, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                const Text(
                  '自动执行',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('使用可灵AI图生视频API生成9个剩余过渡视频'),
            const SizedBox(height: 8),
            const Text('⏱️ 预计耗时: 15-20分钟', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _executeStep,
              icon: const Icon(Icons.play_arrow),
              label: const Text('执行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    final videos = _results?['videos'] as List<dynamic>? ?? [];

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
            Text('生成了 ${videos.length} 个过渡视频'),
            const SizedBox(height: 12),

            // 视频列表
            if (videos.isNotEmpty) ...[
              const Text('视频:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...videos.map((video) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(video.toString(), style: const TextStyle(fontSize: 12))),
                    IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: () async {
                        await DownloadHelper.downloadVideoAndSaveToGallery(
                          context: context,
                          filePath: video.toString(),
                        );
                      },
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}


