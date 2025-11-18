class PetPreset {
  final String name;
  final String species;
  final String pose;
  final String angle;
  final String category;
  final String description;

  const PetPreset({
    required this.name,
    required this.species,
    required this.pose,
    required this.angle,
    required this.category,
    required this.description,
  });
}

class PetPresets {
  static const List<PetPreset> presets = [
    // 边牧组合 (Border Collie)
    PetPreset(
      name: 'U1 - 边牧坐姿正面',
      species: '边牧',
      pose: 'sit',
      angle: 'front',
      category: '边牧',
      description: '边牧坐姿，正前方视角',
    ),
    PetPreset(
      name: 'U2 - 边牧行走正面',
      species: '边牧',
      pose: 'walk',
      angle: 'front',
      category: '边牧',
      description: '边牧行走，正前方视角',
    ),
    PetPreset(
      name: 'U3 - 边牧睡觉正面',
      species: '边牧',
      pose: 'sleep',
      angle: 'front',
      category: '边牧',
      description: '边牧睡觉，正前方视角',
    ),
    PetPreset(
      name: 'U4 - 边牧休息正面',
      species: '边牧',
      pose: 'rest',
      angle: 'front',
      category: '边牧',
      description: '边牧趴下休息，正前方视角',
    ),
    PetPreset(
      name: 'U5 - 边牧坐姿左侧',
      species: '边牧',
      pose: 'sit',
      angle: 'left',
      category: '边牧',
      description: '边牧坐姿，左侧视角',
    ),
    PetPreset(
      name: 'U6 - 边牧行走左侧',
      species: '边牧',
      pose: 'walk',
      angle: 'left',
      category: '边牧',
      description: '边牧行走，左侧视角',
    ),
    PetPreset(
      name: 'U7 - 边牧坐姿右侧',
      species: '边牧',
      pose: 'sit',
      angle: 'right',
      category: '边牧',
      description: '边牧坐姿，右侧视角',
    ),
    PetPreset(
      name: 'U8 - 边牧行走右侧',
      species: '边牧',
      pose: 'walk',
      angle: 'right',
      category: '边牧',
      description: '边牧行走，右侧视角',
    ),
    
    // 金毛组合 (Golden Retriever)
    PetPreset(
      name: 'U9 - 金毛坐姿正面',
      species: '金毛',
      pose: 'sit',
      angle: 'front',
      category: '金毛',
      description: '金毛坐姿，正前方视角',
    ),
    PetPreset(
      name: 'U10 - 金毛行走正面',
      species: '金毛',
      pose: 'walk',
      angle: 'front',
      category: '金毛',
      description: '金毛行走，正前方视角',
    ),
    PetPreset(
      name: 'U11 - 金毛睡觉正面',
      species: '金毛',
      pose: 'sleep',
      angle: 'front',
      category: '金毛',
      description: '金毛睡觉，正前方视角',
    ),
    PetPreset(
      name: 'U12 - 金毛休息正面',
      species: '金毛',
      pose: 'rest',
      angle: 'front',
      category: '金毛',
      description: '金毛趴下休息，正前方视角',
    ),
    
    // 猫咪组合 (Cat)
    PetPreset(
      name: 'U13 - 猫咪坐姿正面',
      species: '猫咪',
      pose: 'sit',
      angle: 'front',
      category: '猫咪',
      description: '猫咪坐姿，正前方视角',
    ),
    PetPreset(
      name: 'U14 - 猫咪行走正面',
      species: '猫咪',
      pose: 'walk',
      angle: 'front',
      category: '猫咪',
      description: '猫咪行走，正前方视角',
    ),
    PetPreset(
      name: 'U15 - 猫咪睡觉正面',
      species: '猫咪',
      pose: 'sleep',
      angle: 'front',
      category: '猫咪',
      description: '猫咪睡觉，正前方视角',
    ),
    PetPreset(
      name: 'U16 - 猫咪休息正面',
      species: '猫咪',
      pose: 'rest',
      angle: 'front',
      category: '猫咪',
      description: '猫咪趴下休息，正前方视角',
    ),
    PetPreset(
      name: 'U17 - 猫咪坐姿左侧',
      species: '猫咪',
      pose: 'sit',
      angle: 'left',
      category: '猫咪',
      description: '猫咪坐姿，左侧视角',
    ),
    PetPreset(
      name: 'U18 - 猫咪行走左侧',
      species: '猫咪',
      pose: 'walk',
      angle: 'left',
      category: '猫咪',
      description: '猫咪行走，左侧视角',
    ),
    
    // 柴犬组合 (Shiba)
    PetPreset(
      name: 'U19 - 柴犬坐姿正面',
      species: '柴犬',
      pose: 'sit',
      angle: 'front',
      category: '柴犬',
      description: '柴犬坐姿，正前方视角',
    ),
    PetPreset(
      name: 'U20 - 柴犬行走正面',
      species: '柴犬',
      pose: 'walk',
      angle: 'front',
      category: '柴犬',
      description: '柴犬行走，正前方视角',
    ),
    PetPreset(
      name: 'U21 - 柴犬睡觉正面',
      species: '柴犬',
      pose: 'sleep',
      angle: 'front',
      category: '柴犬',
      description: '柴犬睡觉，正前方视角',
    ),
    PetPreset(
      name: 'U22 - 柴犬休息正面',
      species: '柴犬',
      pose: 'rest',
      angle: 'front',
      category: '柴犬',
      description: '柴犬趴下休息，正前方视角',
    ),
    
    // 哈士奇组合 (Husky)
    PetPreset(
      name: 'U23 - 哈士奇坐姿正面',
      species: '哈士奇',
      pose: 'sit',
      angle: 'front',
      category: '哈士奇',
      description: '哈士奇坐姿，正前方视角',
    ),
    PetPreset(
      name: 'U24 - 哈士奇行走正面',
      species: '哈士奇',
      pose: 'walk',
      angle: 'front',
      category: '哈士奇',
      description: '哈士奇行走，正前方视角',
    ),
    PetPreset(
      name: 'U25 - 哈士奇睡觉正面',
      species: '哈士奇',
      pose: 'sleep',
      angle: 'front',
      category: '哈士奇',
      description: '哈士奇睡觉，正前方视角',
    ),
    PetPreset(
      name: 'U26 - 哈士奇休息正面',
      species: '哈士奇',
      pose: 'rest',
      angle: 'front',
      category: '哈士奇',
      description: '哈士奇趴下休息，正前方视角',
    ),
    
    // 泰迪组合 (Teddy)
    PetPreset(
      name: 'U27 - 泰迪坐姿正面',
      species: '泰迪',
      pose: 'sit',
      angle: 'front',
      category: '泰迪',
      description: '泰迪坐姿，正前方视角',
    ),
    PetPreset(
      name: 'U28 - 泰迪行走正面',
      species: '泰迪',
      pose: 'walk',
      angle: 'front',
      category: '泰迪',
      description: '泰迪行走，正前方视角',
    ),
    PetPreset(
      name: 'U29 - 泰迪睡觉正面',
      species: '泰迪',
      pose: 'sleep',
      angle: 'front',
      category: '泰迪',
      description: '泰迪睡觉，正前方视角',
    ),
    PetPreset(
      name: 'U30 - 泰迪休息正面',
      species: '泰迪',
      pose: 'rest',
      angle: 'front',
      category: '泰迪',
      description: '泰迪趴下休息，正前方视角',
    ),
  ];

  static List<String> getCategories() {
    return presets.map((p) => p.category).toSet().toList();
  }

  static List<PetPreset> getPresetsByCategory(String category) {
    return presets.where((p) => p.category == category).toList();
  }

  static List<PetPreset> searchPresets(String query) {
    if (query.isEmpty) return presets;
    final lowerQuery = query.toLowerCase();
    return presets.where((p) =>
      p.name.toLowerCase().contains(lowerQuery) ||
      p.species.toLowerCase().contains(lowerQuery) ||
      p.pose.toLowerCase().contains(lowerQuery) ||
      p.angle.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  // 常用姿势选项
  static const List<String> commonPoses = [
    'sit',      // 坐
    'walk',     // 走
    'sleep',    // 睡
    'rest',     // 休息
    'stand',    // 站
    'run',      // 跑
    'jump',     // 跳
    'lie',      // 躺
    'look',     // 看
    'eat',      // 吃
    'play',     // 玩
  ];

  // 常用角度选项
  static const List<String> commonAngles = [
    'front',    // 正面
    'left',     // 左侧
    'right',    // 右侧
    'back',     // 背面
    'front45',  // 前45度
    'top',      // 俯视
    'bottom',   // 仰视
  ];

  // 常用种类选项
  static const List<String> commonSpecies = [
    '边牧',
    '金毛',
    '哈士奇',
    '柴犬',
    '泰迪',
    '萨摩耶',
    '拉布拉多',
    '比熊',
    '博美',
    '雪纳瑞',
    '猫咪',
    '波斯猫',
    '英短',
    '美短',
    '布偶猫',
  ];
}

