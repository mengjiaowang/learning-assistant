import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_layout.dart'; // For reviewFilterProvider

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<dynamic> _words = [];
  final Set<int> _flippedIndices = {};
  bool _isLoading = true;
  List<dynamic> _books = [];
  String? _selectedBookId;
  String? _selectedPath;
  List<String> _paths = [];
  int? _selectedWordIndex;


  @override
  void initState() {
    super.initState();
    _fetchBooks();
    
    // Read initial filter from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filter = ref.read(reviewFilterProvider);
      if (filter.bookId != null) {
        setState(() {
          _selectedBookId = filter.bookId;
          _selectedPath = filter.path;
        });
        _fetchPaths(filter.bookId!);
        _fetchReviewWords();
      } else {
        _fetchReviewWords();
      }
    });
  }

  Future<void> _fetchBooks() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8001/api/books'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _books = data['books'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching books: $e');
    }
  }

  Future<void> _fetchPaths(String bookId) async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8001/api/books/$bookId/hierarchy'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hierarchy = data['hierarchy'] ?? [];
        setState(() {
          _paths = hierarchy.map<String>((item) => item['name'].toString()).toList();
        });
      }
    } catch (e) {
      print('Error fetching paths: $e');
    }
  }

  Future<void> _fetchReviewWords() async {
    setState(() {
      _isLoading = true;
    });
    try {
      String url = 'http://localhost:8001/api/review';
      List<String> params = [];
      if (_selectedBookId != null) {
        params.add('book_id=$_selectedBookId');
      }
      if (_selectedPath != null) {
        params.add('path=$_selectedPath');
      }
      if (params.isNotEmpty) {
        url += '?' + params.join('&');
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _words = data['words'] ?? [];
          _isLoading = false;
          _flippedIndices.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取复习单词失败: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitResult(int index, bool correct) async {
    if (index >= _words.length) return;
    final currentWord = _words[index]['word'];

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8001/api/review/$currentWord'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'correct': correct}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _words[index]['isDone'] = true;
          _flippedIndices.remove(index);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交结果失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeWords = _words.where((w) => w['isDone'] != true).toList();

    if (_words.isEmpty || activeWords.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _words.isEmpty 
                  ? '词库空空如也，快去“录入”页面添加单词吧！' 
                  : '太棒了！你已经看完了词库里的所有单词！',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    for (var w in _words) {
                      w['isDone'] = false;
                    }
                    _flippedIndices.clear();
                  });
                  _fetchReviewWords();
                },
                child: Text(_words.isEmpty ? '重新检查' : '再来一遍'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('单词复习'),
        actions: [
          if (_books.isNotEmpty) ...[
            DropdownButton<String?>(
              value: _selectedBookId,
              dropdownColor: Colors.teal[50],
              hint: const Text('全部单词本'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('全部单词本'),
                ),
                ..._books.map<DropdownMenuItem<String?>>((book) {
                  return DropdownMenuItem<String?>(
                    value: book['id'],
                    child: Text(book['name']),
                  );
                }).toList(),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBookId = newValue;
                  _selectedPath = null;
                  _paths = [];
                  _flippedIndices.clear();
                });
                if (newValue != null) {
                  _fetchPaths(newValue);
                }
                _fetchReviewWords();
              },
            ),
            const SizedBox(width: 16),
            if (_selectedBookId != null && _paths.isNotEmpty)
              DropdownButton<String?>(
                value: _selectedPath,
                dropdownColor: Colors.teal[50],
                hint: const Text('全部层级'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部层级'),
                  ),
                  ..._paths.map<DropdownMenuItem<String?>>((path) {
                    return DropdownMenuItem<String?>(
                      value: path,
                      child: Text(path),
                    );
                  }).toList(),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPath = newValue;
                    _flippedIndices.clear();
                  });
                  _fetchReviewWords();
                },
              ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: _selectedWordIndex != null
          ? _buildDetailView(activeWords)
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(

          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 350,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: activeWords.length,
          itemBuilder: (context, index) {
            final wordData = activeWords[index];
            final word = wordData['word'];

            return GestureDetector(

              onTap: () {
                setState(() {
                  _selectedWordIndex = index;
                });
              },

              child: Card(
                elevation: 8,
                shadowColor: Colors.teal.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.teal[50]!, Colors.white],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (wordData['path'] != null && (wordData['path'] as List).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              (wordData['path'] as List).join(' > '),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        Text(
                          word,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击查看详情',
                          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailView(List<dynamic> activeWords) {
    if (_selectedWordIndex == null || _selectedWordIndex! >= activeWords.length) {
      return const Center(child: Text('无选择的单词'));
    }
    final wordData = activeWords[_selectedWordIndex!];
    final word = wordData['word'];
    final details = wordData['details'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedWordIndex = null;
                  });
                },
              ),
              Text(
                '${_selectedWordIndex! + 1} / ${activeWords.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const Divider(),
          Expanded(
            child: details != null
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            word,
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (details['phonetics'] != null && (details['phonetics'] as Map)['uk'] != null)
                                Text('英: [${(details['phonetics'] as Map)['uk']}]  ', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                              if (details['phonetics'] != null && (details['phonetics'] as Map)['us'] != null)
                                Text('美: [${(details['phonetics'] as Map)['us']}]', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        const Divider(height: 24, thickness: 1),
                        
                        if (details['forms'] != null && (details['forms'] as Map).isNotEmpty) ...[
                          const Text('形态变化', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            children: [
                              if ((details['forms'] as Map)['past_tense'] != null)
                                Text('过去式: ${(details['forms'] as Map)['past_tense']}', style: const TextStyle(fontSize: 14)),
                              if ((details['forms'] as Map)['past_participle'] != null)
                                Text('过去分词: ${(details['forms'] as Map)['past_participle']}', style: const TextStyle(fontSize: 14)),
                              if ((details['forms'] as Map)['plural'] != null)
                                Text('复数: ${(details['forms'] as Map)['plural']}', style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        const Text('释义', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(height: 8),
                        ...?(details['explanations'] as List?)?.map((exp) {
                              final map = exp as Map?;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• [${map?['part_of_speech']}] ${map?['meaning_en']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    Text('  中文: ${map?['meaning_zh']}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                                  ],
                                ),
                              );
                            }),
                        const SizedBox(height: 16),

                        if (details['synonyms'] != null && (details['synonyms'] as List).isNotEmpty) ...[
                          Text('同义词: ${(details['synonyms'] as List).join(', ')}', style: const TextStyle(fontSize: 14, color: Colors.blue)),
                          const SizedBox(height: 4),
                        ],
                        if (details['antonyms'] != null && (details['antonyms'] as List).isNotEmpty) ...[
                          Text('反义词: ${(details['antonyms'] as List).join(', ')}', style: const TextStyle(fontSize: 14, color: Colors.red)),
                          const SizedBox(height: 16),
                        ],
                        
                        const Text('智能例句', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(height: 8),
                        ...?(details['sentences'] as List?)?.map((s) {
                              final map = s as Map?;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50]!.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(map?['en'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                      Text(map?['zh'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                      ],
                    ),
                  )
                : const Center(child: Text('无详情数据')),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _selectedWordIndex! > 0
                    ? () {
                        setState(() {
                          _selectedWordIndex = _selectedWordIndex! - 1;
                        });
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 32),
                onPressed: () {
                  final originalIndex = _words.indexOf(activeWords[_selectedWordIndex!]);
                  _submitResult(originalIndex, false);
                  
                  if (_selectedWordIndex! < activeWords.length - 1) {
                    setState(() {
                      // Stay on same index, points to next item
                    });
                  } else {
                    setState(() {
                      _selectedWordIndex = null;
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green, size: 32),
                onPressed: () {
                  final originalIndex = _words.indexOf(activeWords[_selectedWordIndex!]);
                  _submitResult(originalIndex, true);
                  
                  if (_selectedWordIndex! < activeWords.length - 1) {
                    setState(() {
                      // Stay on same index, points to next item
                    });
                  } else {
                    setState(() {
                      _selectedWordIndex = null;
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _selectedWordIndex! < activeWords.length - 1
                    ? () {
                        setState(() {
                          _selectedWordIndex = _selectedWordIndex! + 1;
                        });
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

