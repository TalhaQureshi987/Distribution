import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

class VerificationService {
  
  /// Check if user needs verification for actions
  static Future<Map<String, dynamic>> checkVerificationStatus() async {
    try {
      print('🔍 VerificationService: checkVerificationStatus called');
      final token = await _getToken();
      if (token == null) {
        print('🔍 VerificationService: No token found');
        return {'verified': false, 'error': 'Not logged in'};
      }

      print('🔍 VerificationService: Making API call to /api/auth/verification-status');
      final response = await ApiService.getJson('/api/auth/verification-status', token: token);
      print('🔍 VerificationService: API response: $response');
      
      return {
        'verified': response['verified'] ?? false,
        'emailVerified': response['emailVerified'] ?? false,
        'identityVerified': response['identityVerified'] ?? false,
        'verificationStatus': response['verificationStatus'] ?? 'pending',
      };
    } catch (e) {
      print('❌ Verification status check error: $e');
      return {'verified': false, 'error': e.toString()};
    }
  }

  /// Show verification prompt dialog
  static Future<bool> showVerificationPrompt(context, {String? action}) async {
    print('🔍 VerificationService: showVerificationPrompt called with action: $action');
    
    final status = await checkVerificationStatus();
    print('🔍 VerificationService: status received: $status');
    
    if (status['verified'] == true) {
      print('🔍 VerificationService: User is verified, allowing action');
      return true; // User is verified, allow action
    }

    print('🔍 VerificationService: User needs verification, showing dialog');
    
    // Check verification status and show appropriate message
    String title = 'Verification Required';
    String message = '';
    bool canProceed = false;
    
    if (status['emailVerified'] != true) {
      title = 'Email Verification Required';
      message = 'Please verify your email address to continue.';
      canProceed = true;
      print('🔍 VerificationService: Email verification required');
    } else if (status['verificationStatus'] == 'pending') {
      title = 'Verification In Process';
      message = 'Your identity verification is being reviewed by our admin team. Please wait for approval.';
      canProceed = false;
      print('🔍 VerificationService: Identity verification pending');
    } else if (status['verificationStatus'] == 'rejected') {
      title = 'Verification Rejected';
      message = 'Your identity verification was rejected. Please upload new documents.';
      canProceed = true;
      print('🔍 VerificationService: Identity verification rejected');
    } else {
      title = 'Identity Verification Required';
      message = 'Please upload your identity documents for verification.';
      canProceed = true;
      print('🔍 VerificationService: Identity verification required');
    }

    print('🔍 VerificationService: About to show dialog - title: $title, canProceed: $canProceed');

    // Show verification dialog
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        print('🔍 VerificationService: Dialog builder called');
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action != null 
                ? 'You need to complete verification to $action.'
                : 'You need to complete verification to perform this action.'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: status['verificationStatus'] == 'pending' 
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      status['verificationStatus'] == 'pending' 
                        ? Icons.hourglass_empty 
                        : Icons.badge,
                      color: status['verificationStatus'] == 'pending' 
                        ? Colors.orange 
                        : Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Expanded(child: Text(message)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('🔍 VerificationService: Cancel pressed');
                Navigator.of(context).pop(false);
              },
              child: Text('Cancel'),
            ),
            if (canProceed)
              ElevatedButton(
                onPressed: () {
                  print('🔍 VerificationService: Verify Now pressed');
                  Navigator.of(context).pop(true);
                  _navigateToVerification(context, status);
                },
                child: Text('Verify Now'),
              ),
            if (!canProceed)
              ElevatedButton(
                onPressed: () {
                  print('🔍 VerificationService: OK pressed');
                  Navigator.of(context).pop(false);
                },
                child: Text('OK'),
              ),
          ],
        );
      },
    ) ?? false;
  }

  /// Navigate to appropriate verification screen
  static void _navigateToVerification(context, Map<String, dynamic> status) {
    if (status['emailVerified'] != true) {
      // Navigate to email verification
      Navigator.pushNamed(context, '/email-otp-verification', arguments: {
        'email': AuthService.currentUser?.email ?? '',
        'userId': AuthService.currentUser?.id ?? '',
        'userData': {},
      });
    } else if (status['identityVerified'] != true) {
      // Navigate to identity verification
      Navigator.pushNamed(context, '/identity-verification');
    }
  }

  /// Get stored token
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
