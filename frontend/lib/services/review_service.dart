import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review_model.dart';
import 'api_service.dart';

class ReviewService {
  static const String baseUrl = '/api/reviews';

  /// Get user reviews
  static Future<Map<String, dynamic>> getUserReviews() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load reviews: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load reviews: $e');
    }
  }

  /// Create a new review
  static Future<ReviewModel> createReview({
    required String reviewedUserId,
    required String reviewedUserName,
    required int rating,
    required String comment,
    String? donationId,
    String? requestId,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reviewedUserId': reviewedUserId,
          'reviewedUserName': reviewedUserName,
          'rating': rating,
          'comment': comment,
          'donationId': donationId,
          'requestId': requestId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ReviewModel.fromJson(data['review']);
      } else {
        throw Exception('Failed to create review: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create review: $e');
    }
  }

  /// Update a review
  static Future<ReviewModel> updateReview({
    required String reviewId,
    required int rating,
    required String comment,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${ApiService.base}$baseUrl/$reviewId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'rating': rating, 'comment': comment}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ReviewModel.fromJson(data['review']);
      } else {
        throw Exception('Failed to update review: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update review: $e');
    }
  }

  /// Delete a review
  static Future<void> deleteReview(String reviewId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiService.base}$baseUrl/$reviewId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete review: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete review: $e');
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
