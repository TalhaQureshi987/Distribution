import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class PaymentService {
  static const String baseUrl = '/api/payments';

  /// Process payment
  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String currency,
    required String paymentMethod,
    required String description,
    String? donationId,
    String? requestId,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/process'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'paymentMethod': paymentMethod,
          'description': description,
          'donationId': donationId,
          'requestId': requestId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Payment failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Payment failed: $e');
    }
  }

  /// Get payment methods
  static Future<Map<String, dynamic>> getPaymentMethods() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/methods'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to load payment methods: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to load payment methods: $e');
    }
  }

  /// Get payment history
  static Future<Map<String, dynamic>> getPaymentHistory() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to load payment history: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to load payment history: $e');
    }
  }

  /// Refund payment
  static Future<Map<String, dynamic>> refundPayment(String paymentId) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/$paymentId/refund'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Refund failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Refund failed: $e');
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
