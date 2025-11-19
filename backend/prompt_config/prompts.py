#!/usr/bin/env python3
"""
可灵AI提示词配置
所有提示词模板集中管理
"""

# 基础姿势提示词（图生图 - 生成第一张基准图）
BASE_POSE_PROMPTS = {
    "sit": "卡通3D{breed}{color}{species}，纯白色背景，坐姿，镜头面对{species}的正前方。",
    "walk": "卡通3D{breed}{color}{species}，纯白色背景，往前走，镜头面对{species}的正前方。",
    "sleep": "卡通3D{breed}{color}{species}，纯白色背景，睡觉，打呼噜，有气体呼入呼出，镜头面对{species}的正前方。",
    "rest": "卡通3D{breed}{color}{species}，纯白色背景，趴下但是睁着眼睛，镜头面对{species}的正前方。",
}

# 过渡视频提示词（图生视频）
TRANSITION_PROMPTS = {
    # 步骤4：首批3个过渡视频
    "sit2walk": "卡通3D{breed}{color}{species}，纯白色背景，宠物起立，然后往前走，镜头面对{species}的正前方。",
    "sit2rest": "卡通3D{breed}{color}{species}，纯白色背景，宠物趴下，然后休息（趴下但是睁着眼睛），镜头面对{species}的正前方。",
    "rest2sleep": "卡通3D{breed}{color}{species}，纯白色背景，宠物闭眼睡觉，在打呼噜，有气体呼入呼出，镜头面对{species}的正前方。",

    # 步骤5：剩余9个过渡视频
    "sit2sleep": "卡通3D{breed}{color}{species}，纯白色背景，宠物趴下，然后睡觉，镜头面对{species}的正前方。",
    "walk2sit": "卡通3D{breed}{color}{species}，纯白色背景，宠物往前走，然后坐下，镜头面对{species}的正前方。",
    "walk2sleep": "卡通3D{breed}{color}{species}，纯白色背景，宠物往前走，然后睡觉，镜头面对{species}的正前方。",
    "walk2rest": "卡通3D{breed}{color}{species}，纯白色背景，宠物往前走，然后休息，镜头面对{species}的正前方。",
    "sleep2walk": "卡通3D{breed}{color}{species}，纯白色背景，宠物睁眼，然后起立，往前走，镜头面对{species}的正前方。",
    "sleep2rest": "卡通3D{breed}{color}{species}，纯白色背景，宠物睁眼，四处张望，镜头面对{species}的正前方。",
    "sleep2sit": "卡通3D{breed}{color}{species}，纯白色背景，宠物睁眼，然后坐起来，镜头面对{species}的正前方。",
    "rest2sit": "卡通3D{breed}{color}{species}，纯白色背景，宠物起立，然后坐下，镜头面对{species}的正前方。",
    "rest2walk": "卡通3D{breed}{color}{species}，纯白色背景，宠物起立，然后往前走，镜头面对{species}的正前方。",
}

# 循环视频提示词（图生视频 - 首尾帧相同）
LOOP_PROMPTS = {
    "sit": "卡通3D{breed}{color}{species}，纯白色背景，坐着，镜头面对{species}的正前方。",
    "walk": "卡通3D{breed}{color}{species}，纯白色背景，往前走，镜头面对{species}的正前方。",
    "rest": "卡通3D{breed}{color}{species}，纯白色背景，趴下但是睁着眼睛，镜头面对{species}的正前方。",
    "sleep": "卡通3D{breed}{color}{species}，纯白色背景，睡觉，打呼噜，有气体呼入呼出，镜头面对{species}的正前方。",
}

# 步骤4的3个过渡视频（用于生成其他3个基准图）
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

