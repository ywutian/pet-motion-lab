import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/species_provider.dart';
import '../widgets/species_selection_sheet.dart';
import '../utils/responsive.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('⚙️ 设置中心'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildVideoGenerationSection(context),
              _buildBackgroundRemovalSection(context),
              _buildSpeciesLibrarySection(context),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  /// 视频生成配置
  Widget _buildVideoGenerationSection(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Padding(
      padding: _sectionPadding(context),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎬 视频生成配置',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '配置可灵 AI 视频生成参数',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              
              // 模型选择（仅保留支持首尾帧的模型）
              DropdownButtonFormField<String>(
                value: settings.videoModel,
                decoration: const InputDecoration(
                  labelText: '视频模型',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.movie_creation),
                  helperText: '所有模型均支持首尾帧控制',
                ),
                isExpanded: true,
                items: const [
                  // V2.5 Turbo 系列（最新，推荐，性价比最高）
                  DropdownMenuItem(
                    value: 'kling-v2-5-turbo',
                    child: Text('kling-v2-5-turbo - pro \$0.35 ⭐推荐'),
                  ),
                  // V2.1 系列
                  DropdownMenuItem(
                    value: 'kling-v2-1',
                    child: Text('kling-v2-1 - pro \$0.49'),
                  ),
                  DropdownMenuItem(
                    value: 'kling-v2-1-master',
                    child: Text('kling-v2-1-master - \$1.40 (最高质量)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setVideoModel(value);
                    // 如果选择 master 模型，自动设置 mode 为 master
                    if (value.contains('master')) {
                      settings.setVideoMode('master');
                    } else if (settings.videoMode == 'master') {
                      settings.setVideoMode('std');
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 生成模式（强制 PRO 模式以支持首尾帧）
              DropdownButtonFormField<String>(
                value: settings.videoModel.contains('master') ? 'master' : 'pro',
                decoration: const InputDecoration(
                  labelText: '生成模式',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.high_quality),
                  helperText: '使用 PRO/Master 模式启用首尾帧控制',
                ),
                items: [
                  if (!settings.videoModel.contains('master'))
                    const DropdownMenuItem(
                      value: 'pro',
                      child: Text('pro - 1080p (首尾帧)'),
                    ),
                  if (settings.videoModel.contains('master'))
                    const DropdownMenuItem(
                      value: 'master',
                      child: Text('master (最高质量)'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setVideoMode(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 视频时长
              DropdownButtonFormField<int>(
                value: settings.videoDuration,
                decoration: const InputDecoration(
                  labelText: '视频时长',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5 秒')),
                  DropdownMenuItem(value: 10, child: Text('10 秒 (×2)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setVideoDuration(value);
                  }
                },
              ),
              
              const SizedBox(height: 16),
              _buildCostEstimate(context, settings),
            ],
          ),
        ),
      ),
    );
  }

  /// 背景去除配置
  Widget _buildBackgroundRemovalSection(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Padding(
      padding: _sectionPadding(context, top: 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✂️ 背景去除配置',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // ========== 图片背景去除 ==========
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          '图片背景去除',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 去除方式
                    DropdownButtonFormField<BackgroundRemovalMethod>(
                      value: settings.imageRemovalMethod,
                      decoration: const InputDecoration(
                        labelText: '去除方式',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.auto_fix_high),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: BackgroundRemovalMethod.removeBgApi,
                          child: Text('Remove.bg API（推荐，效果好）'),
                        ),
                        DropdownMenuItem(
                          value: BackgroundRemovalMethod.rembg,
                          child: Text('本地 rembg（免费）'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          settings.setImageRemovalMethod(value);
                        }
                      },
                    ),
                    
                    // 本地模型选择（仅当选择 rembg 时显示）
                    if (settings.imageRemovalMethod == BackgroundRemovalMethod.rembg) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: settings.imageRembgModel,
                        decoration: const InputDecoration(
                          labelText: '本地模型',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.memory),
                          helperText: '不同模型适用于不同场景',
                        ),
                        items: _buildRembgModelItems(),
                        onChanged: (value) {
                          if (value != null) {
                            settings.setImageRembgModel(value);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ========== GIF 背景去除 ==========
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gif, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GIF 背景去除',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: settings.gifRemovalEnabled,
                          onChanged: (value) {
                            settings.setGifRemovalEnabled(value);
                          },
                        ),
                      ],
                    ),
                    
                    if (!settings.gifRemovalEnabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '启用后，生成的 GIF 将自动去除背景（逐帧处理）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    
                    if (settings.gifRemovalEnabled) ...[
                      const SizedBox(height: 16),
                      
                      // 去除方式
                      DropdownButtonFormField<BackgroundRemovalMethod>(
                        value: settings.gifRemovalMethod,
                        decoration: const InputDecoration(
                          labelText: '去除方式',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.auto_fix_high),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: BackgroundRemovalMethod.rembg,
                            child: Text('本地 rembg（免费，推荐）'),
                          ),
                          DropdownMenuItem(
                            value: BackgroundRemovalMethod.removeBgApi,
                            child: Text('Remove.bg API（效果好，消耗额度）'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            settings.setGifRemovalMethod(value);
                          }
                        },
                      ),
                      
                      // 本地模型选择（仅当选择 rembg 时显示）
                      if (settings.gifRemovalMethod == BackgroundRemovalMethod.rembg) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: settings.gifRembgModel,
                          decoration: const InputDecoration(
                            labelText: '本地模型',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.memory),
                            helperText: 'GIF 逐帧处理，建议选择快速模型',
                          ),
                          items: _buildRembgModelItems(),
                          onChanged: (value) {
                            if (value != null) {
                              settings.setGifRembgModel(value);
                            }
                          },
                        ),
                      ],
                      
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'GIF 去背景会逐帧处理，耗时较长',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ========== 自动裁剪开关 ==========
              SwitchListTile(
                title: const Text('自动裁剪'),
                subtitle: const Text('上传图片后自动进行背景去除'),
                value: settings.autoCut,
                onChanged: (value) => settings.setAutoCut(value),
                secondary: const Icon(Icons.content_cut),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 成本估算
  Widget _buildCostEstimate(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);
    
    // 计算单个视频的 units
    double unitsPerVideo;
    switch (settings.videoModel) {
      case 'kling-v2-5-turbo':
        unitsPerVideo = settings.videoMode == 'std' ? 1.5 : 2.5;
        break;
      case 'kling-v2-1':
        unitsPerVideo = settings.videoMode == 'std' ? 2 : 3.5;
        break;
      case 'kling-v2-1-master':
        unitsPerVideo = 10;
        break;
      default:
        unitsPerVideo = 2.5; // PRO 模式默认
    }
    
    // 10秒视频费用翻倍
    if (settings.videoDuration == 10) {
      unitsPerVideo *= 2;
    }
    
    // 完整生成需要 16 个视频（12 过渡 + 4 循环）
    const totalVideos = 16;
    final totalUnits = unitsPerVideo * totalVideos;
    final totalCost = totalUnits * 0.14; // 1 unit ≈ $0.14
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '成本估算',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '单个视频: ${unitsPerVideo.toStringAsFixed(1)} units',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '完整生成 ($totalVideos 个视频): ${totalUnits.toStringAsFixed(0)} units ≈ \$${totalCost.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 rembg 模型选项
  List<DropdownMenuItem<String>> _buildRembgModelItems() {
    return const [
      DropdownMenuItem(
        value: 'u2net',
        child: Text('u2net（高精度，推荐）'),
      ),
      DropdownMenuItem(
        value: 'u2net_p',
        child: Text('u2net_p（快速）'),
      ),
      DropdownMenuItem(
        value: 'u2net_human_seg',
        child: Text('u2net_human_seg（人像优化）'),
      ),
      DropdownMenuItem(
        value: 'silueta',
        child: Text('silueta（超高精度）'),
      ),
      DropdownMenuItem(
        value: 'isnet-anime',
        child: Text('isnet-anime（动漫风格）'),
      ),
      DropdownMenuItem(
        value: 'birefnet-general',
        child: Text('birefnet-general（顶级精度）'),
      ),
    ];
  }

  /// 宠物种类库
  Widget _buildSpeciesLibrarySection(BuildContext context) {
    final theme = Theme.of(context);
    final speciesProvider = context.watch<SpeciesProvider>();
    final defaultSpecies = speciesProvider.defaultSpecies;
    final customSpecies = speciesProvider.customSpecies;

    return Padding(
      padding: _sectionPadding(context, bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🐾 宠物种类库',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '管理默认与自定义的宠物种类',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              if (!speciesProvider.isInitialized)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '默认种类',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: defaultSpecies
                          .map((species) => Chip(
                                label: Text(species),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '自定义种类',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        if (customSpecies.isNotEmpty)
                          Text(
                            '（长按标签可删除）',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    customSpecies.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '暂无自定义种类，点击下方按钮即可新增。',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: customSpecies
                                .map((species) => GestureDetector(
                                      onLongPress: () => _confirmRemoveSpecies(context, species),
                                      child: Chip(
                                        label: Text(species),
                                        deleteIcon: const Icon(Icons.close, size: 16),
                                        onDeleted: () => _confirmRemoveSpecies(context, species),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ))
                                .toList(),
                          ),
                  ],
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showSpeciesManagementSheet(context),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('浏览全部种类'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showAddSpeciesDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('新增种类'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSpeciesDialog(BuildContext context) async {
    final controller = TextEditingController();
    final speciesProvider = context.read<SpeciesProvider>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新增宠物种类'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '请输入新的宠物种类名称',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final success = await speciesProvider.addSpecies(result);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '已添加 "$result"' : '添加失败：该种类已存在或无效')),
    );
  }

  Future<void> _confirmRemoveSpecies(BuildContext context, String species) async {
    final speciesProvider = context.read<SpeciesProvider>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定删除 "$species" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final success = await speciesProvider.removeSpecies(species);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '已删除 "$species"' : '删除失败，请重试')),
    );
  }

  Future<void> _showSpeciesManagementSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SpeciesSelectionSheet(
          onSelected: (_) {},
        );
      },
    );
  }

  EdgeInsets _sectionPadding(BuildContext context, {double top = 16, double bottom = 0}) {
    final horizontal = Responsive.horizontalPadding(context).left;
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}

