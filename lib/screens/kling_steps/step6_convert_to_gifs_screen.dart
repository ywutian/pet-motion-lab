import 'package:flutter/material.dart';
import '../../services/kling_step_service.dart';
import '../../utils/download_helper.dart';
import '../kling_result_screen.dart';

class Step6ConvertToGifsScreen extends StatefulWidget {
  final String petId;
  final String breed;
  final String color;
  final String species;

  const Step6ConvertToGifsScreen({
    super.key,
    required this.petId,
    required this.breed,
    required this.color,
    required this.species,
  });

  @override
  State<Step6ConvertToGifsScreen> createState() => _Step6ConvertToGifsScreenState();
}

class _Step6ConvertToGifsScreenState extends State<Step6ConvertToGifsScreen> {
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
    } catch (e) {
      setState(() {
        _statusMessage = '失败: $e';
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('步骤6失败: $e')),
        );
      }
    }
  }

  void _viewResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KlingResultScreen(petId: widget.petId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('步骤6: 转换为GIF'),
        backgroundColor: Colors.pink,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.pink.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.pink.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '步骤说明',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('将所有16个视频转换为GIF格式：'),
                    const SizedBox(height: 8),
                    const Text('• 12个过渡视频 → 12个GIF'),
                    const Text('• 4个循环视频 → 4个GIF'),
                    const SizedBox(height: 8),
                    const Text('这是最后一步！完成后即可查看所有结果。'),
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
              onPressed: _results != null && !_isProcessing ? _viewResults : null,
              icon: const Icon(Icons.visibility),
              label: const Text('查看所有结果'),
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
                Icon(Icons.auto_awesome, color: Colors.pink.shade700),
                const SizedBox(width: 8),
                const Text(
                  '自动执行',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('将所有视频转换为GIF格式'),
            const SizedBox(height: 8),
            const Text('⏱️ 预计耗时: 3-5分钟', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _executeStep,
              icon: const Icon(Icons.play_arrow),
              label: const Text('执行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    final gifs = _results?['gifs'] as List<dynamic>? ?? [];

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
                  '🎉 所有步骤完成！',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('生成了 ${gifs.length} 个GIF文件'),
            const SizedBox(height: 8),
            const Text('✅ 4个基础图片'),
            const Text('✅ 12个过渡视频'),
            const Text('✅ 4个循环视频'),
            const Text('✅ 16个GIF动画'),
            const SizedBox(height: 12),
            if (gifs.isNotEmpty) ...[
              const Text('GIF文件:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...gifs.take(5).map((gif) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(gif.toString(), style: const TextStyle(fontSize: 12))),
                    IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: () async {
                        await DownloadHelper.downloadAndSaveToGallery(
                          context: context,
                          filePath: gif.toString(),
                        );
                      },
                    ),
                  ],
                ),
              )),
              if (gifs.length > 5)
                Text('... 还有 ${gifs.length - 5} 个GIF文件',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}


