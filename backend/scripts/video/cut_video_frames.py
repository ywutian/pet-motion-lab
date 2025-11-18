import cv2
import os

def cut_video_by_frames(input_path, output_path, start_frame, end_frame):
    """
    根据起始帧和终止帧剪切视频
    
    Args:
        input_path (str): 输入视频文件路径
        output_path (str): 输出视频文件路径
        start_frame (int): 起始帧（从0开始计数）
        end_frame (int): 终止帧（包含该帧）
    """
    # 检查输入视频文件是否存在
    if not os.path.exists(input_path):
        print(f"错误：视频文件不存在 - {input_path}")
        return False
    
    # 验证帧数参数
    if start_frame < 0:
        print(f"错误：起始帧不能小于0")
        return False
    
    if end_frame <= start_frame:
        print(f"错误：终止帧({end_frame})必须大于起始帧({start_frame})")
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
    
    # 验证帧数范围
    if start_frame >= total_frames:
        print(f"错误：起始帧({start_frame})超出视频范围(0-{total_frames-1})")
        cap.release()
        return False
    
    # 调整终止帧，不能超出视频范围
    actual_end_frame = min(end_frame, total_frames - 1)
    if actual_end_frame != end_frame:
        print(f"警告：终止帧已调整为 {actual_end_frame}（原视频最大帧数为 {total_frames-1}）")
    
    frames_to_extract = actual_end_frame - start_frame + 1
    
    print(f"剪切设置:")
    print(f"  起始帧: {start_frame}")
    print(f"  终止帧: {actual_end_frame}")
    print(f"  提取帧数: {frames_to_extract}")
    print(f"  剪切片段时长: {frames_to_extract/fps:.2f}秒")
    print(f"  起始时间: {start_frame/fps:.2f}秒")
    print(f"  结束时间: {(actual_end_frame+1)/fps:.2f}秒")
    
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
    
    # 跳转到起始帧
    cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)
    
    # 读取并写入指定范围的帧
    frame_count = 0
    current_frame = start_frame
    
    while current_frame <= actual_end_frame:
        ret, frame = cap.read()
        
        if not ret:
            print(f"警告：在第 {current_frame} 帧处读取失败")
            break
        
        out.write(frame)
        frame_count += 1
        current_frame += 1
        
        # 显示进度
        if frame_count % 10 == 0 or current_frame > actual_end_frame:
            progress = (frame_count / frames_to_extract) * 100
            print(f"处理进度: {frame_count}/{frames_to_extract} 帧 ({progress:.1f}%) - 当前帧: {current_frame-1}")
    
    # 释放资源
    cap.release()
    out.release()
    
    print(f"成功！剪切后的视频已保存到: {output_path}")
    print(f"新视频包含 {frame_count} 帧")
    
    return True

if __name__ == "__main__":
    # 设置输入和输出路径
    input_video = "megan/bak/sit-sleep-bak.mp4"
    output_video = "megan/rest-sleep.mp4"
    
    # 设置起始帧和终止帧（可以根据需要修改这些值）
    start_frame = 75    # 起始帧（从0开始计数）
    end_frame = 110     # 终止帧（包含该帧）
    
    print(f"开始剪切视频...")
    print(f"输入视频: {input_video}")
    print(f"输出视频: {output_video}")
    print(f"起始帧: {start_frame}")
    print(f"终止帧: {end_frame}")
    print("-" * 50)
    
    # 执行视频剪切
    success = cut_video_by_frames(input_video, output_video, start_frame, end_frame)
    
    if success:
        print("-" * 50)
        print("视频剪切完成！")
    else:
        print("视频剪切失败！") 