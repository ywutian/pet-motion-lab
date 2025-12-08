#!/usr/bin/env python3
"""
可灵AI提示词配置
所有提示词模板集中管理
"""

# 首批3个过渡视频（步骤3，用于从sit生成walk/rest/sleep基础图）
# 顺序很重要：sit2walk和sit2rest可以并行，但rest2sleep必须在sit2rest之后
FIRST_TRANSITIONS = ["sit2walk", "sit2rest", "rest2sleep"]

# 所有姿势
POSES = ["sit", "walk", "rest", "sleep"]



def get_all_transitions() -> list:
    """获取所有过渡组合（12个）

    仅提供姿势/动作组合信息，不再包含任何旧版文字 Prompt。
    """
    transitions = []
    for start_pose in POSES:
        for end_pose in POSES:
            if start_pose != end_pose:
                transitions.append(f"{start_pose}2{end_pose}")
    return transitions


