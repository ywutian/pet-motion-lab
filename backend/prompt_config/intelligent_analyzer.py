#!/usr/bin/env python3
"""
Pet Motion Lab v3.0 - 智能判断逻辑
根据体重、年龄、品种自动判断体型和年龄阶段
"""

from datetime import datetime, date
from typing import Tuple
from .breed_database import get_breed_config


def calculate_age_in_years(birthday: str) -> float:
    """
    计算年龄（年）
    
    Args:
        birthday: 生日字符串 "YYYY-MM-DD"
    
    Returns:
        年龄（浮点数，精确到月）
    """
    if isinstance(birthday, str):
        birth_date = datetime.strptime(birthday, "%Y-%m-%d").date()
    else:
        birth_date = birthday
    
    today = date.today()
    age_years = today.year - birth_date.year
    age_months = today.month - birth_date.month
    age_days = today.day - birth_date.day
    
    # 调整月份和年份
    if age_days < 0:
        age_months -= 1
    if age_months < 0:
        age_years -= 1
        age_months += 12
    
    # 返回精确到月的年龄
    return age_years + age_months / 12.0


def judge_dog_body_type(weight: float, breed_name: str, age: float) -> str:
    """
    判断狗的体型
    
    Args:
        weight: 体重(kg)
        breed_name: 品种名
        age: 年龄(年)
    
    Returns:
        体型描述: "小型犬体型", "中型犬体型", "大型犬体型", "幼犬体型"
    """
    breed_config = get_breed_config(breed_name)
    
    # 基础判断（无品种配置时）
    if not breed_config:
        if weight < 10:
            return "小型犬体型"
        elif weight < 25:
            return "中型犬体型"
        else:
            return "大型犬体型"
    
    # 有品种配置
    standard_min, standard_max = breed_config["standard_weight_range"]
    standard_avg = (standard_min + standard_max) / 2
    
    # 幼犬判断：年龄<1岁 且 体重明显低于品种标准
    if age < 1.0 and weight < standard_min * 0.7:
        return "幼犬体型"
    
    # 根据体重范围判断
    if weight < 10:
        return "小型犬体型"
    elif weight < 25:
        return "中型犬体型"
    else:
        return "大型犬体型"


def judge_cat_body_type(weight: float, breed_name: str, age: float) -> str:
    """
    判断猫的体型
    
    Args:
        weight: 体重(kg)
        breed_name: 品种名
        age: 年龄(年)
    
    Returns:
        体型描述: "小型猫体型", "中型猫体型", "大型猫体型", "幼猫体型"
    """
    breed_config = get_breed_config(breed_name)
    
    # 基础判断（无品种配置时）
    if not breed_config:
        if weight < 4:
            return "小型猫体型"
        elif weight < 6:
            return "中型猫体型"
        else:
            return "大型猫体型"
    
    # 有品种配置
    standard_min, standard_max = breed_config["standard_weight_range"]
    
    # 幼猫判断：年龄<1岁 且 体重明显低于品种标准
    if age < 1.0 and weight < standard_min * 0.7:
        return "幼猫体型"
    
    # 根据体重范围判断
    if weight < 4:
        return "小型猫体型"
    elif weight < 6:
        return "中型猫体型"
    else:
        return "大型猫体型"


def judge_age_stage(age: float, species_type: str) -> str:
    """
    判断年龄阶段
    
    Args:
        age: 年龄(年)
        species_type: "狗" 或 "猫"
    
    Returns:
        年龄阶段: "幼犬/幼猫", "成年犬/成年猫", "老年犬/老年猫"
    """
    if species_type == "狗":
        if age < 1:
            return "幼犬"
        elif age <= 7:
            return "成年犬"
        else:
            return "老年犬"
    else:  # 猫
        if age < 1:
            return "幼猫"
        elif age <= 10:
            return "成年猫"
        else:
            return "老年猫"


def analyze_pet_info(breed_name: str, weight: float, birthday: str) -> dict:
    """
    综合分析宠物信息
    
    Args:
        breed_name: 品种名
        weight: 体重(kg)
        birthday: 生日 "YYYY-MM-DD"
    
    Returns:
        分析结果字典
    """
    breed_config = get_breed_config(breed_name)
    
    if not breed_config:
        return {
            "error": f"未找到品种配置: {breed_name}",
            "breed_name": breed_name,
            "weight": weight
        }
    
    # 计算年龄
    age = calculate_age_in_years(birthday)
    species_type = breed_config["species_type"]
    
    # 判断体型
    if species_type == "狗":
        body_type = judge_dog_body_type(weight, breed_name, age)
    else:
        body_type = judge_cat_body_type(weight, breed_name, age)
    
    # 判断年龄阶段
    age_stage = judge_age_stage(age, species_type)
    
    return {
        "breed_name": breed_name,
        "species_type": species_type,
        "weight": weight,
        "birthday": birthday,
        "age_years": round(age, 2),
        "age_stage": age_stage,
        "body_type": body_type,
        "breed_config": breed_config
    }


if __name__ == "__main__":
    # 测试用例
    print("=== 智能判断测试 ===\n")
    
    test_cases = [
        {"breed": "金毛", "weight": 30, "birthday": "2020-01-01", "desc": "成年大型金毛"},
        {"breed": "金毛", "weight": 8, "birthday": "2024-06-01", "desc": "幼年金毛"},
        {"breed": "西高地白梗", "weight": 7, "birthday": "2021-01-01", "desc": "成年西高地"},
        {"breed": "橘猫", "weight": 5, "birthday": "2022-01-01", "desc": "成年橘猫"},
        {"breed": "橘猫", "weight": 2, "birthday": "2024-06-01", "desc": "幼年橘猫"},
        {"breed": "英短", "weight": 5.5, "birthday": "2021-06-01", "desc": "成年英短"},
    ]
    
    for case in test_cases:
        print(f"【{case['desc']}】")
        result = analyze_pet_info(case['breed'], case['weight'], case['birthday'])
        
        if "error" in result:
            print(f"  ❌ {result['error']}\n")
            continue
        
        print(f"  品种: {result['breed_name']}")
        print(f"  体重: {result['weight']}kg")
        print(f"  年龄: {result['age_years']}岁")
        print(f"  年龄阶段: {result['age_stage']}")
        print(f"  体型判断: {result['body_type']}")
        print()

