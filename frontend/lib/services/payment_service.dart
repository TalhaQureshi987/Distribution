import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../utils/location_utils.dart';

class PaymentService {
  static const String baseUrl = '/api/payments';

  /// Create payment intent for donations, requests, or volunteer delivery
  Future<Map<String, dynamic>?> createPaymentIntent({
    required String type,
    required double distance,
    Map<String, dynamic>? itemData,
  }) async {
    try {
      final token = await _getToken();

      // Map frontend types to backend endpoints
      String endpoint;
      if (type == 'donate' || type == 'donation') {
        endpoint = 'donation';
      } else if (type == 'request') {
        endpoint = 'request';
      } else if (type == 'volunteer') {
        endpoint = 'volunteer';
      } else {
        throw Exception('Invalid payment type: $type');
      }

      print('💰 PaymentService: Creating $endpoint payment intent');
      print('💰 Distance: ${distance}km');
      print('💰 Item data: $itemData');

      final response = await http
          .post(
            Uri.parse('${ApiService.base}$baseUrl/$endpoint-payment-intent'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'distance': distance,
              'latitude': itemData?['latitude'] ?? LocationUtils.centerLatitude,
              'longitude':
                  itemData?['longitude'] ?? LocationUtils.centerLongitude,
              'centerLat': LocationUtils.centerLatitude, // Karachi center
              'centerLng': LocationUtils.centerLongitude,
            }),
          )
          .timeout(const Duration(seconds: 20));

      print('💰 PaymentService: Response status: ${response.statusCode}');
      print('💰 PaymentService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result;
        } else {
          throw Exception(
            result['message'] ?? 'Payment intent creation failed',
          );
        }
      } else {
        final errorBody = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        throw Exception(
          errorBody['message'] ??
              'Failed to create payment intent: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      throw Exception(
        'Timed out while creating payment intent. Please try again.',
      );
    } catch (e) {
      print('❌ PaymentService: Payment intent creation failed: $e');
      throw Exception('Payment intent creation failed: $e');
    }
  }

  /// Calculate payment preview
  Future<Map<String, dynamic>?> calculatePaymentPreview({
    required String type,
    required double distance,
    double? latitude,
    double? longitude,
    String? deliveryOption,
  }) async {
    try {
      final token = await _getToken();

      // Ensure we have valid distance or coordinates
      if (distance <= 0 && (latitude == null || longitude == null)) {
        throw Exception(
          'Valid distance or coordinates required for payment calculation',
        );
      }

      print(
        '💰 PaymentService: Calculating preview for $type, deliveryOption: $deliveryOption, distance: ${distance}km, coords: ($latitude, $longitude)',
      );

      final response = await http
          .post(
            Uri.parse('${ApiService.base}$baseUrl/calculate-preview'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'type': type,
              'distance': distance,
              'latitude': latitude,
              'longitude': longitude,
              'deliveryOption': deliveryOption ?? 'Self delivery',
              'centerLat': LocationUtils.centerLatitude,
              'centerLng': LocationUtils.centerLongitude,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print(
        '💰 PaymentService: Preview response status: ${response.statusCode}',
      );
      print('💰 PaymentService: Preview response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print(
          '💰 PaymentService: Preview calculated successfully: ${result['paymentInfo']}',
        );
        return result;
      } else {
        throw Exception(
          'Failed to calculate payment preview: ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      throw Exception('Timed out while calculating payment preview.');
    } catch (e) {
      print('❌ PaymentService: Payment preview calculation failed: $e');
      throw Exception('Payment preview calculation failed: $e');
    }
  }

  /// Get delivery rates information
  Future<Map<String, dynamic>?> getDeliveryRates() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/delivery-rates'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get delivery rates: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get delivery rates: $e');
    }
  }

  /// Process payment - DEPRECATED: Use payment confirmation screen instead
  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String currency,
    required String paymentMethod,
    required String description,
    String? donationId,
    String? requestId,
  }) async {
    try {
      final token = await PaymentService()._getToken();
      // FIXED: Use /confirm endpoint instead of non-existent /process
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/confirm'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'paymentMethod': paymentMethod,
          'description': description,
          'donationId': donationId,
          'requestId': requestId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Payment failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Payment failed: $e');
    }
  }

  /// Get payment methods - DEPRECATED: Endpoint doesn't exist in backend
  static Future<Map<String, dynamic>> getPaymentMethods() async {
    try {
      final token = await PaymentService()._getToken();
      // TODO: This endpoint doesn't exist in backend - implement or remove
      throw Exception('Payment methods endpoint not implemented in backend');
      /*
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/methods'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to load payment methods: ${response.statusCode}',
        );
      }
      */
    } catch (e) {
      throw Exception('Failed to load payment methods: $e');
    }
  }

  /// Get payment history - DEPRECATED: Endpoint doesn't exist in backend
  static Future<Map<String, dynamic>> getPaymentHistory() async {
    try {
      final token = await PaymentService()._getToken();
      // TODO: This endpoint doesn't exist in backend - implement or remove
      throw Exception('Payment history endpoint not implemented in backend');
      /*
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/history'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to load payment history: ${response.statusCode}',
        );
      }
      */
    } catch (e) {
      throw Exception('Failed to load payment history: $e');
    }
  }

  /// Refund payment
  static Future<Map<String, dynamic>> refundPayment(String paymentId) async {
    try {
      final token = await PaymentService()._getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/$paymentId/refund'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Refund failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Refund failed: $e');
    }
  }

  /// Create payment intent for registration fee
  static Future<Map<String, dynamic>> createPaymentIntentForRegistrationFee({
    required int amount,
    required String currency,
    required String userId,
    required String description,
  }) async {
    try {
      print('🚀 Creating registration payment intent');
      print('   Amount: $amount');
      print('   Currency: $currency');
      print('   User ID: $userId');
      print('   Description: $description');

      final response = await ApiService.postJson(
        '/api/payments/create-registration-payment-intent',
        body: {
          'amount': amount,
          'currency': currency.toLowerCase(),
          'userId': userId,
          'description': description,
          'metadata': {
            'type': 'registration_fee',
            'userId': userId,
            'description': description,
          },
        },
      );

      print('🔍 Registration Payment Intent Response: $response');

      if (response['success'] == true) {
        return {
          'paymentIntentId': response['paymentIntentId'],
          'clientSecret': response['clientSecret'],
          'amount': response['amount'],
          'currency': response['currency'],
          'status': response['status'],
          'userId': userId,
          'description': description,
        };
      } else {
        throw Exception(
          response['message'] ?? 'Failed to create payment intent',
        );
      }
    } catch (e) {
      print('❌ Registration payment intent creation error: $e');
      throw Exception('Failed to create registration payment intent: $e');
    }
  }

  /// Process registration fee payment (500 PKR) - Updated for backend integration
  static Future<Map<String, dynamic>> processRegistrationFee({
    required Map<String, String> paymentMethod,
    required String userId,
  }) async {
    try {
      print('🚀 Starting registration fee payment');
      print('   userId: $userId');
      print(
        '   cardNumber: ${paymentMethod['cardNumber']?.replaceAll(RegExp(r'\d(?=\d{4})'), '*')}',
      );

      final response = await ApiService.postJson(
        '/api/payments/registration-fee',
        body: {
          'amount': 500,
          'currency': 'pkr',
          'userId': userId,
          'type': 'registration_fee',
          'paymentMethod': {
            'cardNumber': paymentMethod['cardNumber'],
            'expiryMonth': _getExpiryMonth(paymentMethod['expiry']),
            'expiryYear': _getExpiryYear(paymentMethod['expiry']),
            'cvc': paymentMethod['cvc'],
            'cardHolderName': paymentMethod['holder'],
          },
        },
      );

      print('🔍 Registration Payment Response: $response');

      return {
        'success': response['success'] == true,
        'message': response['message'] ?? 'Payment processed successfully',
        'paymentId': response['paymentId'],
        'user': response['user'],
      };
    } catch (e) {
      print('❌ Registration fee payment error: $e');
      return {'success': false, 'message': 'Payment failed: ${e.toString()}'};
    }
  }

  /// Confirm payment intent with Stripe (attach payment method and confirm)
  static Future<Map<String, dynamic>> confirmPaymentIntent({
    required String paymentIntentId,
    required String clientSecret,
    required Map<String, String> paymentMethod,
  }) async {
    try {
      print('🚀 Confirming payment intent with Stripe');
      print('   Payment Intent ID: $paymentIntentId');
      print('   Client Secret: ${clientSecret.substring(0, 20)}...');

      final response = await ApiService.postJson(
        '/api/payments/confirm-payment-intent',
        body: {
          'paymentIntentId': paymentIntentId,
          'clientSecret': clientSecret,
          'paymentMethod': paymentMethod,
        },
      );

      print('🔍 Stripe Confirmation Response: $response');

      if (response['success'] == true) {
        return {
          'success': true,
          'paymentIntentId': response['paymentIntentId'],
          'status': response['status'],
          'message': 'Payment confirmed successfully',
        };
      } else {
        throw Exception(response['message'] ?? 'Payment confirmation failed');
      }
    } catch (e) {
      print('❌ Payment confirmation error: $e');
      return {
        'success': false,
        'message': 'Payment confirmation failed: ${e.toString()}',
      };
    }
  }

  /// Complete registration payment (called after Stripe payment success)
  static Future<Map<String, dynamic>> completeRegistrationPayment({
    required String userId,
    required String paymentIntentId,
    required int amount,
  }) async {
    try {
      print('🚀 Starting completeRegistrationPayment');
      print('   userId: $userId');
      print('   paymentIntentId: $paymentIntentId');
      print('   amount: $amount');

      final response = await ApiService.postJson(
        '/api/auth/complete-registration-payment',
        body: {
          'userId': userId,
          'paymentIntentId': paymentIntentId,
          'amount': amount,
        },
      );

      print('🔍 Backend Response: $response');
      print('🔍 Response Type: ${response.runtimeType}');
      print('🔍 Success Field: ${response['success']}');
      print('🔍 Success Field Type: ${response['success'].runtimeType}');
      print('🔍 Message Field: ${response['message']}');

      final result = {
        'success': response['success'] == true,
        'message': response['message'] ?? 'Payment completed successfully',
        'user': response['user'],
      };

      print('🎯 Final Result: $result');
      return result;
    } catch (e) {
      print('❌ Complete registration payment error: $e');
      print('❌ Error Type: ${e.runtimeType}');
      print('❌ Error Details: ${e.toString()}');

      return {
        'success': false,
        'message': 'Payment completion failed: ${e.toString()}',
      };
    }
  }

  /// Process delivery payment (distance-based charges)
  static Future<Map<String, dynamic>> processDeliveryPayment({
    required String paymentIntentId,
    required Map<String, String> paymentMethod,
    required String type, // 'donation' or 'request'
    required double amount,
  }) async {
    try {
      print('🚀 Starting delivery payment processing');
      print('   paymentIntentId: $paymentIntentId');
      print('   type: $type');
      print('   amount: $amount PKR');

      final token = await PaymentService()._getToken();

      final response = await http.post(
        Uri.parse('${ApiService.base}/api/payments/confirm'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'paymentIntentId': paymentIntentId,
          'amount': amount,
          'type': type,
          'paymentMethod': {
            'cardNumber': paymentMethod['cardNumber'],
            'expiryMonth': _getExpiryMonth(paymentMethod['expiry']),
            'expiryYear': _getExpiryYear(paymentMethod['expiry']),
            'cvc': paymentMethod['cvc'],
            'cardHolderName': paymentMethod['holder'],
          },
        }),
      );

      print('🔍 Delivery Payment Response Status: ${response.statusCode}');
      print('🔍 Delivery Payment Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return {
          'success': result['success'] == true,
          'message': result['message'] ?? 'Payment processed successfully',
          'paymentId': result['paymentId'],
          'paymentRecordId': result['paymentRecordId'],
        };
      } else {
        final errorBody = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        throw Exception(
          errorBody['message'] ??
              'Payment failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Delivery payment error: $e');
      return {'success': false, 'message': 'Payment failed: ${e.toString()}'};
    }
  }

  static String _getExpiryMonth(String? expiry) {
    if (expiry != null && expiry.split('/').length > 0) {
      return expiry.split('/')[0];
    } else {
      return '';
    }
  }

  static String _getExpiryYear(String? expiry) {
    if (expiry != null && expiry.split('/').length > 1) {
      return expiry.split('/')[1];
    } else {
      return '';
    }
  }

  /// Get token from SharedPreferences
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }
}
