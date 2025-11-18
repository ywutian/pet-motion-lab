import cv2
import os

def reverse_video(input_path, output_path):
    """
    将视频倒放
    
    Args:
        input_path (str): 输入视频文件路径
        output_path (str): 输出视频文件路径
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
    print(f"  视频时长: {total_frames/fps:.2f}秒")
    
    print(f"开始读取所有帧...")
    
    # 读取所有帧到内存中
    frames = []
    frame_count = 0
    
    while True:
        ret, frame = cap.read()
        
        if not ret:
            break
        
        frames.append(frame.copy())
        frame_count += 1
        
        # 显示读取进度
        if frame_count % 10 == 0 or frame_count == total_frames:
            progress = (frame_count / total_frames) * 100
            print(f"读取进度: {frame_count}/{total_frames} 帧 ({progress:.1f}%)")
    
    # 释放输入视频
    cap.release()
    
    print(f"成功读取 {len(frames)} 帧")
    print(f"开始生成倒放视频...")
    
    # 创建输出目录（如果不存在）
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # 设置视频编码器
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
    
    if not out.isOpened():
        print(f"错误：无法创建输出视频文件 - {output_path}")
        return False
    
    # 倒序写入帧
    written_frames = 0
    total_frames_to_write = len(frames)
    
    for i in range(len(frames) - 1, -1, -1):  # 从最后一帧开始，倒序遍历
        out.write(frames[i])
        written_frames += 1
        
        # 显示写入进度
        if written_frames % 10 == 0 or written_frames == total_frames_to_write:
            progress = (written_frames / total_frames_to_write) * 100
            print(f"写入进度: {written_frames}/{total_frames_to_write} 帧 ({progress:.1f}%) - 当前处理帧: {i}")
    
    # 释放输出视频
    out.release()
    
    print(f"成功！倒放视频已保存到: {output_path}")
    print(f"倒放视频包含 {written_frames} 帧")
    print(f"倒放视频时长: {written_frames/fps:.2f}秒")
    
    return True

if __name__ == "__main__":
    # 设置输入和输出路径
    input_video = "megan/rest-sleep.mp4"
    output_video = "megan/sleep-rest.mp4"
    
    print(f"开始倒放视频...")
    print(f"输入视频: {input_video}")
    print(f"输出视频: {output_video}")
    print("-" * 50)
    
    # 执行视频倒放
    success = reverse_video(input_video, output_video)
    
    if success:
        print("-" * 50)
        print("视频倒放完成！")
        print("现在视频将以相反的顺序播放，从结束画面到开始画面。")
    else:
        print("视频倒放失败！") 