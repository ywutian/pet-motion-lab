import 'package:flutter/foundation.dart';

/// 平台检测帮助类
class PlatformHelper {
  /// 是否是Web平台
  static bool get isWeb => kIsWeb;
  
  /// 是否是移动平台（iOS或Android）
  static bool get isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
  
  /// 是否是桌面平台
  static bool get isDesktop => !kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux);
  
  /// 是否支持文件系统操作
  static bool get supportsFileSystem => !kIsWeb;
}

