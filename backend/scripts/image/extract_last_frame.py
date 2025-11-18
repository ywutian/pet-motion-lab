import cv2
import os

def extract_last_frame(video_path, output_path):
    """
    从视频中提取最后一帧并保存为PNG文件
    
    Args:
        video_path (str): 输入视频文件路径
        output_path (str): 输出PNG文件路径
    """
    # 检查视频文件是否存在
    if not os.path.exists(video_path):
        print(f"错误：视频文件不存在 - {video_path}")
        return False
    
    # 打开视频文件
    cap = cv2.VideoCapture(video_path)
    
    if not cap.isOpened():
        print(f"错误：无法打开视频文件 - {video_path}")
        return False
    
    # 获取视频总帧数
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    print(f"视频总帧数: {total_frames}")
    
    # 跳转到最后一帧
   # cap.set(cv2.CAP_PROP_POS_FRAMES, total_frames - 1)


    # 跳转到某帧 105
    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
    
    # 读取最后一帧
    ret, last_frame = cap.read()
    
    if ret:
        # 创建输出目录（如果不存在）
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        # 保存最后一帧为PNG文件
        success = cv2.imwrite(output_path, last_frame)
        
        if success:
            print(f"成功！最后一帧已保存到: {output_path}")
        else:
            print(f"错误：无法保存图片到 {output_path}")
    else:
        print("错误：无法读取最后一帧")
    
    # 释放视频文件
    cap.release()
    return ret

if __name__ == "__main__":
    # 设置输入视频路径和输出图片路径
    video_file = "frank/video/rest2sleep.mp4"
    output_file = "frank/image/sleep.png"
    
    print(f"开始提取视频最后一帧...")
    print(f"输入视频: {video_file}")
    print(f"输出图片: {output_file}")
    
    # 提取最后一帧
    extract_last_frame(video_file, output_file) 