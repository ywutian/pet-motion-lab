import 'package:flutter/material.dart';
import '../../services/kling_step_service.dart';
import '../../utils/download_helper.dart';
import 'step6_convert_to_gifs_screen.dart';

class Step5GenerateLoopVideosScreen extends StatefulWidget {
  final String petId;
  final String breed;
  final String color;
  final String species;

  const Step5GenerateLoopVideosScreen({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
  });

  @override
  State<Step5GenerateLoopVideosScreen> createState() => _Step5GenerateLoopVideosScreenState();
}

class _Step5GenerateLoopVideosScreenState extends State<Step5GenerateLoopVideosScreen> {
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
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('步骤5失败: $e')),
        );
      }
    }
  }

  void _goToNextStep() {
    if (_results == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完成步骤5')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step6ConvertToGifsScreen(
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
        title: const Text('步骤5: 生成循环视频'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.indigo.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '步骤说明',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('生成4个循环视频，每个姿态一个：'),
                    const SizedBox(height: 8),
                    const Text('• sit_loop (坐姿循环)'),
                    const Text('• walk_loop (行走循环)'),
                    const Text('• rest_loop (休息循环)'),
                    const Text('• sleep_loop (睡觉循环)'),
                    const SizedBox(height: 8),
                    Text('宠物信息: ${widget.species} - ${widget.breed} - ${widget.color}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildAutoExecuteSection(),
            const SizedBox(height: 24),
            if (_results != null) _buildResultSection(),
            const SizedBox(height: 24),
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
            ElevatedButton.icon(
              onPressed: _results != null && !_isProcessing ? _goToNextStep : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('下一步: 转换为GIF'),
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
                Icon(Icons.auto_awesome, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                const Text(
                  '自动执行',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('使用可灵AI图生视频API生成4个循环视频'),
            const SizedBox(height: 8),
            const Text('⏱️ 预计耗时: 8-12分钟', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _executeStep,
              icon: const Icon(Icons.play_arrow),
              label: const Text('执行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
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
            Text('生成了 ${videos.length} 个循环视频'),
            const SizedBox(height: 12),
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
