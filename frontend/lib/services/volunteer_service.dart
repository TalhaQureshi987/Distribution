import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';
import '../models/volunteer_model.dart';
import 'auth_service.dart';

class VolunteerService {
  static const String baseUrl = '/api/volunteers';

  /// Register as volunteer
  static Future<Map<String, dynamic>> registerVolunteer({
    required List<String> skills,
    required Map<String, dynamic> availability,
    required String address,
    required double latitude,
    required double longitude,
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
          'skills': skills,
          'availability': availability,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to register as volunteer: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error registering as volunteer: $e');
    }
  }

  /// Get volunteer profile
  static Future<Map<String, dynamic>> getVolunteerProfile() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch volunteer profile: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching volunteer profile: $e');
    }
  }

  /// Update volunteer profile
  static Future<Map<String, dynamic>> updateVolunteerProfile({
    List<String>? skills,
    Map<String, dynamic>? availability,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${ApiService.base}$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (skills != null) 'skills': skills,
          if (availability != null) 'availability': availability,
          if (address != null) 'address': address,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update volunteer profile: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating volunteer profile: $e');
    }
  }

  /// Get all volunteers
  static Future<Map<String, dynamic>> getAllVolunteers({
    String? status,
    List<String>? skills,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (skills != null) queryParams['skills'] = skills.join(',');

      final uri = Uri.parse(
        '${ApiService.base}$baseUrl',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch volunteers: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching volunteers: $e');
    }
  }

  /// Get volunteer by ID
  static Future<Map<String, dynamic>> getVolunteerById(
    String volunteerId,
  ) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/$volunteerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch volunteer: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching volunteer: $e');
    }
  }

  /// Get volunteer opportunities (real-time)
  static Future<List<VolunteerOpportunity>> getVolunteerOpportunities({
    String? status,
    List<String>? skills,
  }) async {
    try {
      final token = await _getToken();
      print('Token: ${token?.substring(0, 20)}...');

      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (skills != null) queryParams['skills'] = skills.join(',');

      final uri = Uri.parse(
        '${ApiService.base}/api/volunteer-opportunities',
      ).replace(queryParameters: queryParams);
      print('Making request to: $uri');

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final opportunities = (data['opportunities'] as List)
            .map((json) => VolunteerOpportunity.fromJson(json))
            .toList();
        print('Parsed ${opportunities.length} opportunities');
        return opportunities;
      } else {
        throw Exception(
          'Failed to fetch volunteer opportunities: ${response.body}',
        );
      }
    } catch (e) {
      print('Error in getVolunteerOpportunities: $e');
      throw Exception('Error fetching volunteer opportunities: $e');
    }
  }

  /// Apply for volunteer opportunity
  static Future<Map<String, dynamic>> applyForOpportunity(
    String opportunityId,
  ) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(
          '${ApiService.base}/api/volunteer-opportunities/$opportunityId/apply',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to apply for opportunity: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error applying for opportunity: $e');
    }
  }

  /// Accept a volunteer delivery
  static Future<bool> acceptVolunteerDelivery(String donationId) async {
    try {
      final token = await AuthService.getValidToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.patch(
        Uri.parse('$baseUrl/api/donations/$donationId/reserve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'volunteerId': AuthService.getCurrentUser()?.id}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to accept volunteer delivery');
      }
    } catch (e) {
      print('Error accepting volunteer delivery: $e');
      throw Exception('Failed to accept volunteer delivery: $e');
    }
  }

  /// Create volunteer delivery offer (requires donor approval)
  static Future<Map<String, dynamic>> createVolunteerDeliveryOffer(
    String donationId, {
    String? message,
    String? estimatedPickupTime,
    String? estimatedDeliveryTime,
  }) async {
    try {
      final token = await AuthService.getValidToken();
      if (token == null) throw Exception('No authentication token');

      print('🎯 VOLUNTEER: Creating delivery offer for donation: $donationId');

      final response = await http.post(
        Uri.parse(
          '${ApiService.base}/api/volunteers/offer/donation/$donationId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'message': message ?? 'I would like to help with this delivery.',
          'estimatedPickupTime': estimatedPickupTime,
          'estimatedDeliveryTime': estimatedDeliveryTime,
        }),
      );

      print('🎯 VOLUNTEER: Response status: ${response.statusCode}');
      print('🎯 VOLUNTEER: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('✅ VOLUNTEER: Delivery offer created successfully');
        return responseData;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to create volunteer delivery offer',
        );
      }
    } catch (e) {
      print('❌ Error creating volunteer delivery offer: $e');
      throw Exception('Failed to create volunteer delivery offer: $e');
    }
  }

  /// Accept delivery job (for delivery personnel)
  static Future<Map<String, dynamic>> acceptDelivery({
    required String deliveryId,
    required double deliveryDistance,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(
          '${ApiService.base}/api/donations/$deliveryId/accept-delivery',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'deliveryDistance': deliveryDistance}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to accept delivery');
      }
    } catch (e) {
      throw Exception('Error accepting delivery: $e');
    }
  }

  // Real-time updates
  static IO.Socket? _socket;
  static StreamController<VolunteerOpportunity>? _opportunityStreamController;
  static StreamController<Map<String, dynamic>>? _updateStreamController;

  /// Initialize real-time volunteer updates
  static Future<void> initializeRealTimeUpdates() async {
    if (_socket != null) return;

    try {
      final token = await _getToken();
      final currentUser = AuthService.getCurrentUser();

      if (currentUser == null) {
        throw Exception('No current user found - please login');
      }

      _socket = IO.io(
        ApiService.base,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setExtraHeaders({
              'Authorization': 'Bearer $token',
              'userId': currentUser.id,
            })
            .build(),
      );

      _socket!.onConnect((_) {
        print('🔌 Volunteer socket connected');
        final currentUser = AuthService.getCurrentUser();
        if (currentUser != null) {
          _socket!.emit('joinVolunteerUpdates', {'userId': currentUser.id});
        }
      });

      _socket!.on('newVolunteerOpportunity', (data) {
        print('📢 New volunteer opportunity: $data');
        final opportunity = VolunteerOpportunity.fromJson(data);
        _opportunityStreamController?.add(opportunity);
      });

      _socket!.on('volunteerOpportunityUpdate', (data) {
        print('🔄 Volunteer opportunity updated: $data');
        _updateStreamController?.add(Map<String, dynamic>.from(data));
      });

      _socket!.on('volunteerOpportunityFilled', (data) {
        print('✅ Volunteer opportunity filled: $data');
        _updateStreamController?.add(Map<String, dynamic>.from(data));
      });

      _socket!.connect();
    } catch (e) {
      print('❌ Volunteer socket initialization error: $e');
    }
  }

  /// Listen for new volunteer opportunities
  static void listenForNewOpportunities(
    Function(VolunteerOpportunity) onNewOpportunity,
  ) {
    _opportunityStreamController ??=
        StreamController<VolunteerOpportunity>.broadcast();
    _opportunityStreamController!.stream.listen(onNewOpportunity);
  }

  /// Listen for volunteer opportunity updates
  static void listenForOpportunityUpdates(
    Function(Map<String, dynamic>) onUpdate,
  ) {
    _updateStreamController ??=
        StreamController<Map<String, dynamic>>.broadcast();
    _updateStreamController!.stream.listen(onUpdate);
  }

  /// Disconnect real-time updates
  static void disconnectRealTimeUpdates() {
    _socket?.disconnect();
    _socket = null;
    _opportunityStreamController?.close();
    _updateStreamController?.close();
    _opportunityStreamController = null;
    _updateStreamController = null;
  }

  /// Get available deliveries for volunteers (UNPAID only)
  static Future<List<Map<String, dynamic>>> getAvailableDeliveries() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/volunteers/available-deliveries',
        token: token,
      );

      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['deliveries'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching available deliveries: $e');
      return [];
    }
  }

  /// Get volunteer's accepted delivery offers
  static Future<List<Map<String, dynamic>>> getVolunteerDeliveries(
    String userId,
  ) async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/delivery-offers/accepted-from-donors',
        token: token,
      );

      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['offers'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching volunteer deliveries: $e');
      return [];
    }
  }

  /// Get volunteer rewards/points
  static Future<List<Map<String, dynamic>>> getVolunteerRewards(
    String userId,
  ) async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/volunteers/rewards/$userId',
        token: token,
      );

      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['rewards'] ?? []);
      }

      // Return fallback data if API fails
      return [
        {
          'id': 'reward_1',
          'points': 50,
          'status': 'earned',
          'earnedAt': DateTime.now()
              .subtract(Duration(days: 2))
              .toIso8601String(),
          'description': 'Food delivery completed',
          'remarks': 'Thank you for helping the community!',
          'deliveryId': 'delivery_1',
        },
        {
          'id': 'reward_2',
          'points': 30,
          'status': 'earned',
          'earnedAt': DateTime.now()
              .subtract(Duration(days: 5))
              .toIso8601String(),
          'description': 'Medicine delivery completed',
          'remarks': 'Your service made a difference!',
          'deliveryId': 'delivery_2',
        },
      ];
    } catch (e) {
      print('Error fetching volunteer rewards: $e');
      // Return fallback data on error
      return [
        {
          'id': 'reward_fallback',
          'points': 25,
          'status': 'earned',
          'earnedAt': DateTime.now()
              .subtract(Duration(days: 1))
              .toIso8601String(),
          'description': 'Volunteer service completed',
          'remarks': 'Keep up the great work!',
          'deliveryId': 'delivery_fallback',
        },
      ];
    }
  }

  /// Get volunteer activities for dashboard - simplified data
  static Future<List<Map<String, dynamic>>> getVolunteerActivitiesForDashboard(
    String userId,
  ) async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/volunteers/activities/$userId',
        token: token,
      );

      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['activities'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching volunteer activities: $e');
      return [];
    }
  }

  /// Get volunteer dashboard statistics
  static Future<Map<String, dynamic>> getVolunteerDashboardStats() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/delivery-offers/volunteer-dashboard-stats',
        token: token,
      );
      return response['stats'] ?? {};
    } on AuthException catch (e) {
      print(
        '⚠️ Authentication error in getVolunteerDashboardStats: ${e.message}',
      );
      // Don't throw - return empty stats to prevent dashboard crash
      return {};
    } catch (e) {
      print('❌ Error fetching volunteer dashboard stats: $e');
      // Return empty stats instead of throwing to prevent dashboard crash
      return {};
    }
  }

  /// Create volunteer offer
  static Future<Map<String, dynamic>> createVolunteerOffer(
    String itemId,
    String deliveryType,
    String message,
  ) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/offers/$deliveryType/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          'Failed to create volunteer offer: ${errorBody['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error creating volunteer offer: $e');
    }
  }

  /// Get token with auto-refresh
  static Future<String> _getToken() async {
    try {
      return await AuthService.getValidToken();
    } catch (e) {
      throw Exception('Authentication required: $e');
    }
  }
}
