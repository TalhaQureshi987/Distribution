import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../models/volunteer_model.dart';
import '../../models/donation_model.dart';
import '../../models/request_model.dart';
import '../../models/chat_model.dart';
import '../../services/volunteer_service.dart';
import '../../services/donation_service.dart';
import '../../services/request_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/chat_service.dart';
import '../../config/theme.dart';
import '../common/chat_screen.dart';
import '../auth/identity_verification_screen.dart';

class VolunteerScreen extends StatefulWidget {
  @override
  _VolunteerScreenState createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends State<VolunteerScreen>
    with SingleTickerProviderStateMixin {
  // Data lists - only deliveries now
  List<DonationModel> _donationDeliveries = [];
  List<Map<String, dynamic>> _requestDeliveries = [];
  List<Map<String, dynamic>> _allDeliveries = [];
  List<Map<String, dynamic>> _filteredDeliveries = [];

  // Loading states
  bool _isLoadingDeliveries = false;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  // Tab controller
  late TabController _tabController;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Food',
    'Medicine',
    'Clothing',
    'Emergency',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
    _initializeRealTimeUpdates();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    VolunteerService.disconnectRealTimeUpdates();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadDeliveryOpportunities();
  }

  Future<void> _initializeRealTimeUpdates() async {
    try {
      await VolunteerService.initializeRealTimeUpdates();

      VolunteerService.listenForNewOpportunities((opportunity) {
        if (mounted) {
          _loadDeliveryOpportunities(isRefresh: true); // Refresh deliveries
          _showSnackBar(
            'New delivery opportunity available!',
            AppTheme.successColor,
          );
        }
      });

      // Start timer-based updates every 30 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (mounted) {
          _loadDeliveryOpportunities(isRefresh: true);
        }
      });
    } catch (e) {
      print('Error initializing real-time updates: $e');
    }
  }

  Future<void> _loadDeliveries() async {
    if (_isLoadingDeliveries) return;

    setState(() {
      _isLoadingDeliveries = true;
    });

    try {
      // Since we're only showing deliveries now, we'll load from the delivery opportunities method
      await _loadDeliveryOpportunities();
    } catch (e) {
      _showSnackBar('Error loading deliveries: $e', Colors.red);
    } finally {
      setState(() {
        _isLoadingDeliveries = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadDeliveryOpportunities({bool isRefresh = false}) async {
    if (_isLoadingDeliveries && !isRefresh) return;

    setState(() {
      if (isRefresh) {
        _isRefreshing = true;
      } else {
        _isLoadingDeliveries = true;
      }
    });

    try {
      // Load donations that need volunteer delivery only
      final donations = await DonationService.getAvailableDonations();
      print('DEBUG VOLUNTEER: Total donations fetched: ${donations.length}');

      final volunteerDonations = donations
          .where(
            (donation) =>
                donation.deliveryOption == 'Volunteer Delivery' ||
                donation.needsVolunteer == true,
          )
          .toList();

      print(
        'DEBUG VOLUNTEER: Volunteer donations after filtering: ${volunteerDonations.length}',
      );
      for (var donation in volunteerDonations) {
        print(
          'DEBUG VOLUNTEER: Donation "${donation.title}" deliveryOption: "${donation.deliveryOption}" needsVolunteer: ${donation.needsVolunteer}',
        );
      }

      // Load requests that need volunteer delivery only
      print('🔍 VOLUNTEER: Fetching approved requests...');
      final requests = await RequestService.getAvailableRequests(
        status: 'approved',
      );
      print('🔍 VOLUNTEER: Got ${requests.length} requests');

      for (var request in requests) {
        print(
          '🔍 Request: "${request['title']}" - Delivery: "${request['metadata']?['deliveryOption']}" - Status: "${request['status']}"',
        );
        print(
          '🔍 REQUEST DETAILS: "${request['title']}" - Status: "${request['status']}" - DeliveryOption: "${request['metadata']?['deliveryOption']}" - NeedsVolunteer: ${request['metadata']?['needsVolunteer']}',
        );
      }
      final volunteerRequests = requests
          .where(
            (request) =>
                request['metadata']?['deliveryOption'] == 'Volunteer Delivery',
          )
          .toList();

      // FIX:
      setState(() {
        _donationDeliveries = volunteerDonations;
        _requestDeliveries = volunteerRequests; // ✅ Already defined on line 142
        _updateFilteredDeliveries();
      });
      if (volunteerRequests.isEmpty && requests.isNotEmpty) {
        print('🚨 NO VOLUNTEER REQUESTS! Available options:');
        requests.forEach(
          (r) => print('   - "${r['metadata']?['deliveryOption']}"'),
        );
      }

      print(
        'DEBUG: Final delivery opportunities - Donations: ${_donationDeliveries.length}, Requests: ${_requestDeliveries.length}',
      );
    } catch (e) {
      print('DEBUG: Error loading delivery opportunities: $e');
      _showSnackBar('Error loading delivery opportunities: $e', Colors.red);
    } finally {
      setState(() {
        _isLoadingDeliveries = false;
        _isRefreshing = false;
      });
    }
  }

  void _updateFilteredDeliveries() {
    final query = _searchController.text.toLowerCase();
    final allDeliveries = [
      ..._donationDeliveries.map((d) => {'type': 'donation', 'item': d}),
      ..._requestDeliveries.map((r) => {'type': 'request', 'item': r}),
    ];

    setState(() {
      _filteredDeliveries = allDeliveries.where((delivery) {
        final type = delivery['type'] as String? ?? '';
        final item = delivery['item'];

        String title, category;
        if (type == 'donation') {
          final donation = item as DonationModel;
          title = donation.title;
          category = donation.foodType; // Use foodType instead of category
        } else {
          final request = item as RequestModel;
          title = request.title;
          category = request.foodType; // Use foodType instead of category
        }

        final matchesSearch =
            query.isEmpty || title.toLowerCase().contains(query);
        final matchesCategory =
            _selectedCategory == 'All' ||
            category.toLowerCase().contains(_selectedCategory.toLowerCase());

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _applyForOpportunity(Map<String, dynamic> opportunity) async {
    try {
      final opportunityType = opportunity['type'] ?? 'donation';
      final item = opportunity['item'];

      // Extract ID from the nested item object - handle both DonationModel and Map
      String? opportunityId;
      if (item is Map<String, dynamic>) {
        // If item is a Map, use map access
        opportunityId = item['id'] ?? item['_id'];
      } else {
        // If item is a DonationModel or RequestModel, use property access
        opportunityId = item?.id ?? item?._id;
      }

      if (opportunityId == null) {
        _showSnackBar('Invalid opportunity ID', Colors.red);
        return;
      }

      print(
        'DEBUG VOLUNTEER: Accepting $opportunityType with ID: $opportunityId',
      );

      setState(() {
        _isLoadingDeliveries = true;
      });

      Map<String, dynamic> result;

      if (opportunityType == 'donation') {
        // Create volunteer delivery offer (requires donor approval)
        result = await VolunteerService.createVolunteerDeliveryOffer(
          opportunityId,
          message: 'I would like to help with this delivery.',
          estimatedPickupTime: DateTime.now()
              .add(Duration(hours: 1))
              .toIso8601String(),
          estimatedDeliveryTime: DateTime.now()
              .add(Duration(hours: 3))
              .toIso8601String(),
        );
      } else {
        // For requests, create volunteer offer
        result = await VolunteerService.createVolunteerDeliveryOffer(
          opportunityId,
          message: 'I would like to help with this request.',
          estimatedPickupTime: DateTime.now()
              .add(Duration(hours: 1))
              .toIso8601String(),
          estimatedDeliveryTime: DateTime.now()
              .add(Duration(hours: 3))
              .toIso8601String(),
        );
      }

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        _showSnackBar(
          '✅ Delivery offer created! The donor will review and approve your offer.',
          Colors.green,
        );

        // Refresh data to remove the opportunity (since offer was created)
        _loadDeliveries();
      } else {
        _showSnackBar('Failed to create delivery offer', Colors.red);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      _showSnackBar('Error applying for opportunity: $e', Colors.red);
    } finally {
      setState(() {
        _isLoadingDeliveries = false;
      });
    }
  }

  void _showChatRoomCreatedDialog(
    String chatRoomId,
    Map<String, dynamic> opportunity,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.chat, color: Colors.green),
            SizedBox(width: 8),
            Text('Chat Room Created'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A chat room has been created for this delivery.'),
            SizedBox(height: 8),
            Text(
              'You can now communicate with the donor about pickup details.',
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The donor has been notified of your acceptance',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to chat screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(roomId: chatRoomId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Open Chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _volunteerForDelivery(
    String itemId,
    String itemType,
    String ownerName,
    String ownerId,
  ) async {
    final confirmed = await _showDeliveryConfirmationDialog(
      itemType,
      ownerName,
    );
    if (!confirmed) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Submitting volunteer offer...'),
            ],
          ),
        ),
      );

      final token = await AuthService.getValidToken();
      final deliveryType = itemType == 'donation' ? 'donation' : 'request';

      // Create volunteer offer
      final response = await http.post(
        Uri.parse(
          '${ApiService.base}/api/volunteers/offer/$deliveryType/$itemId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'message': 'I would like to volunteer for this opportunity.',
        }),
      );

      print('🔍 Volunteer offer response status: ${response.statusCode}');
      print('🔍 Volunteer offer response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Close loading dialog
        Navigator.pop(context);

        _showSnackBar(
          '✅ Volunteer offer submitted successfully!',
          Colors.green,
        );

        // Refresh data
        _loadDeliveryOpportunities();
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Failed to submit volunteer offer';

        print('❌ Volunteer offer failed: $errorMessage');
        print('❌ Error details: $errorData');

        // Close loading dialog
        Navigator.pop(context);

        // Show specific alerts based on error type
        if (errorMessage.toLowerCase().contains('already made an offer') ||
            errorMessage.toLowerCase().contains('existing offer')) {
          _showAlertDialog(
            '⚠️ Offer Already Exists',
            'You have already made a volunteer offer for this delivery. Please wait for the donor/requester to respond to your previous offer.',
            'OK',
          );
        } else if (errorMessage.toLowerCase().contains('in progress') ||
            errorMessage.toLowerCase().contains('assigned') ||
            errorMessage.toLowerCase().contains('not available')) {
          _showAlertDialog(
            '📦 Delivery In Progress',
            'This delivery is already assigned to another volunteer or is currently in progress. Please choose another delivery opportunity.',
            'Find Other Deliveries',
          );
        } else if (errorMessage.toLowerCase().contains('not found')) {
          _showAlertDialog(
            '❌ Delivery Not Found',
            'This delivery opportunity is no longer available. It may have been completed or cancelled.',
            'Refresh List',
          );
        } else if (errorMessage.toLowerCase().contains('not verified') ||
            errorMessage.toLowerCase().contains('verification')) {
          _showAlertDialog(
            '🔒 Verification Required',
            'You need to complete identity verification before you can volunteer for deliveries. Please complete your verification first.',
            'Go to Verification',
          );
        } else {
          _showAlertDialog('❌ Error', errorMessage, 'OK');
        }

        return;
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showSnackBar(
        'Error submitting volunteer offer: ${e.toString()}',
        Colors.red,
      );
    }
  }

  Future<bool> _showVolunteerConfirmationDialog(
    VolunteerOpportunity opportunity,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Volunteer Confirmation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Do you want to volunteer for:'),
                SizedBox(height: 8),
                Text(
                  opportunity.title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Organizer: ${opportunity.organizerName}'),
                Text(
                  'Date: ${DateFormat('MMM dd, yyyy').format(opportunity.startDate)}',
                ),
                if (opportunity.address != null)
                  Text('Location: ${opportunity.address}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Volunteer'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showDeliveryConfirmationDialog(
    String itemType,
    String ownerName,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delivery Volunteer Confirmation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Do you want to volunteer for this $itemType delivery?'),
                SizedBox(height: 8),
                Text('Owner: $ownerName'),
                SizedBox(height: 8),
                Text(
                  'You will be able to coordinate pickup and delivery details through chat.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Volunteer'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showAlertDialog(String title, String message, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search delivery opportunities...',
              prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
            onChanged: (_) => _updateFilteredDeliveries(),
          ),
          const SizedBox(height: 16),
          // Category filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                        _updateFilteredDeliveries();
                      });
                    },
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    selectedColor: AppTheme.primaryColor,
                    checkmarkColor: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesView() {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Expanded(
          child: _isLoadingDeliveries
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading delivery opportunities...',
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : _filteredDeliveries.isEmpty
              ? _buildEmptyState('No delivery opportunities found')
              : RefreshIndicator(
                  onRefresh: _loadDeliveryOpportunities,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredDeliveries.length,
                    itemBuilder: (context, index) {
                      final delivery = _filteredDeliveries[index];
                      return _buildModernDeliveryCard(delivery);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOpportunityCard(VolunteerOpportunity opportunity) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    opportunity.title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusChip(opportunity.status),
              ],
            ),
            SizedBox(height: 8),

            // Description
            Text(
              opportunity.description,
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),

            // Details
            _buildModernInfoRow(
              Icons.person,
              'Organizer',
              opportunity.organizerName,
            ),
            _buildModernInfoRow(
              Icons.calendar_today,
              'Date',
              DateFormat('MMM dd, yyyy').format(opportunity.startDate),
            ),
            if (opportunity.address != null)
              _buildModernInfoRow(
                Icons.location_on,
                'Location',
                opportunity.address!,
              ),
            _buildModernInfoRow(
              Icons.people,
              'Volunteers',
              opportunity.spotsText,
            ),

            // Skills
            if (opportunity.requiredSkills.isNotEmpty) ...[
              SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: opportunity.requiredSkills.map((skill) {
                  return Chip(
                    label: Text(skill, style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.blue[100],
                  );
                }).toList(),
              ),
            ],

            SizedBox(height: 16),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: opportunity.isAvailable
                    ? () => _applyForOpportunity(opportunity.toJson())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  opportunity.isAvailable
                      ? 'Volunteer Now'
                      : 'Opportunity Full',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDeliveryCard(Map<String, dynamic> delivery) {
    final type = delivery['type'] as String? ?? '';
    final item = delivery['item'];

    String title, ownerName, ownerId, address, deliveryOption;
    DateTime date;
    bool isUrgent, needsVolunteer;

    if (type == 'donation') {
      final donation = item as DonationModel;
      title = donation.title;
      ownerName = donation.donorName;
      ownerId = donation.donorId;
      address = donation.pickupAddress;
      date = donation.expiryDate;
      isUrgent = donation.isUrgent;
      needsVolunteer = donation.needsVolunteer;
      deliveryOption = donation.deliveryOption;
    } else {
      final request = item as RequestModel;
      title = request.title;
      ownerName = request.requesterName;
      ownerId = request.requesterId;
      address = request.pickupAddress;
      date = request.neededBy;
      isUrgent = request.isUrgent;
      needsVolunteer = request.needsVolunteer;
      deliveryOption = request.deliveryOption ?? 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    type == 'donation'
                        ? Icons.volunteer_activism
                        : Icons.help_outline,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type == 'donation' ? 'Donation' : 'Request',
                          style: TextStyle(
                            color: AppTheme.secondaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'URGENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Details
            _buildModernInfoRow(
              Icons.person_outline,
              type == 'donation' ? 'Donor' : 'Requester',
              ownerName,
            ),
            _buildModernInfoRow(
              Icons.location_on_outlined,
              'Pickup Location',
              address,
            ),
            _buildModernInfoRow(
              Icons.schedule,
              type == 'donation' ? 'Expires on' : 'Needed by',
              DateFormat('MMM dd, yyyy • hh:mm a').format(date),
            ),

            const SizedBox(height: 20),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _applyForOpportunity(delivery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Accept Delivery',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'open':
        color = AppTheme.primaryColor; // Brown instead of green
        break;
      case 'full':
        color =
            AppTheme.secondaryColor; // App secondary color instead of orange
        break;
      case 'closed':
        color = AppTheme.errorColor;
        break;
      default:
        color = AppTheme.secondaryTextColor;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh and check for new opportunities',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Volunteer Deliveries',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_isRefreshing) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildDeliveriesView(),
    );
  }
}
