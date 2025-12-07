#!/usr/bin/env python3
"""
测试可灵AI API连接（不消耗额度）
只验证API密钥是否有效，不实际生成视频
"""

import os
import sys
import jwt
import time
import requests
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent))

from config import KLING_ACCESS_KEY, KLING_SECRET_KEY, KLING_VIDEO_ACCESS_KEY, KLING_VIDEO_SECRET_KEY

# API 端点
BASE_URL_CHINA = "https://api.klingai.com"  # 国内版
BASE_URL_GLOBAL = "https://api.klingai.com"  # 海外版（实际可能不同）


def generate_jwt_token(access_key: str, secret_key: str) -> str:
    """生成 JWT Token"""
    headers = {
        "alg": "HS256",
        "typ": "JWT"
    }
    payload = {
        "iss": access_key,
        "exp": int(time.time()) + 1800,  # 30分钟过期
        "nbf": int(time.time()) - 5
    }
    token = jwt.encode(payload, secret_key, algorithm="HS256", headers=headers)
    return token


def test_api_connection(name: str, access_key: str, secret_key: str, base_url: str):
    """测试API连接"""
    print(f"\n{'='*60}")
    print(f"🔗 测试: {name}")
    print(f"{'='*60}")
    
    if not access_key or not secret_key:
        print(f"   ❌ 未配置 API 密钥")
        return False
    
    print(f"   Access Key: {access_key[:10]}...{access_key[-4:]}")
    print(f"   Secret Key: {secret_key[:10]}...{secret_key[-4:]}")
    
    # 生成 JWT Token
    try:
        token = generate_jwt_token(access_key, secret_key)
        print(f"   ✅ JWT Token 生成成功")
        print(f"      Token: {token[:50]}...")
    except Exception as e:
        print(f"   ❌ JWT Token 生成失败: {e}")
        return False
    
    # 测试 API 端点（使用一个只读的查询接口）
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # 尝试查询一个不存在的任务（这不会消耗额度，只是测试连接）
    test_endpoints = [
        # 查询视频任务（用假的task_id，会返回404但说明连接成功）
        (f"{base_url}/v1/videos/image2video/fake_task_id_12345", "GET", "视频任务查询"),
        # 查询图片任务
        (f"{base_url}/v1/images/generations/fake_task_id_12345", "GET", "图片任务查询"),
    ]
    
    for url, method, desc in test_endpoints:
        print(f"\n   📡 测试端点: {desc}")
        print(f"      URL: {url}")
        
        try:
            if method == "GET":
                response = requests.get(url, headers=headers, timeout=10)
            else:
                response = requests.post(url, headers=headers, json={}, timeout=10)
            
            print(f"      状态码: {response.status_code}")
            
            # 解析响应
            try:
                data = response.json()
                code = data.get("code", "")
                message = data.get("message", "")
                print(f"      响应码: {code}")
                print(f"      消息: {message}")
                
                # 判断连接是否成功
                # 如果返回 "task not found" 或类似错误，说明 API 连接正常，只是任务不存在
                if response.status_code == 404 or "not found" in message.lower() or code in [1001, 1002]:
                    print(f"      ✅ API 连接正常（任务不存在是预期的）")
                    return True
                elif response.status_code == 401 or "unauthorized" in message.lower() or "invalid" in message.lower():
                    print(f"      ❌ API 密钥无效")
                    return False
                elif response.status_code == 200:
                    print(f"      ✅ API 连接正常")
                    return True
                else:
                    print(f"      ⚠️ 未知响应，但连接成功")
                    return True
                    
            except:
                print(f"      响应内容: {response.text[:200]}")
                if response.status_code < 500:
                    return True
                    
        except requests.exceptions.Timeout:
            print(f"      ❌ 请求超时")
        except requests.exceptions.ConnectionError as e:
            print(f"      ❌ 连接失败: {e}")
        except Exception as e:
            print(f"      ❌ 请求失败: {e}")
    
    return False


def main():
    print("=" * 70)
    print("🔌 可灵AI API 连接测试（不消耗额度）")
    print("=" * 70)
    
    results = []
    
    # 测试图片生成 API（国内版）
    result1 = test_api_connection(
        "图片生成 API (KLING_ACCESS_KEY)",
        KLING_ACCESS_KEY,
        KLING_SECRET_KEY,
        BASE_URL_CHINA
    )
    results.append(("图片API", result1))
    
    # 测试视频生成 API（海外版）
    if KLING_VIDEO_ACCESS_KEY and KLING_VIDEO_ACCESS_KEY != KLING_ACCESS_KEY:
        result2 = test_api_connection(
            "视频生成 API (KLING_VIDEO_ACCESS_KEY)",
            KLING_VIDEO_ACCESS_KEY,
            KLING_VIDEO_SECRET_KEY,
            BASE_URL_GLOBAL
        )
        results.append(("视频API", result2))
    else:
        print("\n⚠️ 视频API使用与图片API相同的密钥")
        results.append(("视频API", result1))
    
    # 汇总
    print("\n")
    print("=" * 70)
    print("📊 测试结果汇总")
    print("=" * 70)
    
    all_ok = True
    for name, ok in results:
        status = "✅ 正常" if ok else "❌ 失败"
        print(f"   {name}: {status}")
        if not ok:
            all_ok = False
    
    print("=" * 70)
    
    if all_ok:
        print("\n🎉 所有 API 连接正常！可以开始使用。")
        print("\n💡 推荐的便宜模型配置:")
        print("   模型: kling-v2-5-turbo 或 kling-v2-1")
        print("   模式: std (720p)")
        print("   时长: 5s")
        print("   单价: $0.21 ~ $0.28")
    else:
        print("\n⚠️ 部分 API 连接失败，请检查密钥配置。")


if __name__ == "__main__":
    main()


