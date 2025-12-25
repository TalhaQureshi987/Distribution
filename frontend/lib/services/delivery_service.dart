// lib/services/delivery_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

class DeliveryService {
  // Adjust to match your backend routes
  static const String baseUrl = '/api/deliveries';
  static const Duration _timeout = Duration(seconds: 30);

  /// Request/create a delivery job
  static Future<Map<String, dynamic>> requestDelivery({
    required String pickupAddress,
    required String deliveryAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required double deliveryLatitude,
    required double deliveryLongitude,
    required String
    deliveryType, // 'Self delivery' | 'Volunteer Delivery' | 'Paid Delivery (Earn)'
    required String itemType, // e.g. 'Food Donation'
    required String itemDescription,
    String? donationId,
    double? estimatedPrice,
    String? notes,
  }) async {
    final token = await _getToken();

    final payload = <String, dynamic>{
      'pickupAddress': pickupAddress,
      'deliveryAddress': deliveryAddress,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'deliveryType': deliveryType,
      'itemType': itemType,
      'itemDescription': itemDescription,
      if (donationId != null) 'donationId': donationId,
      if (estimatedPrice != null) 'estimatedPrice': estimatedPrice,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes,
    };

    final res = await http
        .post(
          Uri.parse('${ApiService.base}$baseUrl/request'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    // Expect 201 Created
    final decoded = _handleResponse(res, expectedStatus: 201);
    return _asMap(decoded);
  }

  /// Confirm delivery
  static Future<Map<String, dynamic>> confirmDelivery(String deliveryId) async {
    final token = await _getToken();
    final res = await http
        .post(
          Uri.parse('${ApiService.base}$baseUrl/$deliveryId/confirm'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);

    final decoded = _handleResponse(res, expectedStatus: 200);
    return _asMap(decoded);
  }

  /// Cancel delivery (optional helper)
  static Future<Map<String, dynamic>> cancelDelivery(
    String deliveryId, {
    String? reason,
  }) async {
    final token = await _getToken();
    final res = await http
        .post(
          Uri.parse('${ApiService.base}$baseUrl/$deliveryId/cancel'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'reason': reason}),
        )
        .timeout(_timeout);

    final decoded = _handleResponse(res, expectedStatus: 200);
    return _asMap(decoded);
  }

  /// Fetch delivery by ID
  static Future<Map<String, dynamic>> getDelivery(String deliveryId) async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${ApiService.base}$baseUrl/$deliveryId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);

    final decoded = _handleResponse(res, expectedStatus: 200);
    return _asMap(decoded);
  }

  /// List deliveries — ALWAYS returns a List<dynamic> safely
  static Future<List<dynamic>> listDeliveries() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${ApiService.base}$baseUrl'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);

    final decoded = _handleResponse(res, expectedStatus: 200);

    // Safe handling for many API shapes
    if (decoded is List) return decoded;
    if (decoded is Map) {
      if (decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) return data;
        return [data];
      }
      return [decoded];
    }
    return [decoded];
  }

  // ---------------- Helpers ----------------

  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }

  static dynamic _handleResponse(
    http.Response response, {
    required int expectedStatus,
  }) {
    final decoded = _safeJsonDecode(response.bodyBytes);

    if (response.statusCode == expectedStatus) {
      return decoded;
    }

    final message =
        _extractErrorMessage(decoded) ??
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

  /// Get available deliveries for paid delivery dashboard
  static Future<List<Map<String, dynamic>>> getAvailableDeliveries() async {
    try {
      // Fetch only PAID deliveries for delivery dashboard
      final token = await AuthService.getValidToken();
      final donationsResponse = await ApiService.getJson(
        '/api/donations/paid-deliveries',
        token: token,
      );
      final requestsResponse = await ApiService.getJson(
        '/api/requests/paid-deliveries',
        token: token,
      );
      if (donationsResponse['success'] == true &&
          requestsResponse['success'] == true) {
        final donations = List<Map<String, dynamic>>.from(
          donationsResponse['donations'] ?? [],
        );
        final requests = List<Map<String, dynamic>>.from(
          requestsResponse['requests'] ?? [],
        );

        // Combine donations and requests
        final allDeliveries = <Map<String, dynamic>>[];

        // Add donations with type indicator
        for (final donation in donations) {
          allDeliveries.add({
            ...donation,
            'deliveryType': 'donation',
            'isPaid': true,
          });
        }

        // Add requests with type indicator
        for (final request in requests) {
          allDeliveries.add({
            ...request,
            'deliveryType': 'request',
            'isPaid': true,
          });
        }

        // Sort by creation date (newest first)
        allDeliveries.sort((a, b) {
          final aDate =
              DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final bDate =
              DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        return allDeliveries;
      }
      return [];
    } catch (e) {
      print('Error fetching paid deliveries: $e');
      // Return mock paid delivery data
      return [
        {
          'id': '1',
          'title': 'Fresh Vegetables Delivery',
          'description': 'Deliver fresh vegetables to family in need',
          'foodType': 'Vegetables',
          'quantity': 5,
          'pickupAddress': 'Central Karachi Market',
          'deliveryAddress': 'North Karachi Residential Area',
          'distance': 8.5,
          'paymentAmount': 150,
          'isPaid': true,
          'deliveryType': 'donation',
          'urgencyLevel': 'medium',
          'createdAt': DateTime.now()
              .subtract(Duration(hours: 1))
              .toIso8601String(),
          'status': 'verified',
        },
        {
          'id': '2',
          'title': 'Cooked Meal Request',
          'description': 'Urgent delivery of cooked meals to elderly person',
          'foodType': 'Cooked Food',
          'quantity': 3,
          'pickupAddress': 'Central Karachi Restaurant',
          'deliveryAddress': 'South Karachi',
          'distance': 6.2,
          'paymentAmount': 100,
          'isPaid': true,
          'deliveryType': 'request',
          'urgencyLevel': 'high',
          'createdAt': DateTime.now()
              .subtract(Duration(minutes: 30))
              .toIso8601String(),
          'status': 'verified',
        },
      ];
    }
  }

  /// Get delivery jobs for dashboard - simplified data
  static Future<List<Map<String, dynamic>>> getDeliveryJobsForDashboard(
    String userId,
  ) async {
    try {
      final deliveries = await listDeliveries();
      return deliveries
          .map(
            (delivery) => {
              'id': delivery['id'] ?? delivery['_id'] ?? '',
              'type': delivery['deliveryType'] ?? 'Unknown',
              'status': delivery['status'] ?? 'pending',
              'pickupAddress': delivery['pickupAddress'] ?? '',
              'deliveryAddress': delivery['deliveryAddress'] ?? '',
              'itemType': delivery['itemType'] ?? '',
              'estimatedPrice': delivery['estimatedPrice'] ?? 0.0,
              'createdAt':
                  delivery['createdAt'] ?? DateTime.now().toIso8601String(),
            },
          )
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      // Return empty list if no deliveries or service not available
      return [];
    }
  }

  /// Get paid delivery donations
  static Future<List<Map<String, dynamic>>> getPaidDeliveryDonations() async {
    try {
      final response = await ApiService.getJson(
        '/api/donations/paid-deliveries',
        token: await AuthService.getValidToken(),
      );

      if (response['donations'] != null) {
        return List<Map<String, dynamic>>.from(response['donations']);
      }
      return [];
    } catch (e) {
      print('Error fetching paid delivery donations: $e');
      return [];
    }
  }

  /// Get paid delivery requests
  static Future<List<Map<String, dynamic>>> getPaidDeliveryRequests() async {
    try {
      final response = await ApiService.getJson(
        '/api/requests/paid-deliveries',
        token: await AuthService.getValidToken(),
      );

      if (response['requests'] != null) {
        return List<Map<String, dynamic>>.from(response['requests']);
      }
      return [];
    } catch (e) {
      print('Error fetching paid delivery requests: $e');
      return [];
    }
  }

  /// Accept a delivery offer
  static Future<Map<String, dynamic>> acceptDelivery(String deliveryId) async {
    try {
      final token = await AuthService.getValidToken();

      final response = await http
          .post(
            Uri.parse('${ApiService.base}/api/deliveries/$deliveryId/accept'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);

      final decoded = _handleResponse(response, expectedStatus: 200);
      return _asMap(decoded);
    } catch (e) {
      print('Error accepting delivery: $e');
      throw Exception('Failed to accept delivery: $e');
    }
  }

  /// Accept a paid delivery job
  static Future<bool> acceptDeliveryJob(String donationId) async {
    try {
      final token = await AuthService.getValidToken();

      final response = await http
          .patch(
            Uri.parse('${ApiService.base}/api/donations/$donationId/reserve'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'deliveryPersonId': await _getCurrentUserId()}),
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error accepting delivery job: $e');
      return false;
    }
  }

  /// Get current user ID from token or preferences
  static Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userId');
    } catch (e) {
      print('Error getting current user ID: $e');
      return null;
    }
  }

  static Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    // Some APIs return { data: {...} }
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }
    return {'data': decoded};
  }

  /// Get delivery dashboard statistics
  static Future<Map<String, dynamic>> getDeliveryDashboardStats() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/deliveries/dashboard-stats',
        token: token,
      );
      return response['stats'] ?? {};
    } on AuthException catch (e) {
      print(
        '⚠️ Authentication error in getDeliveryDashboardStats: ${e.message}',
      );
      // Don't throw - return empty stats to prevent dashboard crash
      return {};
    } catch (e) {
      print('❌ Error fetching delivery dashboard stats: $e');
      // Return empty stats instead of throwing to prevent dashboard crash
      return {};
    }
  }

  /// Update delivery status
  static Future<Map<String, dynamic>> updateDeliveryStatus({
    required String deliveryId,
    required String status,
    String? notes,
  }) async {
    try {
      final token = await AuthService.getValidToken();
      if (token == null) throw Exception('No authentication token');

      print('🔄 DELIVERY: Updating delivery status for $deliveryId to $status');

      final response = await http.patch(
        Uri.parse('${ApiService.base}/api/deliveries/$deliveryId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status, if (notes != null) 'notes': notes}),
      );

      print('🔄 DELIVERY: Response status: ${response.statusCode}');
      print('🔄 DELIVERY: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ DELIVERY: Delivery status updated successfully');
        return responseData;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to update delivery status',
        );
      }
    } catch (e) {
      print('❌ Error updating delivery status: $e');
      throw Exception('Failed to update delivery status: $e');
    }
  }

  /// Create delivery offer (requires donor/requester approval)
  static Future<Map<String, dynamic>> createDeliveryOffer({
    required String itemId,
    required String itemType, // 'donation' or 'request'
    String? message,
    String? estimatedPickupTime,
    String? estimatedDeliveryTime,
  }) async {
    try {
      final token = await AuthService.getValidToken();
      if (token == null) throw Exception('No authentication token');

      print('💰 DELIVERY: Creating delivery offer for $itemType: $itemId');

      final response = await http.post(
        Uri.parse(
          '${ApiService.base}/api/delivery-offers/$itemType/$itemId/offer',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': message ?? 'I would like to deliver this item.',
          'estimatedPickupTime':
              estimatedPickupTime ??
              DateTime.now().add(Duration(hours: 1)).toIso8601String(),
          'estimatedDeliveryTime':
              estimatedDeliveryTime ??
              DateTime.now().add(Duration(hours: 3)).toIso8601String(),
        }),
      );

      print('💰 DELIVERY: Response status: ${response.statusCode}');
      print('💰 DELIVERY: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('✅ DELIVERY: Delivery offer created successfully');
        return responseData;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to create delivery offer',
        );
      }
    } catch (e) {
      print('❌ Error creating delivery offer: $e');
      throw Exception('Failed to create delivery offer: $e');
    }
  }
}
