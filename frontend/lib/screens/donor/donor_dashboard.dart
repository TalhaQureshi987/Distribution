import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/donation_service.dart';
import '../../services/notification_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../auth/identity_verification_screen.dart';
import '../common/profile_screen.dart';
import 'donate_screen.dart';
import 'accepted_offers_screen.dart';
import 'package:intl/intl.dart';

class DonorDashboard extends StatefulWidget {
  @override
  _DonorDashboardState createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _donationStats = {};
  List<Map<String, dynamic>> _deliveryOffers = [];
  List<Map<String, dynamic>> _volunteerOffers = [];
  bool _showVerificationAlert = false;
  Timer? _verificationAlertTimer;

  late StreamSubscription _verificationSubscription;
  late StreamSubscription? _donationVerificationSubscription;
  late StreamSubscription? _volunteerAcceptanceSubscription;
  late StreamSubscription? _deliveryAcceptanceSubscription;

  bool _isLoadingVolunteerOffers = false;

  @override
  void initState() {
    super.initState();
    _loadDonationData();
    _setupNotificationListeners();
    _loadDeliveryOffers();
    _loadVolunteerOffers();
  }

  @override
  @override
  void dispose() {
    _verificationSubscription.cancel();
    _donationVerificationSubscription?.cancel();
    _volunteerAcceptanceSubscription?.cancel();
    _deliveryAcceptanceSubscription?.cancel();
    _verificationAlertTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDonationData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await DonationService.getDashboardStats();

      if (mounted) {
        setState(() {
          _donationStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDeliveryOffers() async {
    try {
      final response = await ApiService.getJson(
        '/api/delivery-offers/for-approval',
        token: await AuthService.getValidToken(),
      );

      if (mounted) {
        setState(() {
          _deliveryOffers = List<Map<String, dynamic>>.from(
            response['offers'] ?? [],
          );
        });
      }
    } catch (e) {}
  }

  Future<void> _loadVolunteerOffers() async {
    setState(() {
      _isLoadingVolunteerOffers = true;
    });

    try {
      final token = await AuthService.getValidToken();

      final response = await ApiService.getJson(
        '/api/volunteers/pending-offers',
        token: token,
      );

      if (mounted) {
        setState(() {
          _volunteerOffers = List<Map<String, dynamic>>.from(
            response['offers'] ?? [],
          );
          _isLoadingVolunteerOffers = false;
        });

        if (_volunteerOffers.isNotEmpty) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVolunteerOffers = false;
        });
      }
    }
  }

  void _setupNotificationListeners() {
    final user = AuthService.getCurrentUser();
    if (user != null) {
      NotificationService.setContext(context);

      NotificationService.initializeRealTime()
          .then((_) {
            _verificationSubscription = NotificationService.verificationStream
                .listen((data) {
                  if (data['type'] == 'identity_verified' && mounted) {
                    setState(() {
                      _showVerificationAlert = false;
                    });
                  }
                });

            _donationVerificationSubscription = NotificationService
                .donationVerificationStream
                ?.listen((data) {
                  if (mounted) {
                    if (data['type'] == 'donation_verified') {
                      _loadDonationData(); // Refresh stats and recent donations
                    } else if (data['type'] == 'donation_rejected') {
                      _loadDonationData(); // Refresh stats and recent donations
                    } else if (data['type'] == 'donation_status_changed') {
                      _loadDonationData(); // Refresh for any status change
                    } else if (data['type'] == 'donation_created') {
                      _loadDonationData(); // Refresh for new donations
                    }
                  }
                });

            _setupVolunteerAcceptanceListener();
            _setupDeliveryAcceptanceListener();
          })
          .catchError((error) {});
    }
  }

  void _setupVolunteerAcceptanceListener() {
    try {
      final user = AuthService.getCurrentUser();
      if (user != null) {
        // Listen for volunteer acceptance via ChatService socket
        NotificationService.socket?.on('volunteer_accepted', (data) {
          if (mounted) {
            // Show notification with volunteer details
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.volunteer_activism, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🎉 Volunteer Found!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${data['volunteerName']} will deliver "${data['title']}"',
                    ),
                    if (data['volunteerPhone'] != null)
                      Text('Contact: ${data['volunteerPhone']}'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );

            // Refresh dashboard to show updated donation status
            _loadDonationData();
          }
        });
      }
    } catch (e) {}
  }

  void _setupDeliveryAcceptanceListener() {
    try {
      final user = AuthService.getCurrentUser();
      if (user != null) {
        // Listen for delivery acceptance notifications via ChatService socket
        NotificationService.socket?.on('delivery_accepted', (data) {
          if (mounted) {
            // Show notification with delivery person details
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🚚 Delivery Person Found!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${data['deliveryPersonName']} will handle "${data['donationTitle']}"',
                    ),
                    if (data['deliveryPersonPhone'] != null)
                      Text('Contact: ${data['deliveryPersonPhone']}'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );

            // Refresh dashboard to show updated donation status
            _loadDonationData();
          }
        });
      }
    } catch (e) {}
  }

  void _showVerificationRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 32),
              SizedBox(width: 12),
              Text('Verification Required'),
            ],
          ),
          content: Text(
            'You need to complete identity verification before making donations. This helps ensure the safety and authenticity of our community.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IdentityVerificationScreen(),
                  ),
                );
              },
              child: Text('Verify Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showVerificationPendingDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.hourglass_empty, color: Colors.orange, size: 32),
              SizedBox(width: 12),
              Text('Verification Pending'),
            ],
          ),
          content: Text(
            'Your identity verification is currently being reviewed by our admin team. Please wait for approval before making donations.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _handleDonationAction() async {
    try {
      final user = AuthService.getCurrentUser();
      if (user == null) {
        _showVerificationRequiredDialog();
        return;
      }

      final verificationStatus = user.identityVerificationStatus?.toLowerCase();
      final isVerified = user.isVerified ?? false;
      final isIdentityVerified = user.isIdentityVerified ?? false;

      bool isFullyVerified =
          (verificationStatus == 'approved' ||
              verificationStatus == 'verified') &&
          (isVerified == true || isIdentityVerified == true);

      if (isFullyVerified) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DonateScreen()),
        );
      } else if (verificationStatus == 'pending') {
        _showVerificationPendingDialog();
      } else {
        _showVerificationRequiredDialog();
      }
    } catch (e) {
      _showVerificationRequiredDialog();
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Not specified';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildHeader() {
    final user = AuthService.getCurrentUser();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'D',
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
                  'Welcome back, ${user?.name ?? "Donor"}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thank you for making a difference',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildNotificationIcon(),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    final user = AuthService.getCurrentUser();
    final isVerified = user?.isIdentityVerified ?? false;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isVerified
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isVerified ? Icons.check_circle : Icons.warning,
        color: isVerified ? Colors.green : Colors.red,
        size: 20,
      ),
    );
  }

  Widget _buildVerificationAlert() {
    final user = AuthService.getCurrentUser();
    if (user == null) return Container();

    final isVerified = user.isVerified ?? false;
    final verificationStatus = user.identityVerificationStatus?.toLowerCase();
    final isIdentityVerified = user.isIdentityVerified ?? false;

    bool isFullyVerified =
        isVerified ||
        (verificationStatus == 'approved' ||
            verificationStatus == 'verified') ||
        isIdentityVerified;

    if (!isFullyVerified) {
      if (_showVerificationAlert) {
        _verificationAlertTimer = Timer(Duration(seconds: 5), () {
          setState(() {
            _showVerificationAlert = false;
          });
        });
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Please verify your identity to access donor features',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IdentityVerificationScreen(),
                  ),
                );
              },
              child: Text('Verify'),
            ),
          ],
        ),
      );
    }

    if (isFullyVerified) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your identity verification has been approved!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    return Container();
  }

  Widget _buildStatsSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Your Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Donation Stats - 4 key metrics only
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${_donationStats['overview']?['totalDonations'] ?? 0}',
                  'Total Donations',
                  Icons.volunteer_activism,
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  '${_donationStats['overview']?['verifiedDonations'] ?? 0}',
                  'Verified',
                  Icons.verified,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${_donationStats['overview']?['pendingDonations'] ?? 0}',
                  'Pending',
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  '${_donationStats['overview']?['completedDonations'] ?? 0}',
                  'Completed',
                  Icons.check_circle,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String number,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            number,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOffersSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.local_shipping, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Offers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    Text(
                      'Professional delivery partners ready to help',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (_deliveryOffers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_deliveryOffers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_deliveryOffers.isEmpty)
            _buildEmptyDeliveryState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _deliveryOffers.length,
              itemBuilder: (context, index) {
                final offer = _deliveryOffers[index];
                return _buildEnhancedDeliveryCard(offer);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDeliveryState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No delivery offers yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Delivery partners will offer to help deliver your donations.',
            style: TextStyle(fontSize: 14, color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDeliveryCard(Map<String, dynamic> offer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${offer['offeredBy']?['name'] ?? offer['deliveryPersonId']?['name'] ?? offer['deliveryPersonName'] ?? 'Unknown'} wants to deliver',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text('Item: ${offer['itemTitle'] ?? 'Unknown Item'}'),
                      Text(
                        'Contact: ${offer['offeredBy']?['phone'] ?? offer['deliveryPersonId']?['phone'] ?? offer['deliveryPersonPhone'] ?? 'N/A'}',
                      ),
                      if (offer['estimatedEarning'] != null)
                        Text(
                          'Earning: PKR ${offer['estimatedEarning']}',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveDeliveryOffer(offer['id']),
                    icon: Icon(Icons.check, size: 18),
                    label: Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectDeliveryOffer(offer),
                    icon: Icon(Icons.close, size: 18),
                    label: Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/delivery-person-details',
                      arguments: {
                        'deliveryPersonData': {
                          'name':
                              offer['offeredBy']?['name'] ??
                              offer['deliveryPersonId']?['name'] ??
                              offer['deliveryPersonName'],
                          'phone':
                              offer['offeredBy']?['phone'] ??
                              offer['deliveryPersonId']?['phone'] ??
                              offer['deliveryPersonPhone'],
                          '_id':
                              offer['offeredBy']?['id'] ??
                              offer['deliveryPersonId']?['id'] ??
                              offer['deliveryPersonId'],
                        },
                        'itemData': {
                          'title': offer['itemTitle'],
                          '_id': offer['itemId'],
                        },
                        'itemType': 'donation',
                      },
                    );
                  },
                  icon: Icon(Icons.info, color: Colors.blue),
                  tooltip: 'View Details',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _approveDeliveryOffer(String offerId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Approving delivery offer...'),
            ],
          ),
        ),
      );

      final token = await AuthService.getValidToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}/api/delivery-offers/$offerId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Delivery offer approved! Delivery person notified.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Refresh data
        _loadDeliveryOffers();
        _loadDonationData();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to approve delivery offer',
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve offer: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _rejectDeliveryOffer(Map<String, dynamic> offer) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Delivery Offer'),
        content: Text('Are you sure you want to reject this delivery offer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Rejecting delivery offer...'),
              ],
            ),
          ),
        );

        final token = await AuthService.getValidToken();
        final offerId = offer['id'] ?? offer['offerId'] ?? offer['_id'];

        if (offerId == null) {
          throw Exception('Offer ID not found');
        }

        final response = await http.post(
          Uri.parse('${ApiService.base}/api/delivery-offers/$offerId/reject'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({'message': 'Offer declined'}),
        );

        Navigator.pop(context); // Close loading dialog

        if (response.statusCode == 200) {
          setState(() {
            _deliveryOffers.removeWhere(
              (offer) => offer['offerId'] == offer['offerId'],
            );
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '❌ Delivery offer rejected. The delivery person has been notified.',
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );

          // Refresh data
          _loadDeliveryOffers();
        } else {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'Failed to reject delivery offer',
          );
        }
      } catch (e) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject offer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildVolunteerOffersSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volunteer_activism,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volunteer Offers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    Text(
                      'Kind volunteers ready to help deliver your donations',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (_volunteerOffers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_volunteerOffers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingVolunteerOffers)
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading volunteer offers...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            )
          else if (_volunteerOffers.isEmpty)
            _buildEmptyVolunteerState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _volunteerOffers.length,
              itemBuilder: (context, index) {
                final offer = _volunteerOffers[index];
                return _buildEnhancedVolunteerCard(offer);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyVolunteerState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.volunteer_activism_outlined,
              size: 48,
              color: Colors.green.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Volunteer Offers Yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Volunteers will offer to help deliver your donations to those in need.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryTextColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Free volunteer delivery offers',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedVolunteerCard(Map<String, dynamic> offer) {
    final volunteerName =
        offer['offeredBy']?['name'] ?? offer['volunteerName'] ?? 'Unknown';
    final volunteerPhone =
        offer['offeredBy']?['phone'] ?? offer['volunteerPhone'] ?? '';
    final itemTitle = offer['itemTitle'] ?? 'Unknown Item';
    final offeredAt = offer['offeredAt'] ?? offer['createdAt'];

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/volunteer-details',
          arguments: {
            'volunteerData': {
              'name': volunteerName,
              'phone': volunteerPhone,
              '_id': offer['offeredBy']?['id'] ?? offer['volunteerId'],
            },
            'itemData': {'title': itemTitle, '_id': offer['itemId']},
            'itemType': 'donation',
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.volunteer_activism,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$volunteerName wants to volunteer',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Item: $itemTitle',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        if (volunteerPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Contact: $volunteerPhone',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          'Offered: ${_formatDateTime(offeredAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveVolunteerOffer(offer['id']),
                      icon: Icon(Icons.check_circle, size: 16),
                      label: Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectVolunteerOffer(offer),
                      icon: Icon(Icons.cancel, size: 16),
                      label: Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _approveVolunteerOffer(String offerId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Approving volunteer offer...'),
            ],
          ),
        ),
      );

      final token = await AuthService.getValidToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}/api/volunteers/approve-offer/$offerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Volunteer offer approved! Volunteer notified.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Refresh data
        _loadVolunteerOffers();
        _loadDonationData();

        // Navigate to accepted offers screen
        Navigator.pushNamed(context, '/accepted-offers');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to approve volunteer offer',
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve offer: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _rejectVolunteerOffer(Map<String, dynamic> offer) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Volunteer Offer'),
        content: Text('Are you sure you want to reject this volunteer offer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final token = await AuthService.getValidToken();
        final response = await http.post(
          Uri.parse(
            '${ApiService.base}/api/volunteers/reject-offer/${offer['id']}',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          // Remove from local list
          setState(() {
            _volunteerOffers.removeWhere((item) => item['id'] == offer['id']);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Volunteer offer rejected'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          throw Exception('Failed to reject offer');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject offer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildQuickActionsSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Donate Food',
                  Icons.add,
                  AppTheme.primaryColor,
                  _handleDonationAction,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'My Donations',
                  Icons.list,
                  Colors.blue,
                  () => Navigator.pushNamed(context, '/donation-list'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final user = AuthService.getCurrentUser();
    final isVerified = user?.isVerified ?? false;
    final verificationStatus = user?.identityVerificationStatus?.toLowerCase();
    final isDonateButton = label == 'Donate Food';

    bool isDisabled = false;
    Color buttonColor = color;
    Color textColor = color;

    if (isDonateButton &&
        (!isVerified ||
            (verificationStatus != 'approved' &&
                verificationStatus != 'verified'))) {
      isDisabled = true;
      buttonColor = Colors.grey;
      textColor = Colors.grey;
    }

    return GestureDetector(
      onTap: isDisabled ? () => _showVerificationRequiredDialog() : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: buttonColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Icon(icon, color: textColor, size: 28),
                if (isDisabled)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              isDisabled ? 'Verify Required' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (isDisabled)
              Text(
                '(Identity verification needed)',
                style: TextStyle(fontSize: 10, color: Colors.red),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 70,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 'Home', 0),
          _buildNavItem(Icons.volunteer_activism, 'Donate', 1),
          _buildNavItem(Icons.check_circle, 'Offers', 2),
          _buildNavItem(Icons.person, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = index == _selectedIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });

        if (index == 0) {
          // Already on home, just refresh
          _loadDonationData();
        } else if (index == 1) {
          _handleDonationAction();
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AcceptedOffersScreen()),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.secondaryTextColor,
              size: isSelected ? 28 : 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadDonationData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: 20),
              _buildVerificationAlert(),
              SizedBox(height: 20),
              SizedBox(height: 20),
              _buildStatsSection(),
              SizedBox(height: 20),
              _buildDeliveryOffersSection(),
              SizedBox(height: 20),
              _buildVolunteerOffersSection(),
              SizedBox(height: 20),
              _buildQuickActionsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}
