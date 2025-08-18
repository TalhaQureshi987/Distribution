import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

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

      final uri = Uri.parse('${ApiService.base}$baseUrl').replace(queryParameters: queryParams);
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
  static Future<Map<String, dynamic>> getVolunteerById(String volunteerId) async {
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
