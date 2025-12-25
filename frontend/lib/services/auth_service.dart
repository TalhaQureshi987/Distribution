import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user_model.dart';
import 'chat_service.dart';
import 'notification_service.dart';

class AuthService {
  static bool isLoggedIn = false;
  static UserModel? currentUser;
  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  /// Check if user is already logged in and restore session
  static Future<void> checkLogin() async {
    print('🔍 checkLogin() called');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final expiryString = prefs.getString('token_expiry');

    print('🔍 checkLogin - Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
    print('🔍 checkLogin - Expiry: $expiryString');

    if (token != null && token.isNotEmpty) {
      _cachedToken = token;
      print('✅ Token found, caching it');
      
      if (expiryString != null) {
        _tokenExpiry = DateTime.parse(expiryString);
        print('🔍 Token expiry parsed: $_tokenExpiry');
        
        if (_tokenExpiry!.isBefore(DateTime.now())) {
          print('❌ Token expired, clearing session');
          await _clearSession();
          return;
        } else {
          print('✅ Token still valid');
        }
      } else {
        print('⚠️ No expiry found, assuming token is valid');
      }

      isLoggedIn = true;
      print('🔓 Set isLoggedIn = true');
      
      try {
        print('👤 Fetching user profile...');
        final res = await ApiService.getJson('/api/auth/profile', token: token);
        
        if (res.containsKey('user') && res['user'] != null) {
          currentUser = UserModel.fromJson(res['user']);
          print('✅ User profile loaded: ${currentUser?.name}, Role: ${currentUser?.role}');
          
          // Validate user data completeness
          if (currentUser?.email == null || currentUser?.email?.isEmpty == true) {
            print('⚠️ User profile incomplete, fetching from stored data');
            await _loadStoredUserData();
          }
        } else {
          print('❌ No user data in profile response, loading from storage');
          await _loadStoredUserData();
        }
      } catch (e) {
        print('❌ Failed to fetch user profile: $e');
        final err = e.toString();

        // If backend explicitly says unauthorized or user not found, DO NOT use stored data
        if (err.contains('HTTP 401') || err.contains('User not found') || err.contains('401')) {
          print('🔒 Unauthorized or user not found. Clearing session and requiring login.');
          await _clearSession();
          return;
        }

        print('🔄 Attempting to load stored user data as fallback');
        
        // Try to load stored user data before clearing session (only for transient errors)
        final storedUserData = prefs.getString('user_data');
        if (storedUserData != null) {
          try {
            final userData = json.decode(storedUserData);
            currentUser = UserModel.fromJson(userData);
            print('✅ Loaded user from storage: ${currentUser?.name}');
            return; // Don't clear session if we have valid stored data
          } catch (storageError) {
            print('❌ Failed to load stored user data: $storageError');
          }
        }
        
        await _clearSession();
      }
    } else {
      print('❌ No token found, clearing session');
      await _clearSession();
    }
  }

  /// Load stored user data as fallback
  static Future<void> _loadStoredUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserData = prefs.getString('user_data');
      
      if (storedUserData != null) {
        final userData = json.decode(storedUserData);
        currentUser = UserModel.fromJson(userData);
        print('✅ Loaded stored user data: ${currentUser?.name}');
      } else {
        print('❌ No stored user data available');
      }
    } catch (e) {
      print('❌ Error loading stored user data: $e');
    }
  }

  /// Get current user
  static UserModel? getCurrentUser() => currentUser;

  /// Refresh user data from backend
  static Future<void> refreshUserData() async {
    if (!isLoggedIn) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        final res = await ApiService.getJson('/api/auth/profile', token: token);
        if (res.containsKey('user')) {
          final previousStatus = currentUser?.identityVerificationStatus;
          currentUser = UserModel.fromJson(res['user']);
          print('🔄 AuthService.refreshUserData() - User refreshed: ${currentUser?.name}');
          print('🔄 Previous verification status: $previousStatus');
          print('🔄 New verification status: ${currentUser?.identityVerificationStatus}');
          
          // Ensure verified status persists - don't allow downgrade from verified
          if (previousStatus == 'verified' || previousStatus == 'approved') {
            if (currentUser?.identityVerificationStatus != 'verified' && 
                currentUser?.identityVerificationStatus != 'approved') {
              print('⚠️ WARNING: Verification status downgraded from $previousStatus to ${currentUser?.identityVerificationStatus}');
              print('🔒 MAINTAINING verified status to prevent regression');
              // FORCE maintain verified status to prevent regression
              currentUser = currentUser?.copyWith(
                identityVerificationStatus: 'verified',
                verificationStatus: 'approved',
                isVerified: true
              );
            }
          }
          
          // Additional check: if user was ever verified, keep them verified
          if (currentUser?.identityVerificationStatus == 'approved') {
            currentUser = currentUser?.copyWith(
              identityVerificationStatus: 'verified',
              isVerified: true
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error refreshing user data: $e');
    }
  }

  /// Register user with role-based payment requirement
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String password,
    required String role,
  }) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/register',
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
          'password': password,
          'role': role,
        },
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Send email OTP for verification
  static Future<Map<String, dynamic>> sendEmailOTP(String email) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/send-otp',
        body: {'email': email},
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Verify email OTP code
  static Future<Map<String, dynamic>> verifyEmailOTP(String email, String otp) async {
    try {
      // Validate input
      if (email.isEmpty || otp.isEmpty) {
        return {
          'success': false,
          'message': 'Email and verification code are required',
        };
      }

      // Ensure OTP is exactly 6 digits
      final cleanOtp = otp.trim();
      if (cleanOtp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanOtp)) {
        return {
          'success': false,
          'message': 'Please enter a valid 6-digit verification code',
        };
      }

      final response = await http.post(
        Uri.parse('${ApiService.base}/api/auth/verify-email-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': cleanOtp}),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        // Email verification successful - no auto-login
        // User must login manually after verification
        return {
          'success': true,
          'message': data['message'] ?? 'Email verified successfully. Please login to continue.',
          'emailVerified': data['emailVerified'] ?? true,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Verification failed. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Please check your internet and try again.',
      };
    }
  }

  /// Submit CNIC identity verification
  static Future<Map<String, dynamic>> submitIdentityVerification({
    required String cnicNumber,
    required String frontImagePath,
    required String backImagePath,
  }) async {
    try {
      final token = await getValidToken();
      final res = await ApiService.postJsonAuth(
        '/api/auth/submit-identity-verification',
        token: token,
        body: {
          'cnicNumber': cnicNumber,
          'frontImagePath': frontImagePath,
          'backImagePath': backImagePath,
        },
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Simulate payment (for testing paid roles)
  static Future<Map<String, dynamic>> simulatePayment(String userId) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/simulate-payment',
        body: {'userId': userId},
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Login user with verification & payment checks
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/login',
        body: {'email': email, 'password': password},
      );

      if (res.containsKey('requiresPayment') && res['requiresPayment'] == true) {
        return res; // Paid role
      }

      String? authToken = res['token'] ?? res['accessToken'];
      if (authToken != null) {
        await _saveTokenWithExpiry(authToken, res);
        isLoggedIn = true;
        if (res.containsKey('user')) currentUser = UserModel.fromJson(res['user']);
      } else {
        throw Exception("Login failed: No authentication token received");
      }

      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Logout user
  static Future<void> logout() async {
    print('🚪 Logging out user...');
    
    // Clear session data first
    await _clearSession();
    
    try {
      if (_cachedToken != null) {
        await ApiService.postJsonAuth('/api/auth/logout', token: _cachedToken!);
        print('✅ Logout API call successful');
      }
    } catch (e) {
      print('❌ Logout API call failed: $e');
    }
    
    // Clear all service caches and disconnect real-time connections
    await _clearAllServiceCaches();
    
    print('✅ User logged out successfully - All caches cleared');
  }

  /// Update profile
  static Future<void> updateCurrentUser({
    required String name,
    required String email,
    required String phone,
    String? address,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${ApiService.base}/api/auth/profile/update'),
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
        if (data['user'] != null) currentUser = UserModel.fromJson(data['user']);
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Update password
  static Future<void> updatePassword(String currentPassword, String newPassword) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${ApiService.base}/api/auth/change-password'),
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
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update password');
      }
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Update email
  static Future<void> updateEmail(String newEmail, String password) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${ApiService.base}/api/auth/change-email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'newEmail': newEmail,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          currentUser = UserModel.fromJson(data['user']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(currentUser!.toJson()));
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update email');
      }
    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  /// Check verification status
  static Future<Map<String, dynamic>> checkVerificationStatus() async {
    try {
      String? token;
      try {
        token = await getValidToken();
      } catch (_) {}
      if (token != null) {
        return await ApiService.getJson('/api/auth/verification-status', token: token);
      } else {
        return await ApiService.get('/api/auth/verification-status');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Get user status for role-based access control
  static Future<Map<String, dynamic>?> getUserStatus() async {
    try {
      final token = await getValidToken();
      final res = await ApiService.getJson('/api/auth/user-status', token: token);
      return res;
    } catch (e) {
      print('❌ Error getting user status: $e');
      return null;
    }
  }

  /// ------------------ NEW METHODS ------------------ ///

  /// Forgot password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/forgot-password',
        body: {'email': email},
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Reset password
  static Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/reset-password',
        body: {'token': token, 'newPassword': newPassword},
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Complete registration
  static Future<Map<String, dynamic>> completeRegistration({
    required String email,
    required String password,
    required String role,
    String? name,
    String? cnic,
    String? address,
    String? phone,
  }) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/complete-registration',
        body: {
          'email': email,
          'password': password,
          'role': role,
          'name': name,
          'cnic': cnic,
          'address': address,
          'phone': phone,
        },
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Verify email
  static Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/verify-email',
        body: {'email': email, 'code': code},
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Resend verification code
  static Future<Map<String, dynamic>> resendVerificationCode({required String email}) async {
    try {
      final res = await ApiService.postJson(
        '/api/auth/resend-verification-code',
        body: {'email': email},
      );
      return res;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  /// Update current user data from Socket.IO notification
  static void updateCurrentUserFromSocket(Map<String, dynamic> notificationData) {
    try {
      print('🔄 Updating user data from socket notification: $notificationData');
      
      // Extract user data from the notification structure
      Map<String, dynamic>? userData;
      if (notificationData.containsKey('user')) {
        userData = notificationData['user'] as Map<String, dynamic>;
      } else {
        // Fallback: treat the entire data as user data
        userData = notificationData;
      }
      
      if (userData != null && currentUser != null) {
        print('🔄 Previous user status: ${currentUser?.identityVerificationStatus}');
        print('🔄 New user data from socket: $userData');
        
        // Update current user with new data while preserving existing fields
        currentUser = UserModel(
          id: userData['_id']?.toString() ?? currentUser!.id,
          name: userData['name'] ?? currentUser!.name,
          email: userData['email'] ?? currentUser!.email,
          phone: userData['phone'] ?? currentUser!.phone,
          avatarUrl: userData['avatarUrl'] ?? currentUser!.avatarUrl,
          role: userData['role'] ?? currentUser!.role,
          address: userData['address'] ?? currentUser!.address,
          cnic: userData['cnic'] ?? currentUser!.cnic,
          isVerified: userData['isIdentityVerified'] == true || userData['identityVerificationStatus'] == 'approved' || currentUser!.isVerified,
          verificationStatus: userData['status'] ?? currentUser!.verificationStatus,
          identityVerificationStatus: userData['identityVerificationStatus'] ?? currentUser!.identityVerificationStatus,
          emailVerificationStatus: userData['emailVerificationStatus'] ?? currentUser!.emailVerificationStatus,
          rejectionReason: userData['rejectionReason'] ?? currentUser!.rejectionReason,
          verificationDate: userData['verificationDate'] != null 
              ? DateTime.parse(userData['verificationDate']) 
              : currentUser!.verificationDate,
        );
        
        print('✅ User data updated - Status: ${currentUser?.verificationStatus}, Identity: ${currentUser?.identityVerificationStatus}, Verified: ${currentUser?.isVerified}');
        
        // Save updated user data to preferences
        _saveUserData(currentUser!);
      } else {
        print('❌ No valid user data found in socket notification or currentUser is null');
      }
    } catch (e) {
      print('❌ Error updating user from socket: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Enhanced user model update with permanent verification status preservation
  static void updateUserModel(Map<String, dynamic> userData) {
    try {
      final user = currentUser;
      
      // CRITICAL: Preserve verified status permanently - never downgrade
      if (user != null && user.isVerified) {
        // Force maintain verified status
        userData['identityVerificationStatus'] = 'verified';
        userData['status'] = 'approved';
        print('🔒 AUTH SERVICE: Forcing verified status preservation');
      }
      
      currentUser = UserModel.fromJson(userData);
      print('✅ AUTH SERVICE: User model updated with preserved verification status');
    } catch (e) {
      print('❌ AUTH SERVICE: Error updating user model: $e');
    }
  }

  /// Save user data to SharedPreferences
  static Future<void> _saveUserData(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(user.toJson()));
      print('💾 User data saved to preferences');
    } catch (e) {
      print('❌ Error saving user data: $e');
    }
  }

  /// ------------------ TOKEN MANAGEMENT ------------------ ///
  static Future<void> _clearSession() async {
    print('🧹 Clearing session data...');
    final prefs = await SharedPreferences.getInstance();
    
    // Clear authentication tokens
    await prefs.remove('token');
    await prefs.remove('token_expiry');
    
    // Clear user data
    await prefs.remove('user_data');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('user_roles');
    
    // Clear verification status
    await prefs.remove('identity_verification_status');
    await prefs.remove('email_verification_status');
    
    // Clear any other cached data
    await prefs.remove('last_login');
    await prefs.remove('remember_me');
    
    // Reset in-memory variables
    isLoggedIn = false;
    currentUser = null;
    _cachedToken = null;
    _tokenExpiry = null;
    
    print('✅ Session data cleared completely');
  }

  static Future<String> getValidToken() async {
    print('🔍 getValidToken() called');
    print('🔍 _cachedToken: ${_cachedToken != null ? "${_cachedToken!.substring(0, 20)}..." : "null"}');
    print('🔍 _tokenExpiry: $_tokenExpiry');
    print('🔍 isLoggedIn: $isLoggedIn');
    
    // First check cached token with proper expiry validation
    if (_cachedToken != null && _tokenExpiry != null) {
      final now = DateTime.now();
      final bufferTime = now.add(Duration(minutes: 10)); // Increased buffer time
      print('🔍 Token expiry check - Now: $now, Buffer: $bufferTime, Expiry: $_tokenExpiry');
      
      if (_tokenExpiry!.isAfter(bufferTime)) {
        print('✅ Cached token is still valid');
        return _cachedToken!;
      } else if (_tokenExpiry!.isAfter(now)) {
        print('⚠️ Token expires soon, but still valid - attempting refresh');
        try {
          await _refreshToken();
          return _cachedToken!;
        } catch (e) {
          print('❌ Token refresh failed, but token still valid: $e');
          // Return current token if refresh fails but token is still valid
          return _cachedToken!;
        }
      } else {
        print('❌ Cached token expired, attempting refresh');
        try {
          await _refreshToken();
          return _cachedToken!;
        } catch (e) {
          print('❌ Token refresh failed: $e');
          // Don't clear session immediately, try to get from SharedPreferences
        }
      }
    }
    
    // Fallback to SharedPreferences
    print('� Checking SharedPreferences for token...');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final tokenExpiry = prefs.getString('token_expiry');
    
    if (token == null || token.isEmpty) {
      print('❌ No token found in SharedPreferences');
      // Only clear session if we're sure there's no valid token
      if (_cachedToken == null) {
        await _clearSession();
        throw Exception('No valid authentication token found');
      } else {
        // Return cached token as last resort
        print('⚠️ Using cached token as fallback');
        return _cachedToken!;
      }
    }
    
    // Validate token from SharedPreferences
    if (tokenExpiry != null) {
      try {
        final expiry = DateTime.parse(tokenExpiry);
        final now = DateTime.now();
        
        if (expiry.isBefore(now)) {
          print('❌ Token from SharedPreferences is expired');
          // Try to refresh if we have a cached token
          if (_cachedToken != null) {
            try {
              await _refreshToken();
              return _cachedToken!;
            } catch (e) {
              print('❌ Final token refresh attempt failed: $e');
            }
          }
          // Only clear session as last resort
          await _clearSession();
          throw Exception('Authentication token expired');
        }
      } catch (e) {
        print('⚠️ Failed to parse token expiry, assuming token is valid: $e');
      }
    }
    
    // Restore token and expiry from SharedPreferences
    _cachedToken = token;
    if (tokenExpiry != null) {
      try {
        _tokenExpiry = DateTime.parse(tokenExpiry);
        print('✅ Token restored from SharedPreferences with expiry: $_tokenExpiry');
      } catch (e) {
        print('⚠️ Failed to parse token expiry: $e');
      }
    }
    
    print('✅ Returning token from SharedPreferences');
    return token;
  }

  static Future<void> _refreshToken() async {
    if (_cachedToken == null) throw Exception('No token to refresh');
    print('🔄 _refreshToken() called - Current token: ${_cachedToken!.substring(0, 20)}...');
    
    try {
      print('🔄 Attempting token refresh...');
      final res = await ApiService.postJsonAuth('/api/auth/refresh-token', token: _cachedToken!);
      String? newToken = res['token'] ?? res['accessToken'];
      
      if (newToken != null) {
        print('🔄 New token received from refresh: ${newToken.substring(0, 20)}...');
        await _saveTokenWithExpiry(newToken, res);
        print('✅ Token refresh completed - new token cached');
      } else {
        print('❌ No new token in refresh response');
        throw Exception('No token in refresh response');
      }
    } catch (e) {
      print('❌ Token refresh failed: $e');
      // Don't automatically clear session on refresh failure
      // Let the calling method decide what to do
      throw Exception('Token refresh failed: $e');
    }
  }

  static Future<void> _saveTokenWithExpiry(String token, Map<String, dynamic> response) async {
    print('🔑 _saveTokenWithExpiry() called with new token');
    print('🔑 Old cached token: ${_cachedToken != null ? "${_cachedToken!.substring(0, 20)}..." : "null"}');
    print('🔑 New token: ${token.substring(0, 20)}...');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    
    // CRITICAL: Update cached token immediately
    _cachedToken = token;
    print('✅ Cached token updated in memory');
    
    // Fix: Backend JWT tokens typically have 7 days expiry, not seconds
    // Check if response has explicit expiry, otherwise use 7 days default
    int expiresInSeconds;
    if (response.containsKey('expiresIn')) {
      expiresInSeconds = response['expiresIn'];
    } else if (response.containsKey('expires_in')) {
      expiresInSeconds = response['expires_in'];
    } else {
      // Default to 7 days (604800 seconds) to match backend JWT expiry
      expiresInSeconds = 604800;
    }
    
    // CRITICAL: Update expiry time immediately
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresInSeconds));
    await prefs.setString('token_expiry', _tokenExpiry!.toIso8601String());
    
    print('🔑 Token saved with expiry: ${_tokenExpiry!.toIso8601String()}');
    print('✅ Token caching completed - Memory and SharedPreferences updated');
  }

  static Future<String> _getToken() async => getValidToken();

  static String _parseError(dynamic e) {
    if (e is Exception) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) errorMessage = errorMessage.substring(11);
      try {
        final jsonStart = errorMessage.indexOf('{');
        if (jsonStart != -1) {
          final errorData = jsonDecode(errorMessage.substring(jsonStart));
          if (errorData['error'] != null && errorData['error']['message'] != null) return errorData['error']['message'];
          if (errorData['message'] != null) return errorData['message'];
        }
      } catch (_) {}
      return errorMessage;
    }
    return 'Unknown error occurred';
  }

  static Future<void> _clearAllServiceCaches() async {
    await ChatService.clearCache();
    await NotificationService.clearCache();
  }
}
