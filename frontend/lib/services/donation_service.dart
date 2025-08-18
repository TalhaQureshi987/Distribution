import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/donation_model.dart';
import 'api_service.dart';

class DonationService {
  static const String baseUrl = '/api/donations';

  DonationService._(); // prevent instantiation

  /// -----------------------------
  /// JSON-based create (image URLs)
  /// -----------------------------
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
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
          'notes': notes,
          'isUrgent': isUrgent,
          'images': images,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DonationModel.fromJson(data['donation']);
      } else {
        throw Exception('Failed to create donation: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating donation: $e');
    }
  }

  /// ------------------------------------
  /// Multipart create (File upload support)
  /// ------------------------------------
  /// Use this when you have a File (e.g., from ImagePicker)
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
    File? imageFile,
    List<String> extraImageUrls = const [],
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

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
      if (notes != null) request.fields['notes'] = notes;
      if (extraImageUrls.isNotEmpty) request.fields['images'] = jsonEncode(extraImageUrls);

      if (imageFile != null) {
        final stream = http.ByteStream(imageFile.openRead());
        final length = await imageFile.length();
        final multipartFile = http.MultipartFile(
          'image', // ensure backend expects this field name
          stream,
          length,
          filename: imageFile.path.split(Platform.pathSeparator).last,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final responseString = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 201 || streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseString);
        return DonationModel.fromJson(data['donation']);
      } else {
        throw Exception('Failed to create donation (multipart): ${streamedResponse.statusCode} - $responseString');
      }
    } catch (e) {
      throw Exception('Error creating donation with file: $e');
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

      final uri = Uri.parse('${ApiService.base}$baseUrl').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['donations'] as List)
            .map((json) => DonationModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch donations: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching donations: $e');
    }
  }

  /// -----------------------------
  /// Get donation by ID
  /// -----------------------------
  static Future<DonationModel> getDonationById(String donationId) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/$donationId');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DonationModel.fromJson(data['donation']);
      } else {
        throw Exception('Failed to fetch donation: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching donation: $e');
    }
  }

  /// -----------------------------
  /// Get user's donations
  /// -----------------------------
  static Future<List<DonationModel>> getUserDonations() async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/my-donations');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['donations'] as List)
            .map((json) => DonationModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch user donations: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching user donations: $e');
    }
  }

  /// -----------------------------
  /// Reserve donation
  /// -----------------------------
  static Future<DonationModel> reserveDonation(String donationId) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/$donationId/reserve');
      final response = await http.patch(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DonationModel.fromJson(data['donation']);
      } else {
        throw Exception('Failed to reserve donation: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error reserving donation: $e');
    }
  }

  /// -----------------------------
  /// Update donation status
  /// -----------------------------
  static Future<DonationModel> updateDonationStatus(String donationId, String status) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('${ApiService.base}$baseUrl/$donationId/status');
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DonationModel.fromJson(data['donation']);
      } else {
        throw Exception('Failed to update donation status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
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
      final response = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete donation: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting donation: $e');
    }
  }

  /// -----------------------------
  /// Helper: get token from SharedPreferences
  /// -----------------------------
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }
}
