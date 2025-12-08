import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // 视频模型选择（可灵AI的4个视频模型）
  // kling-v2-5-turbo: $0.35/5s - 性价比最高，支持首尾帧 ⭐推荐
  // kling-v2-1: $0.49/5s - 画质最佳，支持首尾帧
  // kling-v1-6: $0.28/5s - 稳定版本
  // kling-v1-5: $0.21/5s - 经济实惠
  String _defaultVideoModel = 'kling-v2-5-turbo';

  // 宠物信息缓存
  String _lastPetBreed = '';
  String _lastPetColor = '';
  String _lastPetSpecies = '';
  String _lastPetWeight = '';  // 重量（如：5kg）
  String _lastPetBirthday = '';  // 生日（如：2020-01-01）

  // 背景去除
  bool _autoCut = true;

  // 生成参数
  String _defaultResolution = '1080x1080';
  int _defaultDuration = 5;
  int _defaultFps = 24;

  // Getters
  String get defaultVideoModel => _defaultVideoModel;
  String get lastPetBreed => _lastPetBreed;
  String get lastPetColor => _lastPetColor;
  String get lastPetSpecies => _lastPetSpecies;
  String get lastPetWeight => _lastPetWeight;
  String get lastPetBirthday => _lastPetBirthday;
  bool get autoCut => _autoCut;
  String get defaultResolution => _defaultResolution;
  int get defaultDuration => _defaultDuration;
  int get defaultFps => _defaultFps;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultVideoModel = prefs.getString('default_video_model') ?? 'kling-v2-5-turbo';
    _lastPetBreed = prefs.getString('last_pet_breed') ?? '';
    _lastPetColor = prefs.getString('last_pet_color') ?? '';
    _lastPetSpecies = prefs.getString('last_pet_species') ?? '';
    _lastPetWeight = prefs.getString('last_pet_weight') ?? '';
    _lastPetBirthday = prefs.getString('last_pet_birthday') ?? '';
    _autoCut = prefs.getBool('auto_cut') ?? true;
    _defaultResolution = prefs.getString('default_resolution') ?? '1080x1080';
    _defaultDuration = prefs.getInt('default_duration') ?? 5;
    _defaultFps = prefs.getInt('default_fps') ?? 24;
    notifyListeners();
  }

  Future<void> savePetInfo(String breed, String color, String species, {String? weight, String? birthday}) async {
    _lastPetBreed = breed;
    _lastPetColor = color;
    _lastPetSpecies = species;
    if (weight != null) _lastPetWeight = weight;
    if (birthday != null) _lastPetBirthday = birthday;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_pet_breed', breed);
    await prefs.setString('last_pet_color', color);
    await prefs.setString('last_pet_species', species);
    if (weight != null) await prefs.setString('last_pet_weight', weight);
    if (birthday != null) await prefs.setString('last_pet_birthday', birthday);
    notifyListeners();
  }

  Future<void> setDefaultVideoModel(String model) async {
    _defaultVideoModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_video_model', model);
    notifyListeners();
  }

  Future<void> setAutoCut(bool value) async {
    _autoCut = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_cut', value);
    notifyListeners();
  }

  Future<void> setDefaultResolution(String resolution) async {
    _defaultResolution = resolution;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_resolution', resolution);
    notifyListeners();
  }

  Future<void> setDefaultDuration(int duration) async {
    _defaultDuration = duration;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_duration', duration);
    notifyListeners();
  }

  Future<void> setDefaultFps(int fps) async {
    _defaultFps = fps;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_fps', fps);
    notifyListeners();
  }
}

