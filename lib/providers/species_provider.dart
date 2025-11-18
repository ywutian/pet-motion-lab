import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_presets.dart';

class SpeciesProvider extends ChangeNotifier {
  static const _storageKey = 'custom_species_list';

  final List<String> _defaultSpecies = List<String>.from(PetPresets.commonSpecies);
  final List<String> _customSpecies = [];
  bool _isInitialized = false;

  SpeciesProvider() {
    _loadSpecies();
  }

  bool get isInitialized => _isInitialized;

  UnmodifiableListView<String> get defaultSpecies => UnmodifiableListView(_defaultSpecies);

  UnmodifiableListView<String> get customSpecies => UnmodifiableListView(_customSpecies);

  UnmodifiableListView<String> get allSpecies {
    final merged = <String>{};
    for (final species in _defaultSpecies) {
      merged.add(species);
    }
    for (final species in _customSpecies) {
      merged.add(species);
    }
    final sorted = merged.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return UnmodifiableListView(sorted);
  }

  bool isCustom(String species) {
    return _customSpecies.any((item) => _normalize(item) == _normalize(species));
  }

  Future<bool> addSpecies(String species) async {
    final trimmed = species.trim();
    if (trimmed.isEmpty) return false;

    final normalized = _normalize(trimmed);
    final existsInDefaults = _defaultSpecies.any((item) => _normalize(item) == normalized);
    final existsInCustom = _customSpecies.any((item) => _normalize(item) == normalized);

    if (existsInDefaults || existsInCustom) {
      return false;
    }

    _customSpecies.add(_capitalize(trimmed));
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> removeSpecies(String species) async {
    final normalized = _normalize(species);
    final index = _customSpecies.indexWhere((item) => _normalize(item) == normalized);
    if (index == -1) {
      return false;
    }

    _customSpecies.removeAt(index);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> resetCustomSpecies() async {
    if (_customSpecies.isEmpty) return;
    _customSpecies.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _loadSpecies() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey) ?? [];
    _customSpecies
      ..clear()
      ..addAll(stored.where((value) => value.trim().isNotEmpty).map(_capitalize));
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _customSpecies);
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    final trimmed = value.trim();
    if (trimmed.length == 1) {
      return trimmed.toUpperCase();
    }
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
