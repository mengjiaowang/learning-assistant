import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../main.dart'; // 引入 MainNavigationShell

// 单词助手的首页
import '../modules/word_buddy/src/screens/main_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({Key? key}) : super(key: key);

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  // 定义应用的健康检查 URL
  // 在实际生产中，这些应该从配置文件或环境变量中读取
  final Map<String, String> _healthUrls = {
    'mistake_mentor': kDebugMode ? 'http://127.0.0.1:8000/health' : 'https://mistake-mentor-backend-url/health',
    'word_buddy': kDebugMode ? 'http://127.0.0.1:8001/health' : 'https://word-buddy-backend-url/health',
  };

  Future<void> _checkHealthAndNavigate(String appName, Widget targetScreen) async {
    final healthUrl = _healthUrls[appName];
    if (healthUrl == null) return;

    // 显示等待页面
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ColdStartWaitingDialog(
          appName: appName,
          healthUrl: healthUrl,
          onSuccess: () {
            Navigator.pop(context); // 关闭对话框
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => targetScreen),
            );
          },
          onTimeout: () {
            Navigator.pop(context); // 关闭对话框
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('服务启动超时，请稍后重试')),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '请选择应用',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAppCard(
                    title: '错题本',
                    icon: Icons.book,
                    color: Colors.orangeAccent,
                    onTap: () {
                      _checkHealthAndNavigate(
                        'mistake_mentor',
                        const MainNavigationShell(),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildAppCard(
                    title: '单词助手',
                    icon: Icons.spellcheck,
                    color: Colors.tealAccent,
                    onTap: () {
                      _checkHealthAndNavigate(
                        'word_buddy',
                        const ProviderScope(child: MainLayout()),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildAppCard(
                    title: '英文写作辅助\n(敬请期待)',
                    icon: Icons.edit,
                    color: Colors.grey,
                    onTap: null, // 禁用
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: onTap == null ? Colors.grey[300] : Theme.of(context).cardColor,
        child: Container(
          width: 180,
          height: 180,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 70, color: onTap == null ? Colors.grey : color),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onTap == null ? Colors.grey : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColdStartWaitingDialog extends StatefulWidget {
  final String appName;
  final String healthUrl;
  final VoidCallback onSuccess;
  final VoidCallback onTimeout;

  const _ColdStartWaitingDialog({
    Key? key,
    required this.appName,
    required this.healthUrl,
    required this.onSuccess,
    required this.onTimeout,
  }) : super(key: key);

  @override
  State<_ColdStartWaitingDialog> createState() => _ColdStartWaitingDialogState();
}

class _ColdStartWaitingDialogState extends State<_ColdStartWaitingDialog> {
  Timer? _timer;
  int _secondsElapsed = 0;
  final int _timeoutSeconds = 30;
  final Dio _dio = Dio();
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      setState(() {
        _secondsElapsed += 2;
      });

      if (_secondsElapsed >= _timeoutSeconds) {
        timer.cancel();
        widget.onTimeout();
        return;
      }

      if (_isChecking) return;

      _isChecking = true;
      try {
        final response = await _dio.get(widget.healthUrl);
        if (response.statusCode == 200) {
          timer.cancel();
          widget.onSuccess();
        }
      } catch (e) {
        // 忽略错误，继续轮询
        if (kDebugMode) {
          print('Health check failed, retrying... $e');
        }
      } finally {
        _isChecking = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在唤醒服务'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('正在努力加载 [${widget.appName}]，请稍候...'),
          const SizedBox(height: 10),
          Text('已等待: $_secondsElapsed 秒 (超时时间: $_timeoutSeconds 秒)'),
        ],
      ),
    );
  }
}
