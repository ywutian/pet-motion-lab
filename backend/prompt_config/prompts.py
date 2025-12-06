#!/usr/bin/env python3
"""
可灵AI提示词配置
所有提示词模板集中管理

【严格约束版】
- 统一风格：皮克斯/迪士尼风格3D卡通
- 统一背景：纯白色(#FFFFFF)无任何元素
- 统一视角：正前方平视，{species}居中
- 统一构图：全身入镜，留有边距
- 统一光照：柔和均匀的摄影棚灯光
"""

# ============================================
# 通用约束前缀和后缀
# ============================================
STYLE_PREFIX = "皮克斯风格3D卡通，可爱圆润的造型，大眼睛，"
# 更强的背景约束
BACKGROUND_CONSTRAINT = "【重要】整个视频从头到尾保持纯白色背景(#FFFFFF)，背景绝对不能变化，无任何其他元素，无阴影，无地面，无环境变化，"
CAMERA_CONSTRAINT = "镜头正对{species}正前方，平视角度，{species}居中，全身入镜，"
LIGHTING_CONSTRAINT = "柔和均匀的摄影棚灯光，无强烈阴影，光照保持一致不变化。"

# 负向提示词（用于排除不想要的元素）
NEGATIVE_PROMPT = "背景变化,环境变化,场景切换,草地,地板,室内,室外,阴影变化,光照变化,颜色变化,模糊,低质量"

# ============================================
# 基础姿势提示词（图生图 - 生成第一张基准图）
# ============================================
BASE_POSE_PROMPTS = {
    "sit": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "标准坐姿，前腿伸直撑地，后腿收于身下，尾巴自然放置，头部微微抬起，眼睛看向镜头，耳朵竖立，表情自然放松，"
        + CAMERA_CONSTRAINT
        + LIGHTING_CONSTRAINT
    ),
    "walk": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "行走姿势，四肢着地，左前腿和右后腿向前迈步，右前腿和左后腿在后方支撑，身体微微前倾，尾巴自然摆动，"
        + CAMERA_CONSTRAINT
        + LIGHTING_CONSTRAINT
    ),
    "rest": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "趴卧姿势，四肢收于身下，前爪向前伸出，下巴微微抬起，眼睛睁开看向前方，耳朵竖立警觉，尾巴自然放置，"
        + CAMERA_CONSTRAINT
        + LIGHTING_CONSTRAINT
    ),
    "sleep": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "睡眠姿势，侧躺或蜷缩，眼睛完全闭合，表情安详，四肢放松蜷曲，尾巴环绕身体，呼吸起伏可见，"
        + CAMERA_CONSTRAINT
        + LIGHTING_CONSTRAINT
    ),
}

# ============================================
# 过渡视频提示词（图生视频）
# ============================================
TRANSITION_PROMPTS = {
    # 步骤4：首批3个过渡视频（用于生成walk/rest/sleep基础图）
    "sit2walk": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从坐姿缓慢站起，前腿先伸直，后腿发力撑起身体，然后四肢着地开始行走，步伐自然协调，左前腿与右后腿同步，右前腿与左后腿同步，动作流畅连贯，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "sit2rest": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从坐姿缓慢趴下，前腿向前滑动伸展，身体重心下移，后腿收于身下，最终呈趴卧姿势，眼睛保持睁开，头部微抬看向前方，动作缓慢优雅，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "rest2sleep": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从趴卧姿势进入睡眠，头部缓慢低下，眼睛逐渐闭合，身体放松蜷缩，呼吸变得平稳，胸腔有轻微起伏，表情安详，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),

    # 步骤5：剩余9个过渡视频
    "sit2sleep": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从坐姿直接趴下并进入睡眠，身体缓慢前倾趴下，眼睛逐渐闭合，四肢放松蜷曲，呼吸平稳，胸腔轻微起伏，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "walk2sit": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从行走状态停下并坐下，步伐逐渐减慢，后腿收拢，臀部下沉着地，【结束姿势必须是标准坐姿】：前腿伸直撑地，后腿收于身下，尾巴自然放置，头部微微抬起，眼睛看向镜头，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "walk2rest": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从行走状态趴下休息，步伐减慢直至停止，前腿向前滑动，身体重心下移，最终趴卧在地，眼睛保持睁开，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "walk2sleep": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从行走状态趴下并入睡，步伐减慢停止，身体趴下，头部低垂，眼睛闭合，呼吸平稳，进入睡眠状态，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "sleep2sit": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从睡眠中醒来并坐起，眼睛缓慢睁开，头部抬起，前腿撑地，身体抬起，【结束姿势必须是标准坐姿】：前腿伸直撑地，后腿收于身下，尾巴自然放置，头部微微抬起，眼睛看向镜头，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "sleep2walk": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从睡眠中醒来并站起行走，眼睛睁开，伸懒腰，四肢撑地站起，开始迈步行走，逐渐恢复精神，步伐由慢变快，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "sleep2rest": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从睡眠中醒来但保持趴卧，眼睛缓慢睁开，头部微微抬起，四处张望，身体保持趴卧姿势，表情警觉，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "rest2sit": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从趴卧姿势坐起，前腿撑地发力，身体抬起，后腿收拢，臀部着地，【结束姿势必须是标准坐姿】：前腿伸直撑地，后腿收于身下，尾巴自然放置，头部微微抬起，眼睛看向镜头，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
    "rest2walk": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "动作：从趴卧姿势站起并行走，四肢撑地站起，身体抬高，开始迈步向前走，步伐自然协调，精神饱满，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，" + LIGHTING_CONSTRAINT
    ),
}

# ============================================
# 循环视频提示词（图生视频 - 原地微动）
# ============================================
LOOP_PROMPTS = {
    "sit": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "保持坐姿不变，原地轻微晃动，耳朵偶尔抖动，尾巴轻轻摆动，眨眼，头部微微转动，呼吸起伏，表情生动自然，身体位置保持不变，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，首尾帧一致可循环，" + LIGHTING_CONSTRAINT
    ),
    "walk": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "原地踏步行走动作，四肢交替抬起落下模拟行走，身体略有上下起伏，尾巴自然摆动，但整体位置保持不变，不向前移动，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，首尾帧一致可循环，" + LIGHTING_CONSTRAINT
    ),
    "rest": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "保持趴卧姿势不变，呼吸引起胸腔轻微起伏，耳朵偶尔转动，眼睛眨动，尾巴尖轻轻摆动，头部偶尔微微转动观察周围，身体位置保持不变，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，首尾帧一致可循环，" + LIGHTING_CONSTRAINT
    ),
    "sleep": (
        STYLE_PREFIX + "{breed}{color}{species}，"
        + BACKGROUND_CONSTRAINT
        + "保持睡眠姿势不变，深度睡眠呼吸，胸腔明显起伏，偶尔轻微抽动，耳朵偶尔抖动，表情安详，身体位置保持不变，"
        + CAMERA_CONSTRAINT
        + "镜头保持固定不动，首尾帧一致可循环，" + LIGHTING_CONSTRAINT
    ),
}

# 首批3个过渡视频（步骤3，用于从sit生成walk/rest/sleep基础图）
# 顺序很重要：sit2walk和sit2rest可以并行，但rest2sleep必须在sit2rest之后
FIRST_TRANSITIONS = ["sit2walk", "sit2rest", "rest2sleep"]

# 所有姿势
POSES = ["sit", "walk", "rest", "sleep"]


def format_prompt(template: str, breed: str, color: str, species: str) -> str:
    """
    格式化提示词
    
    Args:
        template: 提示词模板
        breed: 品种（如：布偶猫、金毛犬）
        color: 颜色（如：蓝色、金色）
        species: 物种（猫、犬）
    
    Returns:
        格式化后的提示词
    """
    return template.format(breed=breed, color=color, species=species)


def get_base_pose_prompt(pose: str, breed: str, color: str, species: str) -> str:
    """获取基础姿势提示词"""
    if pose not in BASE_POSE_PROMPTS:
        raise ValueError(f"未知姿势: {pose}，支持的姿势: {list(BASE_POSE_PROMPTS.keys())}")
    return format_prompt(BASE_POSE_PROMPTS[pose], breed, color, species)


def get_transition_prompt(transition: str, breed: str, color: str, species: str) -> str:
    """获取过渡视频提示词"""
    if transition not in TRANSITION_PROMPTS:
        raise ValueError(f"未知过渡: {transition}，支持的过渡: {list(TRANSITION_PROMPTS.keys())}")
    return format_prompt(TRANSITION_PROMPTS[transition], breed, color, species)


def get_loop_prompt(pose: str, breed: str, color: str, species: str) -> str:
    """获取循环视频提示词"""
    if pose not in LOOP_PROMPTS:
        raise ValueError(f"未知姿势: {pose}，支持的姿势: {list(LOOP_PROMPTS.keys())}")
    return format_prompt(LOOP_PROMPTS[pose], breed, color, species)


def get_negative_prompt() -> str:
    """获取负向提示词（用于排除不想要的元素）"""
    return NEGATIVE_PROMPT


def get_all_transitions() -> list:
    """获取所有过渡组合（12个）"""
    transitions = []
    for start_pose in POSES:
        for end_pose in POSES:
            if start_pose != end_pose:
                transitions.append(f"{start_pose}2{end_pose}")
    return transitions


if __name__ == "__main__":
    # 测试
    print("基础姿势提示词:")
    print(get_base_pose_prompt("sit", "布偶猫", "蓝色", "猫"))
    print()
    
    print("过渡视频提示词:")
    print(get_transition_prompt("sit2walk", "布偶猫", "蓝色", "猫"))
    print()
    
    print("循环视频提示词:")
    print(get_loop_prompt("sit", "布偶猫", "蓝色", "猫"))
    print()
    
    print(f"所有过渡组合（{len(get_all_transitions())}个）:")
    for t in get_all_transitions():
        print(f"  - {t}")

