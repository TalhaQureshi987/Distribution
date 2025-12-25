// lib/screens/delivery/delivery_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/delivery_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../common/chat_screen.dart';

class DeliveryScreen extends StatefulWidget {
  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<Map<String, dynamic>> _paidDeliveries = [];
  List<Map<String, dynamic>> _filteredDeliveries = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Food', 'Medicine', 'Clothes', 'Other'];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPaidDeliveries();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startRealTimeUpdates() {
    // Refresh every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadPaidDeliveries(isRefresh: true);
      }
    });
  }

  Future<void> _loadPaidDeliveries({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }
    
    try {
      // Load real paid deliveries from backend
      final deliveries = await DeliveryService.getAvailableDeliveries();
      print('DEBUG: Total paid deliveries fetched: ${deliveries.length}');
      
      // Debug: Print all deliveries to see what's available
      for (var delivery in deliveries) {
        print('DEBUG: Delivery "${delivery['title']}" type: "${delivery['deliveryType']}" isPaid: ${delivery['isPaid']}');
      }
      
      setState(() {
        _paidDeliveries = deliveries;
        _updateFilteredDeliveries();
      });
      
      print('DEBUG: Loaded ${_paidDeliveries.length} paid deliveries');
    } catch (e) {
      print('ERROR: Failed to load paid deliveries: $e');
      _showSnackBar('Error loading paid deliveries: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _updateFilteredDeliveries() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredDeliveries = _paidDeliveries.where((delivery) {
        final matchesSearch = (delivery['title']?.toString().toLowerCase().contains(query) ?? false) ||
                            (delivery['description']?.toString().toLowerCase().contains(query) ?? false) ||
                            (delivery['pickupAddress']?.toString().toLowerCase().contains(query) ?? false);
        
        final matchesCategory = _selectedCategory == 'All' || 
                              (delivery['foodType']?.toString() == _selectedCategory);
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _acceptDelivery(Map<String, dynamic> delivery) async {
    try {
      final deliveryId = delivery['_id'] ?? delivery['id'];
      if (deliveryId == null) {
        _showSnackBar('Invalid delivery ID', Colors.red);
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Accepting delivery...'),
            ],
          ),
        ),
      );

      // Create delivery offer (requires donor/requester approval)
      final result = await DeliveryService.createDeliveryOffer(
        itemId: deliveryId,
        itemType: delivery['type'] ?? 'donation',
        message: 'I will deliver this item safely and on time',
        estimatedPickupTime: DateTime.now().add(Duration(hours: 1)).toIso8601String(),
        estimatedDeliveryTime: DateTime.now().add(Duration(hours: 3)).toIso8601String(),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        final paymentAmount = delivery['paymentAmount'] ?? delivery['estimatedPrice'] ?? 0;
        
        _showSnackBar(
          '✅ Delivery offer created! The owner will review and approve your offer. You will earn PKR ${paymentAmount.toStringAsFixed(0)} if approved.',
          Colors.green,
        );

        // Refresh deliveries to remove the one with offer created
        _loadPaidDeliveries();
      } else {
        _showSnackBar('Failed to create delivery offer', Colors.red);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      print('ERROR: Failed to accept delivery: $e');
      _showSnackBar('Error accepting delivery: $e', Colors.red);
    }
  }

  void _showDeliveryAcceptedDialog(Map<String, dynamic> result, Map<String, dynamic> delivery) {
    final deliveryType = delivery['deliveryType'] ?? 'delivery';
    final ownerName = deliveryType == 'donation' 
        ? delivery['donorName'] ?? 'Donor'
        : delivery['requesterName'] ?? 'Requester';
    final paymentAmount = delivery['paymentAmount'] ?? delivery['estimatedPrice'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Delivery Accepted!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Congratulations! You have successfully accepted this delivery.'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.monetization_on, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'You will earn PKR ${paymentAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.chat, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chat room created with $ownerName',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.notifications, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$ownerName has been notified',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to chat screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(roomId: result['chatRoomId']),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Open Chat'),
          ),
        ],
      ),
    );
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
              hintText: 'Search paid delivery opportunities...',
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
                        color: isSelected ? Colors.white : AppTheme.primaryColor,
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

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
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
                    Icons.delivery_dining,
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
                        delivery['title'] ?? 'Unknown Item',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          delivery['deliveryType'] == 'donation' ? 'DONATION DELIVERY' : 'REQUEST DELIVERY',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (delivery['urgencyLevel'] == 'high' || delivery['isUrgent'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            _buildInfoRow(
              Icons.person_outline, 
              delivery['deliveryType'] == 'donation' ? 'Donor' : 'Requester', 
              delivery['deliveryType'] == 'donation' 
                  ? delivery['donorName'] ?? 'Unknown Donor'
                  : delivery['requesterName'] ?? 'Unknown Requester'
            ),
            _buildInfoRow(
              Icons.location_on_outlined, 
              'Pickup Location', 
              delivery['pickupAddress'] ?? 'Unknown Location'
            ),
            if (delivery['distance'] != null && delivery['distance'] > 0)
              _buildInfoRow(
                Icons.route, 
                'Distance', 
                '${delivery['distance'].toStringAsFixed(1)} km'
              ),
            _buildInfoRow(
              Icons.attach_money, 
              'Earning', 
              'PKR ${delivery['paymentAmount'] ?? delivery['estimatedPrice'] ?? 0}'
            ),
            if (delivery['urgencyLevel'] != null)
              _buildInfoRow(
                Icons.priority_high, 
                'Priority', 
                delivery['urgencyLevel'].toString().toUpperCase()
              ),
            
            const SizedBox(height: 20),
            
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptDelivery(delivery),
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
                    Icon(Icons.attach_money, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Accept & Earn',
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon, 
            size: 20, 
            color: AppTheme.primaryColor,
          ),
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

  Widget _buildEmptyState() {
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
                Icons.delivery_dining,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Paid Deliveries Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new earning opportunities',
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
              'Deliver & Earn',
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
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading paid delivery opportunities...',
                          style: TextStyle(
                            color: AppTheme.secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredDeliveries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPaidDeliveries,
                        color: AppTheme.primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredDeliveries.length,
                          itemBuilder: (context, index) {
                            return _buildDeliveryCard(_filteredDeliveries[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
