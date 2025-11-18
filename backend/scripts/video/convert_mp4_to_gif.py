import cv2
import os
import glob
from PIL import Image
import numpy as np

def convert_mp4_to_gif(input_path, output_path, fps_reduction=3, max_width=480):
    """
    将MP4视频转换为GIF
    
    Args:
        input_path (str): 输入MP4文件路径
        output_path (str): 输出GIF文件路径
        fps_reduction (int): 帧率缩减倍数，用于减小GIF文件大小
        max_width (int): GIF最大宽度，用于缩放
    """
    try:
        # 打开视频文件
        cap = cv2.VideoCapture(input_path)
        
        if not cap.isOpened():
            print(f"错误：无法打开视频文件 - {input_path}")
            return False
        
        # 获取视频属性
        fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        print(f"  原视频信息: {width}x{height}, {fps:.1f}FPS, {total_frames}帧")
        
        # 计算缩放后的尺寸
        if width > max_width:
            scale_factor = max_width / width
            new_width = max_width
            new_height = int(height * scale_factor)
        else:
            new_width = width
            new_height = height
            scale_factor = 1.0
        
        print(f"  GIF尺寸: {new_width}x{new_height}")
        
        # 读取帧并转换为PIL图像
        frames = []
        frame_count = 0
        frames_to_skip = fps_reduction - 1  # 每fps_reduction帧取一帧
        
        while True:
            ret, frame = cap.read()
            
            if not ret:
                break
            
            # 跳帧以减小GIF大小
            if frame_count % fps_reduction == 0:
                # OpenCV使用BGR，PIL使用RGB
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                
                # 缩放图像
                if scale_factor != 1.0:
                    frame_rgb = cv2.resize(frame_rgb, (new_width, new_height))
                
                # 转换为PIL Image
                pil_image = Image.fromarray(frame_rgb)
                frames.append(pil_image)
            
            frame_count += 1
            
            # 显示进度
            if frame_count % 30 == 0:
                progress = (frame_count / total_frames) * 100
                print(f"  处理进度: {frame_count}/{total_frames}帧 ({progress:.1f}%)")
        
        cap.release()
        
        if not frames:
            print(f"  错误：没有读取到任何帧")
            return False
        
        print(f"  成功读取 {len(frames)} 帧用于GIF")
        
        # 计算GIF的帧间隔（毫秒）
        gif_fps = fps / fps_reduction
        frame_duration = int(1000 / gif_fps)  # 毫秒
        
        print(f"  GIF帧率: {gif_fps:.1f}FPS, 帧间隔: {frame_duration}ms")
        
        # 保存为GIF
        print(f"  正在保存GIF...")
        frames[0].save(
            output_path,
            save_all=True,
            append_images=frames[1:],
            duration=frame_duration,
            loop=0,  # 无限循环
            optimize=True  # 优化文件大小
        )
        
        # 检查生成的文件大小
        file_size = os.path.getsize(output_path) / (1024 * 1024)  # MB
        print(f"  ✅ 成功保存: {output_path} ({file_size:.2f}MB)")
        
        return True
        
    except Exception as e:
        print(f"  ❌ 转换失败: {str(e)}")
        return False

def batch_convert_mp4_to_gif(input_dir, output_dir, fps_reduction=3, max_width=480):
    """
    批量转换目录中的所有MP4文件为GIF
    
    Args:
        input_dir (str): 输入目录路径
        output_dir (str): 输出目录路径
        fps_reduction (int): 帧率缩减倍数
        max_width (int): GIF最大宽度
    """
    # 检查输入目录是否存在
    if not os.path.exists(input_dir):
        print(f"错误：输入目录不存在 - {input_dir}")
        return False
    
    # 创建输出目录
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"创建输出目录: {output_dir}")
    
    # 查找所有MP4文件
    mp4_pattern = os.path.join(input_dir, "*.mp4")
    mp4_files = glob.glob(mp4_pattern)
    
    if not mp4_files:
        print(f"在目录 {input_dir} 中没有找到MP4文件")
        return False
    
    print(f"找到 {len(mp4_files)} 个MP4文件")
    print("=" * 60)
    
    success_count = 0
    failed_count = 0
    
    # 逐个转换
    for i, mp4_file in enumerate(mp4_files, 1):
        filename = os.path.basename(mp4_file)
        name_without_ext = os.path.splitext(filename)[0]
        gif_filename = f"{name_without_ext}.gif"
        output_path = os.path.join(output_dir, gif_filename)
        
        print(f"[{i}/{len(mp4_files)}] 转换: {filename} -> {gif_filename}")
        
        success = convert_mp4_to_gif(mp4_file, output_path, fps_reduction, max_width)
        
        if success:
            success_count += 1
        else:
            failed_count += 1
        
        print("-" * 60)
    
    # 显示总结
    print(f"批量转换完成!")
    print(f"成功: {success_count} 个文件")
    print(f"失败: {failed_count} 个文件")
    print(f"总计: {len(mp4_files)} 个文件")
    
    return success_count > 0

if __name__ == "__main__":
    # 设置输入和输出目录
    input_directory = "frank/video"
    output_directory = "frank/gif"
    
    # 转换参数
    fps_reduction = 2    # 每2帧取1帧，减少GIF大小
    max_width = 360      # GIF最大宽度（像素）
    
    print(f"MP4转GIF批量转换工具")
    print(f"输入目录: {input_directory}")
    print(f"输出目录: {output_directory}")
    print(f"帧率缩减: 每{fps_reduction}帧取1帧")
    print(f"最大宽度: {max_width}px")
    print("=" * 60)
    
    # 执行批量转换
    success = batch_convert_mp4_to_gif(input_directory, output_directory, fps_reduction, max_width)
    
    if success:
        print("\n🎉 批量转换成功完成！")
        print(f"所有GIF文件已保存到: {output_directory}")
    else:
        print("\n❌ 批量转换失败！") 