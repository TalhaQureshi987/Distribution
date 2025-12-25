import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/api_service.dart';
import '../../../services/request_service.dart';
import 'request_screen.dart';
import 'request_offers_screen.dart';
import '../auth/identity_verification_screen.dart';
import '../common/profile_screen.dart';

class RequesterDashboard extends StatefulWidget {
  const RequesterDashboard({Key? key}) : super(key: key);

  @override
  State<RequesterDashboard> createState() => _RequesterDashboardState();
}

class _RequesterDashboardState extends State<RequesterDashboard>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> deliveryOffers = [];
  List<Map<String, dynamic>> _volunteerOffers = [];
  bool _isLoadingVolunteerOffers = false;
  Map<String, dynamic>? _requestStats;
  bool _isLoading = true;
  bool _showVerificationAlert = false;
  int _selectedIndex = 0;
  late StreamSubscription _verificationSubscription;
  late StreamSubscription? _requestVerificationSubscription;
  late StreamSubscription? _donationVerificationSubscription;
  Timer? _refreshTimer;
  Timer? _verificationAlertTimer;
  final _approvalMessageController = TextEditingController();
  final _rejectionMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupNotificationListeners();
    _loadDashboardData();
    _startPeriodicRefresh();

    // Show verification alert initially for unverified users
    final user = AuthService.getCurrentUser();
    if (user != null) {
      final isVerified = user.isVerified ?? false;
      final verificationStatus = user.identityVerificationStatus?.toLowerCase();
      final isIdentityVerified = user.isIdentityVerified ?? false;

      bool isFullyVerified =
          isVerified ||
          (verificationStatus == 'approved' ||
              verificationStatus == 'verified') ||
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

  void _startPeriodicRefresh() {
    // Refresh stats every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        print('🔄 REQUESTER: Periodic refresh triggered');
        _loadRequestStats();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print(' App resumed - refreshing dashboard data');
      _loadDashboardData();
      // Reinitialize notifications in case socket disconnected
      _setupNotificationListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _verificationSubscription.cancel();
    _requestVerificationSubscription?.cancel();
    _donationVerificationSubscription?.cancel();
    _verificationAlertTimer?.cancel();
    super.dispose();
  }

  void _setupNotificationListeners() {
    // Initialize NotificationService for real-time notifications
    final user = AuthService.getCurrentUser();
    if (user != null) {
      print(
        '🔔 REQUESTER: Setting up notification listeners for user: ${user.name}',
      );

      // Set context for toast notifications
      NotificationService.setContext(context);

      // Initialize real-time notifications
      NotificationService.initializeRealTime()
          .then((_) {
            print('✅ REQUESTER: NotificationService initialized');

            // Listen for verification updates
            _verificationSubscription = NotificationService.verificationStream.listen((
              data,
            ) {
              print('🔔 REQUESTER: Verification notification received: $data');

              if (data['type'] == 'identity_verified' && mounted) {
                print('🔔 REQUESTER: Identity verification approved!');

                // Update user data from socket
                AuthService.updateCurrentUserFromSocket(data);

                // Force refresh dashboard data and UI
                setState(() {
                  _isLoading = true;
                  _showVerificationAlert = false;
                });

                // Reload all requester data
                _loadDashboardData();

                // Silent success (no SnackBar)
                print(
                  '✅ REQUESTER: Dashboard refreshed after verification approval (silent)',
                );

                print(
                  '✅ REQUESTER: Dashboard refreshed after verification approval',
                );
              }
            });

            // Listen for request verification updates
            _requestVerificationSubscription = NotificationService
                .requestVerificationStream
                ?.listen((data) {
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
                ?.listen((data) {
                  if (data['type'] == 'donation_verified' && mounted) {
                    // Refresh dashboard data
                    _loadDashboardData();
                  } else if (data['type'] == 'donation_rejected' && mounted) {
                    // Refresh dashboard data
                    _loadDashboardData();
                  }
                });

            _setupVolunteerAcceptanceListener();
            _setupDeliveryAcceptanceListener();

            print('✅ REQUESTER: Notification listeners setup complete');
          })
          .catchError((error) {
            print(
              '❌ REQUESTER: Failed to initialize NotificationService: $error',
            );
          });
    }
  }

  void _setupVolunteerAcceptanceListener() {
    try {
      final user = AuthService.getCurrentUser();
      if (user != null) {
        // Listen for volunteer acceptance of requests via ChatService socket
        ChatService.socket?.on('volunteer_accepted_request', (data) {
          print('🚚 REQUESTER: Volunteer accepted request delivery: $data');

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
                  label: 'Chat',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to chat with volunteer
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: {
                        'recipientId': data['volunteerId'],
                        'recipientName': data['volunteerName'],
                        'requestId': data['requestId'],
                      },
                    );
                  },
                ),
              ),
            );

            // Refresh dashboard to show updated request status
            _loadDashboardData();
          }
        });

        // Listen for delivery offer notifications
        ChatService.socket?.on('delivery_offer_received', (data) {
          print('🚚 REQUESTER: Delivery offer received: $data');

          if (mounted) {
            // Show notification with delivery offer details
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
                            '🚚 New Delivery Offer!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${data['offeredByName']} wants to deliver "${data['itemTitle']}"',
                    ),
                    if (data['offeredByPhone'] != null)
                      Text('Contact: ${data['offeredByPhone']}'),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'View',
                  textColor: Colors.white,
                  onPressed: () {
                    // Refresh dashboard to show new offer
                    _loadDashboardData();
                  },
                ),
              ),
            );

            // Refresh dashboard to show new offer
            _loadDashboardData();
          }
        });

        print('✅ REQUESTER: Delivery offer listener setup complete');
        print('✅ REQUESTER: Volunteer acceptance listener setup complete');
      }
    } catch (e) {
      print('❌ REQUESTER: Error setting up volunteer acceptance listener: $e');
    }
  }

  void _setupDeliveryAcceptanceListener() {
    try {
      final user = AuthService.getCurrentUser();
      if (user != null) {
        // Listen for delivery acceptance notifications via ChatService socket
        ChatService.socket?.on('delivery_accepted_request', (data) {
          print(
            '🚚 REQUESTER: Delivery person accepted request delivery: $data',
          );

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
                      '${data['deliveryPersonName']} will handle "${data['requestTitle']}"',
                    ),
                    if (data['deliveryPersonPhone'] != null)
                      Text('Contact: ${data['deliveryPersonPhone']}'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Chat',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to chat with delivery person
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: {
                        'recipientId': data['deliveryPersonId'],
                        'recipientName': data['deliveryPersonName'],
                        'requestId': data['deliveryId'],
                      },
                    );
                  },
                ),
              ),
            );

            // Refresh dashboard to show updated request status
            _loadDashboardData();
          }
        });

        print('✅ REQUESTER: Delivery acceptance listener setup complete');
      }
    } catch (e) {
      print('❌ REQUESTER: Error setting up delivery acceptance listener: $e');
    }
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
            'You need to complete identity verification before making requests. This helps ensure the safety and authenticity of our community.',
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

  void _handleRequestAction() async {
    try {
      final user = AuthService.getCurrentUser();
      if (user == null) {
        _showVerificationRequiredDialog();
        return;
      }

      // Allow requests without strict verification - just navigate to request screen
      print('✅ REQUEST ACTION: Allowing navigation to request screen');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RequestScreen()),
      ).then((_) {
        // Refresh dashboard when returning from request screen
        _loadDashboardData();
      });
    } catch (e) {
      print('❌ Error handling request action: $e');
      _showVerificationRequiredDialog();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _loadRequestStats();
      await _loadDeliveryOffers();
      await _loadVolunteerOffers();
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRequestStats() async {
    try {
      final response = await RequestService.getRequestDashboardStats();
      setState(() {
        _requestStats = response;
      });
    } catch (e) {
      print('Error loading request stats: $e');
      setState(() {
        _requestStats = {
          'totalRequests': 0,
          'activeRequests': 0,
          'completedRequests': 0,
          'pendingRequests': 0,
          'verifiedRequests': 0,
          'pendingVerificationRequests': 0,
          'rejectedRequests': 0,
          'foodRequests': 0,
          'medicineRequests': 0,
          'clothesRequests': 0,
          'otherRequests': 0,
          'totalCommissionPaid': 0,
          'recentRequests': 0,
        };
      });
    }
  }

  Future<void> _loadDeliveryOffers() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/delivery-offers/for-approval',
        token: token,
      );
      setState(() {
        deliveryOffers = List<Map<String, dynamic>>.from(
          response['offers'] ?? [],
        );
      });
    } catch (e) {
      print('Error loading delivery offers: $e');
      setState(() {
        deliveryOffers = [];
      });
    }
  }

  Future<void> _loadVolunteerOffers() async {
    setState(() {
      _isLoadingVolunteerOffers = true;
    });

    try {
      final token = await AuthService.getValidToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}/api/volunteers/offers/for-approval'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final jsonData = jsonDecode(response.body);
      setState(() {
        _volunteerOffers = List<Map<String, dynamic>>.from(
          jsonData['offers'] ?? [],
        );
      });
    } catch (e) {
      print('Error loading volunteer offers: $e');
      setState(() {
        _volunteerOffers = [];
      });
    } finally {
      setState(() {
        _isLoadingVolunteerOffers = false;
      });
    }
  }

  void _refreshDashboard() {
    _loadDashboardData();
  }

  void _approveVolunteerOffer(String offerId) async {
    // Show loading dialog
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

    try {
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
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          setState(() {
            _volunteerOffers.removeWhere(
              (offer) => offer['offerId'] == offerId,
            );
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Volunteer offer approved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Refresh dashboard data
        _loadDashboardData();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to approve volunteer offer',
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading dialog if still open
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
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
      // Implement reject functionality
      setState(() {
        _volunteerOffers.removeWhere(
          (offer) => offer['offerId'] == offer['offerId'],
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Volunteer offer rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildVerificationAlert(),
              const SizedBox(height: 20),
              _buildStatsSection(),
              const SizedBox(height: 20),
              _buildDeliveryOffersSection(),
              const SizedBox(height: 20),
              _buildVolunteerOffersSection(),
              const SizedBox(height: 20),
              _buildQuickActionsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    final user = AuthService.getCurrentUser();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondaryColor,
            AppTheme.secondaryColor.withOpacity(0.8),
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
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'R',
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
                  'Welcome back, ${user?.name ?? "Requester"}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find the help you need today',
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

    // Check both isVerified and identityVerificationStatus for proper verification
    final isVerified = user.isVerified ?? false;
    final verificationStatus = user.identityVerificationStatus?.toLowerCase();
    final isIdentityVerified = user.isIdentityVerified ?? false;

    // User is verified if any of these conditions are true:
    // 1. isVerified is true
    // 2. identityVerificationStatus is 'approved' or 'verified'
    // 3. isIdentityVerified is true
    bool isFullyVerified =
        isVerified ||
        (verificationStatus == 'approved' ||
            verificationStatus == 'verified') ||
        isIdentityVerified;

    print(
      ' VERIFICATION CHECK - isVerified: $isVerified, status: $verificationStatus, isIdentityVerified: $isIdentityVerified, fullyVerified: $isFullyVerified',
    );

    // Only show alert for UNVERIFIED users
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
                'Please verify your identity to access requester features',
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

    // Show success alert only if verification was just approved
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
            IconButton(
              onPressed: () {
                setState(() {
                  // Remove alert
                });
              },
              icon: Icon(Icons.close, color: Colors.green, size: 18),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
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
              Icon(Icons.analytics, color: AppTheme.secondaryColor),
              const SizedBox(width: 8),
              Text(
                'Request Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simplified stats - only 4 key metrics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${_requestStats?['totalRequests'] ?? 0}',
                  'Total',
                  Icons.request_page,
                  AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  '${_requestStats?['verifiedRequests'] ?? 0}',
                  'Verified',
                  Icons.verified,
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
                  '${_requestStats?['pendingRequests'] ?? 0}',
                  'Pending',
                  Icons.hourglass_empty,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  '${_requestStats?['completedRequests'] ?? 0}',
                  'Completed',
                  Icons.check_circle,
                  Colors.green,
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
                      'Kind volunteers ready to help deliver your requests',
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: Colors.orange,
                  size: 20,
                ),
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
              if (deliveryOffers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${deliveryOffers.length}',
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
          if (deliveryOffers.isEmpty)
            _buildEmptyDeliveryState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: deliveryOffers.length,
              itemBuilder: (context, index) {
                final offer = deliveryOffers[index];
                return _buildEnhancedDeliveryCard(offer);
              },
            ),
        ],
      ),
    );
  }

  void _approveDeliveryOffer(String offerId) async {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Approve Delivery Offer'),
          content: TextField(
            controller: _approvalMessageController,
            decoration: InputDecoration(
              labelText: 'Message (optional)',
              hintText: 'Thank you for helping with this delivery!',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                final response = await ApiService.postJsonAuth(
                  '/api/delivery-offers/$offerId/approve',
                  body: {'message': _approvalMessageController.text},
                  token: await AuthService.getValidToken(),
                );

                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Delivery offer approved successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadDeliveryOffers();
                  _approvalMessageController.clear();
                } else {
                  throw Exception(
                    response['message'] ?? 'Failed to approve offer',
                  );
                }
              },
              child: Text('Approve'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _rejectDeliveryOffer(String offerId) async {
    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reject Delivery Offer'),
          content: TextField(
            controller: _rejectionMessageController,
            decoration: InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'Thank you, but I found another option.',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                final response = await ApiService.postJsonAuth(
                  '/api/delivery-offers/$offerId/reject',
                  body: {'message': _rejectionMessageController.text},
                  token: await AuthService.getValidToken(),
                );

                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delivery offer rejected'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  _loadDeliveryOffers();
                  _rejectionMessageController.clear();
                } else {
                  throw Exception(
                    response['message'] ?? 'Failed to reject offer',
                  );
                }
              },
              child: Text('Reject'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
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
              Icon(Icons.flash_on, color: AppTheme.secondaryColor),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Request Food',
                  Icons.request_page,
                  AppTheme.secondaryColor,
                  _handleRequestAction,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Browse Donations',
                  Icons.list_alt,
                  AppTheme.primaryColor,
                  () {
                    // Navigate to browse donations
                  },
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
    final isRequestButton = label == 'Request Food';

    // Determine if this button should be disabled
    bool isDisabled = false;
    Color buttonColor = color;
    Color textColor = color;

    if (isRequestButton &&
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
            const SizedBox(height: 8),
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
          _buildNavItem(Icons.request_page, 'Request', 1),
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
          _refreshDashboard();
        } else if (index == 1) {
          // Always navigate to Request screen from bottom navbar
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RequestScreen()),
          );
        } else if (index == 2) {
          // Navigate to Offers screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RequestOffersScreen()),
          );
        } else if (index == 3) {
          // Navigate to Profile screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileScreen()),
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
                  ? AppTheme.secondaryColor
                  : AppTheme.secondaryTextColor,
              size: isSelected ? 28 : 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? AppTheme.secondaryColor
                    : AppTheme.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
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
            'Volunteers will offer to help deliver your requests to those in need.',
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
    final offeredAt = offer['createdAt'];

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/volunteer-details',
          arguments: {
            'volunteerData': {
              'name': volunteerName,
              'phone': volunteerPhone,
              '_id': offer['volunteerId'],
            },
            'itemData': {'title': itemTitle, '_id': offer['itemId']},
            'itemType': 'request',
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
                        // Volunteer info
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

                        // Owner info (donor/requester)
                        if (offer['owner'] != null) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From: ${offer['owner']['name'] ?? 'Unknown'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                                if (offer['owner']['phone'] != null)
                                  Text(
                                    'Phone: ${offer['owner']['phone']}',
                                    style: TextStyle(fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        // Location info
                        if (offer['pickupLocation'] != null ||
                            offer['deliveryLocation'] != null) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (offer['pickupLocation'] != null)
                                  Text(
                                    '📍 Pickup: ${offer['pickupLocation']}',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                if (offer['deliveryLocation'] != null)
                                  Text(
                                    '🏠 Delivery: ${offer['deliveryLocation']}',
                                    style: TextStyle(fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        // Message
                        if (offer['message'] != null) ...[
                          SizedBox(height: 8),
                          Text(
                            'Message: ${offer['message']}',
                            style: TextStyle(fontSize: 12),
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
                      onPressed: () => _approveVolunteerOffer(offer['offerId']),
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

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Not specified';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
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
            'Delivery partners will offer to help deliver your requests.',
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
                  backgroundColor: offer['offerType'] == 'volunteer'
                      ? Colors.green
                      : Colors.orange,
                  child: Icon(
                    offer['offerType'] == 'volunteer'
                        ? Icons.volunteer_activism
                        : Icons.local_shipping,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Delivery person info
                      Text(
                        '${offer['offeredBy']?['name'] ?? offer['deliveryPersonName'] ?? 'Unknown'} wants to deliver',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text('Item: ${offer['itemTitle'] ?? 'Unknown Item'}'),
                      Text(
                        'Contact: ${offer['offeredBy']?['phone'] ?? offer['deliveryPersonPhone'] ?? 'N/A'}',
                      ),

                      // Owner info (donor/requester)
                      if (offer['owner'] != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From: ${offer['owner']['name'] ?? 'Unknown'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              if (offer['owner']['phone'] != null)
                                Text('Phone: ${offer['owner']['phone']}'),
                            ],
                          ),
                        ),
                      ],

                      // Location info
                      if (offer['pickupLocation'] != null ||
                          offer['deliveryLocation'] != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (offer['pickupLocation'] != null)
                                Text('📍 Pickup: ${offer['pickupLocation']}'),
                              if (offer['deliveryLocation'] != null)
                                Text(
                                  '🏠 Delivery: ${offer['deliveryLocation']}',
                                ),
                            ],
                          ),
                        ),
                      ],

                      // Message
                      if (offer['message'] != null) ...[
                        SizedBox(height: 8),
                        Text('Message: ${offer['message']}'),
                      ],

                      // Payment info
                      if (offer['offerType'] != 'volunteer' &&
                          offer['estimatedCost'] != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Earning Breakdown:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              Text('Gross: PKR ${offer['grossAmount'] ?? 0}'),
                              Text(
                                'Commission (10%): PKR ${offer['commission'] ?? 0}',
                              ),
                              Text(
                                'Net Earning: PKR ${offer['estimatedCost']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (offer['offerType'] == 'volunteer')
                        Text(
                          'Free volunteer delivery',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                      if (offer['estimatedDeliveryTime'] != null)
                        Text(
                          'Delivery: ${DateFormat('MMM dd, HH:mm').format(DateTime.parse(offer['estimatedDeliveryTime']))}',
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
                    onPressed: () => _rejectDeliveryOffer(offer['id']),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
