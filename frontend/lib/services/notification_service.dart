import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';
import 'auth_service.dart';
import '../models/notification_model.dart';
import '../config/theme.dart';
import '../screens/auth/identity_verification_screen.dart';

enum NotificationType {
  success,
  error,
  warning,
  info,
  processing,
}

class NotificationService {
  static const String baseUrl = '/api/notifications';
  
  // Socket.IO for real-time notifications
  static IO.Socket? _socket;
  static bool _isConnected = false;
  static StreamController<Map<String, dynamic>>? _notificationController;
  static StreamController<Map<String, dynamic>>? _verificationController;
  static StreamController<Map<String, dynamic>>? _donationVerificationController;
  static StreamController<Map<String, dynamic>>? _requestVerificationController;
  static StreamController<Map<String, dynamic>>? _chatAvailabilityController;
  static StreamController<Map<String, dynamic>>? _deliveryNotificationController;
  static BuildContext? _currentContext;

  /// Initialize real-time notification service with enhanced Socket.IO
  static Future<void> initializeRealTime() async {
    if (_socket != null && _isConnected) return;
    
    try {
      final token = await AuthService.getValidToken();
      final currentUser = AuthService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('No current user found');
      }
      
      // Initialize stream controllers
      _notificationController ??= StreamController<Map<String, dynamic>>.broadcast();
      _verificationController ??= StreamController<Map<String, dynamic>>.broadcast();
      _donationVerificationController ??= StreamController<Map<String, dynamic>>.broadcast();
      _requestVerificationController ??= StreamController<Map<String, dynamic>>.broadcast();
      _chatAvailabilityController ??= StreamController<Map<String, dynamic>>.broadcast();
      _deliveryNotificationController ??= StreamController<Map<String, dynamic>>.broadcast();
      
      // Create socket connection with proper configuration
      String socketUrl = ApiService.base;
      
      // For ngrok URLs, ensure no port is appended
      if (socketUrl.contains('ngrok')) {
        // Remove any existing port and ensure clean URL
        socketUrl = socketUrl.replaceAll(RegExp(r':\d+$'), '');
      }
      
      print('🔌 Connecting to Socket.IO at: $socketUrl');
      
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // Add polling as fallback
            .enableAutoConnect()
            .setExtraHeaders({
              'Authorization': 'Bearer $token',
              'userId': currentUser.id,
              'ngrok-skip-browser-warning': 'true', // Add ngrok header
            })
            .build(),
      );

      // Add auth token to socket connection
      _socket!.io.options?['extraHeaders'] = {
        'Authorization': 'Bearer $token',
        'userId': currentUser.id,
      };

      _socket!.onConnect((_) {
        print('✅ NotificationService connected for user: ${currentUser.name}');
        print('✅ Socket ID: ${_socket!.id}');
        _isConnected = true;
        
        // Join user-specific room
        final userRoom = 'user_${currentUser.id}';
        _socket!.emit('join_user_room', {'userId': currentUser.id});
        
        // Set up all listeners
        _setupSocketListeners(currentUser);
        _setupDeliveryNotificationListeners();
      });

      _socket!.onDisconnect((_) {
        print('🔴 NotificationService disconnected');
        _isConnected = false;
        
        // Attempt to reconnect after a delay
        Timer(Duration(seconds: 5), () {
          if (!_isConnected && _socket != null) {
            print('🔄 Attempting to reconnect NotificationService...');
            _socket!.connect();
          }
        });
      });

      _socket!.onError((error) {
        print('❌ NotificationService error: $error');
        _isConnected = false;
      });

      _socket!.onConnectError((error) {
        print('❌ NotificationService connection error: $error');
        _isConnected = false;
      });

      _socket!.connect();

    } catch (e) {
      print('❌ NotificationService initialization failed: $e');
      // Don't throw, just log - we can fall back to polling
    }
  }

  static void _setupSocketListeners(dynamic currentUser) {
    // Listen for identity verification approval
    _socket!.on('identity_verified', (data) {
      print('🎉 Identity verification approved received: $data');
      
      // Update user data immediately
      if (data['user'] != null) {
        AuthService.updateCurrentUserFromSocket(data['user']);
      }
      
      // Show toast notification
      if (_currentContext != null) {
        showVerificationSuccessToast();
      }
      
      // Emit to verification stream for UI updates
      _verificationController?.add({
        'type': 'identity_verified',
        'title': data['title'] ?? 'Identity Verified!',
        'message': data['message'] ?? 'Your identity verification has been approved!',
        'user': data['user'],
        'refreshDashboard': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Add rejection listener
    _socket!.on('identity_rejected', (data) {
      print('❌ Identity verification rejected: $data');
      
      // Update user data
      if (data['user'] != null) {
        AuthService.updateCurrentUserFromSocket(data['user']);
      }
      
      // Show toast notification
      if (_currentContext != null) {
        showVerificationRejectedToast(data['reason'] ?? '');
      }
      
      // Emit to verification stream
      _verificationController?.add({
        'type': 'identity_rejected',
        'message': data['message'] ?? 'Your identity verification was rejected',
        'reason': data['reason'],
        'user': data['user'],
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Listen for request verification updates
    _socket!.on('request_verification_update', (data) {
      print('🎉 Request verification update received: $data');
      
      if (data['user'] != null) {
        AuthService.updateCurrentUserFromSocket(data['user']);
      }
      
      // Show toast notification
      if (_currentContext != null) {
        if (data['type'] == 'request_verified') {
          showToast(
            title: '✅ Request Approved!',
            message: 'Your request has been verified and is now visible to donors.',
            type: NotificationType.success,
          );
        } else if (data['type'] == 'request_rejected') {
          showToast(
            title: '❌ Request Not Approved',
            message: data['reason'] ?? 'Your request verification was not approved.',
            type: NotificationType.error,
          );
        }
      }
      
      _requestVerificationController?.add({
        'type': data['type'] ?? 'request_verified',
        'title': data['title'] ?? 'Request Update',
        'message': data['message'] ?? 'Your request status has been updated',
        'request': data['request'],
        'requestId': data['requestId'],
        'reason': data['reason'],
        'refreshDashboard': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Listen for donation verification updates
    _socket!.on('donation_verification_update', (data) {
      print('🎉 Donation verification update received: $data');
      
      if (data['user'] != null) {
        AuthService.updateCurrentUserFromSocket(data['user']);
      }
      
      // Show toast notification
      if (_currentContext != null) {
        if (data['type'] == 'donation_verified') {
          showToast(
            title: '✅ Donation Approved!',
            message: 'Your donation has been verified and is now live!',
            type: NotificationType.success,
          );
        } else if (data['type'] == 'donation_rejected') {
          showToast(
            title: '❌ Donation Not Approved',
            message: data['reason'] ?? 'Your donation verification was not approved.',
            type: NotificationType.error,
          );
        }
      }
      
      _donationVerificationController?.add({
        'type': data['type'] ?? 'donation_verified',
        'title': data['title'] ?? 'Donation Update',
        'message': data['message'] ?? 'Your donation status has been updated',
        'donation': data['donation'],
        'reason': data['reason'],
        'refreshDashboard': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Listen for general refresh events
    _socket!.on('refresh_dashboard_stats', (data) {
      print('🔄 Dashboard refresh requested: $data');
      
      _notificationController?.add({
        'type': 'refresh_dashboard',
        'message': 'Dashboard data updated',
        'refreshDashboard': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  static void _setupDeliveryNotificationListeners() {
    if (_socket == null) return;

    // Listen for new volunteer delivery opportunities
    _socket!.on('new_volunteer_delivery', (data) {
      print('🎯 NOTIFICATION: New volunteer delivery opportunity received');
      print('🎯 DATA: $data');
      
      _showNotification(
        title: 'New Volunteer Delivery Available',
        body: data['message'] ?? 'New delivery opportunity available',
        data: data,
        type: 'volunteer_delivery_available',
      );
    });

    // Listen for new paid delivery opportunities
    _socket!.on('new_paid_delivery', (data) {
      print('💰 NOTIFICATION: New paid delivery opportunity received');
      print('💰 DATA: $data');
      
      _showNotification(
        title: 'New Paid Delivery Available',
        body: 'Earn PKR ${data['paymentAmount']} - ${data['message']}',
        data: data,
        type: 'paid_delivery_available',
      );
    });

    // Listen for volunteer acceptance notifications (for donors)
    _socket!.on('volunteer_accepted', (data) {
      print('✅ NOTIFICATION: Volunteer accepted delivery');
      print('✅ DATA: $data');
      
      _showNotification(
        title: 'Volunteer Accepted Your Donation',
        body: '${data['volunteerName']} will deliver your donation',
        data: data,
        type: 'volunteer_accepted',
      );
    });

    // Listen for delivery acceptance notifications (for donors/requesters)
    _socket!.on('delivery_accepted', (data) {
      print('✅ NOTIFICATION: Delivery person accepted');
      print('✅ DATA: $data');
      
      _showNotification(
        title: 'Delivery Person Accepted',
        body: '${data['deliveryPersonName']} will deliver your ${data['itemType']}',
        data: data,
        type: 'delivery_accepted',
      );
    });

    // Listen for delivery rejection notifications
    _socket!.on('delivery_rejected', (data) {
      print('❌ NOTIFICATION: Delivery rejected');
      print('❌ DATA: $data');
      
      _showNotification(
        title: 'Delivery Update',
        body: '${data['rejectedBy']} cannot deliver your ${data['itemType']}',
        data: data,
        type: 'delivery_rejected',
      );
    });

    // Listen for delivery status updates
    _socket!.on('delivery_status_update', (data) {
      print('📦 NOTIFICATION: Delivery status update');
      print('📦 DATA: $data');
      
      _showNotification(
        title: 'Delivery Status Update',
        body: data['message'] ?? 'Your delivery status has been updated',
        data: data,
        type: 'delivery_status_update',
      );
    });

    // Listen for delivery completion
    _socket!.on('delivery_completed', (data) {
      print('🎉 NOTIFICATION: Delivery completed');
      print('🎉 DATA: $data');
      
      _showNotification(
        title: 'Delivery Completed',
        body: data['message'] ?? 'Your delivery has been completed successfully',
        data: data,
        type: 'delivery_completed',
      );
    });

    print('🔔 NOTIFICATION: All delivery notification listeners set up');
  }

  static void _showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String type,
  }) {
    // Add to notification stream
    if (_deliveryNotificationController != null && !_deliveryNotificationController!.isClosed) {
      _deliveryNotificationController!.add({
        'title': title,
        'body': body,
        'data': data,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Show local notification if app is in background
    _showLocalNotification(title, body, data);

    // Show in-app notification if app is in foreground
    if (_currentContext != null) {
      _showInAppNotification(title, body, data, type);
    }
  }

  static void _showLocalNotification(String title, String body, Map<String, dynamic> data) {
    // Implementation for local notifications (using flutter_local_notifications)
    // This would show system notifications when app is in background
    print('📱 LOCAL NOTIFICATION: $title - $body');
  }

  static void _showInAppNotification(String title, String body, Map<String, dynamic> data, String type) {
    if (_currentContext == null) return;

    // Show a toast-style notification overlay
    final overlay = Overlay.of(_currentContext!);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getNotificationColor(type),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  _getNotificationIcon(type),
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => overlayEntry.remove(),
                  icon: Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay?.insert(overlayEntry);

    // Auto-remove after 5 seconds
    Timer(Duration(seconds: 5), () {
      try {
        overlayEntry.remove();
      } catch (e) {
        // Overlay entry might already be removed
      }
    });
  }

  static Color _getNotificationColor(String type) {
    switch (type) {
      case 'volunteer_delivery_available':
      case 'paid_delivery_available':
        return Colors.blue;
      case 'volunteer_accepted':
      case 'delivery_accepted':
        return Colors.green;
      case 'delivery_rejected':
        return Colors.orange;
      case 'delivery_completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'volunteer_delivery_available':
        return Icons.volunteer_activism;
      case 'paid_delivery_available':
        return Icons.delivery_dining;
      case 'volunteer_accepted':
      case 'delivery_accepted':
        return Icons.check_circle;
      case 'delivery_rejected':
        return Icons.cancel;
      case 'delivery_completed':
        return Icons.celebration;
      default:
        return Icons.notifications;
    }
  }

  /// Show a toast notification with custom styling
  static void showToast({
    required String message,
    required NotificationType type,
    String title = '',
    Duration duration = const Duration(seconds: 4),
    bool showCloseButton = true,
  }) {
    if (_currentContext == null) {
      print('❌ Cannot show toast: No context available');
      return;
    }

    final messenger = ScaffoldMessenger.of(_currentContext!);
    
    // Clear any existing toasts
    messenger.clearSnackBars();
    
    // Determine styling based on type
    Color backgroundColor;
    IconData icon;
    
    switch (type) {
      case NotificationType.success:
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case NotificationType.error:
        backgroundColor = Colors.red;
        icon = Icons.error;
        break;
      case NotificationType.warning:
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        break;
      case NotificationType.info:
        backgroundColor = Colors.blue;
        icon = Icons.info;
        break;
      case NotificationType.processing:
        backgroundColor = Colors.purple;
        icon = Icons.hourglass_top;
        break;
      default:
        backgroundColor = Colors.grey;
        icon = Icons.notifications;
    }
    
    // Create and show the toast
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  if (title.isNotEmpty) const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: showCloseButton
            ? SnackBarAction(
                label: 'Close',
                textColor: Colors.white,
                onPressed: () => messenger.hideCurrentSnackBar(),
              )
            : null,
      ),
    );
  }

  /// Show identity verification success toast
  static void showVerificationSuccessToast() {
    showToast(
      title: '🎉 Identity Verified!',
      message: 'Your identity verification has been approved. You can now access all features.',
      type: NotificationType.success,
      duration: const Duration(seconds: 5),
    );
  }

  /// Show identity verification pending toast
  static void showVerificationPendingToast() {
    showToast(
      title: '⏳ Verification in Progress',
      message: 'Your identity verification is under review. Please wait for approval.',
      type: NotificationType.info,
      duration: const Duration(seconds: 4),
    );
  }

  /// Show identity verification rejected toast
  static void showVerificationRejectedToast([String reason = '']) {
    showToast(
      title: '❌ Verification Rejected',
      message: reason.isNotEmpty 
          ? 'Your identity verification was rejected: $reason'
          : 'Your identity verification was rejected. Please try again.',
      type: NotificationType.error,
      duration: const Duration(seconds: 6),
    );
  }

  /// Check if user is fully verified
  static bool isUserFullyVerified(dynamic user) {
    if (user == null) return false;
    
    // Check multiple indicators of verification
    return user.isVerified == true || 
           user.identityVerificationStatus == 'approved' ||
           user.isIdentityVerified == true;
  }

  /// Listen for verification updates
  static Stream<Map<String, dynamic>> get verificationStream {
    _verificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _verificationController!.stream;
  }
  
  /// Listen for general notifications
  static Stream<Map<String, dynamic>> get notificationStream {
    _notificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _notificationController!.stream;
  }

  /// Listen for donation verification events
  static Stream<Map<String, dynamic>> get donationVerificationStream {
    _donationVerificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _donationVerificationController!.stream;
  }

  /// Listen for request verification events
  static Stream<Map<String, dynamic>> get requestVerificationStream {
    _requestVerificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _requestVerificationController!.stream;
  }

  /// Listen for chat availability updates
  static Stream<Map<String, dynamic>> get chatAvailabilityStream {
    _chatAvailabilityController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _chatAvailabilityController!.stream;
  }

  /// Listen for delivery notifications
  static Stream<Map<String, dynamic>> get deliveryNotificationStream {
    _deliveryNotificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _deliveryNotificationController!.stream;
  }

  /// Test notification connection
  static Future<bool> testConnection() async {
    try {
      if (_socket == null || !_isConnected) {
        await initializeRealTime();
      }
      
      if (_socket != null && _isConnected) {
        print('✅ NotificationService connection test: CONNECTED');
        return true;
      } else {
        print('❌ NotificationService connection test: FAILED');
        return false;
      }
    } catch (e) {
      print('❌ NotificationService connection test error: $e');
      return false;
    }
  }

  /// Disconnect notification service
  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    print('🔔 NotificationService disconnected');
  }
  
  /// Clear all cache and disconnect (for logout)
  static Future<void> clearCache() async {
    print('🧹 NotificationService: Clearing all cache and disconnecting...');
    
    // Close all stream controllers
    _notificationController?.close();
    _verificationController?.close();
    _donationVerificationController?.close();
    _requestVerificationController?.close();
    _chatAvailabilityController?.close();
    _deliveryNotificationController?.close();
    
    // Reset all controllers to null
    _notificationController = null;
    _verificationController = null;
    _donationVerificationController = null;
    _requestVerificationController = null;
    _chatAvailabilityController = null;
    _deliveryNotificationController = null;
    
    // Disconnect socket
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
    
    // Clear context
    _currentContext = null;
    
    print('✅ NotificationService: Cache cleared and disconnected');
  }

  /// Dispose all streams (legacy method)
  static void disposeStreams() {
    _notificationController?.close();
    _verificationController?.close();
    _donationVerificationController?.close();
    _requestVerificationController?.close();
    _chatAvailabilityController?.close();
    _deliveryNotificationController?.close();
    _notificationController = null;
    _verificationController = null;
    _donationVerificationController = null;
    _requestVerificationController = null;
    _chatAvailabilityController = null;
    _deliveryNotificationController = null;
  }

  /// Dispose resources
  static void dispose() {
    disconnect();
    _notificationController?.close();
    _verificationController?.close();
    _donationVerificationController?.close();
    _requestVerificationController?.close();
    _chatAvailabilityController?.close();
    _deliveryNotificationController?.close();
    _notificationController = null;
    _verificationController = null;
    _donationVerificationController = null;
    _requestVerificationController = null;
    _chatAvailabilityController = null;
    _deliveryNotificationController = null;
  }

  /// Set context for notifications
  static void setContext(BuildContext context) {
    _currentContext = context;
  }

  /// Initialize method (alias for initializeRealTime)
  static Future<void> initialize() async {
    return await initializeRealTime();
  }

  /// Get user notifications
  static Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson('/api/notifications', token: token);
      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['notifications'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllNotificationsAsRead() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.postJsonAuth('/api/notifications/mark-all-read', token: token);
      return response['success'] == true;
    } catch (e) {
      print('Error marking notifications as read: $e');
      return false;
    }
  }

  /// Mark specific notification as read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.postJsonAuth('/api/notifications/$notificationId/read', token: token);
      return response['success'] == true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Check if user has approval notification
  static Future<bool> hasApprovalNotification() async {
    try {
      final notifications = await getUserNotifications();
      return notifications.any((n) => n['type'] == 'approval' && n['read'] != true);
    } catch (e) {
      print('Error checking approval notification: $e');
      return false;
    }
  }

  /// Get approval message
  static Future<String?> getApprovalMessage() async {
    try {
      final notifications = await getUserNotifications();
      final approvalNotification = notifications.firstWhere(
        (n) => n['type'] == 'approval' && n['read'] != true,
        orElse: () => {},
      );
      return approvalNotification['message'];
    } catch (e) {
      print('Error getting approval message: $e');
      return null;
    }
  }

  // Add socket getter for external access
  static IO.Socket? get socket => _socket;
}
