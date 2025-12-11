import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/kling_generation_service.dart';
import '../config/api_config.dart';
import '../widgets/app_states.dart';
import '../theme/app_spacing.dart';

class KlingHistoryDetailScreen extends StatefulWidget {
  final String petId;

  const KlingHistoryDetailScreen({super.key, required this.petId});

  @override
  State<KlingHistoryDetailScreen> createState() => _KlingHistoryDetailScreenState();
}

class _KlingHistoryDetailScreenState extends State<KlingHistoryDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = KlingGenerationService();
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _service.getHistoryDetail(widget.petId);
      setState(() {
        _detail = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadZip(String type) async {
    final url = _service.getZipDownloadUrl(widget.petId, include: type);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoModel = _detail?['video_model_name'] ?? '';
    final videoMode = _detail?['video_model_mode'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_detail?['breed'] ?? '详情'),
            if (videoModel.isNotEmpty)
              Text('$videoModel ($videoMode)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          if (_detail?['ai_check_result'] != null)
            IconButton(icon: const Icon(Icons.analytics), tooltip: 'AI 检测报告', onPressed: _showAICheckReport),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: _downloadZip,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'gifs', child: Text('下载所有GIF')),
              PopupMenuItem(value: 'videos', child: Text('下载所有视频')),
              PopupMenuItem(value: 'all', child: Text('下载全部文件')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: '图片'),
            Tab(icon: Icon(Icons.movie), text: '拼接视频'),
            Tab(icon: Icon(Icons.videocam), text: '过渡视频'),
            Tab(icon: Icon(Icons.gif), text: 'GIF'),
          ],
        ),
      ),
      body: _isLoading
          ? const AppLoading(message: '加载详情...')
          : _error != null
              ? AppError(message: _error!, onRetry: _loadDetail)
              : _buildBody(),
    );
  }

  /// 显示 AI 检测报告弹窗
  void _showAICheckReport() {
    final aiResult = _detail?['ai_check_result'];
    if (aiResult == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖动指示器
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      '🤖 AI 图片检测报告',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 报告内容
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildAIReportSection(aiResult),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建 AI 报告内容
  Widget _buildAIReportSection(Map<String, dynamic> aiResult) {
    final contentSafety = aiResult['content_safety'] ?? {};
    final petDetection = aiResult['pet_detection'] ?? {};
    final poseAnalysis = aiResult['pose_analysis'] ?? {};
    final backgroundQuality = aiResult['background_quality'] ?? {};
    final featureCompleteness = aiResult['feature_completeness'] ?? {};
    final overallAssessment = aiResult['overall_assessment'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 整体评估卡片
        _buildReportCard(
          title: '⭐ 整体评估',
          color: overallAssessment['suitable_for_generation'] == true 
              ? Colors.green 
              : Colors.orange,
          children: [
            _buildReportRow('适合生成', overallAssessment['suitable_for_generation'] == true ? '✅ 是' : '❌ 否'),
            _buildReportRow('置信度', '${((overallAssessment['confidence_score'] ?? 0) * 100).toStringAsFixed(0)}%'),
            _buildReportRow('严重程度', _getSeverityText(overallAssessment['severity_level'])),
            if (overallAssessment['summary'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  overallAssessment['summary'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 宠物检测
        _buildReportCard(
          title: '🐾 宠物检测',
          color: Colors.blue,
          children: [
            _buildReportRow('检测结果', petDetection['detected'] == true ? '✅ 检测到' : '❌ 未检测到'),
            _buildReportRow('物种', petDetection['species'] == 'dog' ? '🐕 狗' : petDetection['species'] == 'cat' ? '🐱 猫' : '未知'),
            _buildReportRow('置信度', '${((petDetection['confidence'] ?? 0) * 100).toStringAsFixed(0)}%'),
            _buildReportRow('数量', '${petDetection['count'] ?? 0} 只'),
          ],
        ),
        const SizedBox(height: 12),

        // 姿势分析
        _buildReportCard(
          title: '🎭 姿势分析',
          color: Colors.purple,
          children: [
            _buildReportRow('姿势', _getPostureText(poseAnalysis['posture'])),
            _buildReportRow('是否坐姿', poseAnalysis['is_sitting'] == true ? '✅ 是（最佳）' : '❌ 否'),
            _buildReportRow('清晰度', '${((poseAnalysis['clarity'] ?? 0) * 100).toStringAsFixed(0)}%'),
            if (poseAnalysis['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  poseAnalysis['description'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 背景质量
        _buildReportCard(
          title: '🎨 背景质量',
          color: Colors.teal,
          children: [
            _buildReportRow('类型', _getBackgroundTypeText(backgroundQuality['type'])),
            _buildReportRow('是否干净', backgroundQuality['is_clean'] == true ? '✅ 是' : '❌ 否'),
            _buildReportRow('去除难度', _getDifficultyText(backgroundQuality['removal_difficulty'])),
            if (backgroundQuality['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  backgroundQuality['description'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 特征完整性
        _buildReportCard(
          title: '📐 特征完整性',
          color: Colors.orange,
          children: [
            _buildReportRow('完整度', '${((featureCompleteness['completeness_score'] ?? 0) * 100).toStringAsFixed(0)}%'),
            _buildReportRow('拍摄角度', _getAngleText(featureCompleteness['angle_quality'])),
            _buildReportRow('光照质量', _getLightingText(featureCompleteness['lighting_quality'])),
            _buildReportRow('对焦质量', _getFocusText(featureCompleteness['focus_quality'])),
            if (featureCompleteness['visible_features'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: (featureCompleteness['visible_features'] as List)
                      .map<Widget>((f) => Chip(
                            label: Text(_getFeatureText(f), style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 内容安全
        _buildReportCard(
          title: '🔒 内容安全',
          color: contentSafety['safe'] == true ? Colors.green : Colors.red,
          children: [
            _buildReportRow('安全状态', contentSafety['safe'] == true ? '✅ 安全' : '❌ 不安全'),
            if (contentSafety['issues'] != null && (contentSafety['issues'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '问题: ${(contentSafety['issues'] as List).join(', ')}',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getSeverityText(String? severity) {
    switch (severity) {
      case 'pass': return '✅ 通过';
      case 'warning': return '⚠️ 警告';
      case 'error': return '❌ 严重';
      default: return '未知';
    }
  }

  String _getPostureText(String? posture) {
    switch (posture) {
      case 'sitting': return '🪑 坐姿';
      case 'standing': return '🧍 站姿';
      case 'lying': return '🛌 躺姿';
      case 'walking': return '🚶 行走';
      case 'playing': return '🎾 玩耍';
      default: return posture ?? '未知';
    }
  }

  String _getBackgroundTypeText(String? type) {
    switch (type) {
      case 'solid': return '纯色';
      case 'simple': return '简单';
      case 'medium': return '中等';
      case 'complex': return '复杂';
      case 'cluttered': return '杂乱';
      default: return type ?? '未知';
    }
  }

  String _getDifficultyText(String? difficulty) {
    switch (difficulty) {
      case 'easy': return '🟢 容易';
      case 'medium': return '🟡 中等';
      case 'hard': return '🔴 困难';
      default: return difficulty ?? '未知';
    }
  }

  String _getAngleText(String? angle) {
    switch (angle) {
      case 'frontal': return '正面';
      case 'side': return '侧面';
      case 'three-quarter': return '四分之三';
      case 'back': return '背面';
      case 'top': return '俯视';
      default: return angle ?? '未知';
    }
  }

  String _getLightingText(String? lighting) {
    switch (lighting) {
      case 'excellent': return '⭐ 优秀';
      case 'good': return '👍 良好';
      case 'fair': return '👌 一般';
      case 'poor': return '👎 较差';
      default: return lighting ?? '未知';
    }
  }

  String _getFocusText(String? focus) {
    switch (focus) {
      case 'sharp': return '🎯 清晰';
      case 'acceptable': return '👌 可接受';
      case 'blurry': return '😵 模糊';
      default: return focus ?? '未知';
    }
  }

  String _getFeatureText(String feature) {
    switch (feature) {
      case 'face': return '脸部';
      case 'ears': return '耳朵';
      case 'eyes': return '眼睛';
      case 'nose': return '鼻子';
      case 'mouth': return '嘴巴';
      case 'body': return '身体';
      case 'legs': return '腿';
      case 'tail': return '尾巴';
      case 'paws': return '爪子';
      default: return feature;
    }
  }

  Widget _buildBody() {
    final files = _detail?['files'] ?? {};
    return TabBarView(
      controller: _tabController,
      children: [
        _buildImagesTab(files['images'] ?? []),
        _buildConcatenatedVideoTab(files['concatenated_video']),
        _buildVideosTab(files),
        _buildGifsTab(files),
      ],
    );
  }

  Widget _buildImagesTab(List images) {
    if (images.isEmpty) {
      return const Center(child: Text('暂无图片'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final url = '${ApiConfig.baseUrl}${image['url']}';
        
        return _MediaCard(
          title: image['name'] ?? '',
          imageUrl: url,
          onTap: () => _showImageDialog(url),
        );
      },
    );
  }

  Widget _buildConcatenatedVideoTab(Map<String, dynamic>? video) {
    if (video == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_creation, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无拼接视频'),
          ],
        ),
      );
    }

    final url = '${ApiConfig.baseUrl}${video['url']}';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          Text(
            '完整过渡视频',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            video['filename'] ?? '',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _openUrl(url),
            icon: const Icon(Icons.play_circle),
            label: const Text('播放视频'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _openUrl(url),
            icon: const Icon(Icons.download),
            label: const Text('下载视频'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosTab(Map<String, dynamic> files) {
    final transitionVideos = files['transition_videos'] ?? [];
    final loopVideos = files['loop_videos'] ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (transitionVideos.isNotEmpty) ...[
          _buildSectionHeader('过渡视频 (${transitionVideos.length}个)'),
          ...transitionVideos.map((v) => _buildVideoTile(v)),
        ],
        if (loopVideos.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('循环视频 (${loopVideos.length}个)'),
          ...loopVideos.map((v) => _buildVideoTile(v)),
        ],
      ],
    );
  }

  Widget _buildGifsTab(Map<String, dynamic> files) {
    final transitionGifs = files['transition_gifs'] ?? [];
    final loopGifs = files['loop_gifs'] ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (transitionGifs.isNotEmpty) ...[
          _buildSectionHeader('过渡GIF (${transitionGifs.length}个)'),
          _buildGifGrid(transitionGifs),
        ],
        if (loopGifs.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('循环GIF (${loopGifs.length}个)'),
          _buildGifGrid(loopGifs),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVideoTile(Map<String, dynamic> video) {
    final url = '${ApiConfig.baseUrl}${video['url']}';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.videocam, color: Colors.blue),
        title: Text(video['name'] ?? ''),
        subtitle: Text(_formatSize(video['size'] ?? 0)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () => _openUrl(url),
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _openUrl(url),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGifGrid(List gifs) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: gifs.length,
      itemBuilder: (context, index) {
        final gif = gifs[index];
        final url = '${ApiConfig.baseUrl}${gif['url']}';
        
        return _MediaCard(
          title: gif['name'] ?? '',
          imageUrl: url,
          isGif: true,
          onTap: () => _showImageDialog(url),
        );
      },
    );
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () => _openUrl(url),
                child: const Text('下载'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _MediaCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final bool isGif;
  final VoidCallback onTap;

  const _MediaCard({
    required this.title,
    required this.imageUrl,
    this.isGif = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(isGif ? Icons.gif : Icons.image, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

