import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'api_service.dart';
import 'auth_service.dart';

class IdentityVerificationService {
  static const String baseUrl = '/api/identity-verification';

  /// Send email verification code
  static Future<Map<String, dynamic>> sendEmailVerification() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/send-email-verification'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'expiresIn': data['expiresIn']
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to send verification code');
      }
    } catch (e) {
      throw Exception('Error sending verification code: $e');
    }
  }

  /// Verify email code
  static Future<Map<String, dynamic>> verifyEmailCode(String code) async {
    try {
      final token = await AuthService.getValidToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/verify-email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'code': code}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update user verification status
        await AuthService.refreshUserData();

        return {
          'success': true,
          'message': data['message'],
          'nextStep': data['nextStep']
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to verify code');
      }
    } catch (e) {
      throw Exception('Error verifying code: $e');
    }
  }

  /// Upload identity documents
  static Future<Map<String, dynamic>> uploadDocuments({
    required File cnicFront,
    required File cnicBack,
    required File selfie,
    String? cnicNumber,
  }) async {
    try {
      final token = await AuthService.getValidToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.base}$baseUrl/upload-documents'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add files with explicit MIME type detection
      String? frontMimeType = lookupMimeType(cnicFront.path);
      String? backMimeType = lookupMimeType(cnicBack.path);
      String? selfieMimeType = lookupMimeType(selfie.path);
      
      request.files.add(await http.MultipartFile.fromPath(
        'cnicFront', 
        cnicFront.path,
        contentType: MediaType.parse(frontMimeType ?? 'image/jpeg'),
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'cnicBack', 
        cnicBack.path,
        contentType: MediaType.parse(backMimeType ?? 'image/jpeg'),
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'selfie', 
        selfie.path,
        contentType: MediaType.parse(selfieMimeType ?? 'image/jpeg'),
      ));
      
      // Add CNIC number as form field if provided
      if (cnicNumber != null && cnicNumber.isNotEmpty) {
        request.fields['cnicNumber'] = cnicNumber;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update user verification status after document upload
        await AuthService.refreshUserData();

        return {
          'success': true,
          'message': data['message'],
          'status': data['status']
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to upload documents');
      }
    } catch (e) {
      throw Exception('Error uploading documents: $e');
    }
  }

  /// Get verification status
  static Future<Map<String, dynamic>> getVerificationStatus() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to get verification status');
      }
    } catch (e) {
      throw Exception('Error getting verification status: $e');
    }
  }

  /// Check if user needs identity verification
  static Future<bool> needsVerification() async {
    try {
      final status = await getVerificationStatus();
      return status['status'] != 'verified';
    } catch (e) {
      return true; // Assume verification needed if error
    }
  }

  /// Get verification step
  static Future<String> getCurrentStep() async {
    try {
      final status = await getVerificationStatus();
      final currentStatus = status['status'] ?? 'not_started';

      switch (currentStatus) {
        case 'not_started':
        case 'pending_email':
          return 'email_verification';
        case 'email_verified':
          return 'document_upload';
        case 'documents_uploaded':
        case 'under_review':
          return 'under_review';
        case 'verified':
          return 'completed';
        case 'rejected':
          return 'rejected';
        default:
          return 'email_verification';
      }
    } catch (e) {
      return 'email_verification';
    }
  }
}
