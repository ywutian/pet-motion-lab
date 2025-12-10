#!/usr/bin/env python3
"""
Pet Motion Lab v3.0 - Prompt生成器（优化版）
- 保持原图指令
- 强化风格约束
- 使用negative_prompt放置禁止行为
"""

from typing import Optional, Dict, Tuple


# ============ 风格约束模板 ============

DOG_STYLE = "3D卡通动画风格，色彩鲜艳明亮，卡通化柔和阴影"
CAT_DISNEY_STYLE = "迪士尼3D动画风格，温暖明亮色调，柔和艺术化光影"
CAT_REALISTIC_STYLE = "写实渲染风格，自然光影细腻层次"


# ============ 负向提示词（禁止行为）============

# 通用负向提示词
NEGATIVE_COMMON = "写实照片感，摄影质感，模糊，噪点，变形，多余肢体"

# 行走相关负向提示词
NEGATIVE_WALK = "跳跃，小跑，奔跑，四脚同时离地，飞起来，漂浮"

# 姿势相关负向提示词
NEGATIVE_POSE = "站立，行走，奔跑"  # 用于sit/rest/sleep时


# ============ 动作描述模板（正向，简洁）============

POSE_ACTIONS = {
    "sit": "坐姿，抬头四处张望",
    "walk": "四脚着地自然行走，前后脚交替移动",
    "rest": "趴卧，肚子贴地，头抬起，眼睛睁开",
    "sleep": "趴着睡觉，头放下，闭眼，打呼噜，鼻子有气体呼入呼出"
}

TRANSITION_ACTIONS = {
    "sit2walk": "从坐姿站起，然后自然行走，前后脚交替移动",
    "sit2rest": "从坐姿向前趴下，肚子贴地，头抬起眼睛睁开",
    "sit2sleep": "从坐姿趴下，头放下，闭眼打呼噜",
    
    "rest2sleep": "保持趴卧，头慢慢放下，闭眼打呼噜",
    "rest2sit": "从趴卧撑起身体，后腿弯曲坐下",
    "rest2walk": "从趴卧站起，然后自然行走，前后脚交替移动",
    
    "walk2sit": "行走减速停下，后腿弯曲坐下",
    "walk2rest": "行走减速停下，向前趴下，头抬起",
    "walk2sleep": "行走减速停下，趴下，闭眼打呼噜",
    
    "sleep2sit": "睁眼，撑起身体，后腿弯曲坐下",
    "sleep2rest": "睁眼，头抬起，保持趴卧",
    "sleep2walk": "睁眼，站起，然后自然行走，前后脚交替移动",
}


# ============ 猫的风格映射 ============

CAT_STYLE_MAP = {
    # 迪士尼写实风格
    "橘猫": "disney", "美短": "disney", "美国短毛猫": "disney",
    "三花猫": "disney", "田园猫": "disney", "中华田园猫": "disney", "狸花猫": "disney",
    # 纯写实风格
    "英短": "realistic", "英国短毛猫": "realistic",
    "布偶猫": "realistic", "布偶": "realistic",
    "波斯猫": "realistic", "暹罗猫": "realistic", "缅因猫": "realistic",
    "加菲猫": "realistic", "蓝猫": "realistic",
}


def _get_style(breed_name: str, species: str) -> str:
    """根据品种获取风格描述"""
    if species in ("dog", "狗"):
        return DOG_STYLE
    else:
        style_type = CAT_STYLE_MAP.get(breed_name, "disney")
        return CAT_REALISTIC_STYLE if style_type == "realistic" else CAT_DISNEY_STYLE


def _get_species_name(species: str) -> str:
    """获取物种名称"""
    return "犬" if species in ("dog", "狗") else "猫"


def _get_negative_prompt(action_type: str) -> str:
    """
    根据动作类型获取负向提示词
    
    Args:
        action_type: "sit", "walk", "rest", "sleep", 或过渡动作如"sit2walk"
    """
    negatives = [NEGATIVE_COMMON]
    
    # 涉及行走的动作，添加行走约束
    if "walk" in action_type:
        negatives.append(NEGATIVE_WALK)
    
    # 静态姿势（非行走），添加姿势约束
    if action_type in ("sit", "rest", "sleep"):
        negatives.append(NEGATIVE_POSE)
    
    return "，".join(negatives)


# ============ Prompt生成函数 ============

def generate_sit_prompt_v3(
    breed_name: str,
    weight: float = 0,
    gender: str = "",
    birthday: str = "",
    color: str = "",
    precise_pattern: bool = False,
    ai_features: Optional[Dict] = None,
    species: str = "dog"
) -> Tuple[str, str]:
    """
    生成sit坐姿的prompt
    
    Returns:
        (prompt, negative_prompt) 元组
    """
    style = _get_style(breed_name, species)
    species_name = _get_species_name(species)
    action = POSE_ACTIONS["sit"]
    
    prompt = (
        f"保持原图{breed_name}的外观特征，"
        f"{style}，纯白色背景，"
        f"{action}，镜头正对{species_name}的正前方。"
    )
    
    negative_prompt = _get_negative_prompt("sit")
    
    return prompt, negative_prompt


def generate_transition_prompt_v3(
    transition: str,
    breed_name: str,
    body_type: str = "",
    color: str = "",
    use_detailed: bool = True,
    ai_features: Optional[Dict] = None,
    species: str = "dog"
) -> Tuple[str, str]:
    """
    生成过渡视频的prompt
    
    Returns:
        (prompt, negative_prompt) 元组
    """
    style = _get_style(breed_name, species)
    species_name = _get_species_name(species)
    action = TRANSITION_ACTIONS.get(transition, "进行动作过渡")
    
    prompt = (
        f"保持原图{breed_name}的外观特征，"
        f"{style}，纯白色背景，"
        f"{action}，镜头正对{species_name}的正前方。"
    )
    
    negative_prompt = _get_negative_prompt(transition)
    
    return prompt, negative_prompt


def generate_loop_prompt_v3(
    pose: str,
    breed_name: str,
    body_type: str = "",
    color: str = "",
    ai_features: Optional[Dict] = None,
    species: str = "dog"
) -> Tuple[str, str]:
    """
    生成循环视频的prompt
    
    Returns:
        (prompt, negative_prompt) 元组
    """
    style = _get_style(breed_name, species)
    species_name = _get_species_name(species)
    action = POSE_ACTIONS.get(pose, "保持姿势")
    
    prompt = (
        f"保持原图{breed_name}的外观特征，"
        f"{style}，纯白色背景，"
        f"{action}，镜头正对{species_name}的正前方。"
    )
    
    negative_prompt = _get_negative_prompt(pose)
    
    return prompt, negative_prompt


# ============ 兼容性函数（返回单个字符串）============

def get_prompt_only(func, *args, **kwargs) -> str:
    """只返回prompt，不返回negative_prompt（兼容旧代码）"""
    result = func(*args, **kwargs)
    if isinstance(result, tuple):
        return result[0]
    return result


# ============ 测试 ============

if __name__ == "__main__":
    print("=== Prompt生成器 v3.0（支持negative_prompt）测试 ===\n")
    
    print("【金毛 - Sit】")
    prompt, neg = generate_sit_prompt_v3("金毛", species="dog")
    print(f"正向: {prompt}")
    print(f"负向: {neg}")
    print()
    
    print("【金毛 - sit2walk过渡】")
    prompt, neg = generate_transition_prompt_v3("sit2walk", "金毛", species="dog")
    print(f"正向: {prompt}")
    print(f"负向: {neg}")
    print()
    
    print("【金毛 - walk循环】")
    prompt, neg = generate_loop_prompt_v3("walk", "金毛", species="dog")
    print(f"正向: {prompt}")
    print(f"负向: {neg}")
    print()
    
    print("【橘猫 - sleep循环】")
    prompt, neg = generate_loop_prompt_v3("sleep", "橘猫", species="cat")
    print(f"正向: {prompt}")
    print(f"负向: {neg}")
    print()
    
    print("=" * 60)
    print("【所有负向提示词】")
    for action in ["sit", "walk", "rest", "sleep", "sit2walk", "walk2sit"]:
        print(f"{action}: {_get_negative_prompt(action)}")
