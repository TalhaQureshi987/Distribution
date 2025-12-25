import 'dart:io' show Platform, SocketException, File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/config.dart';

class AuthException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  AuthException(this.message, this.statusCode, this.responseBody);
}

class ApiService {
  ApiService._();

  static String? _overrideBase;

  /// Get current base URL
  static String get base {
    if (_overrideBase != null) return _overrideBase!;

    const environment =
        String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

    if (environment == 'production') {
      return AppConfig.baseUrl;
    }

    // Development environment - auto detect
    if (kIsWeb) return AppConfig.getDevUrl('web');
    if (Platform.isAndroid) {
      // Force ngrok URL for physical devices to avoid localhost issues
      return AppConfig.getDevUrl('physical_device');
    }
    if (Platform.isIOS) return AppConfig.getDevUrl('ios');
    return AppConfig.getDevUrl('physical_device');
  }

  /// Override base at runtime (USB, LAN, etc.)
  static void setBase(String url) {
    _overrideBase = url;
    print('ApiService base set to $_overrideBase');
  }

  /// Get headers with ngrok support
  static Map<String, String> _getHeaders({String? token}) {
    Map<String, String> headers = AppConfig.getHeaders(base);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET helper (without auth)
  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('$base$path');
    print('GET -> $uri');

    try {
      final res = await http.get(uri, headers: _getHeaders()).timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body);
      } else {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// GET helper (with auth)
  static Future<Map<String, dynamic>> getAuth(
    String path, {
    Map<String, dynamic>? query,
    Duration timeout = const Duration(seconds: 30),
    required String token,
  }) async {
    final uri = Uri.parse('$base$path');
    print('GET (Auth) -> $uri');

    try {
      final res = await http.get(uri, headers: _getHeaders(token: token)).timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body);
      } else if (res.statusCode == 401) {
        // Don't throw exception immediately for 401 - let calling code handle it
        print('⚠️ 401 Unauthorized - Token may be expired');
        throw AuthException('Authentication failed', res.statusCode, res.body);
      } else {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// POST JSON helper
  static Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
    String? token,
  }) async {
    final uri = Uri.parse('$base$path');
    print('POST -> $uri');
    print('Body -> $body');

    try {
      final res = await http
          .post(uri, body: jsonEncode(body ?? {}), headers: _getHeaders(token: token))
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body);
      } else if (res.statusCode == 401) {
        print('⚠️ 401 Unauthorized - Token may be expired');
        throw AuthException('Authentication failed', res.statusCode, res.body);
      } else {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// POST JSON helper (with auth)
  static Future<Map<String, dynamic>> postJsonAuth(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
    required String token,
  }) async {
    final uri = Uri.parse('$base$path');
    print('POST (Auth) -> $uri');
    print('Body -> $body');

    try {
      final res = await http
          .post(uri, body: jsonEncode(body ?? {}), headers: _getHeaders(token: token))
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body);
      } else if (res.statusCode == 401) {
        print('⚠️ 401 Unauthorized - Token may be expired');
        throw AuthException('Authentication failed', res.statusCode, res.body);
      } else {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// PUT JSON helper
  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
    String? token,
  }) async {
    final uri = Uri.parse('$base$path');
    print('PUT -> $uri');
    print('Body -> $body');

    try {
      final res = await http
          .put(uri, body: jsonEncode(body ?? {}), headers: _getHeaders(token: token))
          .timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body);
      } else if (res.statusCode == 401) {
        print('⚠️ 401 Unauthorized - Token may be expired');
        throw AuthException('Authentication failed', res.statusCode, res.body);
      } else {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// DELETE helper
  static Future<Map<String, dynamic>> delete(
    String path, {
    Duration timeout = const Duration(seconds: 30),
    String? token,
  }) async {
    final uri = Uri.parse('$base$path');
    print('DELETE -> $uri');

    try {
      final res = await http.delete(uri, headers: _getHeaders(token: token)).timeout(timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body);
      } else {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// Upload file helper
  static Future<Map<String, dynamic>> uploadFile(
    String path,
    String filePath, {
    Duration timeout = const Duration(seconds: 60),
    String? token,
  }) async {
    final uri = Uri.parse('$base$path');
    print('UPLOAD -> $uri');
    print('File -> $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers with ngrok support
      final headers = _getHeaders(token: token);
      headers.forEach((key, value) {
        request.headers[key] = value;
      });

      // Add file
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: file.path.split('/').last,
      );
      request.files.add(multipartFile);

      // Send request
      final response = await request.send().timeout(timeout);
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(responseBody);
      } else {
        throw Exception('HTTP ${response.statusCode}: $responseBody');
      }
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// GET JSON helper (with auth) - kept for backward compatibility
  static Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Duration timeout = const Duration(seconds: 30),
    required String token,
  }) async {
    return getAuth(path, query: query, timeout: timeout, token: token);
  }
}
