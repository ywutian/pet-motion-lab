import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/kling_generation_service.dart';
import '../config/api_config.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?['breed'] ?? '详情'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: _downloadZip,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'gifs', child: Text('📦 下载所有GIF')),
              const PopupMenuItem(value: 'videos', child: Text('📦 下载所有视频')),
              const PopupMenuItem(value: 'all', child: Text('📦 下载全部文件')),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDetail, child: const Text('重试')),
          ],
        ),
      );
    }

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
            _buildNetworkImage(url),
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

  /// 构建网络图片，Web 端使用 Image.network，其他平台使用 CachedNetworkImage
  Widget _buildNetworkImage(String imageUrl) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Image load error: $error');
          return const Center(child: Icon(Icons.error, size: 48));
        },
      );
    } else {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.error, size: 48),
        ),
      );
    }
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
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: _buildImage(context),
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

  Widget _buildImage(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.error));
        },
      );
    } else {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.error),
        ),
      );
    }
  }
}

