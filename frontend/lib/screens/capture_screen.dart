import 'dart:io';
import 'dart:typed_data';


import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/api_service.dart';

import '../main.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({Key? key}) : super(key: key);

  @override
  _CaptureScreenState createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isUploading = false;
  int _cameraIndex = 0;
  bool _isMirrored = false; // 新增：是否开启镜像翻转
  int _rotationTurns = 0;   // 新增：旋转四分位角 (0, 1, 2, 3 -> 0, 90, 180, 270度)

  // 新增：保存拍摄后的冷冻帧数据
  Uint8List? _capturedImageBytes;

  String? _capturedImageName;

  @override
  void initState() {
    super.initState();
    _findBackCamera();
    _initController();
  }

  void _findBackCamera() {
    if (cameras.isEmpty) return;
    int index = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    // 找到后置则使用后置，否则默认第一个
    _cameraIndex = index >= 0 ? index : 0;
  }

  void _initController() {
    if (cameras.isEmpty) return;
    _controller = CameraController(
      cameras[_cameraIndex],
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  Future<void> _toggleCamera() async {
    if (cameras.length <= 1) return;
    
    await _controller.dispose();
    setState(() {
      _cameraIndex = (_cameraIndex + 1) % cameras.length;
      _initController();
    });
  }

  @override
  void dispose() {
    if (cameras.isNotEmpty) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      
      final XFile image = await _controller.takePicture();
      final bytes = await image.readAsBytes();
      
      setState(() {
        _capturedImageBytes = bytes;
        _capturedImageName = image.name;
      });


    } catch (e) {
      print('Take picture error: $e');
    }
  }

  Future<void> _confirmUpload() async {
    if (_capturedImageBytes == null) return;
    
    try {
      setState(() => _isUploading = true);
      
      final success = await apiService.uploadQuestion(
        _capturedImageBytes!, 
        _capturedImageName ?? "original.jpg",
        mirror: _isMirrored,
        rotateDegrees: _rotationTurns * 90,
      );
      
      setState(() => _isUploading = false);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 错题上传并解析成功！已同步至云端。')),
          );
          Navigator.pop(context, true); // 成功后返回
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('❌ 上传失败，请检查网络或配置')),
           );
        }
      }
    } catch (e) {
      print('Upload error: $e');
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照录入错题'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isMirrored ? Icons.flip : Icons.flip_outlined, 
              color: _isMirrored ? Colors.orange : Colors.white
            ),
            tooltip: '镜像翻转 (纠正倒影)',
            onPressed: () {
              setState(() {
                _isMirrored = !_isMirrored;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            tooltip: '顺时针顺延90度',
            onPressed: () {
              setState(() {
                _rotationTurns = (_rotationTurns + 1) % 4;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            tooltip: '切换摄像头',
            onPressed: _isUploading ? null : _toggleCamera,
          )
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // 核心：始终保持 CameraPreview 在底层，避免 Web 卸载导致黑屏
                Positioned.fill(
                  child: RotatedBox(
                    quarterTurns: _rotationTurns,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(_isMirrored ? 3.1415926535897932 : 0),
                      child: CameraPreview(_controller),
                    ),
                  ),
                ),
                // 若已拍照，静态图片覆盖在上面
                if (_capturedImageBytes != null)
                  Positioned.fill(
                    child: RotatedBox(
                      quarterTurns: _rotationTurns,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(_isMirrored ? 3.1415926535897932 : 0),
                        child: Image.memory(
                          _capturedImageBytes!, 
                          width: double.infinity, 
                          height: double.infinity, 
                          fit: BoxFit.cover
                        ),
                      ),
                    ),
                  ),
                if (_isUploading)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpinKitCubeGrid(color: Colors.white, size: 40),
                          SizedBox(height: 16),
                          Text('正在由 AI 处理及解析...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _capturedImageBytes == null
          ? FloatingActionButton(
              onPressed: _isUploading ? null : _takePicture,
              backgroundColor: Colors.white,
              child: const Icon(Icons.camera_alt, color: Colors.indigo, size: 30),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton(
                    heroTag: 'retake',
                    onPressed: _isUploading
                        ? null
                        : () {
                            setState(() {
                              _capturedImageBytes = null; // 撤销冷冻，回到相机

                            });
                          },
                    backgroundColor: Colors.red[400],
                    child: const Icon(Icons.refresh, color: Colors.white),
                  ),
                  FloatingActionButton(
                    heroTag: 'upload',
                    onPressed: _isUploading ? null : _confirmUpload,
                    backgroundColor: Colors.green[400],
                    child: const Icon(Icons.cloud_upload, color: Colors.white),
                  ),
                ],
              ),
            ),
    );
  }
}


