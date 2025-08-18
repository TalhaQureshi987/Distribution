import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class NotificationService {
  static const String baseUrl = '/api/notifications';

  /// Get user notifications
  static Future<Map<String, dynamic>> getUserNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'unreadOnly': unreadOnly.toString(),
      };

      final uri = Uri.parse('${ApiService.base}$baseUrl').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch notifications: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  /// Mark notification as read
  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('${ApiService.base}$baseUrl/$notificationId/read'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to mark notification as read: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('${ApiService.base}$baseUrl/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to mark all notifications as read: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiService.base}$baseUrl/$notificationId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete notification: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting notification: $e');
    }
  }

  /// Get unread count
  static Future<int> getUnreadCount() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/unread-count'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unreadCount'] ?? 0;
      } else {
        throw Exception('Failed to get unread count: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting unread count: $e');
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
