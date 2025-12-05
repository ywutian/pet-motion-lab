import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/species_provider.dart';
import '../providers/rembg_model_provider.dart';
import '../widgets/species_selection_sheet.dart';
import '../utils/responsive.dart';
import '../models/rembg_model.dart';

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
              _buildAPIKeysSection(context),
              _buildDefaultModelsSection(context),
              _buildCuttingSettingsSection(context),
              _buildRembgModelSection(context),
              _buildGenerationSettingsSection(context),
              _buildSpeciesLibrarySection(context),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildAPIKeysSection(BuildContext context) {
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
                '🔑 可灵AI配置',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Access Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                  helperText: '可灵AI访问密钥',
                ),
                obscureText: true,
                controller: TextEditingController(text: settings.klingAccessKey),
                onChanged: (value) => settings.setKlingAccessKey(value),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Secret Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: '可灵AI密钥',
                ),
                obscureText: true,
                controller: TextEditingController(text: settings.klingSecretKey),
                onChanged: (value) => settings.setKlingSecretKey(value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultModelsSection(BuildContext context) {
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
                '🤖 默认模型配置',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: settings.defaultStaticModel,
                decoration: const InputDecoration(
                  labelText: '默认静态模型',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                  helperText: '图生图模型',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'kling-image',
                    child: Text('可灵AI 图生图'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setDefaultStaticModel(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: settings.defaultVideoModel,
                decoration: const InputDecoration(
                  labelText: '默认视频模型',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.video_library),
                  helperText: '图生视频模型',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'kling-video',
                    child: Text('可灵AI 图生视频'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setDefaultVideoModel(value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCuttingSettingsSection(BuildContext context) {
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
                '✂️ 裁剪设置',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.content_cut),
                title: const Text('背景去除工具'),
                subtitle: const Text('本地rembg算法（免费）'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('自动裁剪'),
                subtitle: const Text('上传后自动进行背景裁剪'),
                value: settings.autoCut,
                onChanged: (value) => settings.setAutoCut(value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRembgModelSection(BuildContext context) {
    final theme = Theme.of(context);
    final modelProvider = context.watch<RembgModelProvider>();

    return Padding(
      padding: _sectionPadding(context),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '🎯 本地裁剪模型',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '选择本地背景移除算法模型，不同模型适用于不同场景',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              ...modelProvider.availableModels.map((model) {
                final isSelected = modelProvider.selectedModel == model.type;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  child: InkWell(
                    onTap: () => modelProvider.selectModel(model.type),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                              if (isSelected) const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  model.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimaryContainer
                                        : null,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                      : theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '~${model.estimatedTime.toStringAsFixed(1)}s',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            model.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildModelChip(
                                theme,
                                Icons.photo_size_select_large,
                                '输入: ${model.inputSize}×${model.inputSize}',
                                isSelected,
                              ),
                              if (model.type == RembgModelType.u2net)
                                _buildModelChip(
                                  theme,
                                  Icons.star,
                                  '高精度',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.u2netP)
                                _buildModelChip(
                                  theme,
                                  Icons.speed,
                                  '快速',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.u2netHuman)
                                _buildModelChip(
                                  theme,
                                  Icons.person,
                                  '人像优化',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.silueta)
                                _buildModelChip(
                                  theme,
                                  Icons.auto_awesome,
                                  '超高精度',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.isnetAnime)
                                _buildModelChip(
                                  theme,
                                  Icons.animation,
                                  '动漫风格',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.modnet)
                                _buildModelChip(
                                  theme,
                                  Icons.flash_on,
                                  '实时',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.modnet)
                                _buildModelChip(
                                  theme,
                                  Icons.new_releases,
                                  '2024最新',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.birefnet)
                                _buildModelChip(
                                  theme,
                                  Icons.diamond,
                                  '顶级精度',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.birefnet)
                                _buildModelChip(
                                  theme,
                                  Icons.auto_fix_high,
                                  '双向精修',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.dis)
                                _buildModelChip(
                                  theme,
                                  Icons.contrast,
                                  '高对比度',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.dis)
                                _buildModelChip(
                                  theme,
                                  Icons.blur_on,
                                  '透明物体',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.rmbg2)
                                _buildModelChip(
                                  theme,
                                  Icons.business,
                                  '商业级',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.rmbg2)
                                _buildModelChip(
                                  theme,
                                  Icons.shopping_bag,
                                  '电商专用',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.inspyrenet)
                                _buildModelChip(
                                  theme,
                                  Icons.psychology,
                                  '智能识别',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.inspyrenet)
                                _buildModelChip(
                                  theme,
                                  Icons.center_focus_strong,
                                  '显著性',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.backgroundmattingv2)
                                _buildModelChip(
                                  theme,
                                  Icons.video_library,
                                  '视频级',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.backgroundmattingv2)
                                _buildModelChip(
                                  theme,
                                  Icons.motion_photos_on,
                                  '动态背景',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.ppmatting)
                                _buildModelChip(
                                  theme,
                                  Icons.phone_android,
                                  '移动优化',
                                  isSelected,
                                ),
                              if (model.type == RembgModelType.ppmatting)
                                _buildModelChip(
                                  theme,
                                  Icons.language,
                                  '中文优化',
                                  isSelected,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '当前选择: ${modelProvider.selectedModelInfo.name}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelChip(ThemeData theme, IconData icon, String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationSettingsSection(BuildContext context) {
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
                '🎨 生成设置',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: settings.defaultResolution,
                decoration: const InputDecoration(
                  labelText: '默认分辨率',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.aspect_ratio),
                ),
                items: const [
                  DropdownMenuItem(
                    value: '512x512',
                    child: Text('512 × 512'),
                  ),
                  DropdownMenuItem(
                    value: '1024x1024',
                    child: Text('1024 × 1024'),
                  ),
                  DropdownMenuItem(
                    value: '1080x1080',
                    child: Text('1080 × 1080'),
                  ),
                  DropdownMenuItem(
                    value: '1920x1080',
                    child: Text('1920 × 1080'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setDefaultResolution(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('默认时长'),
                trailing: Text('${settings.defaultDuration}秒'),
                subtitle: Slider(
                  value: settings.defaultDuration.toDouble(),
                  min: 3,
                  max: 10,
                  divisions: 7,
                  label: '${settings.defaultDuration}秒',
                  onChanged: (value) {
                    settings.setDefaultDuration(value.toInt());
                  },
                ),
              ),
              DropdownButtonFormField<int>(
                value: settings.defaultFps,
                decoration: const InputDecoration(
                  labelText: '默认FPS',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                items: const [
                  DropdownMenuItem(value: 24, child: Text('24 FPS')),
                  DropdownMenuItem(value: 30, child: Text('30 FPS')),
                  DropdownMenuItem(value: 60, child: Text('60 FPS')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setDefaultFps(value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                '管理默认与自定义的宠物种类，支持在上传与生成流程中统一使用。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
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
                              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
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

