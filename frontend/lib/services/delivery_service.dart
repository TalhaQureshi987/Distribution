import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class DonationService {
  static const String baseUrl = '/api/donations';
  static const Duration _timeout = Duration(seconds: 30);

  static Future<Map<String, dynamic>> createDonation({
    required String title,
    required String description,
    required String foodType,
    required int quantity,
    required String quantityUnit,
    required DateTime expiryDate,
    required String pickupAddress,
    required double latitude,
    required double longitude,
    String? notes,
    bool isUrgent = false,
    File? imageFile,
  }) async {
    try {
      // Validate required fields
      _validateNonEmpty('title', title);
      _validateNonEmpty('description', description);
      _validateNonEmpty('foodType', foodType);
      _validateNonEmpty('pickupAddress', pickupAddress);
      _validateLatLng('latitude', latitude);
      _validateLng('longitude', longitude);

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.base}$baseUrl'),
      );

      // Add headers
      final token = await _getToken();
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add text fields
      request.fields.addAll({
        'title': title,
        'description': description,
        'foodType': foodType,
        'quantity': quantity.toString(),
        'quantityUnit': quantityUnit,
        'expiryDate': expiryDate.toIso8601String(),
        'pickupAddress': pickupAddress,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'isUrgent': isUrgent.toString(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes,
      });

      // Add image file if provided
      if (imageFile != null) {
        final fileStream = http.ByteStream(imageFile.openRead());
        final length = await imageFile.length();
        
        final multipartFile = http.MultipartFile(
          'image',
          fileStream,
          length,
          filename: 'donation_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        
        request.files.add(multipartFile);
      }

      // Send request
      final response = await request.send().timeout(_timeout);
      final responseBody = await response.stream.bytesToString();
      
      return _handleResponse(
        http.Response(responseBody, response.statusCode),
        expectedStatus: 201,
      );
    } catch (e) {
      throw Exception('Failed to create donation: $e');
    }
  }

  // Helper methods
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }

  static void _validateNonEmpty(String field, String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$field cannot be empty');
    }
  }

  static void _validateLatLng(String field, double lat) {
    if (lat < -90 || lat > 90) {
      throw ArgumentError('$field must be between -90 and 90');
    }
  }

  static void _validateLng(String field, double lng) {
    if (lng < -180 || lng > 180) {
      throw ArgumentError('$field must be between -180 and 180');
    }
  }

  static Map<String, dynamic> _handleResponse(
    http.Response response, {
    required int expectedStatus,
  }) {
    final decoded = _safeJsonDecode(response.bodyBytes);

    if (response.statusCode == expectedStatus) {
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }

    final message = _extractErrorMessage(decoded) ??
        'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';

    throw Exception(message);
  }

  static dynamic _safeJsonDecode(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) return null;
    try {
      final text = utf8.decode(bodyBytes);
      if (text.isEmpty) return null;
      return jsonDecode(text);
    } catch (_) {
      try {
        return utf8.decode(bodyBytes);
      } catch (_) {
        return null;
      }
    }
  }

  static String? _extractErrorMessage(dynamic decoded) {
    if (decoded == null) return null;
    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] is String) return decoded['message'];
      if (decoded['error'] is String) return decoded['error'];
      if (decoded['errors'] is List) {
        final first = (decoded['errors'] as List).first;
        if (first is String) return first;
        if (first is Map && first['msg'] is String) return first['msg'];
      }
    } else if (decoded is String) {
      return decoded;
    }
    return null;
  }
}