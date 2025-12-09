#!/usr/bin/env python3
"""
Pet Motion Lab v3.0 - Prompt生成器
基于新的三行格式生成prompt
"""

from .breed_database import get_breed_config, get_style_type
from .intelligent_analyzer import analyze_pet_info


def generate_sit_prompt_v3(
    breed_name: str,
    weight: float,
    gender: str,
    birthday: str,
    color: str,
    precise_pattern: bool = False
) -> str:
    """
    生成sit坐姿的prompt (v3.0三行格式)

    Args:
        breed_name: 品种名（如：西高地白梗、金毛、橘猫）
        weight: 体重(kg)
        gender: 性别（公/母）
        birthday: 生日 "YYYY-MM-DD"
        color: 颜色描述（如：纯白色、金黄色、橘色）
        precise_pattern: 是否使用精确条纹版本（仅橘猫）

    Returns:
        三行格式的prompt
    """
    # 获取品种配置（即使没有体重/生日也能工作）
    breed_config = get_breed_config(breed_name)

    # 默认物种和体型
    if breed_config:
        species_type = breed_config["species_type"]
        default_body_type = breed_config.get(
            "standard_size",
            "中型犬体型" if species_type == "狗" else "中型猫体型",
        )
    else:
        # 未配置的品种，做一个通用兜底
        species_type = "狗"
        default_body_type = "中型犬体型"

    body_type = default_body_type
    analysis = None

    # 如果提供了完整的体重和生日，尝试进行智能分析
    if weight and weight > 0 and birthday:
        try:
            analysis = analyze_pet_info(breed_name, weight, birthday)
        except Exception:
            analysis = None

    if analysis and "error" not in analysis:
        breed_config = analysis.get("breed_config", breed_config)
        body_type = analysis.get("body_type", default_body_type)
        species_type = analysis.get("species_type", species_type)

    # 如果仍然没有breed_config（完全未知品种），使用极简三行prompt兜底
    if not breed_config:
        species_name = "犬" if species_type == "狗" else "猫"
        line1 = f"保持原图{breed_name}的{body_type}和外观特征：{color}毛发。"
        line2 = "3D卡通动画风格，色彩明亮柔和，避免写实照片感和过强噪点。"
        line3 = f"背景纯白色(#FFFFFF)，坐在地上抬头四处张望，镜头正对{species_name}的正前方。"
        return f"{line1}\n{line2}\n{line3}"

    # 确定物种名称
    species_name = "犬" if species_type == "狗" else "猫"

    # 生成第1行
    line1 = _generate_line1(breed_name, body_type, color, breed_config, precise_pattern)

    # 生成第2行
    line2 = _generate_line2(breed_config, species_type)

    # 生成第3行
    line3 = f"背景纯白色(#FFFFFF)，坐在地上抬头四处张望，镜头正对{species_name}的正前方。"

    # 组合三行
    prompt = f"{line1}\n{line2}\n{line3}"

    return prompt


def _generate_line1(breed_name: str, body_type: str, color: str, breed_config: dict, precise_pattern: bool = False) -> str:
    """生成第1行：保持原图特征"""
    fur_feature = breed_config["fur_feature"]
    ear_shape = breed_config["ear_shape"]

    # 基础特征
    features = [color, fur_feature, ear_shape]

    # 添加特殊标记（如果有）
    if "special_markers" in breed_config:
        # 橘猫特殊处理
        if breed_name == "橘猫" and precise_pattern:
            features = ["橘色底色、原图虎斑条纹的精确图案", fur_feature, ear_shape, "白色胸毛和白爪"]
        else:
            features.extend(breed_config["special_markers"])
    elif "special_feature" in breed_config:
        special = breed_config["special_feature"]
        # 橘猫特殊处理
        if breed_name == "橘猫":
            if precise_pattern:
                features[0] = "橘色底色、原图虎斑条纹的精确图案"
            else:
                features[0] = f"{color}虎斑"
        elif special:
            features.insert(0, special) if "重点色" in special else features.append(special)

    features_str = "、".join(features)

    # 构建第1行
    if precise_pattern and breed_name == "橘猫":
        line1 = f"保持原图{breed_name}的{body_type}和完整外观：{features_str}。"
    else:
        line1 = f"保持原图{breed_name}的{body_type}和外观特征：{features_str}。"

    return line1


def _generate_line2(breed_config: dict, species_type: str) -> str:
    """生成第2行：风格描述"""
    fur_style = breed_config["fur_style"]

    if species_type == "狗":
        # 狗 - 卡通风格
        exclude = breed_config["exclude"]
        line2 = (
            f"3D卡通动画风格，参考《疯狂动物城》《爱宠大机密》的宠物角色，"
            f"{fur_style}，色彩鲜艳明亮，卡通化柔和阴影，{exclude}。"
        )
    else:
        # 猫 - 根据style_type选择
        style_type = breed_config.get("style_type", "realistic")

        if style_type == "disney_realistic":
            # 迪士尼写实风格
            line2 = (
                f"迪士尼3D动画风格，{fur_style}，"
                f"温暖明亮色调，柔和艺术化光影，避免过度卡通平涂和真实照片质感。"
            )
        else:
            # 纯写实风格
            line2 = f"写实渲染，{fur_style}，自然光影细腻层次。"

    return line2


def generate_loop_prompt_v3(
    pose: str,
    breed_name: str,
    body_type: str,
    color: str
) -> str:
    """
    生成循环视频的prompt (v3.0单行格式)

    Args:
        pose: 姿势名称 (如 "sit", "walk", "rest", "sleep")
        breed_name: 品种名
        body_type: 体型 [未使用]
        color: 颜色 [未使用]

    Returns:
        循环视频prompt
    """
    breed_config = get_breed_config(breed_name)

    if not breed_config:
        return f"错误: 未找到品种配置 {breed_name}"

    species_type = breed_config.get("species_type", "狗")
    species_name = "犬" if species_type == "狗" else "猫"

    # 姿势动作描述 - 参考截图格式
    pose_actions = {
        "sit": "坐在地上四处张望",
        "walk": "往前走，不要双脚同时离地，镜头跟随宠物移动保持距离不变",
        "rest": "趴在地上四处张望",
        "sleep": "在睡觉，打呼噜，有气体呼入呼出"
    }

    action = pose_actions.get(pose, "保持姿势")

    # Walk动作的镜头描述已经包含在action中，不需要重复
    if pose == "walk":
        prompt = f"卡通3D{breed_name}，背景是纯白色#FFFFFF，{action}。"
    else:
        prompt = f"卡通3D{breed_name}，背景是纯白色#FFFFFF，{action}，镜头面对{species_name}的正前方。"

    return prompt


def generate_transition_prompt_v3(
    transition: str,
    breed_name: str,
    body_type: str,
    color: str,
    use_detailed: bool = True
) -> str:
    """
    生成过渡视频的prompt (v3.0单行格式)

    Args:
        transition: 过渡名称 (如 "sit2walk")
        breed_name: 品种名
        body_type: 体型 [未使用]
        color: 颜色 [未使用]
        use_detailed: 是否使用详细描述 [未使用]

    Returns:
        过渡视频prompt
    """
    breed_config = get_breed_config(breed_name)

    if not breed_config:
        return f"错误: 未找到品种配置 {breed_name}"

    species_type = breed_config.get("species_type", "狗")
    species_name = "犬" if species_type == "狗" else "猫"

    # 过渡动作描述 - 参考截图格式
    transition_actions = {
        "sit2walk": "从坐姿自然站起，不要双脚同时离地，然后自然行走前后交替移动，镜头跟随宠物移动保持距离不变",
        "sit2rest": "从坐姿身体向前倾，前腿向前伸展后腿向后伸展，肚子前部贴地呈趴卧姿势，头抬起眼睛睁开",
        "sit2sleep": "从坐姿身体向前倾倒趴下，四肢放松伸展肚子贴地，头放下贴近地面，闭眼，嘴微张有节奏打呼噜，鼻子有气体呼入呼出",
        "rest2sleep": "保持趴姿肚子贴地，头慢慢放下，眼睛缓缓闭上，身体完全放松，嘴微张有节奏打呼噜，鼻子有明显气体呼入呼出",
        "rest2sit": "从趴卧姿势自然挺身，不要双脚同时离地，后腿弯曲臀部下沉呈坐姿",
        "rest2walk": "从趴卧姿势自然站起，不要双脚同时离地，然后自然行走前后交替移动，镜头跟随宠物移动保持距离不变",
        "walk2sit": "四脚着地自然行走前后交替移动，逐渐减速停下，后腿弯曲臀部下沉呈坐姿",
        "walk2rest": "四脚着地自然行走前后交替移动，逐渐减速停下，身体向前趴下肚子贴地，头抬起眼睛睁开",
        "walk2sleep": "四脚着地自然行走前后交替移动，逐渐减速停下趴下，头放下闭眼，嘴微张打呼噜",
        "sleep2sit": "从睡觉闭眼打呼噜状态，慢慢睁眼停止打呼噜，自然挺起身体，不要双脚同时离地，后腿弯曲坐下前腿直立呈坐姿",
        "sleep2rest": "从睡觉闭眼打呼噜状态，慢慢睁眼停止打呼噜，头抬起，保持趴卧但呈警觉状态，眼睛睁开环顾四周",
        "sleep2walk": "从睡觉闭眼打呼噜状态，慢慢睁眼停止打呼噜，自然站起，不要双脚同时离地，然后自然行走前后交替移动，镜头跟随宠物移动保持距离不变"
    }

    action = transition_actions.get(transition, "宠物进行动作过渡")

    # 涉及walk的过渡动作，镜头描述已经包含在action中，不需要重复
    walk_transitions = ["sit2walk", "rest2walk", "sleep2walk"]
    if transition in walk_transitions:
        prompt = f"卡通3D{breed_name}，背景是纯白色#FFFFFF，{action}。"
    else:
        prompt = f"卡通3D{breed_name}，背景是纯白色#FFFFFF，{action}，镜头面对{species_name}的正前方。"

    return prompt


if __name__ == "__main__":
    # 测试用例
    print("=== Prompt生成器 v3.0 测试 ===\n")

    test_cases = [
        {
            "breed": "西高地白梗",
            "weight": 7,
            "gender": "公",
            "birthday": "2021-03-15",
            "color": "纯白色"
        },
        {
            "breed": "金毛",
            "weight": 30,
            "gender": "公",
            "birthday": "2020-01-01",
            "color": "金黄色"
        },
        {
            "breed": "金毛",
            "weight": 8,
            "gender": "公",
            "birthday": "2024-06-01",
            "color": "金黄色"
        },
        {
            "breed": "橘猫",
            "weight": 5,
            "gender": "公",
            "birthday": "2022-01-01",
            "color": "橘色"
        },
        {
            "breed": "英短",
            "weight": 5.5,
            "gender": "母",
            "birthday": "2021-06-01",
            "color": "蓝灰色"
        }
    ]

    for i, case in enumerate(test_cases, 1):
        print(f"【测试{i}: {case['breed']} - {case['weight']}kg】")
        prompt = generate_sit_prompt_v3(**case)
        print(prompt)
        print("\n" + "="*60 + "\n")
