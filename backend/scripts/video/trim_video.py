import cv2
import os

def trim_video_to_frames(input_path, output_path, max_frames):
    """
    保留视频的前N帧，去掉后半段
    
    Args:
        input_path (str): 输入视频文件路径
        output_path (str): 输出视频文件路径
        max_frames (int): 要保留的帧数
    """
    # 检查输入视频文件是否存在
    if not os.path.exists(input_path):
        print(f"错误：视频文件不存在 - {input_path}")
        return False
    
    # 打开输入视频
    cap = cv2.VideoCapture(input_path)
    
    if not cap.isOpened():
        print(f"错误：无法打开视频文件 - {input_path}")
        return False
    
    # 获取视频属性
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    print(f"原视频信息:")
    print(f"  分辨率: {width}x{height}")
    print(f"  帧率: {fps:.2f} FPS")
    print(f"  总帧数: {total_frames}")
    print(f"  原视频时长: {total_frames/fps:.2f}秒")
    
    # 确保要保留的帧数不超过总帧数
    frames_to_keep = min(max_frames, total_frames)
    print(f"将保留前 {frames_to_keep} 帧")
    print(f"新视频时长: {frames_to_keep/fps:.2f}秒")
    
    # 创建输出目录（如果不存在）
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # 设置视频编码器
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
    
    if not out.isOpened():
        print(f"错误：无法创建输出视频文件 - {output_path}")
        cap.release()
        return False
    
    # 读取并写入前N帧
    frame_count = 0
    while frame_count < frames_to_keep:
        ret, frame = cap.read()
        
        if not ret:
            print(f"警告：只读取到 {frame_count} 帧")
            break
        
        out.write(frame)
        frame_count += 1
        
        # 显示进度
        if frame_count % 10 == 0 or frame_count == frames_to_keep:
            progress = (frame_count / frames_to_keep) * 100
            print(f"处理进度: {frame_count}/{frames_to_keep} 帧 ({progress:.1f}%)")
    
    # 释放资源
    cap.release()
    out.release()
    
    print(f"成功！裁剪后的视频已保存到: {output_path}")
    print(f"新视频包含 {frame_count} 帧")
    
    return True

if __name__ == "__main__":
    # 设置输入和输出路径
    input_video = "frank/video/sit2walk_bak.mp4"
    output_video = "frank/video/sit2walk.mp4"
    target_frames = 123
    
    print(f"开始裁剪视频...")
    print(f"输入视频: {input_video}")
    print(f"输出视频: {output_video}")
    print(f"保留帧数: {target_frames}")
    print("-" * 50)
    
    # 执行视频裁剪
    success = trim_video_to_frames(input_video, output_video, target_frames)
    
    if success:
        print("-" * 50)
        print("视频裁剪完成！")
    else:
        print("视频裁剪失败！") 