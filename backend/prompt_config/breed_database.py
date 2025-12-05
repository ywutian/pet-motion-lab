#!/usr/bin/env python3
"""
Pet Motion Lab v3.0 - 品种配置数据库
包含狗和猫的详细品种配置
"""

# 🐕 狗类品种配置（全部卡通风格）
DOG_BREEDS = {
    "西高地白梗": {
        "species_type": "狗",
        "standard_weight_range": (6, 10),
        "standard_size": "小型犬体型",
        "fur_type": "硬毛",
        "fur_feature": "蓬松硬毛质感",
        "fur_style": "毛发高度简化为蓬松块状",
        "ear_shape": "直立小耳朵",
        "exclude": "完全去除写实照片感、真实毛发纹理、摄影质感"
    },
    
    "金毛": {
        "species_type": "狗",
        "standard_weight_range": (25, 34),
        "standard_size": "大型犬体型",
        "fur_type": "长毛",
        "fur_feature": "长毛柔顺质感",
        "fur_style": "长毛呈现流畅柔顺的块状质感，保留飘逸感",
        "ear_shape": "垂耳",
        "exclude": "避免写实照片和逐根毛发细节"
    },
    
    "金毛犬": {  # 别名
        "species_type": "狗",
        "standard_weight_range": (25, 34),
        "standard_size": "大型犬体型",
        "fur_type": "长毛",
        "fur_feature": "长毛柔顺质感",
        "fur_style": "长毛呈现流畅柔顺的块状质感，保留飘逸感",
        "ear_shape": "垂耳",
        "exclude": "避免写实照片和逐根毛发细节"
    },
    
    "柯基": {
        "species_type": "狗",
        "standard_weight_range": (10, 14),
        "standard_size": "中型犬体型",
        "fur_type": "短毛",
        "fur_feature": "短毛",
        "fur_style": "短毛呈现光滑块状质感",
        "ear_shape": "大直立耳",
        "exclude": "完全去除写实照片感、真实毛发纹理、摄影质感"
    },
    
    "柴犬": {
        "species_type": "狗",
        "standard_weight_range": (8, 12),
        "standard_size": "中型犬体型",
        "fur_type": "短毛",
        "fur_feature": "短毛",
        "fur_style": "短毛呈现光滑块状质感",
        "ear_shape": "直立三角耳",
        "exclude": "完全去除写实照片感、真实毛发纹理、摄影质感"
    },
    
    "哈士奇": {
        "species_type": "狗",
        "standard_weight_range": (20, 27),
        "standard_size": "大型犬体型",
        "fur_type": "中长毛",
        "fur_feature": "中长毛",
        "fur_style": "中长毛呈现块状质感，保留毛色对比",
        "ear_shape": "直立三角耳",
        "exclude": "避免写实照片和逐根毛发细节"
    },
    
    "比熊": {
        "species_type": "狗",
        "standard_weight_range": (5, 8),
        "standard_size": "小型犬体型",
        "fur_type": "卷毛",
        "fur_feature": "卷毛蓬松质感",
        "fur_style": "卷毛呈现柔软蓬松的云朵状质感",
        "ear_shape": "垂耳",
        "exclude": "完全去除写实照片感、真实毛发纹理、摄影质感"
    },
    
    "比熊犬": {  # 别名
        "species_type": "狗",
        "standard_weight_range": (5, 8),
        "standard_size": "小型犬体型",
        "fur_type": "卷毛",
        "fur_feature": "卷毛蓬松质感",
        "fur_style": "卷毛呈现柔软蓬松的云朵状质感",
        "ear_shape": "垂耳",
        "exclude": "完全去除写实照片感、真实毛发纹理、摄影质感"
    },
    
    "萨摩耶": {
        "species_type": "狗",
        "standard_weight_range": (20, 30),
        "standard_size": "大型犬体型",
        "fur_type": "长毛",
        "fur_feature": "长毛蓬松质感",
        "fur_style": "长毛呈现蓬松柔软的块状质感，保留云朵般的蓬松感",
        "ear_shape": "直立三角耳",
        "exclude": "避免写实照片和逐根毛发细节"
    }
}

# 🐱 猫类品种配置（分迪士尼写实和纯写实）
CAT_BREEDS = {
    # === 迪士尼写实风格 ===
    "橘猫": {
        "species_type": "猫",
        "standard_weight_range": (4, 6),
        "standard_size": "中型猫体型",
        "fur_type": "短毛",
        "fur_feature": "短毛",
        "special_feature": "虎斑条纹",
        "fur_style": "保留虎斑条纹和毛发纹理细节",
        "ear_shape": "圆耳",
        "style_type": "disney_realistic",
        "special_markers": ["橘色虎斑", "白色胸毛"]
    },
    
    "美国短毛猫": {
        "species_type": "猫",
        "standard_weight_range": (4, 6),
        "standard_size": "中型猫体型",
        "fur_type": "短毛",
        "fur_feature": "短毛",
        "special_feature": "虎斑条纹",
        "fur_style": "保留虎斑条纹和毛发纹理细节",
        "ear_shape": "圆耳",
        "style_type": "disney_realistic"
    },
    
    "美短": {  # 别名
        "species_type": "猫",
        "standard_weight_range": (4, 6),
        "standard_size": "中型猫体型",
        "fur_type": "短毛",
        "fur_feature": "短毛",
        "special_feature": "虎斑条纹",
        "fur_style": "保留虎斑条纹和毛发纹理细节",
        "ear_shape": "圆耳",
        "style_type": "disney_realistic"
    },
    
    "三花猫": {
        "species_type": "猫",
        "standard_weight_range": (3, 5),
        "standard_size": "中型猫体型",
        "fur_type": "短毛",
        "fur_feature": "短毛",
        "special_feature": "三花色分布",
        "fur_style": "保留三花色分布和毛发纹理细节",
        "ear_shape": "圆耳",
        "style_type": "disney_realistic"
    },
    
    "田园猫": {
        "species_type": "猫",
        "standard_weight_range": (3, 5),
        "standard_size": "中型猫体型",
        "fur_type": "短毛",
        "fur_feature": "短毛",
        "fur_style": "保留毛发纹理细节",
        "ear_shape": "圆耳",
        "style_type": "disney_realistic"
    },
    
    # === 纯写实风格 ===
    "英国短毛猫": {
        "species_type": "猫",
        "standard_weight_range": (4, 7),
        "standard_size": "中型猫体型",
        "fur_type": "浓密短毛",
        "fur_feature": "浓密短毛丝绒质感",
        "fur_style": "保留丝绒质感和细腻纹理",
        "ear_shape": "圆耳",
        "style_type": "realistic"
    },
    
    "英短": {  # 别名
        "species_type": "猫",
        "standard_weight_range": (4, 7),
        "standard_size": "中型猫体型",
        "fur_type": "浓密短毛",
        "fur_feature": "浓密短毛丝绒质感",
        "fur_style": "保留丝绒质感和细腻纹理",
        "ear_shape": "圆耳",
        "style_type": "realistic"
    },
    
    "布偶猫": {
        "species_type": "猫",
        "standard_weight_range": (6, 10),
        "standard_size": "大型猫体型",
        "fur_type": "长毛",
        "fur_feature": "长毛蓬松质感",
        "special_feature": "重点色",
        "fur_style": "保留长毛蓬松质感和重点色分布",
        "ear_shape": "圆耳",
        "style_type": "realistic"
    },
    
    "布偶": {  # 别名
        "species_type": "猫",
        "standard_weight_range": (6, 10),
        "standard_size": "大型猫体型",
        "fur_type": "长毛",
        "fur_feature": "长毛蓬松质感",
        "special_feature": "重点色",
        "fur_style": "保留长毛蓬松质感和重点色分布",
        "ear_shape": "圆耳",
        "style_type": "realistic"
    },
    
    "波斯猫": {
        "species_type": "猫",
        "standard_weight_range": (4, 6),
        "standard_size": "中型猫体型",
        "fur_type": "长毛",
        "fur_feature": "长毛华丽质感",
        "fur_style": "保留长毛华丽质感和层次",
        "ear_shape": "小圆耳",
        "style_type": "realistic"
    },
    
    "暹罗猫": {
        "species_type": "猫",
        "standard_weight_range": (3, 5),
        "standard_size": "中型猫体型",
        "fur_type": "短毛",
        "fur_feature": "短毛",
        "special_feature": "重点色",
        "fur_style": "保留短毛光滑质感和重点色分布",
        "ear_shape": "大三角耳",
        "style_type": "realistic"
    },
    
    "缅因猫": {
        "species_type": "猫",
        "standard_weight_range": (6, 11),
        "standard_size": "大型猫体型",
        "fur_type": "长毛",
        "fur_feature": "长毛蓬松质感",
        "fur_style": "保留长毛蓬松质感和层次",
        "ear_shape": "大三角耳",
        "style_type": "realistic"
    }
}

# 所有品种合并（用于查找）
ALL_BREEDS = {**DOG_BREEDS, **CAT_BREEDS}


def get_breed_config(breed_name: str) -> dict:
    """
    获取品种配置
    
    Args:
        breed_name: 品种名称
    
    Returns:
        品种配置字典，如果未找到返回None
    """
    return ALL_BREEDS.get(breed_name)


def is_dog_breed(breed_name: str) -> bool:
    """判断是否为狗品种"""
    breed = get_breed_config(breed_name)
    return breed and breed["species_type"] == "狗"


def is_cat_breed(breed_name: str) -> bool:
    """判断是否为猫品种"""
    breed = get_breed_config(breed_name)
    return breed and breed["species_type"] == "猫"


def get_style_type(breed_name: str) -> str:
    """
    获取品种的风格类型
    
    Returns:
        "cartoon" (狗-卡通), "disney_realistic" (猫-迪士尼写实), "realistic" (猫-纯写实)
    """
    breed = get_breed_config(breed_name)
    if not breed:
        return "cartoon"  # 默认卡通风格
    
    if breed["species_type"] == "狗":
        return "cartoon"
    else:  # 猫
        return breed.get("style_type", "realistic")


if __name__ == "__main__":
    # 测试
    print("=== 品种配置测试 ===\n")
    
    test_breeds = ["西高地白梗", "金毛", "橘猫", "英短", "布偶猫"]
    
    for breed in test_breeds:
        config = get_breed_config(breed)
        if config:
            print(f"品种: {breed}")
            print(f"  物种: {config['species_type']}")
            print(f"  标准体重: {config['standard_weight_range']}kg")
            print(f"  标准体型: {config['standard_size']}")
            print(f"  毛发类型: {config['fur_type']}")
            if config['species_type'] == '猫':
                print(f"  风格: {config.get('style_type', 'N/A')}")
            print()

