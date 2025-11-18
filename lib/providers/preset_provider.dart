import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_presets.dart';

class CustomPreset {
  final String id;
  final String name;
  final String species;
  final String pose;
  final String angle;
  final String description;
  final DateTime createdAt;

  CustomPreset({
    required this.id,
    required this.name,
    required this.species,
    required this.pose,
    required this.angle,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'pose': pose,
      'angle': angle,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomPreset.fromJson(Map<String, dynamic> json) {
    return CustomPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      pose: json['pose'] as String,
      angle: json['angle'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  PetPreset toPetPreset() {
    return PetPreset(
      name: name,
      species: species,
      pose: pose,
      angle: angle,
      category: '自定义',
      description: description,
    );
  }
}

class PresetProvider extends ChangeNotifier {
  static const _storageKey = 'custom_presets_list';

  final List<CustomPreset> _customPresets = [];
  bool _isInitialized = false;

  PresetProvider() {
    _loadPresets();
  }

  bool get isInitialized => _isInitialized;

  UnmodifiableListView<CustomPreset> get customPresets => 
      UnmodifiableListView(_customPresets);

  List<PetPreset> get allPresets {
    final defaultPresets = PetPresets.presets.toList();
    final customPetPresets = _customPresets
        .map((preset) => preset.toPetPreset())
        .toList();
    return [...defaultPresets, ...customPetPresets];
  }

  List<String> getAllCategories() {
    final categories = PetPresets.getCategories().toSet();
    if (_customPresets.isNotEmpty) {
      categories.add('自定义');
    }
    return categories.toList();
  }

  List<PetPreset> getPresetsByCategory(String category) {
    if (category == '自定义') {
      return _customPresets.map((p) => p.toPetPreset()).toList();
    }
    return PetPresets.getPresetsByCategory(category);
  }

  bool isCustomPreset(PetPreset preset) {
    return preset.category == '自定义';
  }

  Future<bool> addPreset({
    required String name,
    required String species,
    required String pose,
    required String angle,
    String? description,
  }) async {
    if (name.trim().isEmpty || species.trim().isEmpty || 
        pose.trim().isEmpty || angle.trim().isEmpty) {
      return false;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final preset = CustomPreset(
      id: id,
      name: name.trim(),
      species: species.trim(),
      pose: pose.trim(),
      angle: angle.trim(),
      description: description?.trim() ?? '$species $pose $angle',
      createdAt: DateTime.now(),
    );

    _customPresets.add(preset);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> removePreset(String presetName) async {
    final index = _customPresets.indexWhere((p) => p.name == presetName);
    if (index == -1) return false;

    _customPresets.removeAt(index);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> clearAllCustomPresets() async {
    if (_customPresets.isEmpty) return;
    _customPresets.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _loadPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored != null) {
        final List<dynamic> jsonList = jsonDecode(stored);
        _customPresets.clear();
        _customPresets.addAll(
          jsonList.map((json) => CustomPreset.fromJson(json)),
        );
      }
    } catch (e) {
      debugPrint('加载自定义预设失败: $e');
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _customPresets.map((p) => p.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存自定义预设失败: $e');
    }
  }
}

