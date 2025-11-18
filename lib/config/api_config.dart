import 'package:flutter/foundation.dart';

/// API 配置 - 统一管理后端地址
class ApiConfig {
  // 从环境变量读取 API 地址（Web 部署时使用）
  // 在 Web 构建时，可以通过 --dart-define 传入
  static const String _envApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// 获取后端 API 基础 URL
  static String get baseUrl {
    // 1. 优先使用环境变量（生产环境）
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }

    // 2. 本地开发环境
    if (kIsWeb) {
      // Web 开发环境：使用 localhost
      return 'http://localhost:8002';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 真机：使用电脑的实际 IP 地址
      // 注意：需要根据你的网络环境修改这个 IP
      return 'http://10.0.0.120:8002';
    } else {
      // iOS/macOS/Windows/Linux：使用 localhost
      return 'http://localhost:8002';
    }
  }

  /// 可灵AI API 地址（直接调用可灵AI时使用）
  static const String klingApiUrl = 'https://api-beijing.klingai.com';

  /// 是否为生产环境
  static bool get isProduction => _envApiUrl.isNotEmpty;

  /// 打印当前配置（调试用）
  static void printConfig() {
    print('🔧 API Configuration:');
    print('  Base URL: $baseUrl');
    print('  Environment: ${isProduction ? "Production" : "Development"}');
    print('  Platform: ${defaultTargetPlatform.name}');
    print('  Is Web: $kIsWeb');
  }
}

