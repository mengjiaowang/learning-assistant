import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/api/stats'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _stats = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取统计数据失败: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_stats == null) {
      return const Scaffold(body: Center(child: Text('加载失败')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('学习统计')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('我的成就', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            // Grid of stats
            Row(
              children: [
                _buildStatCard('总词数', _stats!['total_words'].toString(), Colors.blue[300]!),
                const SizedBox(width: 16),
                _buildStatCard('已掌握', _stats!['mastered_words'].toString(), Colors.green[300]!),
                const SizedBox(width: 16),
                _buildStatCard('坚持天数', _stats!['streak_days'].toString(), Colors.orange[300]!),
              ],
            ),
            const SizedBox(height: 48),
            const Text('本周活跃度', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            // Weekly activity bar chart (simple)
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final count = (_stats!['weekly_activity'] as List)[index];
                  return _buildBar(count, ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][index]);
                }),
              ),
            ),
            const SizedBox(height: 48),
            _buildHeatmap(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, color: Colors.white)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(int count, String label) {
    final double height = (count / 15.0) * 150.0; // Assume max count is 15 for scaling
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(count.toString(), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: height.clamp(5, 150), // Min height 5
          decoration: BoxDecoration(
            color: Colors.teal[300],
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildHeatmap() {
    final dailyActivity = _stats!['daily_activity'] as Map<String, dynamic>? ?? {};
    
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 90));
    
    List<Widget> squares = [];
    for (int i = 0; i <= 90; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final count = dailyActivity[dateStr] ?? 0;
      
      Color color = Colors.grey[200]!;
      if (count > 0 && count <= 3) color = Colors.green[100]!;
      else if (count > 3 && count <= 6) color = Colors.green[300]!;
      else if (count > 6 && count <= 9) color = Colors.green[500]!;
      else if (count > 9) color = Colors.green[700]!;
      
      squares.add(
        Tooltip(
          message: "$dateStr: $count 次复习",
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('过去 90 天活跃度', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: squares,
        ),
      ],
    );
  }
}
