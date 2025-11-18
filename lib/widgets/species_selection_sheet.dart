import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/species_provider.dart';

class SpeciesSelectionSheet extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onSelected;

  const SpeciesSelectionSheet({
    super.key,
    this.initialValue,
    required this.onSelected,
  });

  @override
  State<SpeciesSelectionSheet> createState() => _SpeciesSelectionSheetState();
}

class _SpeciesSelectionSheetState extends State<SpeciesSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newSpeciesController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _newSpeciesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Consumer<SpeciesProvider>(
              builder: (context, provider, _) {
                final speciesList = provider.allSpecies
                    .where((item) => item.toLowerCase().contains(_query.toLowerCase()))
                    .toList();

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '选择宠物种类',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            tooltip: '关闭',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '搜索种类 (支持中/英文)',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _query = '';
                                      _searchController.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                  tooltip: '清除搜索',
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() => _query = value.trim());
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newSpeciesController,
                              decoration: const InputDecoration(
                                labelText: '新增宠物种类',
                                hintText: '如 萨摩耶 / ragdoll',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleAddSpecies(provider),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _handleAddSpecies(provider),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: speciesList.isEmpty
                          ? _buildEmptyState(theme)
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: speciesList.length,
                              itemBuilder: (context, index) {
                                final item = speciesList[index];
                                final isSelected = widget.initialValue != null &&
                                    item.toLowerCase() == widget.initialValue!.toLowerCase();
                                final isCustom = provider.isCustom(item);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                                      child: Text(
                                        _firstSymbol(item),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(item),
                                    subtitle: isCustom
                                        ? const Text('自定义种类', style: TextStyle(fontSize: 12))
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: theme.colorScheme.primary,
                                          ),
                                        if (isCustom)
                                          IconButton(
                                            tooltip: '删除自定义种类',
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: () => _confirmRemoveSpecies(provider, item),
                                          ),
                                      ],
                                    ),
                                    onTap: () {
                                      widget.onSelected(item);
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无匹配的种类，请尝试添加新种类。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddSpecies(SpeciesProvider provider) async {
    final value = _newSpeciesController.text.trim();
    if (value.isEmpty) {
      _showSnackBar('请输入宠物种类名称');
      return;
    }

    final success = await provider.addSpecies(value);
    if (!mounted) return;

    if (success) {
      _showSnackBar('已添加 "$value"');
      _newSpeciesController.clear();
    } else {
      _showSnackBar('该种类已存在或无效');
    }
  }

  Future<void> _confirmRemoveSpecies(SpeciesProvider provider, String species) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除 "$species" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final success = await provider.removeSpecies(species);
    if (!mounted) return;

    if (success) {
      _showSnackBar('已删除 "$species"');
    } else {
      _showSnackBar('删除失败，请重试');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _firstSymbol(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '宠';
    final iterator = trimmed.runes.iterator;
    if (!iterator.moveNext()) return trimmed.substring(0, 1);
    final rune = iterator.current;
    final char = String.fromCharCode(rune);
    if (RegExp(r'^[a-zA-Z]$').hasMatch(char)) {
      return char.toUpperCase();
    }
    return char;
  }
}
