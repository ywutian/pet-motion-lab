enum RembgModelType {
  u2net,
  u2netHuman,
  u2netP,
  silueta,
  isnetAnime,
  modnet,
  birefnet,
  dis,
  rmbg2,
  inspyrenet,
  backgroundmattingv2,
  ppmatting;

  String get displayName {
    switch (this) {
      case RembgModelType.u2net:
        return 'U2-Net (通用)';
      case RembgModelType.u2netHuman:
        return 'U2-Net Human (人像)';
      case RembgModelType.u2netP:
        return 'U2-Net-P (轻量)';
      case RembgModelType.silueta:
        return 'Silueta (高精度)';
      case RembgModelType.isnetAnime:
        return 'IS-Net Anime (动漫)';
      case RembgModelType.modnet:
        return 'MODNet (实时抠图)';
      case RembgModelType.birefnet:
        return 'BiRefNet (双向精修)';
      case RembgModelType.dis:
        return 'DIS (二分分割)';
      case RembgModelType.rmbg2:
        return 'RMBG-2.0 (商业级)';
      case RembgModelType.inspyrenet:
        return 'InSPyReNet (显著性)';
      case RembgModelType.backgroundmattingv2:
        return 'BGMv2 (视频抠图)';
      case RembgModelType.ppmatting:
        return 'PP-Matting (实用级)';
    }
  }

  String get description {
    switch (this) {
      case RembgModelType.u2net:
        return '通用背景移除模型，适用于大多数场景，精度高但速度较慢';
      case RembgModelType.u2netHuman:
        return '专门针对人像优化的模型，对人物轮廓识别更准确';
      case RembgModelType.u2netP:
        return '轻量级模型，速度快但精度略低，适合快速处理';
      case RembgModelType.silueta:
        return '高精度模型，对复杂背景和细节处理更好，但速度最慢';
      case RembgModelType.isnetAnime:
        return '专为动漫/卡通图像优化，适合处理二次元风格图片';
      case RembgModelType.modnet:
        return '2024最新实时抠图模型，无需三分图，专为人像设计，速度极快且精度高';
      case RembgModelType.birefnet:
        return '2024顶级双向精修网络，抠图精度最高，边缘处理完美，适合专业摄影';
      case RembgModelType.dis:
        return '二分图像分割模型，专注高对比度场景，对透明物体和细节处理优秀';
      case RembgModelType.rmbg2:
        return 'Bria AI商业级模型，超越Remove.bg，电商产品图专用，精度和速度完美平衡';
      case RembgModelType.inspyrenet:
        return '显著性检测网络，自动识别主体，复杂场景下表现出色，智能化程度高';
      case RembgModelType.backgroundmattingv2:
        return '视频级抠图模型，支持动态背景，适合视频处理和实时应用，一致性好';
      case RembgModelType.ppmatting:
        return 'PaddlePaddle实用级模型，中文场景优化，轻量高效，适合移动端部署';
    }
  }

  String get modelFileName {
    switch (this) {
      case RembgModelType.u2net:
        return 'u2net.tflite';
      case RembgModelType.u2netHuman:
        return 'u2net_human_seg.tflite';
      case RembgModelType.u2netP:
        return 'u2netp.tflite';
      case RembgModelType.silueta:
        return 'silueta.tflite';
      case RembgModelType.isnetAnime:
        return 'isnet_anime.tflite';
      case RembgModelType.modnet:
        return 'modnet_photographic.tflite';
      case RembgModelType.birefnet:
        return 'birefnet_general.tflite';
      case RembgModelType.dis:
        return 'dis_general.tflite';
      case RembgModelType.rmbg2:
        return 'rmbg_v2.tflite';
      case RembgModelType.inspyrenet:
        return 'inspyrenet_plus.tflite';
      case RembgModelType.backgroundmattingv2:
        return 'bgmv2_mobilenet.tflite';
      case RembgModelType.ppmatting:
        return 'ppmatting_hrnet.tflite';
    }
  }

  int get inputSize {
    switch (this) {
      case RembgModelType.u2net:
      case RembgModelType.u2netHuman:
      case RembgModelType.silueta:
      case RembgModelType.u2netP:
      case RembgModelType.isnetAnime:
        return 320;
      case RembgModelType.modnet:
        return 512;
      case RembgModelType.birefnet:
        return 1024;
      case RembgModelType.dis:
        return 1024;
      case RembgModelType.rmbg2:
        return 1024;
      case RembgModelType.inspyrenet:
        return 640;
      case RembgModelType.backgroundmattingv2:
        return 512;
      case RembgModelType.ppmatting:
        return 512;
    }
  }

  double get estimatedProcessingTime {
    switch (this) {
      case RembgModelType.u2net:
        return 2.5;
      case RembgModelType.u2netHuman:
        return 2.0;
      case RembgModelType.u2netP:
        return 1.0;
      case RembgModelType.silueta:
        return 3.5;
      case RembgModelType.isnetAnime:
        return 2.2;
      case RembgModelType.modnet:
        return 0.8;
      case RembgModelType.birefnet:
        return 4.5;
      case RembgModelType.dis:
        return 3.8;
      case RembgModelType.rmbg2:
        return 3.2;
      case RembgModelType.inspyrenet:
        return 2.8;
      case RembgModelType.backgroundmattingv2:
        return 1.5;
      case RembgModelType.ppmatting:
        return 1.2;
    }
  }

  bool get isAvailable {
    // 在实际应用中，这里可以检查模型文件是否存在
    // 目前我们使用算法模拟，所以都返回 true
    return true;
  }
}

class RembgModelInfo {
  final RembgModelType type;
  final String name;
  final String description;
  final int inputSize;
  final double estimatedTime;
  final bool isAvailable;

  RembgModelInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.inputSize,
    required this.estimatedTime,
    required this.isAvailable,
  });

  factory RembgModelInfo.fromType(RembgModelType type) {
    return RembgModelInfo(
      type: type,
      name: type.displayName,
      description: type.description,
      inputSize: type.inputSize,
      estimatedTime: type.estimatedProcessingTime,
      isAvailable: type.isAvailable,
    );
  }

  static List<RembgModelInfo> getAllModels() {
    return RembgModelType.values.map((type) => RembgModelInfo.fromType(type)).toList();
  }
}

