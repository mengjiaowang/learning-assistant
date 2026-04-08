import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class WordBuddyApiService {
  // 本地开发使用 8001 端口，生产环境使用相对路径（由 Firebase Hosting 转发）
  static String get baseUrl {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
        return 'http://127.0.0.1:8001';
      }
      return ''; 
    }
    return 'http://127.0.0.1:8001';
  }
  
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  WordBuddyApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        String? token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // 这里可以处理登录过期逻辑，或者简单抛出
          if (kDebugMode) print('Word Buddy API Unauthorized');
        }
        return handler.next(e);
      },
    ));
  }

  // ==========================================
  // 生词本管理
  // ==========================================
  
  Future<List<dynamic>> getBooks() async {
    try {
      final response = await _dio.get('/api/books');
      if (response.statusCode == 200) {
        return response.data['books'] ?? [];
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getBooks error: $e');
      return [];
    }
  }

  Future<bool> createBook(String name, List<String> hierarchy) async {
    try {
      final response = await _dio.post('/api/books', data: {
        'name': name,
        'hierarchy': hierarchy,
      });
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('createBook error: $e');
      return false;
    }
  }

  Future<bool> deleteBook(String bookId) async {
    try {
      final response = await _dio.delete('/api/books/$bookId');
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('deleteBook error: $e');
      return false;
    }
  }

  // ==========================================
  // 单词管理
  // ==========================================
  
  Future<bool> saveWords(List<String> words, String bookId, List<String> path) async {
    try {
      final response = await _dio.post('/api/words', data: {
        'words': words,
        'book_id': bookId,
        'path': path,
      });
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('saveWords error: $e');
      return false;
    }
  }

  Future<List<dynamic>> getWords(String bookId) async {
    try {
      final response = await _dio.get('/api/words', queryParameters: {'book_id': bookId});
      if (response.statusCode == 200) {
        return response.data['words'] ?? [];
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getWords error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getWordDetails(String word) async {
    try {
      final response = await _dio.post('/api/word_details', data: {'word': word});
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getWordDetails error: $e');
      return null;
    }
  }

  Future<List<dynamic>> getRecycleBin() async {
    try {
      final response = await _dio.get('/api/recycle_bin');
      if (response.statusCode == 200) {
        return response.data['books'] ?? [];
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('getRecycleBin error: $e');
      return [];
    }
  }

  Future<bool> restoreBook(String bookId) async {
    try {
      final response = await _dio.post('/api/recycle_bin/$bookId/restore');
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('restoreBook error: $e');
      return false;
    }
  }

  Future<bool> permanentDeleteBook(String bookId) async {
    try {
      final response = await _dio.delete('/api/recycle_bin/$bookId/permanent');
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('permanentDeleteBook error: $e');
      return false;
    }
  }
}

final wordBuddyApiService = WordBuddyApiService();
