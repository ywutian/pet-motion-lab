/// 工具历史记录项
class ToolHistoryItem {
  final String id;
  final ToolType toolType;
  final String resultPath; // 生成的文件路径
  final DateTime createdAt;
  final Map<String, dynamic> metadata; // 额外信息（如提示词、物种、品种等）

  ToolHistoryItem({
    required this.id,
    required this.toolType,
    required this.resultPath,
    required this.createdAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'toolType': toolType.name,
      'resultPath': resultPath,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ToolHistoryItem.fromJson(Map<String, dynamic> json) {
    return ToolHistoryItem(
      id: json['id'] as String,
      toolType: ToolType.values.firstWhere(
        (e) => e.name == json['toolType'],
        orElse: () => ToolType.backgroundRemoval,
      ),
      resultPath: json['resultPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  String get toolName {
    switch (toolType) {
      case ToolType.backgroundRemoval:
        return '去除背景';
      case ToolType.imageToImage:
        return '图片生成图片';
      case ToolType.imageToVideo:
        return '图片生成视频';
      case ToolType.frameExtraction:
        return '提取视频首尾帧';
      case ToolType.framesToVideo:
        return '首尾帧生成视频';
      case ToolType.videoToGif:
        return '视频转GIF';
    }
  }

  String get toolIcon {
    switch (toolType) {
      case ToolType.backgroundRemoval:
        return '✂️';
      case ToolType.imageToImage:
        return '🎨';
      case ToolType.imageToVideo:
        return '🎬';
      case ToolType.frameExtraction:
        return '📸';
      case ToolType.framesToVideo:
        return '🎥';
      case ToolType.videoToGif:
        return '🎞️';
    }
  }

  bool get isImage {
    return toolType == ToolType.backgroundRemoval ||
        toolType == ToolType.imageToImage ||
        toolType == ToolType.frameExtraction;
  }

  bool get isVideo {
    return toolType == ToolType.imageToVideo ||
        toolType == ToolType.framesToVideo;
  }

  bool get isGif {
    return toolType == ToolType.videoToGif;
  }
}

/// 工具类型枚举
enum ToolType {
  backgroundRemoval, // 去除背景
  imageToImage, // 图片生成图片
  imageToVideo, // 图片生成视频
  frameExtraction, // 提取视频首尾帧
  framesToVideo, // 首尾帧生成视频
  videoToGif, // 视频转GIF
}

