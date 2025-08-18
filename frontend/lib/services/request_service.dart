import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/request_model.dart';
import 'api_service.dart';

class RequestService {
  static const String baseUrl = '/api/requests';

  /// Create a new food request
  static Future<RequestModel> createRequest({
    required String title,
    required String description,
    required String foodType,
    required int quantity,
    required String quantityUnit,
    required DateTime neededBy,
    required String pickupAddress,
    required double latitude,
    required double longitude,
    String? notes,
    bool isUrgent = false,
    List<String> images = const [],
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'foodType': foodType,
          'quantity': quantity,
          'quantityUnit': quantityUnit,
          'neededBy': neededBy.toIso8601String(),
          'pickupAddress': pickupAddress,
          'latitude': latitude,
          'longitude': longitude,
          'notes': notes,
          'isUrgent': isUrgent,
          'images': images,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return RequestModel.fromJson(data['request']);
      } else {
        throw Exception('Failed to create request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating request: $e');
    }
  }

  /// Get all available requests
  static Future<List<RequestModel>> getAvailableRequests({
    String? foodType,
    String? location,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isUrgent,
    String? status,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{};

      if (foodType != null) queryParams['foodType'] = foodType;
      if (location != null) queryParams['location'] = location;
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (radius != null) queryParams['radius'] = radius.toString();
      if (isUrgent != null) queryParams['isUrgent'] = isUrgent.toString();
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse(
        '${ApiService.base}$baseUrl',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['requests'] as List)
            .map((json) => RequestModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch requests: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching requests: $e');
    }
  }

  /// Get request by ID
  static Future<RequestModel> getRequestById(String requestId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/$requestId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RequestModel.fromJson(data['request']);
      } else {
        throw Exception('Failed to fetch request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching request: $e');
    }
  }

  /// Get user's requests
  static Future<List<RequestModel>> getUserRequests() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/my-requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['requests'] as List)
            .map((json) => RequestModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch user requests: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching user requests: $e');
    }
  }

  /// Fulfill a request
  static Future<RequestModel> fulfillRequest(String requestId) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('${ApiService.base}$baseUrl/$requestId/fulfill'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RequestModel.fromJson(data['request']);
      } else {
        throw Exception('Failed to fulfill request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fulfilling request: $e');
    }
  }

  /// Update request status
  static Future<RequestModel> updateRequestStatus(
    String requestId,
    String status, {
    String? reason,
  }) async {
    try {
      final token = await _getToken();
      final body = {'status': status};
      if (reason != null) body['reason'] = reason;

      final response = await http.patch(
        Uri.parse('${ApiService.base}$baseUrl/$requestId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RequestModel.fromJson(data['request']);
      } else {
        throw Exception('Failed to update request status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating request status: $e');
    }
  }

  /// Cancel a request
  static Future<RequestModel> cancelRequest(
    String requestId,
    String reason,
  ) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('${ApiService.base}$baseUrl/$requestId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RequestModel.fromJson(data['request']);
      } else {
        throw Exception('Failed to cancel request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error canceling request: $e');
    }
  }

  /// Delete request
  static Future<void> deleteRequest(String requestId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiService.base}$baseUrl/$requestId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting request: $e');
    }
  }

  /// Get requests by status
  static Future<List<RequestModel>> getRequestsByStatus(String status) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/status/$status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['requests'] as List)
            .map((json) => RequestModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch requests by status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching requests by status: $e');
    }
  }

  /// Get urgent requests
  static Future<List<RequestModel>> getUrgentRequests() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/urgent'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['requests'] as List)
            .map((json) => RequestModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch urgent requests: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching urgent requests: $e');
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
