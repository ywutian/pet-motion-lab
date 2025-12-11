import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/model_test_service.dart';
import '../widgets/app_states.dart';
import '../theme/app_spacing.dart';

/// 可灵AI模型测试界面
/// 用于测试各种模型的可用性和首尾帧支持情况
class ModelTestScreen extends StatefulWidget {
  const ModelTestScreen({super.key});

  @override
  State<ModelTestScreen> createState() => _ModelTestScreenState();
}

class _ModelTestScreenState extends State<ModelTestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 需要测试的模型
  List<Map<String, dynamic>> _modelsToTest = [];
  // 已确认支持的模型
  List<Map<String, dynamic>> _modelsConfirmed = [];
  // 不推荐测试的模型
  List<Map<String, dynamic>> _modelsSkip = [];
  // 图片模型列表
  List<Map<String, dynamic>> _imageModels = [];
  
  // 测试结果
  final Map<String, Map<String, dynamic>> _testResults = {};
  
  // 测试图片
  XFile? _testImage;
  XFile? _tailImage;
  
  // 加载状态
  bool _isLoading = true;
  String? _error;
  
  // 当前正在测试的模型
  String? _testingModel;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadModels();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final response = await ModelTestService.getAvailableModels();
      
      if (response != null) {
        setState(() {
          _modelsToTest = List<Map<String, dynamic>>.from(response['models_to_test'] ?? []);
          _modelsConfirmed = List<Map<String, dynamic>>.from(response['models_confirmed'] ?? []);
          _modelsSkip = List<Map<String, dynamic>>.from(response['models_skip'] ?? []);
          _imageModels = List<Map<String, dynamic>>.from(response['image_models'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '无法加载模型列表';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickTestImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _testImage = image;
      });
    }
  }
  
  Future<void> _pickTailImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _tailImage = image;
      });
    }
  }
  
  Future<void> _testVideoModel(String modelName, String mode) async {
    if (_testImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择首帧图片')),
      );
      return;
    }
    
    if (_tailImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择尾帧图片（测试首尾帧功能必须上传两张图片）')),
      );
      return;
    }
    
    final key = '$modelName-$mode';
    setState(() {
      _testingModel = key;
      _testResults[key] = {'status': 'testing'};
    });
    
    try {
      final result = await ModelTestService.testVideoModel(
        imageFile: _testImage!,
        modelName: modelName,
        mode: mode,
        testTailImage: true,
        tailImageFile: _tailImage,
      );
      
      setState(() {
        _testResults[key] = result ?? {'status': 'error', 'error': '无响应'};
        _testingModel = null;
      });
    } catch (e) {
      setState(() {
        _testResults[key] = {'status': 'error', 'error': e.toString()};
        _testingModel = null;
      });
    }
  }
  
  Future<void> _testImageModel(String modelName) async {
    if (_testImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择测试图片')),
      );
      return;
    }
    
    setState(() {
      _testingModel = modelName;
      _testResults[modelName] = {'status': 'testing'};
    });
    
    try {
      final result = await ModelTestService.testImageModel(
        imageFile: _testImage!,
        modelName: modelName,
      );
      
      setState(() {
        _testResults[modelName] = result ?? {'status': 'error', 'error': '无响应'};
        _testingModel = null;
      });
    } catch (e) {
      setState(() {
        _testResults[modelName] = {'status': 'error', 'error': e.toString()};
        _testingModel = null;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('模型测试中心'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.video_library), text: '视频模型'),
            Tab(icon: Icon(Icons.image), text: '图片模型'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadModels, tooltip: '刷新模型列表'),
        ],
      ),
      body: _isLoading
          ? const AppLoading(message: '加载模型列表...')
          : _error != null
              ? AppError(message: _error!, onRetry: _loadModels)
              : Column(
                  children: [
                    _buildImageSelectionCard(theme),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [_buildVideoModelList(theme), _buildImageModelList(theme)],
                      ),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildImageSelectionCard(ThemeData theme) {
    return Card(
      margin: AppSpacing.paddingLG,
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('测试图片', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.vGapMD,
            Row(
              children: [
                Expanded(child: _buildImageSelector(theme, '首帧图片', _testImage, _pickTestImage, required: true)),
                AppSpacing.hGapMD,
                Expanded(child: _buildImageSelector(theme, '尾帧图片 (可选)', _tailImage, _pickTailImage, required: false)),
              ],
            ),
            AppSpacing.vGapSM,
            Text('提示: 如果不选择尾帧，测试时会使用首帧作为尾帧（测试循环视频效果）', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSelector(
    ThemeData theme,
    String label,
    XFile? image,
    VoidCallback onPick, {
    bool required = false,
  }) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(
            color: required && image == null
                ? theme.colorScheme.error.withOpacity(0.5)
                : theme.colorScheme.outline.withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: kIsWeb
                    ? Image.network(image.path, fit: BoxFit.cover)
                    : Image.file(File(image.path), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 32,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildVideoModelList(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 需要测试的模型（重点）
        if (_modelsToTest.isNotEmpty) ...[
          _buildSectionHeader(
            theme,
            '🔥 需要测试',
            '以下模型首尾帧支持未确认，测试后可能成为更便宜的备选',
            Colors.orange,
          ),
          ..._modelsToTest.map((model) => _buildModelCard(theme, model, showTestButton: true)),
          const SizedBox(height: 24),
        ],
        
        // 已确认支持的模型
        if (_modelsConfirmed.isNotEmpty) ...[
          _buildSectionHeader(
            theme,
            '✅ 已确认支持',
            '以下模型已确认支持首尾帧，可选择测试验证',
            Colors.green,
          ),
          ..._modelsConfirmed.map((model) => _buildModelCard(theme, model, showTestButton: true)),
          const SizedBox(height: 24),
        ],
        
        // 不推荐测试的模型
        if (_modelsSkip.isNotEmpty) ...[
          _buildSectionHeader(
            theme,
            '⚠️ 不推荐测试',
            '以下模型太旧或没有测试价值',
            Colors.grey,
          ),
          ..._modelsSkip.map((model) => _buildModelCard(theme, model, showTestButton: false, dimmed: true)),
        ],
      ],
    );
  }
  
  Widget _buildSectionHeader(ThemeData theme, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModelCard(ThemeData theme, Map<String, dynamic> model, {bool showTestButton = true, bool dimmed = false}) {
    final modelName = model['model_name'] as String;
    final modes = List<String>.from(model['modes'] ?? ['pro']);
    final tailSupport = model['tail_support'] as String? ?? 'unknown';
    final prices = model['price_5s'] as Map<String, dynamic>? ?? {};
    final note = model['note'] as String? ?? '';
    
    // 获取价格显示
    final priceDisplay = modes.map((m) => prices[m]?.toString() ?? '').where((p) => p.isNotEmpty).join(' / ');
    
    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 模型名称、价格和状态
              Row(
                children: [
                  _buildTailSupportBadge(theme, tailSupport),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          modelName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (priceDisplay.isNotEmpty)
                          Text(
                            '💰 $priceDisplay (5秒)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 备注
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              if (showTestButton) ...[
                const SizedBox(height: 12),
                // 模式和测试按钮
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: modes.map((mode) {
                    final key = '$modelName-$mode';
                    final result = _testResults[key];
                    final isTesting = _testingModel == key;
                    final price = prices[mode] ?? '未知';
                    
                    return _buildModeTestButton(
                      theme,
                      modelName,
                      mode,
                      price.toString(),
                      result,
                      isTesting,
                    );
                  }).toList(),
                ),
                // 测试结果
                if (_testResults.containsKey('$modelName-${modes.first}'))
                  _buildTestResultWidget(theme, _testResults['$modelName-${modes.first}']!),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildModeTestButton(
    ThemeData theme,
    String modelName,
    String mode,
    String price,
    Map<String, dynamic>? result,
    bool isTesting,
  ) {
    Color buttonColor;
    IconData icon;
    String statusText = mode.toUpperCase();
    
    if (isTesting) {
      buttonColor = theme.colorScheme.tertiary;
      icon = Icons.hourglass_top;
      statusText = '测试中...';
    } else if (result != null) {
      if (result['success'] == true) {
        buttonColor = Colors.green;
        icon = Icons.check_circle;
        statusText = '$mode ✓';
      } else {
        buttonColor = Colors.red;
        icon = Icons.error;
        statusText = '$mode ✗';
      }
    } else {
      buttonColor = theme.colorScheme.primary;
      icon = Icons.play_arrow;
    }
    
    return ElevatedButton.icon(
      onPressed: isTesting ? null : () => _testVideoModel(modelName, mode),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor.withOpacity(0.1),
        foregroundColor: buttonColor,
      ),
      icon: isTesting
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(buttonColor),
              ),
            )
          : Icon(icon, size: 18),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(statusText),
          Text(
            price,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTailSupportBadge(ThemeData theme, String tailSupport) {
    Color color;
    String text;
    IconData icon;
    
    switch (tailSupport) {
      case 'confirmed':
        color = Colors.green;
        text = '已确认';
        icon = Icons.verified;
        break;
      case 'likely':
        color = Colors.orange;
        text = '可能支持';
        icon = Icons.help_outline;
        break;
      default:
        color = Colors.grey;
        text = '待测试';
        icon = Icons.quiz;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTestResultWidget(ThemeData theme, Map<String, dynamic> result) {
    if (result['status'] == 'testing') {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      );
    }
    
    final success = result['success'] == true;
    final taskId = result['task_id'] as String?;
    final error = result['error'] as String?;
    final tailAccepted = result['tail_image_accepted'] as bool?;
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (success ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (success ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                success ? '测试成功' : '测试失败',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: success ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (taskId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Task ID: $taskId',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (tailAccepted != null) ...[
            const SizedBox(height: 4),
            Text(
              '首尾帧参数: ${tailAccepted ? "✅ 已接受" : "❌ 不支持"}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tailAccepted ? Colors.green : Colors.red,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              '错误: $error',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildImageModelList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _imageModels.length,
      itemBuilder: (context, index) {
        final model = _imageModels[index];
        final modelName = model['model_name'] as String;
        final note = model['note'] as String? ?? '';
        final result = _testResults[modelName];
        final isTesting = _testingModel == modelName;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: const Icon(Icons.image),
            ),
            title: Text(modelName),
            subtitle: Text(note),
            trailing: isTesting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : result != null
                    ? Icon(
                        result['success'] == true ? Icons.check_circle : Icons.error,
                        color: result['success'] == true ? Colors.green : Colors.red,
                      )
                    : ElevatedButton(
                        onPressed: () => _testImageModel(modelName),
                        child: const Text('测试'),
                      ),
          ),
        );
      },
    );
  }
}

