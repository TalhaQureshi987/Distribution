import 'package:flutter/material.dart';
import 'dart:async';
import '../common/profile_screen.dart';
import 'offers_screen.dart';
import '../auth/identity_verification_screen.dart';
import 'delivery_screen.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../config/theme.dart';

class DeliveryDashboard extends StatefulWidget {
  @override
  _DeliveryDashboardState createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  int _selectedIndex = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _availableDeliveries = [];
  List<Map<String, dynamic>> _earnings = [];
  Map<String, dynamic> _deliveryStats = {
    'totalEarned': 0.0,
    'availableEarnings': 0.0,
    'completedDeliveries': 0,
    'availableDeliveries': 0,
    'pendingDeliveries': 0,
    'estimatedHours': 0,
    'foodTypeBreakdown': {},
    'recentActivity': [],
  };
  StreamSubscription? _verificationSubscription;
  StreamSubscription? _donationVerificationSubscription;
  StreamSubscription? _requestVerificationSubscription;
  bool _showVerificationAlert = true;
  Timer? _verificationAlertTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupDeliveryListeners();
    _setupNotificationListeners();

    // Show verification alert initially for unverified users
    final user = AuthService.getCurrentUser();
    if (user != null) {
      final isVerified = user.isVerified;
      final verificationStatus = user.identityVerificationStatus.toLowerCase();
      final isIdentityVerified = user.isIdentityVerified;

      bool isFullyVerified =
          isVerified ||
          verificationStatus == 'approved' ||
          verificationStatus == 'verified' ||
          isIdentityVerified;

      if (!isFullyVerified) {
        setState(() {
          _showVerificationAlert = true;
        });

        // Auto-hide after 5 seconds
        _verificationAlertTimer = Timer(Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showVerificationAlert = false;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _verificationSubscription?.cancel();
    _donationVerificationSubscription?.cancel();
    _requestVerificationSubscription?.cancel();
    _verificationAlertTimer?.cancel();
    super.dispose();
  }

  void _setupDeliveryListeners() {
    // Listen for new delivery opportunities via NotificationService
    NotificationService.socket?.on('new_delivery_opportunity', (data) {
      if (mounted) {
        setState(() {
          _availableDeliveries.insert(0, {
            'id': data['deliveryId'] ?? '',
            'title': data['title'] ?? 'Food Delivery',
            'pickupAddress': data['pickupAddress'] ?? '',
            'deliveryAddress': data['deliveryAddress'] ?? '',
            'estimatedEarning': data['estimatedEarning'] ?? 50,
            'distance': data['distance'] ?? 0,
            'status': 'available',
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New delivery opportunity! Earn ${data['estimatedEarning']} PKR',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    // Listen for earning notifications via NotificationService
    NotificationService.socket?.on('earning_added', (data) {
      if (mounted) {
        setState(() {
          _earnings.insert(0, {
            'id': data['earningId'] ?? '',
            'amount': data['amount'] ?? 0,
            'status': data['status'] ?? 'pending',
            'earnedAt': DateTime.now().toIso8601String(),
            'description': data['description'] ?? 'Delivery earning',
            'remarks': data['remarks'] ?? 'Delivery completed successfully',
            'deliveryId': data['deliveryId'] ?? '',
          });
        });

        // Update stats
        _deliveryStats['totalEarned'] =
            (_deliveryStats['totalEarned'] ?? 0.0) + (data['amount'] ?? 0);
        _deliveryStats['completedDeliveries'] =
            (_deliveryStats['completedDeliveries'] ?? 0) + 1;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎉 You earned ${data['amount']} PKR!'),
                if (data['remarks'] != null)
                  Text(
                    'Remark: ${data['remarks']}',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });

    // Listen for delivery status confirmations via NotificationService
    NotificationService.socket?.on('delivery_status_confirmed', (data) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ ${data['message'] ?? 'Status updated'}'),
                if (data['remarks'] != null)
                  Text(
                    'Note: ${data['remarks']}',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh dashboard data to show updated status
        _loadDashboardData();
      }
    });
  }

  void _setupNotificationListeners() {
    // Initialize NotificationService for real-time notifications
    final user = AuthService.getCurrentUser();
    if (user != null) {
      print(
        '🔔 DELIVERY: Setting up notification listeners for user: ${user.name}',
      );

      // Set context for toast notifications
      NotificationService.setContext(context);

      // Initialize real-time notifications
      NotificationService.initializeRealTime()
          .then((_) {
            print('✅ DELIVERY: NotificationService initialized');

            // Listen for verification updates
            _verificationSubscription = NotificationService.verificationStream.listen((
              data,
            ) {
              print('🔔 DELIVERY: Verification notification received: $data');

              if (data['type'] == 'identity_verified' && mounted) {
                print('🔔 DELIVERY: Identity verification approved!');

                // Update user data from socket
                AuthService.updateCurrentUserFromSocket(data);

                // Force refresh user data from backend to ensure consistency
                AuthService.refreshUserData();

                // Force refresh dashboard data and UI with verification status update
                setState(() {
                  _loading = true;
                  _showVerificationAlert = false; // Hide verification alert
                });

                // Reload all delivery data
                _loadDashboardData().then((_) {
                  // After data is loaded, update UI state again to reflect verification status
                  if (mounted) {
                    setState(() {
                      _loading = false;
                      // Force UI rebuild to show verification status changes
                    });
                  }
                });

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✅ Identity verified! Delivery features unlocked.',
                            style: TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4),
                  ),
                );

                print(
                  '✅ DELIVERY: Dashboard refreshed after verification approval',
                );
              }
            });

            // Listen for request verification updates
            _requestVerificationSubscription = NotificationService
                .requestVerificationStream
                .listen((data) {
                  if (data['type'] == 'request_verified' && mounted) {
                    // Refresh dashboard data
                    _loadDashboardData();
                  } else if (data['type'] == 'request_rejected' && mounted) {
                    // Refresh dashboard data
                    _loadDashboardData();
                  }
                });

            // Listen for donation verification updates
            _donationVerificationSubscription = NotificationService
                .donationVerificationStream
                .listen((data) {
                  if (data['type'] == 'donation_verified' && mounted) {
                    // Refresh dashboard data
                    _loadDashboardData();
                  } else if (data['type'] == 'donation_rejected' && mounted) {
                    // Refresh dashboard data
                    _loadDashboardData();
                  }
                });

            print('✅ DELIVERY: Notification listeners setup complete');
          })
          .catchError((error) {
            print(
              '❌ DELIVERY: Failed to initialize NotificationService: $error',
            );
          });
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);

    try {
      final user = AuthService.getCurrentUser();
      if (user != null) {
        // Load delivery dashboard stats (real-time data)
        final statsResponse = await ApiService.getJson(
          '/api/deliveries/dashboard-stats',
          token: await AuthService.getValidToken(),
        );

        if (statsResponse['success'] == true) {
          final stats = statsResponse['stats'];
          _deliveryStats = {
            'totalEarned': stats['totalEarned'] ?? 0.0,
            'availableEarnings': stats['availableEarnings'] ?? 0.0,
            'completedDeliveries': stats['completedDeliveries'] ?? 0,
            'availableDeliveries': stats['availableDeliveries'] ?? 0,
            'pendingDeliveries': stats['pendingDeliveries'] ?? 0,
            'estimatedHours': stats['estimatedHours'] ?? 0,
            'foodTypeBreakdown': stats['foodTypeBreakdown'] ?? {},
            'recentActivity': stats['recentActivity'] ?? [],
          };
        }

        // Load available deliveries (real data from donations and requests)
        final availableResponse = await ApiService.getJson(
          '/api/deliveries/available',
          token: await AuthService.getValidToken(),
        );

        if (availableResponse['success'] == true) {
          _availableDeliveries = List<Map<String, dynamic>>.from(
            availableResponse['deliveries'] ?? [],
          );
        }

        // My deliveries section removed from home page

        // Load earnings
        final earningsResponse = await ApiService.getJson(
          '/api/deliveries/my-earnings',
          token: await AuthService.getValidToken(),
        );

        if (earningsResponse['success'] == true) {
          _earnings = List<Map<String, dynamic>>.from(
            earningsResponse['earnings'] ?? [],
          );
        }
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      _availableDeliveries = [];
      _earnings = [];
      _deliveryStats = {
        'totalEarned': 0.0,
        'availableEarnings': 0.0,
        'completedDeliveries': 0,
        'availableDeliveries': 0,
        'pendingDeliveries': 0,
        'estimatedHours': 0,
        'foodTypeBreakdown': {},
        'recentActivity': [],
      };
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.getCurrentUser();
    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      );
    }

    final isVerified =
        user.isIdentityVerified ||
        user.identityVerificationStatus == 'approved' ||
        user.identityVerificationStatus == 'verified' ||
        user.isVerified;

    if (_loading) {
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header at the top
              _buildWelcomeHeader(),
              const SizedBox(height: 20),

              // Verification alert
              _buildVerificationAlert(),
              const SizedBox(height: 20),

              // Identity verification notification
              _buildVerificationNotification(),
              const SizedBox(height: 20),

              // Stats section
              _buildStatsSection(),
              const SizedBox(height: 20),

              // Show delivery sections only if verified
              if (isVerified) ...[
                // Removed available deliveries and my deliveries sections from home page
              ] else ...[
                _buildVerificationRequiredMessage(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildWelcomeHeader() {
    final user = AuthService.getCurrentUser();
    final userName = user?.name ?? 'Delivery Partner';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'D',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $userName!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to deliver and earn money?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
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

  Widget _buildVerificationNotification() {
    final user = AuthService.getCurrentUser();
    if (user == null) return SizedBox.shrink();

    final isVerified =
        user.isIdentityVerified ||
        user.identityVerificationStatus == 'approved' ||
        user.identityVerificationStatus == 'verified' ||
        user.isVerified;

    if (!isVerified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identity Verification Required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete identity verification to access delivery features and start earning.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/identity-verification');
              },
              child: Text('Verify Now'),
            ),
          ],
        ),
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildVerificationAlert() {
    final user = AuthService.getCurrentUser();
    if (user == null) return Container();

    final isVerified = user.isVerified;
    final verificationStatus = user.identityVerificationStatus.toLowerCase();
    final isIdentityVerified = user.isIdentityVerified;

    bool isFullyVerified =
        isVerified ||
        verificationStatus == 'approved' ||
        verificationStatus == 'verified' ||
        isIdentityVerified;

    if (!isFullyVerified && _showVerificationAlert) {
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
                'Please verify your identity to access delivery features',
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
                    builder: (_) => IdentityVerificationScreen(),
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

  Widget _buildVerificationRequiredMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Deliveries Locked',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete identity verification to unlock delivery opportunities and start earning.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => IdentityVerificationScreen()),
              );
            },
            icon: Icon(Icons.verified_user),
            label: Text('Verify Identity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
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
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'PKR ${(_deliveryStats['totalEarned'] * 0.9)?.toStringAsFixed(0) ?? '0'}',
                  'Your Payment',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '${_deliveryStats['completedDeliveries'] ?? 0}',
                  'Completed',
                  Icons.check_circle,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${_deliveryStats['pendingDeliveries'] ?? 0}',
                  'Process',
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '${_deliveryStats['availableDeliveries'] ?? 0}',
                  'Available',
                  Icons.local_shipping,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
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
          _buildNavItem(Icons.local_shipping, 'Deliveries', 1),
          _buildNavItem(Icons.check_circle, 'Offers', 2),
          _buildNavItem(Icons.person, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (index == 1)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DeliveryScreen()),
          );
        if (index == 2)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => OffersScreen()),
          );
        if (index == 3)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen()),
          );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.blue : Colors.grey,
            size: isSelected ? 28 : 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        Icon(Icons.notifications, color: Colors.white, size: 24),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  // Add these methods before the closing brace of _DeliveryDashboardState class
}
