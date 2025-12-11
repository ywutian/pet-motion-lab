import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/species_provider.dart';
import '../widgets/species_selection_sheet.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../theme/app_spacing.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('设置中心')),
      scrollable: true,
      body: Column(
        children: [
          _buildVideoModelsSection(context),
          AppSpacing.vGapLG,
          _buildGenerationSettingsSection(context),
          AppSpacing.vGapLG,
          _buildSpeciesLibrarySection(context),
          AppSpacing.vGapXXL,
        ],
      ),
    );
  }

  Widget _buildVideoModelsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Card(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '视频模型配置',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.vGapXS,
            Text(
              '选择默认的视频生成模型，不同模型在质量和价格上有所差异',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            AppSpacing.vGapMD,
            DropdownButtonFormField<String>(
              value: settings.defaultVideoModel,
              decoration: const InputDecoration(
                labelText: '默认视频模型',
                prefixIcon: Icon(Icons.video_library),
              ),
              items: const [
                DropdownMenuItem(value: 'kling-v2-5-turbo', child: Text('V2.5 Turbo · \$0.35/5s · 性价比最高 ⭐')),
                DropdownMenuItem(value: 'kling-v2-1', child: Text('V2.1 Pro · \$0.49/5s · 画质最佳')),
                DropdownMenuItem(value: 'kling-v1-6', child: Text('V1.6 Pro · \$0.28/5s · 稳定版本')),
                DropdownMenuItem(value: 'kling-v1-5', child: Text('V1.5 Pro · \$0.21/5s · 经济实惠')),
              ],
              onChanged: (value) {
                if (value != null) settings.setDefaultVideoModel(value);
              },
            ),
            AppSpacing.vGapMD,
            Container(
              padding: AppSpacing.paddingMD,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: AppSpacing.borderRadiusMD,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('模型对比', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  AppSpacing.vGapSM,
                  _buildModelCompareRow(theme, 'V2.5 Turbo', '\$0.35', '⭐⭐⭐⭐', '支持首尾帧，性价比最高'),
                  _buildModelCompareRow(theme, 'V2.1 Pro', '\$0.49', '⭐⭐⭐⭐⭐', '支持首尾帧，画质最佳'),
                  _buildModelCompareRow(theme, 'V1.6 Pro', '\$0.28', '⭐⭐⭐', '稳定版本，适合常规使用'),
                  _buildModelCompareRow(theme, 'V1.5 Pro', '\$0.21', '⭐⭐', '最便宜，质量较低'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCompareRow(ThemeData theme, String name, String price, String quality, String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(name, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 50,
            child: Text(price, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
          ),
          SizedBox(
            width: 70,
            child: Text(quality, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(note, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Card(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('生成设置', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.vGapMD,
            DropdownButtonFormField<String>(
              value: settings.defaultResolution,
              decoration: const InputDecoration(labelText: '默认分辨率', prefixIcon: Icon(Icons.aspect_ratio)),
              items: const [
                DropdownMenuItem(value: '512x512', child: Text('512 × 512')),
                DropdownMenuItem(value: '1024x1024', child: Text('1024 × 1024')),
                DropdownMenuItem(value: '1080x1080', child: Text('1080 × 1080')),
                DropdownMenuItem(value: '1920x1080', child: Text('1920 × 1080')),
              ],
              onChanged: (value) {
                if (value != null) settings.setDefaultResolution(value);
              },
            ),
            AppSpacing.vGapMD,
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer),
              title: const Text('默认时长'),
              trailing: Text('${settings.defaultDuration}秒'),
              subtitle: Slider(
                value: settings.defaultDuration.toDouble(),
                min: 3,
                max: 10,
                divisions: 7,
                label: '${settings.defaultDuration}秒',
                onChanged: (value) => settings.setDefaultDuration(value.toInt()),
              ),
            ),
            AppSpacing.vGapSM,
            DropdownButtonFormField<int>(
              value: settings.defaultFps,
              decoration: const InputDecoration(labelText: '默认FPS', prefixIcon: Icon(Icons.speed)),
              items: const [
                DropdownMenuItem(value: 24, child: Text('24 FPS')),
                DropdownMenuItem(value: 30, child: Text('30 FPS')),
                DropdownMenuItem(value: 60, child: Text('60 FPS')),
              ],
              onChanged: (value) {
                if (value != null) settings.setDefaultFps(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeciesLibrarySection(BuildContext context) {
    final theme = Theme.of(context);
    final speciesProvider = context.watch<SpeciesProvider>();
    final defaultSpecies = speciesProvider.defaultSpecies;
    final customSpecies = speciesProvider.customSpecies;

    return Card(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('宠物种类库', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            AppSpacing.vGapXS,
            Text(
              '管理默认与自定义的宠物种类，支持在上传与生成流程中统一使用。',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            AppSpacing.vGapMD,
            if (!speciesProvider.isInitialized)
              const AppLoading()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('默认种类', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  AppSpacing.vGapSM,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: defaultSpecies.map((s) => Chip(label: Text(s), visualDensity: VisualDensity.compact)).toList(),
                  ),
                  AppSpacing.vGapMD,
                  Row(
                    children: [
                      Text('自定义种类', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      AppSpacing.hGapSM,
                      if (customSpecies.isNotEmpty)
                        Text('（长按标签可删除）', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                  AppSpacing.vGapSM,
                  customSpecies.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: AppSpacing.paddingMD,
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                            borderRadius: AppSpacing.borderRadiusMD,
                          ),
                          child: Text('暂无自定义种类，点击下方按钮即可新增。', style: theme.textTheme.bodyMedium),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: customSpecies
                              .map((s) => GestureDetector(
                                    onLongPress: () => _confirmRemoveSpecies(context, s),
                                    child: Chip(
                                      label: Text(s),
                                      deleteIcon: const Icon(Icons.close, size: 16),
                                      onDeleted: () => _confirmRemoveSpecies(context, s),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ))
                              .toList(),
                        ),
                ],
              ),
            AppSpacing.vGapLG,
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _showSpeciesManagementSheet(context), icon: const Icon(Icons.list_alt), label: const Text('浏览全部'))),
                AppSpacing.hGapMD,
                Expanded(child: FilledButton.icon(onPressed: () => _showAddSpeciesDialog(context), icon: const Icon(Icons.add), label: const Text('新增种类'))),
              ],
            ),
          ],
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

}

