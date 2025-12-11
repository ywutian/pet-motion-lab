import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/kling_generation_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';

class KlingResultScreen extends StatefulWidget {
  final String petId;

  const KlingResultScreen({super.key, required this.petId});

  @override
  State<KlingResultScreen> createState() => _KlingResultScreenState();
}

class _KlingResultScreenState extends State<KlingResultScreen> {
  Map<String, dynamic>? _results;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final service = KlingGenerationService();
      final results = await service.getResults(widget.petId);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('生成结果'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResults,
          ),
        ],
      ),
      scrollable: true,
      body: _isLoading
          ? const AppLoading(message: '加载结果中...')
          : _error != null
              ? AppError(
                  message: _error ?? '未知错误',
                  onRetry: _loadResults,
                )
              : _buildResultsView(),
    );
  }

  Widget _buildResultsView() {
    if (_results == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(),
        const SizedBox(height: 24),
        _buildBaseImagesSection(),
        const SizedBox(height: 24),
        _buildTransitionVideosSection(),
        const SizedBox(height: 24),
        _buildLoopVideosSection(),
        const SizedBox(height: 24),
        _buildGifsSection(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return FadeInDown(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '宠物信息',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildInfoRow('品种', _results!['breed']),
              _buildInfoRow('颜色', _results!['color']),
              _buildInfoRow('物种', _results!['species']),
              _buildInfoRow('ID', _results!['pet_id']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildBaseImagesSection() {
    final steps = _results!['steps'] as Map<String, dynamic>;
    final baseImages = steps['other_base_images'] as Map<String, dynamic>?;

    if (baseImages == null) return const SizedBox();

    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '基准姿势图 (4张)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: baseImages.length,
                itemBuilder: (context, index) {
                  final entry = baseImages.entries.elementAt(index);
                  return _buildImageCard(entry.key, entry.value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransitionVideosSection() {
    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '过渡视频 (12个)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('视频文件已生成，请在输出目录查看'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoopVideosSection() {
    return FadeInUp(
      delay: const Duration(milliseconds: 600),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '循环视频 (4个)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('循环视频已生成，请在输出目录查看'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGifsSection() {
    return FadeInUp(
      delay: const Duration(milliseconds: 800),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GIF动画 (16个)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('GIF文件已生成，请在输出目录查看'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(String name, String path) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.image, size: 48),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

