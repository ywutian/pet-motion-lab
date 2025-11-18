import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rembg_model.dart';

class RembgModelProvider extends ChangeNotifier {
  static const _storageKey = 'selected_rembg_model';
  
  RembgModelType _selectedModel = RembgModelType.u2netP;
  bool _isInitialized = false;

  RembgModelProvider() {
    _loadSelectedModel();
  }

  bool get isInitialized => _isInitialized;
  RembgModelType get selectedModel => _selectedModel;
  RembgModelInfo get selectedModelInfo => RembgModelInfo.fromType(_selectedModel);

  List<RembgModelInfo> get availableModels => RembgModelInfo.getAllModels();

  Future<void> selectModel(RembgModelType model) async {
    if (_selectedModel == model) return;
    
    _selectedModel = model;
    await _persist();
    notifyListeners();
  }

  Future<void> _loadSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedIndex = prefs.getInt(_storageKey);
      
      if (storedIndex != null && storedIndex >= 0 && storedIndex < RembgModelType.values.length) {
        _selectedModel = RembgModelType.values[storedIndex];
      }
    } catch (e) {
      debugPrint('加载模型选择失败: $e');
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageKey, _selectedModel.index);
    } catch (e) {
      debugPrint('保存模型选择失败: $e');
    }
  }
}


