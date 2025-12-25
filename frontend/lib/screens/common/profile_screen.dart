import 'package:flutter/material.dart';
import '../account/personal_info_screen.dart';
import '../account/address_screen.dart';
import '../account/phone_number_screen.dart';
import '../account/change_password_screen.dart';
import '../account/email_update_screen.dart';
import '../auth/identity_verification_screen.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/notification_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _loadingPayments = false;
  bool _hasPayments = false;
  List<Map<String, dynamic>> _recentPayments = [];
  Map<String, dynamic> _paymentStats = {};
  Timer? _paymentsTimer;
  
  // Approval notification data
  bool _hasApprovalNotification = false;
  String? _approvalMessage;
  bool _showApprovalBanner = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _paymentsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    
    // Force refresh user data from backend first
    try {
      await AuthService.refreshUserData();
    } catch (e) {
      print('Error refreshing user data: $e');
      // Try to check login as fallback
      await AuthService.checkLogin();
    }
    
    // Validate that we have proper user data
    final user = AuthService.getCurrentUser();
    if (user == null || user.email == null || user.email!.isEmpty) {
      print('❌ Profile: No valid user data, forcing re-authentication');
      // Clear invalid session and redirect to login
      await AuthService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
    }
    
    await _loadRealTimeData();
    setState(() => _loading = false);
  }

  Future<void> _loadRealTimeData() async {
    if (!mounted) return;
    
    setState(() => _loadingPayments = true);
    
    try {
      // Refresh user data from backend to get latest status
      await AuthService.refreshUserData();
      
      final user = AuthService.getCurrentUser();
      if (user != null) {
        // Load role-based payments feed
        final roleBasedData = await ProfileService.getRoleBasedPayments(user.id);
        _recentPayments = List<Map<String, dynamic>>.from(roleBasedData['payments'] ?? []);
        
        // Load role-based payment statistics
        final stats = roleBasedData['stats'] ?? {};
        _paymentStats = stats;
        
        // Check if user has any payments
        _hasPayments = _recentPayments.isNotEmpty || 
                      (stats['totalDeliveries'] ?? 0) > 0 ||
                      (stats['totalPaid'] ?? 0) > 0 ||
                      (stats['totalEarnings'] ?? 0) > 0 ||
                      (stats['registrationFee'] ?? 0) > 0;
                      
        // Check for approval notifications
        _hasApprovalNotification = await NotificationService.hasApprovalNotification();
        if (_hasApprovalNotification) {
          _approvalMessage = await NotificationService.getApprovalMessage();
          _showApprovalBanner = true;
        }
      }
    } catch (e) {
      print('Error loading real-time data: $e');
      // For new users, start with empty data
      _recentPayments = [];
      _paymentStats = {
        'roleType': 'default',
        'registrationFee': 0,
      };
      _hasPayments = false;
      _hasApprovalNotification = false;
      _approvalMessage = null;
    }
    
    if (mounted) {
      setState(() => _loadingPayments = false);
    }
  }

  void _startRealTimeUpdates() {
    // Update payments data every 30 seconds
    _paymentsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadRealTimeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_showApprovalBanner) ...[
              _buildApprovalBanner(),
              const SizedBox(height: 16),
            ],
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildAccountSection(),
            const SizedBox(height: 20),
            _buildPaymentsSection(),
            const SizedBox(height: 20),
            _buildSettingsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = AuthService.getCurrentUser();
    final isVerified = user?.verificationStatus.toLowerCase() == 'approved';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'G',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? "Guest User",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user?.email ?? "No email",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ),
                    if (isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Verified",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (user?.identityVerificationStatus == 'pending')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Verification Pending",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (user?.identityVerificationStatus == 'rejected')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Verification Rejected",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isVerified && user?.identityVerificationStatus != 'pending')
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => IdentityVerificationScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          user?.identityVerificationStatus == 'rejected' ? 'Re-submit Verification' : 'Verify Yourself',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (user?.identityVerificationStatus == 'pending')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verification Under Review',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    final user = AuthService.getCurrentUser();
    return _buildSection(
      title: "User",
      icon: Icons.account_circle,
      children: [
        _buildApprovalStatusItem(user),
        const Divider(height: 1),
        _buildMenuItem(
          Icons.phone_outlined,
          "Phone Number",
          "Update contact number",
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => PhoneNumberScreen())),
        ),
        if (_hasPayments) ...[
          _buildMenuItem(
            Icons.person_outline,
            "Personal Information",
            "Update your name and details",
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => PersonalInfoScreen())),
          ),
          _buildMenuItem(
            Icons.location_on_outlined,
            "Address",
            "Manage your addresses",
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddressScreen())),
          ),
          _buildMenuItem(
            Icons.badge,
            "Verify Identity",
            "Verify your identity for actions",
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => IdentityVerificationScreen())),
          ),
        ],
      ],
    );
  }

Widget _buildPaymentsSection() {
  final user = AuthService.getCurrentUser();
  final userRole = user?.role ?? 'default';
  final roleType = _paymentStats['roleType'] ?? userRole;
  
  return _buildSection(
    title: _getPaymentsSectionTitle(roleType),
    icon: _getPaymentsSectionIcon(roleType),
    children: [
      if (roleType == 'volunteer') ...[
        // Volunteer - Show message about free services
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.volunteer_activism, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Volunteer Services",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _paymentStats['message'] ?? 'Volunteers provide free services - no payment history',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ] else ...[
        // Other roles - Show payment statistics
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildRoleBasedStats(roleType),
        ),
        if (_hasPayments && _recentPayments.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent ${_getPaymentTypeLabel(roleType)}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          ..._recentPayments.take(5).map((payment) => _buildRoleBasedPaymentItem(payment, roleType)).toList(),
        ],
      ],
    ],
  );
}


 Widget _buildRoleBasedStats(String roleType) {
  switch (roleType) {
    case 'delivery':
      // Delivery Personnel: Registration fee (500 PKR) + earnings
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.app_registration, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Registration Fee: PKR 500 (Paid)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("${_paymentStats['totalDeliveries'] ?? 0}", "Deliveries", Icons.local_shipping),
              _buildStatItem("PKR ${_paymentStats['totalEarnings'] ?? 0}", "Earned", Icons.monetization_on),
              _buildStatItem("${(_paymentStats['averageDistance'] ?? 0).toStringAsFixed(1)} km", "Avg Distance", Icons.route),
            ],
          ),
        ],
      );
    
    case 'requester':
      // Requester: Registration fee + service fees + delivery charges
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.app_registration, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Registration Fee: PKR 500 (Paid)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("${_paymentStats['totalRequests'] ?? 0}", "Requests", Icons.request_page),
              _buildStatItem("PKR ${_paymentStats['totalServiceFees'] ?? 0}", "Service Fees", Icons.receipt),
              _buildStatItem("PKR ${_paymentStats['totalDeliveryCharges'] ?? 0}", "Delivery Charges", Icons.local_shipping),
            ],
          ),
        ],
      );
    
    case 'donor':
      // Donor: Free registration + delivery charges only
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Registration: FREE (No fee for donors)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("${_paymentStats['totalDonations'] ?? 0}", "Donations", Icons.favorite),
              _buildStatItem("PKR ${_paymentStats['totalDeliveryCharges'] ?? 0}", "Delivery Charges", Icons.local_shipping),
              _buildStatItem("${_paymentStats['helpedFamilies'] ?? 0}", "Families Helped", Icons.people),
            ],
          ),
        ],
      );
    
    case 'volunteer':
      // Volunteer: No payments (completely free)
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.volunteer_activism, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Volunteer Services: FREE - Thank you!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.purple),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("${_paymentStats['totalVolunteerHours'] ?? 0}", "Hours", Icons.access_time),
              _buildStatItem("${_paymentStats['totalDeliveries'] ?? 0}", "Deliveries", Icons.local_shipping),
              _buildStatItem("${_paymentStats['helpedFamilies'] ?? 0}", "Families Helped", Icons.people),
            ],
          ),
        ],
      );
    default:
      {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem("PKR ${_paymentStats['registrationFee'] ?? 0}", "Registration", Icons.app_registration),
            _buildStatItem("PKR 0", "Delivery", Icons.local_shipping),
            _buildStatItem("PKR 0", "Payments", Icons.payment),
            _buildStatItem("0", "Activities", Icons.local_activity),
          ],
        );
      }
  }
}

  String _getPaymentsSectionTitle(String roleType) {
    switch (roleType) {
      case 'delivery':
        return 'Delivery Payments';
      case 'requester':
        return 'Registration & Request Payments';
      case 'donor':
        return 'Delivery Payments';
      case 'volunteer':
        return 'Volunteer Services';
      default:
        return 'Payments';
    }
  }

  IconData _getPaymentsSectionIcon(String roleType) {
    switch (roleType) {
      case 'delivery':
        return Icons.local_shipping;
      case 'requester':
        return Icons.request_page;
      case 'donor':
        return Icons.favorite;
      case 'volunteer':
        return Icons.volunteer_activism;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentTypeLabel(String roleType) {
    switch (roleType) {
      case 'delivery':
        return 'Deliveries';
      case 'requester':
        return 'Payments';
      case 'donor':
        return 'Delivery Payments';
      default:
        return 'Payments';
    }
  }

 

  Widget _buildRoleBasedPaymentItem(Map<String, dynamic> payment, String roleType) {
    final timeAgo = _getTimeAgo(_parseDateTime(payment['date']));
    
    // Get the correct icon based on payment type and role
    IconData paymentIcon;
    Color iconColor = AppTheme.primaryColor;
    
    switch (payment['type']) {
      case 'delivery_charge':
        paymentIcon = Icons.local_shipping;
        iconColor = Colors.blue;
        break;
      case 'delivery_commission':
        paymentIcon = Icons.monetization_on;
        iconColor = Colors.green;
        break;
      case 'registration_fee':
        paymentIcon = Icons.app_registration;
        iconColor = Colors.orange;
        break;
      case 'request_fee':
        paymentIcon = Icons.request_page;
        iconColor = Colors.purple;
        break;
      default:
        paymentIcon = Icons.payment;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              paymentIcon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['action'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                if (roleType == 'delivery' && payment['distance'] != null) ...[
                  Text(
                    '${payment['distance']} km • ${payment['pickupLocation']} → ${payment['deliveryLocation']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ] else ...[
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${payment['amount'] ?? 0}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: payment['type'] == 'delivery_commission' ? Colors.green : AppTheme.primaryColor,
                ),
              ),
              if (roleType == 'delivery' && payment['commission'] != null && payment['commission'] > 0) ...[
                Text(
                  'Commission: PKR ${payment['commission']}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  DateTime _parseDateTime(dynamic date) {
    try {
      if (date is DateTime) {
        return date;
      } else if (date is String && date.isNotEmpty) {
        return DateTime.parse(date);
      } else {
        // Fallback to current time if date is null or invalid
        return DateTime.now();
      }
    } catch (e) {
      print('Error parsing date: $date, error: $e');
      // Return current time as fallback
      return DateTime.now();
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildSettingsSection() {
    return _buildSection(
      title: "Settings",
      icon: Icons.settings,
      children: [
        _buildMenuItem(
          Icons.notifications_outlined,
          "Notifications",
          "Manage notification preferences",
          _showNotificationSettings,
        ),
        _buildMenuItem(
          Icons.lock_outline,
          "Change Password",
          "Update your password",
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChangePasswordScreen())),
        ),
        _buildMenuItem(
          Icons.email_outlined,
          "Email Update",
          "Update your email address",
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => EmailUpdateScreen())),
        ),
        _buildMenuItem(
          Icons.security_outlined,
          "Privacy & Security",
          "Other security settings",
          _showSecuritySettings,
        ),
        _buildMenuItem(
          Icons.help_outline,
          "Help & Support",
          "Get help and contact support",
          _showHelpDialog,
        ),
        _buildMenuItem(
          Icons.info_outline,
          "About",
          "App version and information",
          _showAboutDialog,
        ),
        const SizedBox(height: 16),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildApprovalStatusItem(UserModel? user) {
    if (user?.verificationStatus.toLowerCase() == 'approved') {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.verified_user, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              "Your account is verified",
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ],
        ),
      );
    } else if (user?.identityVerificationStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Verification pending",
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ],
        ),
      );
    } else if (user?.identityVerificationStatus == 'rejected') {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              "Verification rejected",
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              "Verify your account",
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: AppTheme.primaryTextColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.secondaryTextColor,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildStatItem(String amount, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final timeAgo = _getTimeAgo(_parseDateTime(payment['date']));
    
    // Get the correct icon based on payment type
    IconData paymentIcon;
    
    // Handle both String and IconData types for the icon field
    final iconValue = payment['icon'];
    if (iconValue is IconData) {
      // If it's already an IconData, use it directly
      paymentIcon = iconValue;
    } else {
      // If it's a String, convert it to IconData
      switch (iconValue as String? ?? 'payment') {
        case 'app_registration':
          paymentIcon = Icons.app_registration;
          break;
        case 'local_shipping':
          paymentIcon = Icons.local_shipping;
          break;
        case 'request_page':
          paymentIcon = Icons.request_page;
          break;
        case 'monetization_on':
          paymentIcon = Icons.monetization_on;
          break;
        default:
          paymentIcon = Icons.payment;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              paymentIcon,
              color: AppTheme.primaryColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['action'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'PKR ${payment['amount'] ?? 0}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _approvalMessage ?? '',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.green),
            onPressed: () {
              setState(() => _showApprovalBanner = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () async {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.logout, size: 16),
          const SizedBox(width: 4),
          Text(
            'Logout',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Push Notifications'),
              value: true,
              onChanged: (value) {},
              activeColor: AppTheme.primaryColor,
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              value: false,
              onChanged: (value) {},
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSecuritySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: const Text('Change password and manage security settings here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text('Contact us at support@careconnect.com for assistance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Care Connect'),
        content: const Text('Care Connect v1.0.0\nHelping communities reduce food waste and share resources.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
