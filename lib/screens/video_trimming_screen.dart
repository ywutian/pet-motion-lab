import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/video_trimming_service.dart';
import '../theme/app_spacing.dart';
import '../utils/responsive_helper.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoTrimmingScreen extends StatefulWidget {
  const VideoTrimmingScreen({super.key});

  @override
  State<VideoTrimmingScreen> createState() => _VideoTrimmingScreenState();
}

class _VideoTrimmingScreenState extends State<VideoTrimmingScreen> {
  File? _selectedVideo;
  VideoInfo? _videoInfo;
  bool _isLoading = false;
  bool _isTrimming = false;
  File? _trimmedVideo;

  // 提取帧的加载状态
  bool _isExtractingFirstFrame = false;
  bool _isExtractingLastFrame = false;

  // 使用时间而不是帧数
  double _startTime = 0.0; // 秒
  double _endTime = 0.0;   // 秒

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      
      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
          _videoInfo = null;
          _trimmedVideo = null;
          _startTime = 0.0;
          _endTime = 0.0;
          _isLoading = true;
        });

        // 获取视频信息
        try {
          final info = await VideoTrimmingService.getVideoInfo(_selectedVideo!);
          setState(() {
            _videoInfo = info;
            _endTime = info.duration;
            _isLoading = false;
          });
        } catch (e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('获取视频信息失败: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择视频失败: $e')),
        );
      }
    }
  }

  Future<void> _trimVideo() async {
    if (_selectedVideo == null || _videoInfo == null) return;

    setState(() => _isTrimming = true);

    try {
      // 将时间转换为帧数
      final startFrame = (_startTime * _videoInfo!.fps).round();
      final endFrame = (_endTime * _videoInfo!.fps).round();

      final trimmedFile = await VideoTrimmingService.trimVideo(
        videoFile: _selectedVideo!,
        startFrame: startFrame,
        endFrame: endFrame,
      );

      setState(() {
        _trimmedVideo = trimmedFile;
        _isTrimming = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 视频裁剪成功！点击"保存到相册"按钮保存')),
        );
      }
    } catch (e) {
      setState(() => _isTrimming = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('裁剪失败: $e')),
        );
      }
    }
  }

  Future<void> _saveVideo() async {
    if (_trimmedVideo == null) return;

    try {
      // 请求存储权限
      print('📱 请求存储权限...');
      PermissionStatus status;

      if (Platform.isAndroid) {
        // Android 13+ 需要 photos 权限
        if (await Permission.photos.isGranted) {
          status = PermissionStatus.granted;
        } else {
          status = await Permission.photos.request();
        }

        // 如果 photos 权限被拒绝，尝试 storage 权限（Android 12 及以下）
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ 需要存储权限才能保存视频')),
          );
        }
        return;
      }

      print('✅ 权限已授予');
      print('📁 视频路径: ${_trimmedVideo!.path}');
      print('📊 文件大小: ${await _trimmedVideo!.length()} 字节');

      // 保存到相册
      print('💾 开始保存到相册...');
      await Gal.putVideo(_trimmedVideo!.path);
      print('✅ 保存成功！');

      // 删除临时文件
      try {
        if (await _trimmedVideo!.exists()) {
          await _trimmedVideo!.delete();
          print('🗑️ 已删除临时文件: ${_trimmedVideo!.path}');
        }
      } catch (e) {
        print('⚠️ 删除临时文件失败: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 视频已保存到相册！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // 清空状态
        setState(() {
          _trimmedVideo = null;
        });
      }
    } catch (e) {
      print('❌ 保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _extractFirstFrame() async {
    if (_selectedVideo == null) return;

    setState(() => _isExtractingFirstFrame = true);

    try {
      final frameFile = await VideoTrimmingService.extractFrame(
        videoFile: _selectedVideo!,
        frameType: 'first',
      );

      // 直接保存到相册
      await _saveFrameDirectly(frameFile, '首帧');

      setState(() => _isExtractingFirstFrame = false);
    } catch (e) {
      setState(() => _isExtractingFirstFrame = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 提取首帧失败: $e')),
        );
      }
    }
  }

  Future<void> _extractLastFrame() async {
    if (_selectedVideo == null) return;

    setState(() => _isExtractingLastFrame = true);

    try {
      final frameFile = await VideoTrimmingService.extractFrame(
        videoFile: _selectedVideo!,
        frameType: 'last',
      );

      // 直接保存到相册
      await _saveFrameDirectly(frameFile, '尾帧');

      setState(() => _isExtractingLastFrame = false);
    } catch (e) {
      setState(() => _isExtractingLastFrame = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 提取尾帧失败: $e')),
        );
      }
    }
  }

  // 直接保存帧到相册（不显示预览）
  Future<void> _saveFrameDirectly(File frameFile, String frameName) async {
    try {
      // 请求权限
      PermissionStatus status;
      if (Platform.isAndroid) {
        if (await Permission.photos.isGranted) {
          status = PermissionStatus.granted;
        } else {
          status = await Permission.photos.request();
        }
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ 需要存储权限才能保存图片')),
          );
        }
        // 删除临时文件
        if (await frameFile.exists()) {
          await frameFile.delete();
        }
        return;
      }

      // 保存到相册
      await Gal.putImage(frameFile.path);

      // 删除临时文件
      if (await frameFile.exists()) {
        await frameFile.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $frameName已保存到相册！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ 保存图片失败: $e');
      // 删除临时文件
      try {
        if (await frameFile.exists()) {
          await frameFile.delete();
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 保存图片失败: $e')),
        );
      }
    }
  }



  @override
  void dispose() {
    // 清理临时视频文件
    if (_trimmedVideo != null) {
      _trimmedVideo!.delete().catchError((e) {
        print('⚠️ 清理临时文件失败: $e');
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频裁剪'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 选择视频按钮
            ElevatedButton.icon(
              onPressed: _isLoading || _isTrimming ? null : _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('选择视频'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            if (_isLoading) ...[
              AppSpacing.vGapLG,
              const Center(child: CircularProgressIndicator()),
              AppSpacing.vGapSM,
              const Center(child: Text('正在获取视频信息...')),
            ],

            // 视频信息
            if (_videoInfo != null) ...[
              AppSpacing.vGapLG,
              _buildVideoInfoCard(),
              AppSpacing.vGapLG,
              _buildTrimControls(),
              AppSpacing.vGapLG,
              _buildTrimButton(),
            ],

            // 裁剪结果
            if (_trimmedVideo != null) ...[
              AppSpacing.vGapLG,
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoInfoCard() {
    final info = _videoInfo!;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                AppSpacing.hGapSM,
                Text(
                  '视频信息',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            AppSpacing.vGapMD,
            _buildInfoRow('分辨率', '${info.width} x ${info.height}'),
            _buildInfoRow('帧率', '${info.fps.toStringAsFixed(2)} FPS'),
            _buildInfoRow('总帧数', '${info.totalFrames} 帧'),
            _buildInfoRow('时长', info.durationFormatted),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTrimControls() {
    final info = _videoInfo!;
    final duration = info.duration;

    // 计算 divisions，确保至少为 1
    final divisions = (duration * 10).toInt().clamp(1, 10000);

    return Card(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.content_cut, color: Colors.orange),
                AppSpacing.hGapSM,
                Text(
                  '裁剪设置',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 22,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            AppSpacing.vGapMD,

            // 起始时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('起始时间:', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  _formatTime(_startTime),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            Slider(
              value: _startTime,
              min: 0,
              max: duration,
              divisions: divisions,
              label: _formatTime(_startTime),
              onChanged: (value) {
                setState(() {
                  _startTime = value;
                  if (_startTime > _endTime) {
                    _endTime = _startTime;
                  }
                });
              },
            ),

            AppSpacing.vGapSM,

            // 结束时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('结束时间:', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  _formatTime(_endTime),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            Slider(
              value: _endTime,
              min: 0,
              max: duration,
              divisions: divisions,
              label: _formatTime(_endTime),
              onChanged: (value) {
                setState(() {
                  _endTime = value;
                  if (_endTime < _startTime) {
                    _startTime = _endTime;
                  }
                });
              },
            ),

            AppSpacing.vGapMD,

            // 快捷按钮
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickButton('前3秒', () {
                  setState(() {
                    _startTime = 0;
                    _endTime = duration > 3 ? 3 : duration;
                  });
                }),
                _buildQuickButton('后3秒', () {
                  setState(() {
                    _startTime = duration > 3 ? duration - 3 : 0;
                    _endTime = duration;
                  });
                }),
                _buildQuickButton('中间部分', () {
                  setState(() {
                    _startTime = duration * 0.25;
                    _endTime = duration * 0.75;
                  });
                }),
                _buildQuickButton('全部', () {
                  setState(() {
                    _startTime = 0;
                    _endTime = duration;
                  });
                }),
              ],
            ),

            AppSpacing.vGapMD,

            // 裁剪后信息
            Container(
              padding: AppSpacing.paddingMD,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '裁剪后:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.vGapSM,
                  Text('时长: ${_formatTime(_endTime - _startTime)}'),
                  Text('帧数: ${((_endTime - _startTime) * info.fps).round()} 帧'),
                  Text('占比: ${((_endTime - _startTime) / duration * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 0),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    final millis = ((seconds % 1) * 10).floor();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${millis}';
  }

  Widget _buildTrimButton() {
    return Column(
      children: [
        // 裁剪视频按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isTrimming ? null : _trimVideo,
            icon: _isTrimming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cut),
            label: Text(_isTrimming ? '裁剪中...' : '开始裁剪'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ),

        AppSpacing.vGapMD,

        // 提取帧按钮
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExtractingFirstFrame ? null : _extractFirstFrame,
                icon: _isExtractingFirstFrame
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image, size: 20),
                label: Text(
                  _isExtractingFirstFrame ? '提取中...' : '保存首帧',
                  style: const TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            AppSpacing.hGapSM,
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExtractingLastFrame ? null : _extractLastFrame,
                icon: _isExtractingLastFrame
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image, size: 20),
                label: Text(
                  _isExtractingLastFrame ? '提取中...' : '保存尾帧',
                  style: const TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    return Column(
      children: [
        // 裁剪完成的视频
        if (_trimmedVideo != null)
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: AppSpacing.paddingLG,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      AppSpacing.hGapSM,
                      Text(
                        '裁剪完成',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(
                            context,
                            mobile: 18,
                            tablet: 20,
                            desktop: 22,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapMD,
                  const Text('视频已成功裁剪！'),
                  AppSpacing.vGapMD,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveVideo,
                      icon: const Icon(Icons.save),
                      label: const Text('保存视频到相册'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),


      ],
    );
  }
}
