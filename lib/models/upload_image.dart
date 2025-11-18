import 'dart:io';

class UploadImage {
  final String id;
  final File file;
  String species;
  String pose;
  String angle;
  String tag;
  String staticPrompt;
  String motionPrompt;
  double? originalPS;
  double? cutPS;
  String? cutFilePath;
  bool isProcessing;

  UploadImage({
    required this.id,
    required this.file,
    this.species = '',
    this.pose = '',
    this.angle = '',
    this.tag = '',
    this.staticPrompt = '',
    this.motionPrompt = '',
    this.originalPS,
    this.cutPS,
    this.cutFilePath,
    this.isProcessing = false,
  });

  UploadImage copyWith({
    String? species,
    String? pose,
    String? angle,
    String? tag,
    String? staticPrompt,
    String? motionPrompt,
    double? originalPS,
    double? cutPS,
    String? cutFilePath,
    bool? isProcessing,
  }) {
    return UploadImage(
      id: id,
      file: file,
      species: species ?? this.species,
      pose: pose ?? this.pose,
      angle: angle ?? this.angle,
      tag: tag ?? this.tag,
      staticPrompt: staticPrompt ?? this.staticPrompt,
      motionPrompt: motionPrompt ?? this.motionPrompt,
      originalPS: originalPS ?? this.originalPS,
      cutPS: cutPS ?? this.cutPS,
      cutFilePath: cutFilePath ?? this.cutFilePath,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

