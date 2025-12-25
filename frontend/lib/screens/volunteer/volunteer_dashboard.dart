import 'package:flutter/material.dart';
import 'dart:async';
import '../common/profile_screen.dart';
import '../common/volunteer_screen_new.dart';
import '../auth/identity_verification_screen.dart';
import '../../services/auth_service.dart';
import '../../services/volunteer_service.dart';
import '../../services/notification_service.dart';
import '../../config/theme.dart';

class VolunteerDashboard extends StatefulWidget {
  @override
  _VolunteerDashboardState createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  int _selectedIndex = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _recentActivities = [];
  List<Map<String, dynamic>> _availableDeliveries = [];
  List<Map<String, dynamic>> _myVolunteerDeliveries = [];
  List<Map<String, dynamic>> _volunteerRewards = [];
  Map<String, dynamic> _volunteerStats = {
    'totalPoints': 0,
    'availableOpportunities': 0,
    'completedDeliveries': 0,
    'activeDeliveries': 0,
    'totalVolunteerHours': 0,
    'peopleHelped': 0,
    'foodTypeBreakdown': {},
    'recentActivity': [],
  };
  StreamSubscription<Map<String, dynamic>>? _verificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _donationVerificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _requestVerificationSubscription;
  StreamSubscription? _emailVerificationSubscription;
  bool _showVerificationAlert = false;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    _loadVolunteerData();
    _setupNotificationListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning from other screens
    _loadVolunteerData();
  }

  void _setupNotificationListeners() {
    // Initialize NotificationService for real-time notifications
    final user = AuthService.getCurrentUser();
    if (user != null) {
      print(
        '🔔 VOLUNTEER: Setting up notification listeners for user: ${user.name}',
      );

      // Set context for toast notifications
      NotificationService.setContext(context);

      // Initialize real-time notifications
      NotificationService.initializeRealTime()
          .then((_) {
            print('✅ VOLUNTEER: NotificationService initialized');

            // Listen for new volunteer opportunities via NotificationService
            NotificationService.socket?.on('new_volunteer_opportunity', (data) {
              if (mounted) {
                setState(() {
                  _availableDeliveries.insert(0, {
                    'id': data['deliveryId'] ?? '',
                    'title': data['title'] ?? 'Volunteer Delivery',
                    'pickupAddress': data['pickupAddress'] ?? '',
                    'deliveryAddress': data['deliveryAddress'] ?? '',
                    'estimatedPoints': data['estimatedPoints'] ?? 10,
                    'distance': data['distance'] ?? 0,
                    'status': 'available',
                  });
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'New volunteer opportunity! Earn ${data['estimatedPoints']} points',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            });

            // Listen for volunteer points/rewards notifications
            NotificationService.socket?.on('volunteer_points_added', (data) {
              if (mounted) {
                setState(() {
                  _volunteerRewards.insert(0, {
                    'id': data['rewardId'] ?? '',
                    'points': data['points'] ?? 0,
                    'status': data['status'] ?? 'earned',
                    'earnedAt': DateTime.now().toIso8601String(),
                    'description':
                        data['description'] ?? 'Volunteer service completed',
                    'remarks': data['remarks'] ?? 'Thank you for volunteering!',
                    'deliveryId': data['deliveryId'] ?? '',
                  });
                });

                // Update stats
                _volunteerStats['totalPoints'] =
                    (_volunteerStats['totalPoints'] ?? 0) +
                    (data['points'] ?? 0);
                _volunteerStats['completedDeliveries'] =
                    (_volunteerStats['completedDeliveries'] ?? 0) + 1;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🌟 You earned ${data['points']} volunteer points!',
                        ),
                        if (data['remarks'] != null)
                          Text(
                            'Note: ${data['remarks']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            });

            // Listen for volunteer status confirmations
            NotificationService.socket?.on('volunteer_status_confirmed', (
              data,
            ) {
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
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 3),
                  ),
                );

                // Refresh dashboard data to show updated status
                _loadVolunteerData();
              }
            });

            // Listen for volunteer offer completion
            NotificationService.socket?.on('volunteer_offer_completed', (data) {
              if (mounted) {
                // Update stats immediately
                setState(() {
                  _volunteerStats['completedDeliveries'] =
                      (_volunteerStats['completedDeliveries'] ?? 0) + 1;
                  _volunteerStats['totalPoints'] =
                      (_volunteerStats['totalPoints'] ?? 0) +
                      (data['points'] ?? 0);
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🎉 Volunteer delivery completed!'),
                        if (data['points'] != null)
                          Text(
                            'Earned ${data['points']} points',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4),
                  ),
                );

                // Refresh all dashboard data
                _loadVolunteerData();
              }
            });

            // Listen for verification updates (existing code)
            _verificationSubscription = NotificationService.verificationStream.listen((
              data,
            ) {
              print('🔔 VOLUNTEER: Verification notification received: $data');

              if (data['type'] == 'identity_verified' && mounted) {
                print('🔔 VOLUNTEER: Identity verification approved!');

                // Update user data from socket
                AuthService.updateCurrentUserFromSocket(data);

                // Force refresh user data from backend to ensure consistency
                AuthService.refreshUserData();

                // Force refresh dashboard data and UI with verification status update
                setState(() {
                  _loading = true;
                  _showVerificationAlert = false; // Hide verification alert
                });

                // Reload all volunteer data
                _loadVolunteerData().then((_) {
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
                            '✅ Identity verified! Volunteer features unlocked.',
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
                  '✅ VOLUNTEER: Dashboard refreshed after verification approval',
                );
              }
            });

            // Listen for request verification updates
            _requestVerificationSubscription = NotificationService
                .requestVerificationStream
                .listen((data) {
                  if (data['type'] == 'request_verified' && mounted) {
                    // Refresh dashboard data
                    _loadVolunteerData();
                  } else if (data['type'] == 'request_rejected' && mounted) {
                    // Refresh dashboard data
                    _loadVolunteerData();
                  }
                });

            // Listen for donation verification updates
            _donationVerificationSubscription = NotificationService
                .donationVerificationStream
                .listen((data) {
                  if (data['type'] == 'donation_verified' && mounted) {
                    // Refresh dashboard data
                    _loadVolunteerData();
                  } else if (data['type'] == 'donation_rejected' && mounted) {
                    // Refresh dashboard data
                    _loadVolunteerData();
                  }
                });

            print('✅ VOLUNTEER: Notification listeners setup complete');
          })
          .catchError((error) {
            print(
              '❌ VOLUNTEER: Failed to initialize NotificationService: $error',
            );
          });
    }
  }

  @override
  void dispose() {
    _verificationSubscription?.cancel();
    _donationVerificationSubscription?.cancel();
    _requestVerificationSubscription?.cancel();
    _emailVerificationSubscription?.cancel();
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVolunteerData() async {
    try {
      final user = AuthService.getCurrentUser();
      if (user != null) {
        print('🔄 Loading volunteer data for user: ${user.name}');
        print(
          '🔄 User verification status: ${user.identityVerificationStatus}',
        );

        // Load recent volunteer activities - filter only completed deliveries
        final activities =
            await VolunteerService.getVolunteerActivitiesForDashboard(user.id);
        _recentActivities = activities
            .where((activity) => activity['status'] == 'completed')
            .take(5)
            .toList();

        // Load available deliveries
        final deliveries = await VolunteerService.getAvailableDeliveries();
        _availableDeliveries = deliveries.take(3).toList();

        // Load volunteer deliveries
        final volunteerDeliveries =
            await VolunteerService.getVolunteerDeliveries(user.id);
        _myVolunteerDeliveries = volunteerDeliveries;

        // Load volunteer rewards
        final rewards = await VolunteerService.getVolunteerRewards(user.id);
        _volunteerRewards = rewards;

        // Load volunteer dashboard stats from new endpoint
        final stats = await VolunteerService.getVolunteerDashboardStats();
        _volunteerStats = stats;

        print('✅ Volunteer data loaded successfully');
        print('📊 Stats: $_volunteerStats');
        print('📦 Available deliveries: ${_availableDeliveries.length}');
        print('🚚 Volunteer deliveries: ${_myVolunteerDeliveries.length}');
      } else {
        print('❌ No user found, cannot load volunteer data');
      }
    } catch (e) {
      print('❌ Error loading volunteer data: $e');
      _recentActivities = [];
      _availableDeliveries = [];
      _myVolunteerDeliveries = [];
      _volunteerRewards = [];
      _volunteerStats = {
        'totalPoints': 0,
        'availableOpportunities': 0,
        'completedDeliveries': 0,
        'activeDeliveries': 0,
        'totalVolunteerHours': 0,
        'peopleHelped': 0,
        'foodTypeBreakdown': {},
        'recentActivity': [],
      };
    }

    setState(() => _loading = false);
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
                'Please verify your identity to access volunteer features',
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

  Widget _buildWelcomeHeader() {
    final user = AuthService.getCurrentUser();
    final userName = user?.name ?? 'Volunteer';

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
                userName.isNotEmpty ? userName[0].toUpperCase() : 'V',
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
                  'Ready to volunteer and make a difference?',
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
            'Volunteer Features Locked',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete identity verification to unlock volunteer features and start helping your community.',
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
                  '${_volunteerStats['totalPoints'] ?? 0}',
                  'Total Points',
                  Icons.star,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '${_volunteerStats['completedDeliveries'] ?? 0}',
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
                  '${_volunteerStats['activeDeliveries'] ?? 0}',
                  'Active',
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '${_volunteerStats['availableOpportunities'] ?? 0}',
                  'Available',
                  Icons.volunteer_activism,
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
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

  Widget _buildRecentActivitiesSection() {
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
              Icon(Icons.history, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentActivities.isEmpty)
            _buildNoActivitiesPlaceholder()
          else
            ..._recentActivities
                .map((activity) => _buildActivityItem(activity))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildNoActivitiesPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.volunteer_activism,
            size: 48,
            color: Colors.green.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No volunteer activities yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start volunteering to help your community.',
            style: TextStyle(fontSize: 14, color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final status = activity['status'] ?? 'pending';
    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'active'
        ? Colors.orange
        : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.volunteer_activism, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['description'] ?? 'Volunteer Activity',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hours: ${activity['hours'] ?? 0}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
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
          _buildNavItem(Icons.volunteer_activism, 'Volunteer', 1),
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

        switch (index) {
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => VolunteerScreen()),
            );
            break;
          case 2:
            // Navigate to Accepted Offers screen
            Navigator.pushNamed(context, '/accepted-volunteer-offers');
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            );
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green : AppTheme.secondaryTextColor,
              size: isSelected ? 28 : 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.green : AppTheme.secondaryTextColor,
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
    final user = AuthService.getCurrentUser();
    final isVerified = NotificationService.isUserFullyVerified(user);

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
        child: RefreshIndicator(
          onRefresh: _loadVolunteerData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(),
                const SizedBox(height: 20),

                // Identity verification notification
                _buildVerificationAlert(),
                const SizedBox(height: 20),

                // Stats section
                _buildStatsSection(),
                const SizedBox(height: 20),

                // Show delivery sections only if verified
                if (isVerified) ...[
                  _buildRecentActivitiesSection(),
                ] else ...[
                  _buildVerificationRequiredMessage(),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}
