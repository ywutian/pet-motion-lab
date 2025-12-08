import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/upload_image.dart';
import '../models/prompt_templates.dart';
import '../models/pet_presets.dart';
import '../services/cutting_service.dart';
import '../services/purity_detector.dart';
import '../providers/settings_provider.dart';
import '../providers/preset_provider.dart';
import '../providers/species_provider.dart';
import '../providers/rembg_model_provider.dart';
import 'species_selection_sheet.dart';

class ImageCard extends StatefulWidget {
  final UploadImage image;
  final Function(UploadImage) onUpdate;
  final VoidCallback onRemove;

  const ImageCard({
    super.key,
    required this.image,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<ImageCard> {
  final _speciesController = TextEditingController();
  final _poseController = TextEditingController();
  final _angleController = TextEditingController();
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speciesController.text = widget.image.species;
    _poseController.text = widget.image.pose;
    _angleController.text = widget.image.angle;
    _tagController.text = widget.image.tag;
  }

  @override
  void dispose() {
    _speciesController.dispose();
    _poseController.dispose();
    _angleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _updateField() {
    widget.onUpdate(widget.image.copyWith(
      species: _speciesController.text.trim(),
      pose: _poseController.text.trim(),
      angle: _angleController.text.trim(),
      tag: _tagController.text.trim(),
    ));
  }

  Future<void> _cutImage() async {
    final settings = context.read<SettingsProvider>();
    final modelProvider = context.read<RembgModelProvider>();
    
    setState(() {
      widget.onUpdate(widget.image.copyWith(isProcessing: true));
    });

    try {
      final result = await CuttingService.cutImage(
        inputFile: widget.image.file,
        tool: settings.defaultCuttingTool,
        apiKey: settings.clipdropApiKey,
        modelType: settings.defaultCuttingTool == 'rembg_local' 
            ? modelProvider.selectedModel 
            : null,
      );

      if (result.success) {
        final purity = await PurityDetector.detect(result.outputFile);
        
        widget.onUpdate(widget.image.copyWith(
          cutFilePath: result.outputFile.path,
          cutPS: purity.ps,
          isProcessing: false,
        ));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('裁剪完成！纯净度: ${purity.ps.toStringAsFixed(1)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result.error);
      }
    } catch (e) {
      widget.onUpdate(widget.image.copyWith(isProcessing: false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('裁剪失败: $e')),
        );
      }
    }
  }

  void _showPromptDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PromptConfigSheet(
        image: widget.image,
        onUpdate: widget.onUpdate,
      ),
    );
  }

  void _showPresetDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => PresetSelectionSheet(
        onPresetSelected: (preset) {
          setState(() {
            _speciesController.text = preset.species;
            _poseController.text = preset.pose;
            _angleController.text = preset.angle;
          });
          _updateField();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openSpeciesSelector() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SpeciesSelectionSheet(
        initialValue: _speciesController.text,
        onSelected: _handleSpeciesSelected,
      ),
    );
  }

  void _handleSpeciesSelected(String species) {
    setState(() {
      _speciesController.text = species;
    });
    _updateField();
  }

  @override
  Widget build(BuildContext context) {
    final displayFile = widget.image.cutFilePath != null
        ? File(widget.image.cutFilePath!)
        : widget.image.file;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  displayFile,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (widget.image.originalPS != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getPSColor(widget.image.originalPS!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PS: ${widget.image.originalPS!.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (widget.image.cutPS != null)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getPSColor(widget.image.cutPS!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.content_cut,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PS: ${widget.image.cutPS!.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.image.isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showPresetDialog,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      '快速选择预设组合',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _speciesController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: '宠物种类',
                          hintText: '点击选择或新增',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.expand_more),
                            tooltip: '选择或新增宠物种类',
                            onPressed: _openSpeciesSelector,
                          ),
                        ),
                        onTap: _openSpeciesSelector,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _poseController,
                        decoration: const InputDecoration(
                          labelText: '姿势',
                          hintText: 'sit/walk/rest',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => _updateField(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _angleController,
                        decoration: const InputDecoration(
                          labelText: '角度',
                          hintText: 'front/left/right',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => _updateField(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          hintText: '可选',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => _updateField(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 裁剪提示（如果还没裁剪）
                if (widget.image.cutFilePath == null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '建议先裁剪主体，去除背景后效果更好',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: widget.image.isProcessing ? null : _cutImage,
                        icon: const Icon(Icons.content_cut, size: 18),
                        label: Text(
                          widget.image.cutFilePath != null ? '重新裁剪' : '裁剪主体',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showPromptDialog,
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text(
                          'Prompt',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPSColor(double ps) {
    if (ps >= 85) return Colors.green;
    if (ps >= 70) return Colors.orange;
    return Colors.red;
  }
}

class PromptConfigSheet extends StatefulWidget {
  final UploadImage image;
  final Function(UploadImage) onUpdate;

  const PromptConfigSheet({
    super.key,
    required this.image,
    required this.onUpdate,
  });

  @override
  State<PromptConfigSheet> createState() => _PromptConfigSheetState();
}

class _PromptConfigSheetState extends State<PromptConfigSheet> {
  late TextEditingController _staticPromptController;
  late TextEditingController _motionPromptController;
  String _selectedCategory = '基础静态动作';

  @override
  void initState() {
    super.initState();
    _staticPromptController = TextEditingController(text: widget.image.staticPrompt);
    _motionPromptController = TextEditingController(text: widget.image.motionPrompt);
  }

  @override
  void dispose() {
    _staticPromptController.dispose();
    _motionPromptController.dispose();
    super.dispose();
  }

  void _applyTemplate(PromptTemplate template) {
    final species = widget.image.species.isNotEmpty 
        ? widget.image.species 
        : '宠物';
    final animalType = _getAnimalType(species);
    
    final filledPrompt = PromptTemplates.fillTemplate(
      template.prompt,
      species,
      animalType,
    );

    if (template.category == 'static') {
      setState(() {
        _staticPromptController.text = filledPrompt;
      });
    } else {
      setState(() {
        _motionPromptController.text = filledPrompt;
      });
    }
  }

  String _getAnimalType(String species) {
    if (species.toLowerCase().contains('dog') || 
        species.contains('犬') || 
        species.contains('柴') ||
        species.contains('边牧')) {
      return '犬';
    } else if (species.toLowerCase().contains('cat') || 
               species.contains('猫')) {
      return '猫';
    }
    return '动物';
  }

  void _save() {
    widget.onUpdate(widget.image.copyWith(
      staticPrompt: _staticPromptController.text,
      motionPrompt: _motionPromptController.text,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = PromptTemplates.getAllCategories();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Prompt配置',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Text(
                      '静态图Prompt',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _staticPromptController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '输入静态图生成提示词...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '动态视频Prompt',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _motionPromptController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '输入动态视频生成提示词...',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Prompt模板库',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((category) {
                          final isSelected = _selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedCategory = category);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...PromptTemplates.getTemplatesByCategory(_selectedCategory)
                        .map((template) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(template.name),
                            subtitle: Text(
                              template.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _applyTemplate(template),
                            ),
                            onTap: () => _applyTemplate(template),
                          ),
                        )),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('保存Prompt'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PresetSelectionSheet extends StatefulWidget {
  final Function(PetPreset) onPresetSelected;

  const PresetSelectionSheet({
    super.key,
    required this.onPresetSelected,
  });

  @override
  State<PresetSelectionSheet> createState() => _PresetSelectionSheetState();
}

class _PresetSelectionSheetState extends State<PresetSelectionSheet> {
  String _selectedCategory = '边牧';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PetPreset> _getFilteredPresets(PresetProvider presetProvider) {
    if (_searchQuery.isNotEmpty) {
      return presetProvider.allPresets
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.species.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.pose.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.angle.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return presetProvider.getPresetsByCategory(_selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presetProvider = context.watch<PresetProvider>();
    final categories = presetProvider.getAllCategories();
    final filteredPresets = _getFilteredPresets(presetProvider);

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
          child: Column(
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择预设组合',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddPresetDialog(context, presetProvider),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('新增'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索组合 (种类/姿势/角度)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (_searchQuery.isEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = category);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredPresets.length,
                  itemBuilder: (context, index) {
                    final preset = filteredPresets[index];
                    final isCustom = presetProvider.isCustomPreset(preset);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            preset.species.substring(0, 1),
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                preset.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isCustom)
                              const Chip(
                                label: Text('自定义', style: TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              preset.description,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: [
                                Chip(
                                  label: Text(preset.pose),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelStyle: const TextStyle(fontSize: 11),
                                ),
                                Chip(
                                  label: Text(preset.angle),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelStyle: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isCustom
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    tooltip: '删除自定义预设',
                                    onPressed: () => _confirmDeletePreset(context, presetProvider, preset.name),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => widget.onPresetSelected(preset),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddPresetDialog(BuildContext context, PresetProvider presetProvider) async {
    final speciesProvider = context.read<SpeciesProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedSpecies = speciesProvider.allSpecies.first;
    String selectedPose = PetPresets.commonPoses.first;
    String selectedAngle = PetPresets.commonAngles.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('新增自定义预设'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '预设名称',
                        hintText: '如: 自定义萨摩耶坐姿',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSpecies,
                      decoration: const InputDecoration(
                        labelText: '宠物种类',
                        border: OutlineInputBorder(),
                      ),
                      items: speciesProvider.allSpecies
                          .map((species) => DropdownMenuItem(
                                value: species,
                                child: Text(species),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedSpecies = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPose,
                      decoration: const InputDecoration(
                        labelText: '姿势',
                        border: OutlineInputBorder(),
                      ),
                      items: PetPresets.commonPoses
                          .map((pose) => DropdownMenuItem(
                                value: pose,
                                child: Text(pose),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedPose = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAngle,
                      decoration: const InputDecoration(
                        labelText: '角度',
                        border: OutlineInputBorder(),
                      ),
                      items: PetPresets.commonAngles
                          .map((angle) => DropdownMenuItem(
                                value: angle,
                                child: Text(angle),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedAngle = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: '描述（可选）',
                        hintText: '简单描述这个预设',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final presetName = nameController.text;

    final success = await presetProvider.addPreset(
      name: presetName,
      species: selectedSpecies,
      pose: selectedPose,
      angle: selectedAngle,
      description: descriptionController.text.isEmpty
          ? null
          : descriptionController.text,
    );

    if (!mounted) return;

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('已添加预设 "$presetName"')),
      );
      setState(() => _selectedCategory = '自定义');
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('添加失败：预设名称不能为空')),
      );
    }
  }

  Future<void> _confirmDeletePreset(
    BuildContext context,
    PresetProvider presetProvider,
    String presetName,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除预设 "$presetName" 吗？'),
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

    final success = await presetProvider.removePreset(presetName);
    if (!mounted) return;

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('已删除预设 "$presetName"')),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('删除失败，请重试')),
      );
    }
  }
}
