// lib/services/donation_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/donation_model.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../config/config.dart'; // Import AppConfig

class DonationService {
  // Keep relative path; combined with ApiService.base when building URIs
  static const String baseUrl = '/api/donations';

  DonationService._(); // prevent instantiation

  /// -----------------------------
  /// JSON-based create (image URLs)
  /// -----------------------------
  /// Use this when you already have remote image URLs and want to send JSON.
  static Future<List<DonationModel>> getDonations() async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl');

      print('🔍 DONATION SERVICE - getDonations()');
      print('🔍 API Base URL: ${ApiService.base}');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final headers = AppConfig.getHeaders(
        ApiService.base,
      ); // Use AppConfig to get headers
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      print('🔍 Headers: $headers');
      print('🔍 Making HTTP GET request...');

      final response = await http
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('💥 HTTP Request TIMEOUT after 30 seconds');
              throw TimeoutException(
                'Request timeout',
                const Duration(seconds: 30),
              );
            },
          );

      print('🔍 HTTP Response received!');
      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Headers: ${response.headers}');
      print('🔍 Response Body Length: ${response.body.length}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('🔍 Parsing JSON response...');
        final List<dynamic> data = jsonDecode(response.body);
        print('🔍 JSON parsed successfully. Items count: ${data.length}');
        final donations = data
            .map((json) => DonationModel.fromJson(json))
            .toList();
        print('🔍 DonationModel objects created: ${donations.length}');
        return donations;
      } else {
        print('💥 Non-200 status code: ${response.statusCode}');
        throw Exception('Failed to load donations: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('💥 Timeout Error in getDonations: $e');
      throw Exception('Request timeout: $e');
    } catch (e) {
      print('💥 Error in getDonations: $e');
      throw Exception('Error fetching donations: $e');
    }
  }

  static Future<DonationModel> createDonation({
    required String title,
    required String description,
    required String foodType,
    required int quantity,
    required String quantityUnit,
    required DateTime expiryDate,
    required String pickupAddress,
    required double latitude,
    required double longitude,
    String? notes,
    bool isUrgent = false,
    List<String> images = const [], // pass remote URLs here
    // payment integration
    double? distance,
    double? paymentAmount,
    String? paymentStatus,
    String? stripePaymentIntentId,
    String? deliveryOption,
    String? foodName,
    String? foodCategory,
  }) async {
    // Basic client-side validation
    if (title.trim().isEmpty) throw Exception('Title is required.');
    if (description.trim().isEmpty) throw Exception('Description is required.');
    if (quantityUnit.trim().isEmpty)
      throw Exception('quantityUnit is required.');

    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl');

      print('🔍 DONATION SERVICE - createDonation()');
      print('🔍 API Base URL: ${ApiService.base}');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final headers = AppConfig.getHeaders(
        ApiService.base,
      ); // Use AppConfig to get headers
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'title': title,
              'description': description,
              'foodType': foodType,
              'quantity': quantity,
              'quantityUnit': quantityUnit,
              'expiryDate': expiryDate.toIso8601String(),
              'pickupAddress': pickupAddress,
              'latitude': latitude,
              'longitude': longitude,
              'notes': notes ?? '',
              'isUrgent': isUrgent,
              'images': images,
              if (deliveryOption != null) 'deliveryOption': deliveryOption,
              if (distance != null) 'distance': distance,
              if (paymentAmount != null) 'paymentAmount': paymentAmount,
              if (paymentStatus != null) 'paymentStatus': paymentStatus,
              if (stripePaymentIntentId != null)
                'stripePaymentIntentId': stripePaymentIntentId,
              if (foodName != null) 'foodName': foodName,
              if (foodCategory != null) 'foodCategory': foodCategory,
            }),
          )
          .timeout(const Duration(seconds: 25));

      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DonationModel.fromJson(data['donation']);
      } else {
        // Provide server body for debugging
        throw Exception(
          'Failed to create donation: ${response.statusCode} - ${response.body}',
        );
      }
    } on TimeoutException {
      throw Exception(
        'Timed out while creating donation. Please check your connection and try again.',
      );
    } catch (e) {
      print('💥 Error in createDonation: $e');
      throw Exception('Error creating donation: $e');
    }
  }

  /// -----------------------------
  /// Fetch donations (list / filters)
  /// -----------------------------
  static Future<List<DonationModel>> getAvailableDonations({
    String? foodType,
    String? location,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isUrgent,
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

      final uri = Uri.parse(
        '${ApiService.base}$baseUrl',
      ).replace(queryParameters: queryParams);

      print('🔍 DONATION SERVICE - getAvailableDonations()');
      print('🔍 API Base URL: ${ApiService.base}');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final headers = AppConfig.getHeaders(
        ApiService.base,
      ); // Use AppConfig to get headers
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // Support both shapes: root list or { donations: [...] }
        if (decoded is List) {
          return decoded.map((json) => DonationModel.fromJson(json)).toList();
        }
        if (decoded is Map && decoded['donations'] is List) {
          return (decoded['donations'] as List)
              .map((json) => DonationModel.fromJson(json))
              .toList();
        }
        // Fallback: attempt to treat entire decoded as a single donation map
        if (decoded is Map) {
          return [DonationModel.fromJson(Map<String, dynamic>.from(decoded))];
        }
        return const <DonationModel>[];
      } else {
        throw Exception(
          'Failed to fetch donations: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Error in getAvailableDonations: $e');
      throw Exception('Error fetching donations: $e');
    }
  }

  /// -----------------------------
  /// Get user's donations
  /// -----------------------------
  static Future<List<DonationModel>> getUserDonations() async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/my-donations');

      print('🔍 DONATION SERVICE - getUserDonations()');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final headers = AppConfig.getHeaders(ApiService.base);
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('💥 HTTP Request TIMEOUT after 30 seconds');
              throw TimeoutException(
                'Request timeout',
                const Duration(seconds: 30),
              );
            },
          );

      print('🔍 HTTP Response received!');
      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> donationsJson = data['donations'] ?? [];
        final donations = donationsJson
            .map((json) => DonationModel.fromJson(json))
            .toList();
        print('🔍 User donations loaded: ${donations.length}');
        return donations;
      } else {
        print('💥 Non-200 status code: ${response.statusCode}');
        throw Exception(
          'Failed to load user donations: ${response.statusCode}',
        );
      }
    } on TimeoutException catch (e) {
      print('💥 Timeout Error in getUserDonations: $e');
      throw Exception('Request timeout: $e');
    } catch (e) {
      print('💥 Error in getUserDonations: $e');
      throw Exception('Error fetching user donations: $e');
    }
  }

  /// Get donation statistics for dashboard
  static Future<Map<String, dynamic>> getDonationStats() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '${ApiService.base}$baseUrl/stats',
        token: token,
      );
      return response['stats'] ?? {};
    } on AuthException catch (e) {
      print('⚠️ Authentication error in getDonationStats: ${e.message}');
      // Don't throw - return empty stats to prevent dashboard crash
      return {};
    } catch (e) {
      print('Error getting donation stats: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      print('📊 DonationService: Getting dashboard stats...');
      final token = await AuthService.getValidToken();

      final response = await ApiService.getJson(
        '/api/donations/dashboard-stats',
        token: token,
      );

      print('📊 DonationService: Raw stats response: $response');

      // Handle different response structures
      Map<String, dynamic> stats = {};

      if (response['success'] == true && response['stats'] != null) {
        stats = Map<String, dynamic>.from(response['stats']);
      } else if (response is Map<String, dynamic>) {
        stats = response;
      }

      print('📊 DonationService: Processed stats: $stats');
      return stats;
    } catch (e) {
      print('❌ Error getting donation dashboard stats: $e');
      // Return empty stats instead of throwing to prevent dashboard crash
      return {
        'overview': {
          'totalDonations': 0,
          'pendingDonations': 0,
          'verifiedDonations': 0,
          'completedDonations': 0,
          'pendingVerificationDonations': 0,
        },
        'foodTypeBreakdown': {
          'food': {'total': 0},
          'medicine': {'total': 0},
          'clothes': {'total': 0},
          'other': {'total': 0},
        },
        'deliveryBreakdown': {},
        'recentActivity': [],
        'monthlyTrends': {},
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get user donations by userId (for dashboard)
  static Future<List<Map<String, dynamic>>> getUserDonationsForDashboard(
    String userId,
  ) async {
    print(
      '🏠 DASHBOARD SERVICE - getUserDonationsForDashboard() called with userId: $userId',
    );
    try {
      print('🏠 DASHBOARD SERVICE - Calling getUserDonations()...');
      final donations = await getUserDonations();
      print(
        '🏠 DASHBOARD SERVICE - Received ${donations.length} donations from getUserDonations()',
      );

      final mappedDonations = donations
          .map(
            (donation) => {
              'id': donation.id,
              'foodType': donation.foodType,
              'quantity': '${donation.quantity} ${donation.quantityUnit}',
              'status': donation.status,
              'createdAt': donation.createdAt
                  .toIso8601String(), // Convert DateTime to String
            },
          )
          .toList();

      print(
        '🏠 DASHBOARD SERVICE - Mapped ${mappedDonations.length} donations for dashboard',
      );
      return mappedDonations;
    } catch (e) {
      print('💥 DASHBOARD SERVICE ERROR: $e');
      print('💥 DASHBOARD SERVICE ERROR TYPE: ${e.runtimeType}');
      // Return empty list for dashboard compatibility
      return [];
    }
  }

  /// Get recent donations for dashboard display
  static Future<List<Map<String, dynamic>>> getRecentDonations() async {
    print('🏠 DASHBOARD SERVICE - getRecentDonations() called');
    try {
      print('🏠 DASHBOARD SERVICE - Calling getUserDonations()...');
      final donations = await getUserDonations();
      print(
        '🏠 DASHBOARD SERVICE - Received ${donations.length} donations from getUserDonations()',
      );

      // Sort by creation date and take the most recent ones
      donations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final recentDonations = donations.take(5).toList();

      final mappedDonations = recentDonations
          .map(
            (donation) => {
              'id': donation.id,
              'title': donation.title ?? 'Untitled Donation', // Include title
              'foodType':
                  donation.foodType ?? 'Other', // Ensure foodType is set
              'quantity': donation.quantity ?? 0,
              'quantityUnit': donation.quantityUnit ?? 'items',
              'status': donation.status ?? 'pending',
              'verificationStatus':
                  donation.status ??
                  'pending', // Use status as verificationStatus
              'createdAt': donation.createdAt
                  .toIso8601String(), // Convert DateTime to String
              'images': donation.images ?? [], // Include images for display
              'description': donation.description ?? '', // Include description
              'pickupAddress': donation.pickupAddress ?? '', // Include address
            },
          )
          .toList();

      print(
        '🏠 DASHBOARD SERVICE - Mapped ${mappedDonations.length} recent donations for dashboard',
      );
      return mappedDonations;
    } catch (e) {
      print('💥 DASHBOARD SERVICE ERROR: $e');
      print('💥 DASHBOARD SERVICE ERROR TYPE: ${e.runtimeType}');
      // Return empty list for dashboard compatibility
      return [];
    }
  }

  /// Complete donation (mark as received by Care Connect team)
  static Future<void> completeDonation(
    String donationId, {
    String? notes,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/$donationId/complete');

      print('🔍 DONATION SERVICE - completeDonation()');
      print('🔍 Full URL: $uri');
      print('🔍 Donation ID: $donationId');

      final headers = AppConfig.getHeaders(ApiService.base);
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = <String, dynamic>{};
      if (notes != null && notes.isNotEmpty) {
        body['notes'] = notes;
      }

      final response = await http
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('💥 HTTP Request TIMEOUT after 30 seconds');
              throw TimeoutException(
                'Request timeout',
                const Duration(seconds: 30),
              );
            },
          );

      print('🔍 HTTP Response received!');
      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Donation completed successfully');
      } else {
        print('💥 Non-200 status code: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to complete donation');
      }
    } on TimeoutException catch (e) {
      print('💥 Timeout Error in completeDonation: $e');
      throw Exception('Request timeout: $e');
    } catch (e) {
      print('💥 Error in completeDonation: $e');
      throw Exception('Error completing donation: $e');
    }
  }

  /// ------------------------------------
  /// Multipart create (File upload support)
  /// ------------------------------------
  /// Use this when you have local File(s) (e.g., from ImagePicker).
  /// - imageFiles: List<File> local files to upload (optional).
  /// - extraImageUrls: list of already-hosted image URLs to include (optional).
  ///
  /// Notes:
  /// - Files are attached with configurable field name (default 'images').
  ///   If your backend expects a different field name (e.g. 'image'), use fileFieldName param.
  /// - extraImageUrls will be sent as a JSON-encoded string field 'images_meta'
  ///   so backend can merge those with uploaded file URLs. Adjust as needed.
  static Future<DonationModel> createDonationWithFile({
    required String title,
    required String description,
    required String foodType,
    required int quantity,
    required String quantityUnit,
    required DateTime expiryDate,
    required String pickupAddress,
    required double latitude,
    required double longitude,
    String? notes,
    bool isUrgent = false,
    List<File>? imageFiles, // multiple local files
    List<String> extraImageUrls = const [], // already-hosted URLs
    String fileFieldName =
        'images', // change to 'image' if backend expects single-field name
    // payment integration
    double? distance,
    double? paymentAmount,
    String? paymentStatus,
    String? stripePaymentIntentId,
    String? deliveryOption,
    String? foodName,
    String? foodCategory,
  }) async {
    // Client-side validation to avoid obvious 400s
    if (title.trim().isEmpty) {
      throw Exception('Title is required (client check).');
    }
    if (description.trim().isEmpty) {
      throw Exception('Description is required (client check).');
    }
    if (quantityUnit.trim().isEmpty) {
      throw Exception('quantityUnit is required (client check).');
    }

    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl');

      print('🔍 DONATION SERVICE - createDonationWithFile()');
      print('🔍 API Base URL: ${ApiService.base}');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final request = http.MultipartRequest('POST', uri);

      final headers = AppConfig.getHeaders(
        ApiService.base,
      ); // Use AppConfig to get headers
      request.headers.addAll(headers);
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add fields (all values must be strings)
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['foodType'] = foodType;
      request.fields['quantity'] = quantity.toString();
      request.fields['quantityUnit'] = quantityUnit;
      request.fields['expiryDate'] = expiryDate.toIso8601String();
      request.fields['pickupAddress'] = pickupAddress;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['isUrgent'] = isUrgent.toString();
      request.fields['deliveryOption'] = deliveryOption ?? 'Self delivery';
      if (notes != null) request.fields['notes'] = notes;
      if (distance != null) request.fields['distance'] = distance.toString();
      if (paymentAmount != null)
        request.fields['paymentAmount'] = paymentAmount.toString();
      if (paymentStatus != null)
        request.fields['paymentStatus'] = paymentStatus;
      if (stripePaymentIntentId != null)
        request.fields['stripePaymentIntentId'] = stripePaymentIntentId;
      if (foodName != null) request.fields['foodName'] = foodName;
      if (foodCategory != null) request.fields['foodCategory'] = foodCategory;

      if (extraImageUrls.isNotEmpty) {
        request.fields['images_meta'] = jsonEncode(extraImageUrls);
      }

      // Attach files under the configurable field name (default: 'images')
      int attached = 0;
      if (imageFiles != null && imageFiles.isNotEmpty) {
        for (final file in imageFiles) {
          try {
            if (!file.existsSync()) continue;
            final mimeType =
                lookupMimeType(file.path) ?? 'application/octet-stream';
            final parts = mimeType.split('/');
            final multipart = await http.MultipartFile.fromPath(
              fileFieldName,
              file.path,
              filename: file.path.split(Platform.pathSeparator).last,
              contentType: MediaType(
                parts[0],
                parts.length > 1 ? parts[1] : '',
              ),
            );
            request.files.add(multipart);
            attached++;
          } catch (fileErr) {
            // continue attaching other files but log
            print('Failed to attach file ${file.path}: $fileErr');
          }
        }
      }

      // Debug: print fields and file count before sending
      print('--- createDonationWithFile DEBUG ---');
      request.fields.forEach((k, v) {
        // avoid dumping huge values; truncate large strings
        final display = v.toString().length > 300
            ? v.toString().substring(0, 300) + '...'
            : v;
        print('field: $k => $display');
      });
      print('Attached files count: $attached (field name: $fileFieldName)');
      print('Endpoint: $uri');
      print('Headers: ${request.headers}');
      print('-------------------------------------');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 40),
      );
      // Decode response stream safely (no bytesToString on Stream<List<int>> in this SDK)
      final responseString = await streamedResponse.stream
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 40))
          .join();

      print('🔍 Response Status: ${streamedResponse.statusCode}');
      print('🔍 Response Body: $responseString');

      if (streamedResponse.statusCode == 201 ||
          streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseString);
        return DonationModel.fromJson(data['donation']);
      } else {
        // Debug: include server response (useful to read exact validation message)
        print('SERVER ERROR (${streamedResponse.statusCode}): $responseString');

        throw Exception(
          'Failed to create donation (multipart): ${streamedResponse.statusCode} - $responseString',
        );
      }
    } on TimeoutException {
      throw Exception(
        'Timed out while uploading donation. The image upload or network is too slow.',
      );
    } catch (e) {
      print('💥 Error in createDonationWithFile: $e');
      throw Exception('Error creating donation with file: $e');
    }
  }

  /// -----------------------------
  /// Get donation by ID
  /// -----------------------------
  static Future<DonationModel> getDonationById(String donationId) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/$donationId');

      print('🔍 DONATION SERVICE - getDonationById()');
      print('🔍 API Base URL: ${ApiService.base}');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final headers = AppConfig.getHeaders(
        ApiService.base,
      ); // Use AppConfig to get headers
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DonationModel.fromJson(data['donation']);
      } else {
        throw Exception(
          'Failed to fetch donation: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Error in getDonationById: $e');
      throw Exception('Error fetching donation: $e');
    }
  }

  /// -----------------------------
  /// Reserve donation
  /// -----------------------------
  static Future<DonationModel> reserveDonation(String donationId) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/$donationId/reserve');

      print('🔍 DONATION SERVICE - reserveDonation()');
      print('🔍 API Base URL: ${ApiService.base}');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final headers = AppConfig.getHeaders(
        ApiService.base,
      ); // Use AppConfig to get headers
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.patch(uri, headers: headers);

      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DonationModel.fromJson(data['donation']);
      } else {
        throw Exception(
          'Failed to reserve donation: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Error in reserveDonation: $e');
      throw Exception('Error reserving donation: $e');
    }
  }

  /// -----------------------------
  /// Update donation status
  /// -----------------------------
  static Future<DonationModel> updateDonationStatus(
    String donationId,
    String status,
  ) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/$donationId/status');

      print('🔍 DONATION SERVICE - updateDonationStatus()');
      print('🔍 API Base URL: ${ApiService.base}');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final headers = AppConfig.getHeaders(
        ApiService.base,
      ); // Use AppConfig to get headers
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode({'status': status}),
      );

      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DonationModel.fromJson(data['donation']);
      } else {
        throw Exception(
          'Failed to update donation status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Error in updateDonationStatus: $e');
      throw Exception('Error updating donation status: $e');
    }
  }

  /// -----------------------------
  /// Delete donation
  /// -----------------------------
  static Future<void> deleteDonation(String donationId) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/$donationId');

      print('🔍 DONATION SERVICE - deleteDonation()');
      print('🔍 API Base URL: ${ApiService.base}');
      print('🔍 Full URL: $uri');
      print('🔍 Token: ${token.isNotEmpty ? "Present" : "Missing"}');

      final headers = AppConfig.getHeaders(
        ApiService.base,
      ); // Use AppConfig to get headers
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.delete(uri, headers: headers);

      print('🔍 Response Status: ${response.statusCode}');
      print('🔍 Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete donation: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Error in deleteDonation: $e');
      throw Exception('Error deleting donation: $e');
    }
  }

  /// -----------------------------
  /// Helper: get valid token with auto-refresh
  /// -----------------------------
  static Future<String> _getToken() async {
    try {
      return await AuthService.getValidToken();
    } catch (e) {
      print('⚠️ Failed to get valid token in DonationService: $e');
      // Return empty string to allow graceful degradation
      return '';
    }
  }
}
