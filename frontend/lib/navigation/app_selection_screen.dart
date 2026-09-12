import 'package:flutter/material.dart';
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MainNavigationShell()),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildAppCard(
                    title: '单词助手',
                    icon: Icons.spellcheck,
                    color: Colors.tealAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProviderScope(child: MainLayout())),
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

