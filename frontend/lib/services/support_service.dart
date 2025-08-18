import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SupportService {
  static const String baseUrl = '/api/support';

  /// Submit support ticket
  static Future<Map<String, dynamic>> submitTicket({
    required String subject,
    required String message,
    required String category,
    String? priority,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'subject': subject,
          'message': message,
          'category': category,
          'priority': priority ?? 'medium',
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to submit ticket: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to submit ticket: $e');
    }
  }

  /// Get user support tickets
  static Future<Map<String, dynamic>> getUserTickets() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load tickets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load tickets: $e');
    }
  }

  /// Get support categories
  static Future<Map<String, dynamic>> getSupportCategories() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  /// Get FAQ
  static Future<Map<String, dynamic>> getFAQ() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/faq'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load FAQ: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load FAQ: $e');
    }
  }

  /// Contact support via email
  static Future<Map<String, dynamic>> contactSupport({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/contact'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'subject': subject,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Get token from SharedPreferences
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }
}
