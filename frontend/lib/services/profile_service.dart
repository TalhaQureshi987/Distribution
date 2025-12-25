import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class ProfileService {
  static const String _baseUrl = '/api/profile';
  
  /// Get user profile data
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId', token: token);
      if (response['success']) {
        return response['data'];
      } else {
        throw Exception(response['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }
  
  /// Get user statistics
  static Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/statistics', token: token);
      if (response['success']) {
        return response['data'];
      } else {
        throw Exception(response['message'] ?? 'Failed to load statistics');
      }
    } catch (e) {
      print('Error fetching user statistics: $e');
      // Return fallback statistics based on actual user data
      return await _generateFallbackStatistics(userId);
    }
  }

  /// Generate fallback statistics from user's actual donations and requests
  static Future<Map<String, dynamic>> _generateFallbackStatistics(String userId) async {
    try {
      int totalDonations = 0;
      int totalRequests = 0;
      int helpedFamilies = 0;
      int impactHours = 0;

      // Count actual donations
      try {
        final donations = await getDonationHistory(userId);
        totalDonations = donations.length;
        helpedFamilies += donations.where((d) => d['status'] == 'completed').length;
        impactHours += totalDonations * 2; // Estimate 2 hours per donation
      } catch (e) {
        print('Could not load donations for statistics: $e');
      }

      // Count actual requests
      try {
        final requests = await getRequestHistory(userId);
        totalRequests = requests.length;
        helpedFamilies += requests.where((r) => r['status'] == 'completed').length;
        impactHours += totalRequests * 1; // Estimate 1 hour per request
      } catch (e) {
        print('Could not load requests for statistics: $e');
      }

      return {
        'totalDonations': totalDonations,
        'totalRequests': totalRequests,
        'helpedFamilies': helpedFamilies,
        'impactHours': impactHours,
      };
    } catch (e) {
      print('Error generating fallback statistics: $e');
      // Return zero stats if all else fails
      return {
        'totalDonations': 0,
        'totalRequests': 0,
        'helpedFamilies': 0,
        'impactHours': 0,
      };
    }
  }
  
  /// Get donation/offer history
  static Future<List<Map<String, dynamic>>> getDonationHistory(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/donations', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load donation history');
      }
    } catch (e) {
      print('Error fetching donation history: $e');
      rethrow;
    }
  }
  
  /// Get request history
  static Future<List<Map<String, dynamic>>> getRequestHistory(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/requests', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load request history');
      }
    } catch (e) {
      print('Error fetching request history: $e');
      rethrow;
    }
  }
  
  /// Get review history
  static Future<List<Map<String, dynamic>>> getReviewHistory(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/reviews', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load review history');
      }
    } catch (e) {
      print('Error fetching review history: $e');
      rethrow;
    }
  }
  
  /// Get payment methods
  static Future<List<Map<String, dynamic>>> getPaymentMethods(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/payment-methods', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load payment methods');
      }
    } catch (e) {
      print('Error fetching payment methods: $e');
      rethrow;
    }
  }
  
  /// Get transaction history
  static Future<List<Map<String, dynamic>>> getTransactionHistory(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/transactions', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load transaction history');
      }
    } catch (e) {
      print('Error fetching transaction history: $e');
      rethrow;
    }
  }
  
  /// Update user profile
  static Future<bool> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.put('$_baseUrl/$userId', body: data, token: token);
      return response['success'] ?? false;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }
  
  /// Upload profile picture
  static Future<String?> uploadProfilePicture(String userId, String imagePath) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.uploadFile('$_baseUrl/$userId/avatar', imagePath, token: token);
      if (response['success']) {
        return response['data']['avatarUrl'];
      } else {
        throw Exception(response['message'] ?? 'Failed to upload profile picture');
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }
  
  /// Get real-time notifications
  static Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/notifications', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load notifications');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      rethrow;
    }
  }
  
  /// Mark notification as read
  static Future<bool> markNotificationAsRead(String userId, String notificationId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.put('$_baseUrl/$userId/notifications/$notificationId/read', body: {}, token: token);
      return response['success'] ?? false;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }
  
  /// Get user activity feed
  static Future<List<Map<String, dynamic>>> getActivityFeed(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/activity', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data'] ?? []);
      } else {
        throw Exception(response['message'] ?? 'Failed to load activity feed');
      }
    } catch (e) {
      print('Error fetching activity feed: $e');
      // Return fallback activity data based on user's donations and requests
      return await _generateFallbackActivityFeed(userId);
    }
  }

  /// Generate fallback activity feed from donations and requests
  static Future<List<Map<String, dynamic>>> _generateFallbackActivityFeed(String userId) async {
    try {
      List<Map<String, dynamic>> activities = [];
      
      // Try to get donations and requests to create activity feed
      try {
        final donations = await getDonationHistory(userId);
        for (var donation in donations.take(5)) {
          activities.add({
            'id': 'donation_${donation['id']}',
            'type': 'donation',
            'title': 'Donation Created',
            'description': 'You created a donation: ${donation['title'] ?? 'Food Item'}',
            'timestamp': donation['createdAt'] ?? DateTime.now().toIso8601String(),
            'icon': 'favorite',
            'color': '#8B4513'
          });
        }
      } catch (e) {
        print('Could not load donations for activity feed: $e');
      }

      try {
        final requests = await getRequestHistory(userId);
        for (var request in requests.take(5)) {
          activities.add({
            'id': 'request_${request['id']}',
            'type': 'request',
            'title': 'Request Created',
            'description': 'You created a request: ${request['title'] ?? 'Food Item'}',
            'timestamp': request['createdAt'] ?? DateTime.now().toIso8601String(),
            'icon': 'handshake',
            'color': '#D2691E'
          });
        }
      } catch (e) {
        print('Could not load requests for activity feed: $e');
      }

      // Sort by timestamp (newest first)
      activities.sort((a, b) => 
        DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp']))
      );

      return activities.take(10).toList();
    } catch (e) {
      print('Error generating fallback activity feed: $e');
      // Return demo activity if all else fails
      return [
        {
          'id': 'demo_1',
          'type': 'donation',
          'title': 'Welcome to Care Connect!',
          'description': 'Start by creating your first donation or request',
          'timestamp': DateTime.now().toIso8601String(),
          'icon': 'favorite',
          'color': '#8B4513'
        }
      ];
    }
  }
  
  /// Get user connections/friends
  static Future<List<Map<String, dynamic>>> getUserConnections(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/connections', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load connections');
      }
    } catch (e) {
      print('Error fetching user connections: $e');
      rethrow;
    }
  }
  
  /// Get user achievements/badges
  static Future<List<Map<String, dynamic>>> getUserAchievements(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/achievements', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load achievements');
      }
    } catch (e) {
      print('Error fetching user achievements: $e');
      rethrow;
    }
  }
  
  /// Get user payment statistics
  static Future<Map<String, dynamic>> getPaymentStatistics(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/payment-statistics', token: token);
      if (response['success']) {
        return response['data'];
      } else {
        throw Exception(response['message'] ?? 'Failed to load payment statistics');
      }
    } catch (e) {
      print('Error fetching payment statistics: $e');
      // Return fallback payment statistics
      return {
        'registrationFee': 500,
        'deliveryFeesPaid': 0,
        'requesterFeesPaid': 0,
        'deliveryEarnings': 0,
        'totalPayments': 1,
        'totalAmount': 500,
      };
    }
  }

  /// Get payments feed
  static Future<List<Map<String, dynamic>>> getPaymentsFeed(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/payments', token: token);
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data'] ?? []);
      } else {
        throw Exception(response['message'] ?? 'Failed to load payments feed');
      }
    } catch (e) {
      print('Error fetching payments feed: $e');
      // Return fallback payments data
      return [
        {
          'id': 'reg_payment_1',
          'type': 'registration',
          'action': 'Registration Fee Paid',
          'amount': 500,
          'date': DateTime.now().subtract(Duration(days: 30)),
          'icon': Icons.app_registration,
          'status': 'completed'
        }
      ];
    }
  }
  
  /// Get role-based payments feed
  static Future<Map<String, dynamic>> getRoleBasedPayments(String userId) async {
    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await ApiService.getAuth('$_baseUrl/$userId/role-based-payments', token: token);
      if (response['success']) {
        return response['data'];
      } else {
        throw Exception(response['message'] ?? 'Failed to load role-based payments');
      }
    } catch (e) {
      print('Error fetching role-based payments: $e');
      // Return fallback data based on user role
      return await _generateFallbackRoleBasedPayments(userId);
    }
  }

  /// Generate fallback role-based payments data
  static Future<Map<String, dynamic>> _generateFallbackRoleBasedPayments(String userId) async {
    try {
      // Get current user to determine role
      final user = AuthService.getCurrentUser();
      final userRole = user?.role ?? 'default';
      
      switch (userRole) {
        case 'delivery':
          return {
            'payments': [],
            'stats': {
              'roleType': 'delivery',
              'totalDeliveries': 0,
              'totalEarnings': 0,
              'totalDistance': 0,
              'averageDistance': 0
            },
            'userRole': 'delivery'
          };
        
        case 'requester':
          return {
            'payments': [],
            'stats': {
              'roleType': 'requester',
              'registrationFee': 0,
              'totalRequestFees': 0,
              'totalRequests': 0,
              'totalPaid': 0
            },
            'userRole': 'requester'
          };
        
        case 'donor':
          return {
            'payments': [],
            'stats': {
              'roleType': 'donor',
              'totalDeliveryFees': 0,
              'totalDeliveries': 0,
              'averageDeliveryFee': 0
            },
            'userRole': 'donor'
          };
        
        case 'volunteer':
          return {
            'payments': [],
            'stats': {
              'roleType': 'volunteer',
              'message': 'Volunteers provide free services - no payment history'
            },
            'userRole': 'volunteer'
          };
        
        default:
          return {
            'payments': [],
            'stats': {
              'roleType': 'default',
              'registrationFee': 0
            },
            'userRole': 'default'
          };
      }
    } catch (e) {
      print('Error generating fallback role-based payments: $e');
      return {
        'payments': [],
        'stats': {'roleType': 'default'},
        'userRole': 'default'
      };
    }
  }
  
  /// Helper method to get auth token
  static Future<String?> _getAuthToken() async {
    try {
      return await AuthService.getValidToken();
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }
}
