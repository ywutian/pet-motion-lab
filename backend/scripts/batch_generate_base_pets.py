#!/usr/bin/env python3
"""
批量生成第一张图片 - 多个品种的3D卡通宠物
"""

from generate_base_pet import generate_base_pet_image
import time


# 常见宠物品种列表
PET_BREEDS = {
    "cat": [
        "ragdoll",           # 布偶猫
        "british_shorthair", # 英国短毛猫
        "persian",           # 波斯猫
        "siamese",           # 暹罗猫
        "maine_coon",        # 缅因猫
        "scottish_fold",     # 苏格兰折耳猫
    ],
    "dog": [
        "golden_retriever",  # 金毛
        "labrador",          # 拉布拉多
        "husky",             # 哈士奇
        "corgi",             # 柯基
        "poodle",            # 贵宾犬
        "shiba_inu",         # 柴犬
        "bulldog",           # 斗牛犬
        "german_shepherd",   # 德国牧羊犬
    ]
}


def batch_generate_all_breeds(output_dir: str = "output/base_pets"):
    """批量生成所有品种的基础图片"""
    print("=" * 70)
    print("🚀 批量生成所有品种的3D卡通宠物基础图")
    print("=" * 70)
    print()
    
    total_start = time.time()
    results = {"success": [], "failed": []}
    
    # 生成所有猫品种
    print("🐱 开始生成猫品种...")
    print("-" * 70)
    for breed in PET_BREEDS["cat"]:
        print(f"\n正在生成: cat - {breed}")
        result = generate_base_pet_image(
            species="cat",
            breed=breed,
            output_dir=output_dir,
        )
        
        if result:
            results["success"].append(f"cat/{breed}")
        else:
            results["failed"].append(f"cat/{breed}")
        
        # 避免API限流，等待一下
        time.sleep(2)
    
    print("\n" + "=" * 70)
    print("🐶 开始生成狗品种...")
    print("-" * 70)
    
    # 生成所有狗品种
    for breed in PET_BREEDS["dog"]:
        print(f"\n正在生成: dog - {breed}")
        result = generate_base_pet_image(
            species="dog",
            breed=breed,
            output_dir=output_dir,
        )
        
        if result:
            results["success"].append(f"dog/{breed}")
        else:
            results["failed"].append(f"dog/{breed}")
        
        # 避免API限流，等待一下
        time.sleep(2)
    
    # 总结
    total_time = time.time() - total_start
    
    print("\n" + "=" * 70)
    print("🎉 批量生成完成!")
    print("=" * 70)
    print(f"⏱️  总耗时: {total_time:.1f}s")
    print(f"✅ 成功: {len(results['success'])} 个")
    print(f"❌ 失败: {len(results['failed'])} 个")
    
    if results["success"]:
        print("\n✅ 成功生成的品种:")
        for item in results["success"]:
            print(f"   - {item}")
    
    if results["failed"]:
        print("\n❌ 失败的品种:")
        for item in results["failed"]:
            print(f"   - {item}")
    
    print("\n" + "=" * 70)
    print(f"📁 所有图片保存在: {output_dir}")
    print(f"💡 查看结果: open {output_dir}")
    print("=" * 70)


def batch_generate_species(species: str, output_dir: str = "output/base_pets"):
    """批量生成指定物种的所有品种"""
    print("=" * 70)
    print(f"🚀 批量生成 {species} 的所有品种")
    print("=" * 70)
    print()
    
    if species not in PET_BREEDS:
        print(f"❌ 不支持的物种: {species}")
        return
    
    total_start = time.time()
    results = {"success": [], "failed": []}
    
    for breed in PET_BREEDS[species]:
        print(f"\n正在生成: {species} - {breed}")
        result = generate_base_pet_image(
            species=species,
            breed=breed,
            output_dir=output_dir,
        )
        
        if result:
            results["success"].append(breed)
        else:
            results["failed"].append(breed)
        
        # 避免API限流
        time.sleep(2)
    
    # 总结
    total_time = time.time() - total_start
    
    print("\n" + "=" * 70)
    print("🎉 批量生成完成!")
    print("=" * 70)
    print(f"⏱️  总耗时: {total_time:.1f}s")
    print(f"✅ 成功: {len(results['success'])} 个")
    print(f"❌ 失败: {len(results['failed'])} 个")
    print("=" * 70)


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="批量生成3D卡通宠物基础图")
    parser.add_argument("--species", type=str, default="all", choices=["all", "cat", "dog"], 
                        help="物种 (all/cat/dog)")
    parser.add_argument("--output", type=str, default="output/base_pets", help="输出目录")
    
    args = parser.parse_args()
    
    if args.species == "all":
        batch_generate_all_breeds(args.output)
    else:
        batch_generate_species(args.species, args.output)

