import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EntryScreen extends StatefulWidget {
  const EntryScreen({Key? key}) : super(key: key);

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  XFile? _pickedFile;
  Uint8List? _webImage;
  final TextEditingController _textController = TextEditingController();
  
  List<dynamic> _books = [];
  String? _selectedBookId;
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  Future<void> _fetchBooks() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8001/api/books'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _books = data['books'];
          if (_books.isNotEmpty) {
            _selectedBookId = _books[0]['id'];
          }
        });
      }
    } catch (e) {
      print('Error fetching books: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      var f = await image.readAsBytes();
      setState(() {
        _pickedFile = image;
        _webImage = f;
      });
    }
  }

  Future<void> _startOcr() async {
    if (_pickedFile == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在识别...')),
    );

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8001/api/ocr'),
      );
      
      var bytes = await _pickedFile!.readAsBytes();
      if (!mounted) return;
      
      var multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: _pickedFile!.name,
      );
      
      request.files.add(multipartFile);
      
      var response = await request.send();
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        if (!mounted) return;
        var data = json.decode(responseData);
        
        if (data.containsKey('words')) {
          setState(() {
            _textController.text = data['words'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('识别成功！')),
          );
        } else if (data.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('错误: ${data['error']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请求失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误: $e')),
      );
    }
  }

  Future<void> _saveWords() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_selectedBookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择或创建单词本')),
      );
      return;
    }

    final words = text.split(RegExp(r'[\n,]+')).map((w) => w.trim()).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return;

    final path = _pathController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在保存...')),
    );

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8001/api/words'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'words': words,
          'book_id': _selectedBookId,
          'path': path,
        }),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('message')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
          setState(() {
            _textController.clear();
            _pathController.clear();
            _pickedFile = null;
            _webImage = null;
          });
        } else if (data.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('错误: ${data['error']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请求失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('录入单词')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Image Picker & Preview
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('拍照识词', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (_webImage != null)
                        Expanded(child: Image.memory(_webImage!))
                      else
                        const Expanded(
                          child: Center(
                            child: Text('未选择图片'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('选择图片'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickedFile == null ? null : _startOcr,
                        icon: const Icon(Icons.search),
                        label: const Text('开始识别'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right side: Manual Input & Settings
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('单词本与层级', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (_books.isEmpty)
                        const Text('正在加载单词本或无可用单词本...')
                      else
                        DropdownButton<String>(
                          value: _selectedBookId,
                          isExpanded: true,
                          items: _books.map<DropdownMenuItem<String>>((book) {
                            return DropdownMenuItem<String>(
                              value: book['id'],
                              child: Text(book['name']),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedBookId = newValue;
                            });
                          },
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pathController,
                        decoration: const InputDecoration(
                          hintText: '层级路径 (例如: Unit 1, Part A)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('手动批量输入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _textController,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          hintText: '请输入单词，每行一个或用逗号分隔...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _saveWords,
                        child: const Text('保存单词'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
