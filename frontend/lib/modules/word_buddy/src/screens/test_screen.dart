import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<dynamic> _quiz = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _selectedAnswer;
  bool _isAnswered = false;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _fetchTest();
  }

  Future<void> _fetchTest() async {
    setState(() {
      _isLoading = true;
      _quiz = [];
      _currentIndex = 0;
      _selectedAnswer = null;
      _isAnswered = false;
      _score = 0;
    });
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/api/test'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('quiz')) {
          setState(() {
            _quiz = json.decode(data['quiz']) ?? [];
            _isLoading = false;
          });
        } else if (data.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('错误: ${data['error']}')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取测试题目失败: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkAnswer(String option) {
    if (_isAnswered) return;
    
    final correctAnswer = _quiz[_currentIndex]['answer'];
    setState(() {
      _selectedAnswer = option;
      _isAnswered = true;
      if (option == correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex++;
      _selectedAnswer = null;
      _isAnswered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_quiz.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('库中没有足够的单词来生成测试。', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchTest,
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentIndex >= _quiz.length) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('测试完成！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('您的得分: $_score / ${_quiz.length}', style: const TextStyle(fontSize: 20, color: Colors.teal)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _fetchTest,
                icon: const Icon(Icons.refresh),
                label: const Text('再测一次'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _quiz[_currentIndex];
    final options = currentQuestion['options'] as Map<String, dynamic>;
    final correctAnswer = currentQuestion['answer'];

    return Scaffold(
      appBar: AppBar(title: Text('单元测试 (${_currentIndex + 1}/${_quiz.length})')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    currentQuestion['question'] ?? '',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Options
            ...options.entries.map((entry) {
              final optionKey = entry.key;
              final optionValue = entry.value;
              
              Color? buttonColor = Colors.white;
              if (_isAnswered) {
                if (optionKey == correctAnswer) {
                  buttonColor = Colors.green[200];
                } else if (optionKey == _selectedAnswer) {
                  buttonColor = Colors.red[200];
                }
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _checkAnswer(optionKey),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('$optionKey. $optionValue', style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const Spacer(),
            // Next Button
            if (_isAnswered)
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton.icon(
                  onPressed: _nextQuestion,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('下一题'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
