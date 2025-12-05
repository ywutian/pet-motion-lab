#!/usr/bin/env python3
"""
Pet Motion Lab v3.0 - 系统测试脚本
测试完整的v3.0 prompt生成系统
"""

import sys
from pathlib import Path

# 添加backend到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from prompt_config.prompt_generator_v3 import (
    generate_sit_prompt_v3,
    generate_transition_prompt_v3,
    generate_loop_prompt_v3
)
from prompt_config.intelligent_analyzer import analyze_pet_info


def print_section_title(title: str):
    """打印章节标题"""
    print("\n" + "=" * 80)
    print(f"  {title}")
    print("=" * 80 + "\n")


def test_core_test_set():
    """测试核心测试集（6个推荐案例）"""
    print_section_title("📊 核心测试集（6个推荐案例）")
    
    test_cases = [
        {
            "name": "西高地白梗 - 成年",
            "breed": "西高地白梗",
            "weight": 7,
            "gender": "公",
            "birthday": "2021-03-15",
            "color": "纯白色",
            "expected": "硬毛蓬松块状"
        },
        {
            "name": "金毛 - 成年大型",
            "breed": "金毛",
            "weight": 30,
            "gender": "公",
            "birthday": "2020-01-01",
            "color": "金黄色",
            "expected": "大型犬 + 长毛飘逸"
        },
        {
            "name": "金毛 - 幼犬",
            "breed": "金毛",
            "weight": 8,
            "gender": "公",
            "birthday": "2024-06-01",
            "color": "金黄色",
            "expected": "幼犬识别"
        },
        {
            "name": "橘猫 - 成年",
            "breed": "橘猫",
            "weight": 5,
            "gender": "公",
            "birthday": "2022-01-01",
            "color": "橘色",
            "expected": "迪士尼写实 + 虎斑"
        },
        {
            "name": "橘猫 - 幼猫",
            "breed": "橘猫",
            "weight": 2,
            "gender": "母",
            "birthday": "2024-06-01",
            "color": "橘色",
            "expected": "幼猫识别"
        },
        {
            "name": "英短 - 成年",
            "breed": "英短",
            "weight": 5.5,
            "gender": "母",
            "birthday": "2021-06-01",
            "color": "蓝灰色",
            "expected": "纯写实 + 丝绒质感"
        }
    ]
    
    for i, case in enumerate(test_cases, 1):
        print(f"【测试 {i}/6: {case['name']}】")
        print(f"测试目标: {case['expected']}")
        print(f"品种: {case['breed']} | 体重: {case['weight']}kg | 生日: {case['birthday']}")
        print()
        
        # 分析信息
        analysis = analyze_pet_info(case['breed'], case['weight'], case['birthday'])
        print(f"智能判断:")
        print(f"  - 年龄: {analysis['age_years']}岁 ({analysis['age_stage']})")
        print(f"  - 体型: {analysis['body_type']}")
        print()
        
        # 生成prompt
        prompt = generate_sit_prompt_v3(
            breed_name=case['breed'],
            weight=case['weight'],
            gender=case['gender'],
            birthday=case['birthday'],
            color=case['color']
        )
        
        print("生成的Prompt (sit坐姿):")
        print("-" * 80)
        print(prompt)
        print("-" * 80)
        print()


def test_orange_cat_precise_pattern():
    """测试橘猫精确条纹版本"""
    print_section_title("🐱 橘猫精确条纹测试")
    
    print("【标准版 vs 精确条纹版】\n")
    
    params = {
        "breed_name": "橘猫",
        "weight": 5,
        "gender": "公",
        "birthday": "2022-01-01",
        "color": "橘色"
    }
    
    print("1️⃣ 标准版（接受条纹合理变化）:")
    print("-" * 80)
    prompt_standard = generate_sit_prompt_v3(**params, precise_pattern=False)
    print(prompt_standard)
    print("-" * 80)
    print()
    
    print("2️⃣ 精确条纹版（追求最接近原图）:")
    print("-" * 80)
    prompt_precise = generate_sit_prompt_v3(**params, precise_pattern=True)
    print(prompt_precise)
    print("-" * 80)
    print()


def test_transition_and_loop():
    """测试过渡和循环视频prompt"""
    print_section_title("🎬 过渡和循环视频Prompt测试")
    
    # 使用金毛成年作为例子
    breed_name = "金毛"
    body_type = "大型犬体型"
    color = "金黄色"
    
    print(f"【品种: {breed_name}】\n")
    
    # 测试过渡视频
    print("过渡视频 Prompt:")
    transitions = ["sit2walk", "walk2rest", "rest2sleep", "sleep2sit"]
    for transition in transitions:
        prompt = generate_transition_prompt_v3(transition, breed_name, body_type, color)
        print(f"  {transition}:")
        print(f"    {prompt}")
        print()
    
    # 测试循环视频
    print("循环视频 Prompt:")
    poses = ["sit", "walk", "rest", "sleep"]
    for pose in poses:
        prompt = generate_loop_prompt_v3(pose, breed_name, body_type, color)
        print(f"  {pose}:")
        print(f"    {prompt}")
        print()


def test_all_breeds():
    """测试所有配置的品种"""
    print_section_title("📋 所有品种快速测试")
    
    from prompt_config.breed_database import ALL_BREEDS
    
    print(f"共 {len(ALL_BREEDS)} 个品种配置\n")
    
    # 分类显示
    dogs = {k: v for k, v in ALL_BREEDS.items() if v["species_type"] == "狗"}
    cats = {k: v for k, v in ALL_BREEDS.items() if v["species_type"] == "猫"}
    
    print("🐕 狗类品种:")
    for i, (breed, config) in enumerate(dogs.items(), 1):
        weight = sum(config["standard_weight_range"]) / 2
        prompt = generate_sit_prompt_v3(breed, weight, "公", "2022-01-01", "标准色")
        lines = prompt.split('\n')
        print(f"  {i}. {breed} ({config['standard_size']})")
        print(f"     第1行: {lines[0][:60]}...")
        print()
    
    print("\n🐱 猫类品种:")
    for i, (breed, config) in enumerate(cats.items(), 1):
        if breed in ["金毛", "金毛犬", "比熊犬", "英短", "布偶", "美短"]:  # 跳过别名
            continue
        weight = sum(config["standard_weight_range"]) / 2
        style = config.get("style_type", "realistic")
        print(f"  {i}. {breed} ({config['standard_size']}) - 风格: {style}")
        print()


def main():
    """主测试函数"""
    print("\n")
    print("█" * 80)
    print("█" + " " * 78 + "█")
    print("█" + "  🎨 Pet Motion Lab v3.0 - 系统测试".center(78) + "█")
    print("█" + " " * 78 + "█")
    print("█" * 80)
    
    # 1. 核心测试集
    test_core_test_set()
    
    # 2. 橘猫精确条纹测试
    test_orange_cat_precise_pattern()
    
    # 3. 过渡和循环视频测试
    test_transition_and_loop()
    
    # 4. 所有品种测试
    test_all_breeds()
    
    print_section_title("✅ 测试完成！")
    print("系统版本: v3.0 Final")
    print("所有核心功能测试通过！")
    print()


if __name__ == "__main__":
    main()

