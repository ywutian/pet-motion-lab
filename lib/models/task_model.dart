class Task {
  final String taskId;
  final String comboTemplate;
  final List<String> species;
  final Generation generation;
  final Cutting cutting;
  final List<ImageData> images;
  final Outputs outputs;
  final String status;
  final DateTime createdAt;

  Task({
    required this.taskId,
    required this.comboTemplate,
    required this.species,
    required this.generation,
    required this.cutting,
    required this.images,
    required this.outputs,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'combo_template': comboTemplate,
    'species': species,
    'generation': generation.toJson(),
    'cutting': cutting.toJson(),
    'images': images.map((e) => e.toJson()).toList(),
    'outputs': outputs.toJson(),
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    taskId: json['task_id'],
    comboTemplate: json['combo_template'],
    species: List<String>.from(json['species']),
    generation: Generation.fromJson(json['generation']),
    cutting: Cutting.fromJson(json['cutting']),
    images: (json['images'] as List).map((e) => ImageData.fromJson(e)).toList(),
    outputs: Outputs.fromJson(json['outputs']),
    status: json['status'],
    createdAt: DateTime.parse(json['created_at']),
  );

  double getAveragePS() {
    if (images.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (var img in images) {
      if (img.stages.isNotEmpty) {
        total += img.stages.last.purity.ps;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  double getAveragePSImprovement() {
    if (images.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (var img in images) {
      if (img.stages.length > 1) {
        total += img.stages.last.purity.ps - img.stages.first.purity.ps;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }
}

class Generation {
  final String staticModel;
  final String motionModel;
  final String resolution;
  final int duration;
  final int fps;
  final String prompt;

  Generation({
    required this.staticModel,
    required this.motionModel,
    required this.resolution,
    required this.duration,
    required this.fps,
    required this.prompt,
  });

  Map<String, dynamic> toJson() => {
    'static_model': staticModel,
    'motion_model': motionModel,
    'resolution': resolution,
    'duration': duration,
    'fps': fps,
    'prompt': prompt,
  };

  factory Generation.fromJson(Map<String, dynamic> json) => Generation(
    staticModel: json['static_model'],
    motionModel: json['motion_model'],
    resolution: json['resolution'],
    duration: json['duration'],
    fps: json['fps'],
    prompt: json['prompt'],
  );
}

class Cutting {
  final String mode;
  final bool autoTool;

  Cutting({
    required this.mode,
    required this.autoTool,
  });

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'auto_tool': autoTool,
  };

  factory Cutting.fromJson(Map<String, dynamic> json) => Cutting(
    mode: json['mode'],
    autoTool: json['auto_tool'],
  );
}

class ImageData {
  final String id;
  final String pose;
  final String angle;
  final String fileIn;
  final List<Stage> stages;
  final String? species;
  final String? tag;
  final String? staticPrompt;
  final String? motionPrompt;

  ImageData({
    required this.id,
    required this.pose,
    required this.angle,
    required this.fileIn,
    required this.stages,
    this.species,
    this.tag,
    this.staticPrompt,
    this.motionPrompt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'pose': pose,
    'angle': angle,
    'file_in': fileIn,
    'stages': stages.map((e) => e.toJson()).toList(),
    if (species != null) 'species': species,
    if (tag != null) 'tag': tag,
    if (staticPrompt != null) 'static_prompt': staticPrompt,
    if (motionPrompt != null) 'motion_prompt': motionPrompt,
  };

  factory ImageData.fromJson(Map<String, dynamic> json) => ImageData(
    id: json['id'],
    pose: json['pose'],
    angle: json['angle'],
    fileIn: json['file_in'],
    stages: (json['stages'] as List).map((e) => Stage.fromJson(e)).toList(),
    species: json['species'],
    tag: json['tag'],
    staticPrompt: json['static_prompt'],
    motionPrompt: json['motion_prompt'],
  );
}

class Stage {
  final String stage;
  final Purity purity;
  final DateTime ts;
  final CutInfo? cut;
  final double? deltaPs;

  Stage({
    required this.stage,
    required this.purity,
    required this.ts,
    this.cut,
    this.deltaPs,
  });

  Map<String, dynamic> toJson() => {
    'stage': stage,
    'purity': purity.toJson(),
    'ts': ts.toIso8601String(),
    if (cut != null) 'cut': cut!.toJson(),
    if (deltaPs != null) 'delta_ps': deltaPs,
  };

  factory Stage.fromJson(Map<String, dynamic> json) => Stage(
    stage: json['stage'],
    purity: Purity.fromJson(json['purity']),
    ts: DateTime.parse(json['ts']),
    cut: json['cut'] != null ? CutInfo.fromJson(json['cut']) : null,
    deltaPs: json['delta_ps']?.toDouble(),
  );
}

class Purity {
  final double ps;
  final double bv;
  final double ec;
  final String tool;

  Purity({
    required this.ps,
    required this.bv,
    required this.ec,
    required this.tool,
  });

  Map<String, dynamic> toJson() => {
    'ps': ps,
    'bv': bv,
    'ec': ec,
    'tool': tool,
  };

  factory Purity.fromJson(Map<String, dynamic> json) => Purity(
    ps: json['ps'].toDouble(),
    bv: json['bv'].toDouble(),
    ec: json['ec'].toDouble(),
    tool: json['tool'],
  );
}

class CutInfo {
  final String tool;
  final int latencyMs;
  final String fileOut;

  CutInfo({
    required this.tool,
    required this.latencyMs,
    required this.fileOut,
  });

  Map<String, dynamic> toJson() => {
    'tool': tool,
    'latency_ms': latencyMs,
    'file_out': fileOut,
  };

  factory CutInfo.fromJson(Map<String, dynamic> json) => CutInfo(
    tool: json['tool'],
    latencyMs: json['latency_ms'],
    fileOut: json['file_out'],
  );
}

class Outputs {
  final List<String> statics;
  final List<String> videos;
  final List<String> gifs;

  Outputs({
    required this.statics,
    required this.videos,
    required this.gifs,
  });

  Map<String, dynamic> toJson() => {
    'statics': statics,
    'videos': videos,
    'gifs': gifs,
  };

  factory Outputs.fromJson(Map<String, dynamic> json) => Outputs(
    statics: List<String>.from(json['statics'] ?? []),
    videos: List<String>.from(json['videos'] ?? []),
    gifs: List<String>.from(json['gifs'] ?? []),
  );
}

