import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/word_buddy_api_service.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({Key? key}) : super(key: key);

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _wordDetails;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _searchWord() async {
    final word = _searchController.text.trim();
    if (word.isEmpty) return;

    setState(() {
      _isLoading = true;
      _wordDetails = null;
      _errorMessage = null;
    });

    try {
      final data = await wordBuddyApiService.getWordDetails(word);
      if (data != null) {
        if (data.containsKey('details')) {
          final detailsStr = data['details'];
          try {
            final details = json.decode(detailsStr);
            setState(() {
              _wordDetails = details;
            });
          } catch (e) {
            setState(() {
              _wordDetails = {
                'word': word,
                'meaning': '解析失败，原始输出：',
                'etymology': detailsStr,
              };
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = '请求失败，请检查网络或登录状态';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '发生错误: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('单词学习')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '输入要学习的单词...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _searchWord,
                  icon: const Icon(Icons.search),
                  label: const Text('学习'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Loading Indicator
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            // Result Display
            else if (_wordDetails != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Word & Phonetics
                          Row(
                            children: [
                              Text(
                                _wordDetails!['word'] ?? '',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '[${_wordDetails!['phonetics'] ?? ''}]',
                                style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          // Meaning
                          const Text('中文意思', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_wordDetails!['meaning'] ?? '', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 24),
                          // Etymology
                          const Text('词源/词根', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_wordDetails!['etymology'] ?? '', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 24),
                          // Sentences
                          const Text('智能例句', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...?(_wordDetails!['sentences'] as List?)?.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(s.toString(), style: const TextStyle(fontSize: 16)),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text(_errorMessage!, style: const TextStyle(fontSize: 18, color: Colors.red)),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text('输入单词并点击“学习”开始吧！', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
