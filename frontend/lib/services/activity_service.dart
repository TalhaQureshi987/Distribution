import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ActivityService {
  static const String baseUrl = '/api/activity';

  // Simplified to only fetch donation and request history
  static Future<List<Map<String, dynamic>>> getDonationHistory() async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}/api/donations/my');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return List<Map<String, dynamic>>.from(data['donations'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRequestHistory() async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}/api/requests/my');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return List<Map<String, dynamic>>.from(data['requests'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Combined activity for simple display
  static Future<List<Map<String, dynamic>>> getSimpleActivity() async {
    final donations = await getDonationHistory();
    final requests = await getRequestHistory();
    
    List<Map<String, dynamic>> activities = [];
    
    // Add donations to activity list
    for (var donation in donations) {
      activities.add({
        'type': 'donation',
        'title': donation['title'] ?? 'Food Donation',
        'description': donation['description'] ?? '',
        'date': donation['createdAt'] ?? DateTime.now().toIso8601String(),
        'status': donation['status'] ?? 'active',
      });
    }
    
    // Add requests to activity list
    for (var request in requests) {
      activities.add({
        'type': 'request',
        'title': request['title'] ?? 'Food Request',
        'description': request['description'] ?? '',
        'date': request['createdAt'] ?? DateTime.now().toIso8601String(),
        'status': request['status'] ?? 'active',
      });
    }
    
    // Sort by date (newest first)
    activities.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    
    return activities;
  }

  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }
}
