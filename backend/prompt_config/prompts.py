#!/usr/bin/env python3
"""
可灵AI提示词配置
所有提示词模板集中管理

【核心约束】
1. 风格：皮克斯/迪士尼3D卡通风格
2. 背景：纯白色（必须像白纸一样干净）
3. 视角：正前方平视，宠物居中
4. 构图：全身入镜，四周留白
5. 光照：柔和均匀，无阴影
"""

# ============================================
# 核心组件（模块化设计，便于维护）
# ============================================

# 风格定义
STYLE = "3D卡通风格，皮克斯动画质感，可爱圆润造型，大眼睛，毛发蓬松柔软"

# 宠物主体描述（{breed}=品种，{color}=毛色）
PET_SUBJECT = "一只{breed}，毛色是{color}"

# 背景约束（最重要！放在最前面强调）
BACKGROUND = "纯白色背景，干净的白色，像白纸一样的纯净背景，没有任何其他颜色"

# 镜头约束（{species}=猫/犬）
CAMERA = "正面视角，{species}位于画面中央，全身可见，四周留有空白"

# 光照约束
LIGHTING = "柔和均匀的灯光，没有阴影"

# 视频专用约束
VIDEO_CONSTRAINT = "背景从头到尾保持纯白不变"

# 镜头跟随约束（用于walk相关视频）
CAMERA_FOLLOW = "镜头跟随{species}移动，保持{species}始终在画面中央，大小不变"

# 镜头固定约束（用于非移动视频）
CAMERA_STATIC = "镜头固定不动"

# ============================================
# 负向提示词（排除不想要的元素）
# ============================================
NEGATIVE_PROMPT = ",".join([
    # 背景颜色（最重要）
    "black background", "dark background", "黑色背景", "深色背景", "暗色背景",
    "gray background", "grey background", "灰色背景",
    "colored background", "彩色背景", "蓝色背景", "绿色背景", "渐变背景",
    # 环境元素
    "grass", "floor", "ground", "草地", "地板", "地面",
    "indoor", "outdoor", "室内", "室外", "房间",
    "sky", "clouds", "天空", "云",
    "shadow", "阴影", "影子",
    # 质量问题
    "blurry", "low quality", "模糊", "低质量",
    # 背景变化
    "background change", "环境变化", "场景切换"
])


# ============================================
# 辅助函数：构建提示词
# ============================================
def _build_prompt(action_desc: str, is_video: bool = False, camera_follow: bool = False) -> str:
    """
    构建完整提示词
    
    结构顺序（按重要性）：
    1. 背景约束（最重要）
    2. 风格定义
    3. 宠物主体
    4. 动作描述
    5. 镜头约束
    6. 光照约束
    7. 视频约束（如果是视频）
    8. 镜头移动约束（跟随或固定）
    
    Args:
        action_desc: 动作描述
        is_video: 是否为视频
        camera_follow: 是否需要镜头跟随（用于walk等移动场景）
    """
    parts = [
        BACKGROUND,
        STYLE,
        PET_SUBJECT,
        action_desc,
        CAMERA,
        LIGHTING,
    ]
    if is_video:
        parts.append(VIDEO_CONSTRAINT)
        if camera_follow:
            parts.append(CAMERA_FOLLOW)
        else:
            parts.append(CAMERA_STATIC)
    
    return "，".join(parts) + "。"


# ============================================
# 基础姿势提示词（图生图）
# ============================================
BASE_POSE_PROMPTS = {
    "sit": _build_prompt(
        "标准坐姿，前腿伸直撑地，后腿收于身下，尾巴自然放置，"
        "头部微微抬起，眼睛看向镜头，耳朵竖立，表情放松"
    ),
    "walk": _build_prompt(
        "行走姿势，四肢着地迈步，身体微微前倾，尾巴自然摆动，"
        "眼睛看向前方，表情活泼"
    ),
    "rest": _build_prompt(
        "趴卧姿势，四肢收于身下，前爪向前伸出，下巴微抬，"
        "眼睛睁开看向前方，耳朵竖立，表情警觉"
    ),
    "sleep": _build_prompt(
        "睡眠姿势，蜷缩或侧躺，眼睛闭合，表情安详，"
        "四肢放松蜷曲，尾巴环绕身体，呼吸起伏可见"
    ),
}


# ============================================
# 过渡视频提示词（图生视频 - 姿势变换）
# ============================================
TRANSITION_PROMPTS = {
    # === 从坐姿开始 ===
    "sit2walk": _build_prompt(
        "从坐姿站起并开始行走，前腿先伸直，后腿发力撑起身体，"
        "然后四肢着地迈步向前走，动作流畅自然",
        is_video=True,
        camera_follow=True  # 镜头跟随移动
    ),
    "sit2rest": _build_prompt(
        "从坐姿缓慢趴下，前腿向前滑动，身体重心下移，"
        "最终趴卧，眼睛保持睁开，动作优雅",
        is_video=True
    ),
    "sit2sleep": _build_prompt(
        "从坐姿趴下并入睡，身体前倾趴下，眼睛逐渐闭合，"
        "四肢放松蜷曲，呼吸平稳",
        is_video=True
    ),
    
    # === 从行走开始 ===
    "walk2sit": _build_prompt(
        "从行走停下并坐下，步伐逐渐减慢直到停止，后腿收拢，臀部着地，"
        "最终呈标准坐姿，前腿伸直，眼睛看向镜头",
        is_video=True,
        camera_follow=True  # 镜头跟随到停止
    ),
    "walk2rest": _build_prompt(
        "从行走趴下休息，步伐逐渐减慢直到停止，前腿滑动，身体下沉，"
        "最终趴卧，眼睛保持睁开",
        is_video=True,
        camera_follow=True  # 镜头跟随到停止
    ),
    "walk2sleep": _build_prompt(
        "从行走趴下并入睡，步伐逐渐减慢直到停止，身体趴下，"
        "眼睛闭合，呼吸平稳，进入睡眠",
        is_video=True,
        camera_follow=True  # 镜头跟随到停止
    ),
    
    # === 从趴卧开始 ===
    "rest2sit": _build_prompt(
        "从趴卧坐起，前腿撑地发力，身体抬起，后腿收拢，"
        "最终呈标准坐姿，眼睛看向镜头",
        is_video=True
    ),
    "rest2walk": _build_prompt(
        "从趴卧站起并行走，四肢撑地站起，身体抬高，"
        "开始迈步向前走，精神饱满",
        is_video=True,
        camera_follow=True  # 镜头跟随移动
    ),
    "rest2sleep": _build_prompt(
        "从趴卧进入睡眠，头部缓慢低下，眼睛逐渐闭合，"
        "身体放松，呼吸平稳，表情安详",
        is_video=True
    ),
    
    # === 从睡眠开始 ===
    "sleep2sit": _build_prompt(
        "从睡眠醒来并坐起，眼睛缓慢睁开，头部抬起，"
        "前腿撑地，最终呈标准坐姿，眼睛看向镜头",
        is_video=True
    ),
    "sleep2walk": _build_prompt(
        "从睡眠醒来并站起行走，眼睛睁开，伸懒腰，"
        "四肢撑地站起，开始迈步向前走，逐渐恢复精神",
        is_video=True,
        camera_follow=True  # 镜头跟随移动
    ),
    "sleep2rest": _build_prompt(
        "从睡眠醒来但保持趴卧，眼睛缓慢睁开，头部微抬，"
        "四处张望，身体保持趴卧，表情警觉",
        is_video=True
    ),
}


# ============================================
# 循环视频提示词（图生视频 - 原地微动）
# ============================================
LOOP_PROMPTS = {
    "sit": _build_prompt(
        "保持坐姿不动，只有微小动作，耳朵偶尔抖动，尾巴轻摆，"
        "眨眼，头部微微转动，呼吸起伏，位置不变，首尾帧一致可循环",
        is_video=True
    ),
    "walk": _build_prompt(
        "持续向前行走，四肢交替迈步，身体略有起伏，"
        "尾巴自然摆动，步伐稳定均匀，首尾帧动作姿势一致可循环",
        is_video=True,
        camera_follow=True  # 镜头跟随移动
    ),
    "rest": _build_prompt(
        "保持趴卧不动，只有呼吸起伏，耳朵偶尔转动，眨眼，"
        "尾巴尖轻摆，位置不变，首尾帧一致可循环",
        is_video=True
    ),
    "sleep": _build_prompt(
        "保持睡姿不动，深度睡眠呼吸，胸腔明显起伏，"
        "偶尔轻微抽动，表情安详，位置不变，首尾帧一致可循环",
        is_video=True
    ),
}


# ============================================
# 配置常量
# ============================================

# 首批过渡视频（用于生成其他姿势的基础图）
FIRST_TRANSITIONS = ["sit2walk", "sit2rest", "rest2sleep"]

# 所有姿势
POSES = ["sit", "walk", "rest", "sleep"]


# ============================================
# API 函数
# ============================================

def format_prompt(template: str, breed: str, color: str, species: str) -> str:
    """
    格式化提示词，替换占位符
    
    Args:
        template: 提示词模板
        breed: 品种（如：布偶猫、金毛犬）
        color: 毛色（如：蓝白色、金色）
        species: 物种（猫、犬）
    
    Returns:
        格式化后的提示词
    """
    return template.format(breed=breed, color=color, species=species)


def get_base_pose_prompt(pose: str, breed: str, color: str, species: str) -> str:
    """获取基础姿势提示词（图生图）"""
    if pose not in BASE_POSE_PROMPTS:
        raise ValueError(f"未知姿势: {pose}，支持: {list(BASE_POSE_PROMPTS.keys())}")
    return format_prompt(BASE_POSE_PROMPTS[pose], breed, color, species)


def get_transition_prompt(transition: str, breed: str, color: str, species: str) -> str:
    """获取过渡视频提示词（图生视频）"""
    if transition not in TRANSITION_PROMPTS:
        raise ValueError(f"未知过渡: {transition}，支持: {list(TRANSITION_PROMPTS.keys())}")
    return format_prompt(TRANSITION_PROMPTS[transition], breed, color, species)


def get_loop_prompt(pose: str, breed: str, color: str, species: str) -> str:
    """获取循环视频提示词（图生视频）"""
    if pose not in LOOP_PROMPTS:
        raise ValueError(f"未知姿势: {pose}，支持: {list(LOOP_PROMPTS.keys())}")
    return format_prompt(LOOP_PROMPTS[pose], breed, color, species)


def get_negative_prompt() -> str:
    """获取负向提示词"""
    return NEGATIVE_PROMPT


def get_all_transitions() -> list:
    """获取所有过渡组合（12个）"""
    return [f"{s}2{e}" for s in POSES for e in POSES if s != e]


# ============================================
# 测试
# ============================================
if __name__ == "__main__":
    print("=" * 60)
    print("提示词测试（布偶猫，蓝白色）")
    print("=" * 60)
    
    print("\n【基础姿势 - sit】")
    print(get_base_pose_prompt("sit", "布偶猫", "蓝白色", "猫"))
    
    print("\n【过渡视频 - sit2walk】")
    print(get_transition_prompt("sit2walk", "布偶猫", "蓝白色", "猫"))
    
    print("\n【循环视频 - sit】")
    print(get_loop_prompt("sit", "布偶猫", "蓝白色", "猫"))
    
    print("\n【负向提示词】")
    print(get_negative_prompt())
    
    print(f"\n【所有过渡组合】（{len(get_all_transitions())}个）")
    for t in get_all_transitions():
        print(f"  - {t}")
