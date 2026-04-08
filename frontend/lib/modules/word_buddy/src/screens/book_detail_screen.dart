import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main_layout.dart'; // For reviewFilterProvider and navigationProvider

class BookDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> book;

  const BookDetailScreen({Key? key, required this.book}) : super(key: key);

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  List<dynamic> _hierarchy = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHierarchy();
  }

  Future<void> _fetchHierarchy() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/api/books/${widget.book['id']}/hierarchy'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _hierarchy = data['hierarchy'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取层级失败: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book['name']),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hierarchy.isEmpty
              ? const Center(child: Text('暂无子层级'))
              : ListView.builder(
                  itemCount: _hierarchy.length,
                  itemBuilder: (context, index) {
                    final item = _hierarchy[index];
                    return ListTile(
                      title: Text(item['name']),
                      trailing: Text('${item['word_count']} 单词'),
                      onTap: () {
                        // Update filter and navigate
                        ref.read(reviewFilterProvider.notifier).state = ReviewFilter(
                          bookId: widget.book['id'],
                          path: item['name'],
                        );
                        ref.read(navigationProvider.notifier).state = 0; // Go to Review
                        Navigator.pop(context); // Return to main layout which now shows Review
                      },
                    );
                  },
                ),
    );
  }
}
