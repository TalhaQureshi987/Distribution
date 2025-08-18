import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user_model.dart';

class AuthService {
  static bool isLoggedIn = false;
  static UserModel? currentUser;

  /// Check if user is already logged in
  static Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      isLoggedIn = true;
      try {
        final res = await ApiService.getJson('/api/auth/profile', token: token);

        if (res.containsKey('user')) {
          currentUser = UserModel.fromJson(res['user']);
        }
      } catch (e) {
        isLoggedIn = false;
        await prefs.remove('token');
      }
    } else {
      isLoggedIn = false;
    }
  }

  /// Get current user - returns null if not logged in
  static UserModel? getCurrentUser() {
    return currentUser;
  }

  /// Register user
  static Future<void> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/register',
        body: {
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
        },
      );

      // Handle both 'token' and 'accessToken' keys
      String? authToken = res['token'] ?? res['accessToken'];

      if (authToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', authToken);
        isLoggedIn = true;
        if (res.containsKey('user')) {
          currentUser = UserModel.fromJson(res['user']);
        }
      } else {
        throw Exception(
          "Registration failed: No authentication token received",
        );
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Login user
  static Future<void> login(String email, String password) async {
    try {
      final res = await ApiService.postJson(
        '/api/login',
        body: {'email': email, 'password': password},
      );

      // Handle both 'token' and 'accessToken' keys
      String? authToken = res['token'] ?? res['accessToken'];

      if (authToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', authToken);
        isLoggedIn = true;

        if (res.containsKey('user')) {
          currentUser = UserModel.fromJson(res['user']);
        } else {
          await checkLogin();
        }
      } else {
        throw Exception("Login failed: No authentication token received");
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Logout user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    isLoggedIn = false;
    currentUser = null;
  }

  static String _parseError(dynamic e) {
    if (e is Exception) return e.toString();
    return 'Unknown error';
  }

  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }

  static Future<void> updateCurrentUser({
    required String name,
    required String email,
    required String phone,
    String? address,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${ApiService.base}/api/users/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          if (address != null) 'address': address,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user']) {
          currentUser = UserModel.fromJson(data['user']);
        }
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${ApiService.base}/api/users/change-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to change password: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }
}
