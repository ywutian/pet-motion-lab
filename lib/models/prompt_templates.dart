class PromptTemplates {
  static const Map<String, List<PromptTemplate>> templates = {
    '基础静态动作': [
      PromptTemplate(
        name: 'Sit - 坐姿',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，坐在地上四处张望，镜头面对{动物}的正前方。',
        category: 'static',
      ),
      PromptTemplate(
        name: 'Walk - 行走',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，往前走，镜头面对{动物}的正前方。',
        category: 'static',
      ),
      PromptTemplate(
        name: 'Sleep - 睡觉',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，在睡觉，打呼噜，有气体呼入呼出，镜头面对{动物}的正前方。',
        category: 'static',
      ),
      PromptTemplate(
        name: 'Rest - 休息',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，趴在地上四处张望，镜头面对{动物}的正前方。',
        category: 'static',
      ),
    ],
    '过渡动作视频': [
      PromptTemplate(
        name: 'sit2walk - 坐到走',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物起立，然后往前走，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'sit2sleep - 坐到睡',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物趴下，然后睡觉，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'sit2rest - 坐到休息',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物趴下，然后休息（趴下但是睁着眼睛），镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'walk2sit - 走到坐',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物往前走，然后坐下，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'walk2sleep - 走到睡',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物往前走，然后睡觉，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'walk2rest - 走到休息',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物往前走，然后休息，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'sleep2walk - 睡到走',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物睁眼，然后起立，往前走，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'sleep2rest - 睡到休息',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物睁眼，四处张望，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'sleep2sit - 睡到坐',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物睁眼，然后坐起来，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'rest2sit - 休息到坐',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物起立，然后坐下，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'rest2walk - 休息到走',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物起立，然后往前走，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
      PromptTemplate(
        name: 'rest2sleep - 休息到睡',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，宠物闭眼睡觉，在打呼噜，有气体呼入呼出，镜头面对{动物}的正前方。',
        category: 'motion',
      ),
    ],
    '循环动作视频': [
      PromptTemplate(
        name: '循环走步',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，在走步，镜头面对{动物}的正前方。【首尾帧：站立】',
        category: 'motion',
      ),
      PromptTemplate(
        name: '循环跳跃',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，缓缓跳跃一次，就像慢动作一样，镜头面对{动物}的正前方。【首尾帧：站立】',
        category: 'motion',
      ),
      PromptTemplate(
        name: '循环吃饭',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，在吃饭，镜头面对{动物}的正前方。【首尾帧：站立】',
        category: 'motion',
      ),
      PromptTemplate(
        name: '循环四处看',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，坐着四处看，镜头面对{动物}的正前方。【首尾帧：坐下】',
        category: 'motion',
      ),
    ],
    '特定场景过渡': [
      PromptTemplate(
        name: '站立到趴下张望',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，趴下，然后四处张望一会，镜头面对{动物}的正前方。【首帧：站立；尾帧：趴下】',
        category: 'motion',
      ),
      PromptTemplate(
        name: '趴下到站立张望',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，起立，然后四处张望一会，镜头面对{动物}的正前方。【首帧：趴下；尾帧：站立】',
        category: 'motion',
      ),
      PromptTemplate(
        name: '站立到坐下张望',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，坐下，然后四处张望一会，镜头面对{动物}的正前方。【首帧：站立；尾帧：坐下】',
        category: 'motion',
      ),
      PromptTemplate(
        name: '坐下到站立张望',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，起立，然后四处张望一会，镜头面对{动物}的正前方。【首帧：坐下；尾帧：站立】',
        category: 'motion',
      ),
      PromptTemplate(
        name: '睡觉到趴着',
        prompt: '卡通3D{宠物品种}，背景是纯白色0x000000，抬头，镜头面对{动物}的正前方。【首帧：睡觉；尾帧：趴着】',
        category: 'motion',
      ),
    ],
  };

  static String fillTemplate(String template, String species, String animalType) {
    return template
        .replaceAll('{宠物品种}', species)
        .replaceAll('{动物}', animalType);
  }

  static List<PromptTemplate> getStaticTemplates() {
    return templates['基础静态动作'] ?? [];
  }

  static List<PromptTemplate> getMotionTemplates() {
    final List<PromptTemplate> motionTemplates = [];
    templates.forEach((category, templates) {
      if (category != '基础静态动作') {
        motionTemplates.addAll(templates);
      }
    });
    return motionTemplates;
  }

  static List<String> getAllCategories() {
    return templates.keys.toList();
  }

  static List<PromptTemplate> getTemplatesByCategory(String category) {
    return templates[category] ?? [];
  }
}

class PromptTemplate {
  final String name;
  final String prompt;
  final String category;

  const PromptTemplate({
    required this.name,
    required this.prompt,
    required this.category,
  });
}

