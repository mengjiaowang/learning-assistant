import 'package:flutter/material.dart';
import 'dart:convert';
import 'book_detail_screen.dart';
import 'package:mistake_mentor/modules/word_buddy/services/word_buddy_api_service.dart';

class BookManagementScreen extends StatefulWidget {
  const BookManagementScreen({Key? key}) : super(key: key);

  @override
  State<BookManagementScreen> createState() => _BookManagementScreenState();
}

class _BookManagementScreenState extends State<BookManagementScreen> {
  final WordBuddyApiService wordBuddyApiService = WordBuddyApiService();
  List<dynamic> _books = [];
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  bool _isRecycleBin = false;

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  Future<void> _fetchBooks() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final books = _isRecycleBin 
          ? await wordBuddyApiService.getRecycleBin()
          : await wordBuddyApiService.getBooks();
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取单词本失败: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createBook() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final success = await wordBuddyApiService.createBook(name, []);
      if (success) {
        _nameController.clear();
        _fetchBooks();
        Navigator.of(context).pop(); // Close dialog
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建单词本失败: $e')),
      );
    }
  }

  Future<void> _deleteBook(String bookId) async {
    try {
      final success = await wordBuddyApiService.deleteBook(bookId);
      if (success) {
        _fetchBooks();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除单词本失败: $e')),
      );
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建新单词本'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: '单词本名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: _createBook,
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRecycleBin ? '回收站' : '单词本管理'),
        actions: [
          IconButton(
            icon: Icon(_isRecycleBin ? Icons.book : Icons.delete_outline),
            onPressed: () {
              setState(() {
                _isRecycleBin = !_isRecycleBin;
              });
              _fetchBooks();
            },
            tooltip: _isRecycleBin ? '返回书架' : '查看回收站',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
              ? const Center(child: Text('暂无单词本，点击右下角添加'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    final wordCount = book['word_count'] ?? 0;
                    
                    return GestureDetector(
                      onTap: () {
                        if (!_isRecycleBin) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookDetailScreen(book: book),
                            ),
                          );
                        }
                      },
                      child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isRecycleBin
                                ? [Colors.grey[400]!, Colors.grey[600]!]
                                : [Colors.teal[400]!, Colors.teal[700]!],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Book spine effect
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            // Content
                            Padding(
                              padding: const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    book['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$wordCount 单词',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '创建: ${book['created_at'] != null ? book['created_at'].toString().substring(0, 10) : "N/A"}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Delete/Restore buttons
                            Positioned(
                              right: 4,
                              top: 4,
                              child: _isRecycleBin
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.restore, color: Colors.white70, size: 20),
                                          onPressed: () => _restoreBook(book['id']),
                                          tooltip: '恢复',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_forever, color: Colors.white70, size: 20),
                                          onPressed: () => _permanentDeleteBook(book['id'], book['name']),
                                          tooltip: '彻底删除',
                                        ),
                                      ],
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.white70, size: 20),
                                      onPressed: () {
                                        // Confirm delete
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('删除单词本'),
                                            content: Text('确定要删除“${book['name']}”吗？这将删除其中所有的单词。'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                child: const Text('取消'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  _deleteBook(book['id']);
                                                },
                                                child: const Text('删除', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                ),
                
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _restoreBook(String bookId) async {
    try {
      final success = await wordBuddyApiService.restoreBook(bookId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复单词本')),
        );
        _fetchBooks();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败: $e')),
      );
    }
  }

  Future<void> _permanentDeleteBook(String bookId, String bookName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text('确定要永久删除“$bookName”吗？此操作不可逆！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              try {
                final success = await wordBuddyApiService.permanentDeleteBook(bookId);
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('已彻底删除单词本')),
                  );
                  _fetchBooks();
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('删除失败: $e')),
                );
              }
            },
            child: const Text('彻底删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
