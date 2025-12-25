import 'package:flutter/material.dart';
import '../screens/donor/donor_dashboard.dart';
import '../screens/requester/requester_dashboard.dart';
import '../screens/volunteer/volunteer_dashboard.dart';
import '../screens/delivery/delivery_dashboard.dart';
import '../screens/auth/identity_verification_screen.dart';
import 'auth_service.dart';

class DashboardRouter {
  static Widget getHomeDashboard() {
    final user = AuthService.getCurrentUser();
    
    print('🔍 DashboardRouter.getHomeDashboard() - User: ${user?.name}, Role: "${user?.role}"');
    print('🔍 Full user object: $user');
    print('🔍 User.toJson(): ${user?.toJson()}');
    
    if (user == null) {
      print('❌ No user found, returning DonorDashboard as fallback');
      return DonorDashboard();
    }

    // Get user's role and normalize it
    final userRole = user.role?.toLowerCase().trim() ?? '';
    print('🔍 Normalized user role: "$userRole"');
    print('🔍 Raw user role before normalization: "${user.role}"');
    print('🔍 User role is null: ${user.role == null}');
    print('🔍 User role is empty: ${user.role?.isEmpty}');
    print('🔍 User role length: ${user.role?.length}');

    // Route based on user's selected role
    switch (userRole) {
      case 'donor':
        print('✅ Routing to DonorDashboard');
        return DonorDashboard();
      case 'requester':
        print('✅ Routing to RequesterDashboard');
        return RequesterDashboard();
      case 'volunteer':
        print('✅ Routing to VolunteerDashboard');
        return VolunteerDashboard();
      case 'delivery':
      case 'earn & deliver':
        print('✅ Routing to DeliveryDashboard');
        return DeliveryDashboard();
      default:
        print('⚠️ Unknown role "$userRole", checking with hasRole method...');
        
        // Fallback: try hasRole method for additional checking
        if (user.hasRole('donor')) {
          print('✅ hasRole detected donor, returning DonorDashboard');
          return DonorDashboard();
        } else if (user.hasRole('requester')) {
          print('✅ hasRole detected requester, returning RequesterDashboard');
          return RequesterDashboard();
        } else if (user.hasRole('volunteer')) {
          print('✅ hasRole detected volunteer, returning VolunteerDashboard');
          return VolunteerDashboard();
        } else if (user.hasRole('delivery')) {
          print('✅ hasRole detected delivery, returning DeliveryDashboard');
          return DeliveryDashboard();
        } else {
          print('❌ No role detected, defaulting to DonorDashboard');
          return DonorDashboard();
        }
    }
  }

  static String getHomeRoute() {
    final user = AuthService.getCurrentUser();
    
    print('🔍 DashboardRouter.getHomeRoute() - User: ${user?.name}, Role: "${user?.role}"');
    
    if (user == null) {
      print('❌ No user found, returning /donor-dashboard as fallback');
      return '/donor-dashboard';
    }

    // Get user's role and normalize it
    final userRole = user.role?.toLowerCase().trim() ?? '';
    print('🔍 Normalized user role for routing: "$userRole"');

    // Route based on user's selected role
    switch (userRole) {
      case 'donor':
        print('✅ Routing to /donor-dashboard');
        return '/donor-dashboard';
      case 'requester':
        print('✅ Routing to /requester-dashboard');
        return '/requester-dashboard';
      case 'volunteer':
        print('✅ Routing to /volunteer-dashboard');
        return '/volunteer-dashboard';
      case 'delivery':
      case 'earn & deliver':
        print('✅ Routing to /delivery-dashboard');
        return '/delivery-dashboard';
      default:
        print('⚠️ Unknown role "$userRole", checking with hasRole method...');
        
        // Fallback: try hasRole method for additional checking
        if (user.hasRole('donor')) {
          print('✅ hasRole detected donor, returning /donor-dashboard');
          return '/donor-dashboard';
        } else if (user.hasRole('requester')) {
          print('✅ hasRole detected requester, returning /requester-dashboard');
          return '/requester-dashboard';
        } else if (user.hasRole('volunteer')) {
          print('✅ hasRole detected volunteer, returning /volunteer-dashboard');
          return '/volunteer-dashboard';
        } else if (user.hasRole('delivery')) {
          print('✅ hasRole detected delivery, returning /delivery-dashboard');
          return '/delivery-dashboard';
        } else {
          print('❌ No role detected, defaulting to /donor-dashboard');
          return '/donor-dashboard';
        }
    }
  }

  static String getDashboardRoute(dynamic user) {
    if (user == null) {
      return '/donor-dashboard';
    }

    // Return route name based on user role
    if (user.hasRole('donor')) {
      return '/donor-dashboard';
    } else if (user.hasRole('requester')) {
      return '/requester-dashboard';
    } else if (user.hasRole('volunteer')) {
      return '/volunteer-dashboard';
    } else if (user.hasRole('delivery')) {
      return '/delivery-dashboard';
    } else {
      return '/donor-dashboard';
    }
  }

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      '/donor-dashboard': (context) => DonorDashboard(),
      '/requester-dashboard': (context) => RequesterDashboard(),
      '/volunteer-dashboard': (context) => VolunteerDashboard(),
      '/delivery-dashboard': (context) => DeliveryDashboard(),
    };
  }

  static void navigateToDashboard(BuildContext context) {
    final user = AuthService.getCurrentUser();
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Check if user needs identity verification
    _checkUserVerificationStatus(context, user);
  }

  static void _checkUserVerificationStatus(BuildContext context, dynamic user) async {
    try {
      // Get current user status from backend
      final userStatus = await AuthService.getUserStatus();
      
      if (userStatus != null && userStatus['success'] == true) {
        final permissions = userStatus['permissions'];
        final statusMessages = userStatus['statusMessages'] as List?;
        final isFullyActivated = permissions['isFullyActivated'] ?? false;
        
        // If user is fully activated, go to dashboard
        if (isFullyActivated) {
          Widget dashboard = getHomeDashboard();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => dashboard),
            (route) => false,
          );
          return;
        }
        
        // Check if identity verification is needed
        bool needsIdentityVerification = false;
        String verificationMessage = '';
        
        if (statusMessages != null) {
          for (var message in statusMessages) {
            if (message['action'] == 'Complete identity verification' || 
                message['action'] == 'Resubmit identity verification') {
              needsIdentityVerification = true;
              verificationMessage = message['message'];
              break;
            }
          }
        }
        
        if (needsIdentityVerification) {
          // Show identity verification dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Identity Verification Required',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please verify your identity to access ${user.role} features.',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload clear photos of your CNIC for verification.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Skip for Now'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Widget dashboard = getHomeDashboard();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => dashboard),
                      (route) => false,
                    );
                  },
                ),
                ElevatedButton(
                  child: Text('Verify Identity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => IdentityVerificationScreen()),
                    );
                  },
                ),
              ],
            ),
          );
        } else {
          // User has other pending requirements, go to dashboard
          Widget dashboard = getHomeDashboard();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => dashboard),
            (route) => false,
          );
        }
      } else {
        // Fallback to dashboard if status check fails
        Widget dashboard = getHomeDashboard();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => dashboard),
          (route) => false,
        );
      }
    } catch (error) {
      print('❌ Error checking user verification status: $error');
      // Fallback to dashboard on error
      Widget dashboard = getHomeDashboard();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => dashboard),
        (route) => false,
      );
    }
  }
}
