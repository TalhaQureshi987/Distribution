// lib/services/api_service.dart
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ApiService {
  ApiService._();

  static String? _overrideBase;

  /// Get current base URL
  static String get base {
    if (_overrideBase != null) return _overrideBase!;

   if (kIsWeb) return 'http://localhost:3001';
if (Platform.isAndroid) return 'http://10.0.2.2:3001';
if (Platform.isIOS) return 'http://127.0.0.1:3001';
return 'http://localhost:3001';

  }

  /// Override base at runtime (USB, LAN, etc.)
  static void setBase(String url) {
    _overrideBase = url;
    print('ApiService base set to $_overrideBase');
  }

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// POST JSON helper
  static Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('$base$path');
    print('POST -> $uri');
    print('Body -> $body');

    try {
      final res = await http
          .post(uri, body: jsonEncode(body ?? {}), headers: _jsonHeaders)
          .timeout(timeout);

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

  /// GET JSON helper
  static Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Duration timeout = const Duration(seconds: 30), 
    required String token,
  }) async {
    final uri = Uri.parse('$base$path');
    print('GET -> $uri');

    // Add authorization header with token
    final headers = Map<String, String>.from(_jsonHeaders);
    headers['Authorization'] = 'Bearer $token';

    try {
      final res = await http.get(uri, headers: headers).timeout(timeout);

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
}
