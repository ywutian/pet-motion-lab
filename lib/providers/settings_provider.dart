import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 背景去除方式
enum BackgroundRemovalMethod {
  rembg,      // 本地 rembg
  removeBgApi, // Remove.bg API
}

class SettingsProvider with ChangeNotifier {
  // ============================================
  // 视频生成配置
  // ============================================
  String _videoModel = 'kling-v2-5-turbo'; // 默认使用最新最划算的模型
  String _videoMode = 'std';                // std(720p) 更便宜
  int _videoDuration = 5;                   // 5秒

  // ============================================
  // 背景去除配置 - 图片
  // ============================================
  BackgroundRemovalMethod _imageRemovalMethod = BackgroundRemovalMethod.removeBgApi;
  String _imageRembgModel = 'u2net'; // 本地模型选择

  // ============================================
  // 背景去除配置 - GIF
  // ============================================
  bool _gifRemovalEnabled = false; // 是否启用 GIF 去背景
  BackgroundRemovalMethod _gifRemovalMethod = BackgroundRemovalMethod.rembg;
  String _gifRembgModel = 'u2net'; // 本地模型选择

  // ============================================
  // 宠物信息缓存
  // ============================================
  String _lastPetBreed = '';
  String _lastPetColor = '';
  String _lastPetSpecies = '';
  String _lastPetWeight = '';
  String _lastPetBirthday = '';

  // ============================================
  // 其他设置
  // ============================================
  bool _autoCut = true; // 自动裁剪

  // ============================================
  // Getters - 视频生成
  // ============================================
  String get videoModel => _videoModel;
  String get videoMode => _videoMode;
  int get videoDuration => _videoDuration;

  // ============================================
  // Getters - 图片背景去除
  // ============================================
  BackgroundRemovalMethod get imageRemovalMethod => _imageRemovalMethod;
  String get imageRembgModel => _imageRembgModel;

  // ============================================
  // Getters - GIF 背景去除
  // ============================================
  bool get gifRemovalEnabled => _gifRemovalEnabled;
  BackgroundRemovalMethod get gifRemovalMethod => _gifRemovalMethod;
  String get gifRembgModel => _gifRembgModel;

  // ============================================
  // Getters - 宠物信息
  // ============================================
  String get lastPetBreed => _lastPetBreed;
  String get lastPetColor => _lastPetColor;
  String get lastPetSpecies => _lastPetSpecies;
  String get lastPetWeight => _lastPetWeight;
  String get lastPetBirthday => _lastPetBirthday;

  // ============================================
  // Getters - 其他
  // ============================================
  bool get autoCut => _autoCut;

  // ============================================
  // 兼容旧代码的 Getters（后续可移除）
  // ============================================
  String get klingAccessKey => '';
  String get klingSecretKey => '';
  String get defaultStaticModel => 'kling-image';
  String get defaultVideoModel => 'kling-video';
  String get defaultResolution => '1080x1080';
  int get defaultDuration => _videoDuration;
  int get defaultFps => 24;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 视频生成配置
    _videoModel = prefs.getString('video_model') ?? 'kling-v2-5-turbo';
    _videoMode = prefs.getString('video_mode') ?? 'std';
    _videoDuration = prefs.getInt('video_duration') ?? 5;
    
    // 图片背景去除
    final imageMethodStr = prefs.getString('image_removal_method') ?? 'removeBgApi';
    _imageRemovalMethod = imageMethodStr == 'rembg' 
        ? BackgroundRemovalMethod.rembg 
        : BackgroundRemovalMethod.removeBgApi;
    _imageRembgModel = prefs.getString('image_rembg_model') ?? 'u2net';
    
    // GIF 背景去除
    _gifRemovalEnabled = prefs.getBool('gif_removal_enabled') ?? false;
    final gifMethodStr = prefs.getString('gif_removal_method') ?? 'rembg';
    _gifRemovalMethod = gifMethodStr == 'removeBgApi' 
        ? BackgroundRemovalMethod.removeBgApi 
        : BackgroundRemovalMethod.rembg;
    _gifRembgModel = prefs.getString('gif_rembg_model') ?? 'u2net';
    
    // 宠物信息
    _lastPetBreed = prefs.getString('last_pet_breed') ?? '';
    _lastPetColor = prefs.getString('last_pet_color') ?? '';
    _lastPetSpecies = prefs.getString('last_pet_species') ?? '';
    _lastPetWeight = prefs.getString('last_pet_weight') ?? '';
    _lastPetBirthday = prefs.getString('last_pet_birthday') ?? '';
    
    // 其他
    _autoCut = prefs.getBool('auto_cut') ?? true;
    
    notifyListeners();
  }

  // ============================================
  // Setters - 视频生成
  // ============================================
  Future<void> setVideoModel(String model) async {
    _videoModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('video_model', model);
    notifyListeners();
  }

  Future<void> setVideoMode(String mode) async {
    _videoMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('video_mode', mode);
    notifyListeners();
  }

  Future<void> setVideoDuration(int duration) async {
    _videoDuration = duration;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('video_duration', duration);
    notifyListeners();
  }

  // ============================================
  // Setters - 图片背景去除
  // ============================================
  Future<void> setImageRemovalMethod(BackgroundRemovalMethod method) async {
    _imageRemovalMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('image_removal_method', 
        method == BackgroundRemovalMethod.rembg ? 'rembg' : 'removeBgApi');
    notifyListeners();
  }

  Future<void> setImageRembgModel(String model) async {
    _imageRembgModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('image_rembg_model', model);
    notifyListeners();
  }

  // ============================================
  // Setters - GIF 背景去除
  // ============================================
  Future<void> setGifRemovalEnabled(bool enabled) async {
    _gifRemovalEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gif_removal_enabled', enabled);
    notifyListeners();
  }

  Future<void> setGifRemovalMethod(BackgroundRemovalMethod method) async {
    _gifRemovalMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gif_removal_method', 
        method == BackgroundRemovalMethod.rembg ? 'rembg' : 'removeBgApi');
    notifyListeners();
  }

  Future<void> setGifRembgModel(String model) async {
    _gifRembgModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gif_rembg_model', model);
    notifyListeners();
  }

  // ============================================
  // Setters - 宠物信息
  // ============================================
  Future<void> savePetInfo(String breed, String color, String species, 
      {String? weight, String? birthday}) async {
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

  // ============================================
  // Setters - 其他
  // ============================================
  Future<void> setAutoCut(bool value) async {
    _autoCut = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_cut', value);
    notifyListeners();
  }

  // ============================================
  // 兼容旧代码的 Setters（空实现）
  // ============================================
  Future<void> setKlingAccessKey(String key) async {}
  Future<void> setKlingSecretKey(String key) async {}
  Future<void> setDefaultStaticModel(String model) async {}
  Future<void> setDefaultVideoModel(String model) async {}
  Future<void> setDefaultResolution(String resolution) async {}
  Future<void> setDefaultDuration(int duration) async {
    await setVideoDuration(duration);
  }
  Future<void> setDefaultFps(int fps) async {}
}
