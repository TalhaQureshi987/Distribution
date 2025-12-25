import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../common/chat_screen.dart';

class OffersScreen extends StatefulWidget {
  @override
  _OffersScreenState createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _acceptedOffers = [];

  @override
  void initState() {
    super.initState();
    _loadAcceptedOffers();
  }

  Future<void> _loadAcceptedOffers() async {
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getValidToken();

      // Load accepted delivery offers from donors
      final donorResponse = await ApiService.getJson(
        '/api/delivery-offers/accepted-from-donors',
        token: token,
      );

      // Load accepted delivery offers from requesters
      final requesterResponse = await ApiService.getJson(
        '/api/delivery-offers/accepted-from-requesters',
        token: token,
      );

      if (mounted) {
        setState(() {
          _acceptedOffers = [
            ...List<Map<String, dynamic>>.from(
              donorResponse['offers'] ?? [],
            ).map((offer) => {...offer, 'source': 'donor'}),
            ...List<Map<String, dynamic>>.from(
              requesterResponse['offers'] ?? [],
            ).map((offer) => {...offer, 'source': 'requester'}),
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading accepted offers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load accepted offers: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Accepted Offers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            )
          : _acceptedOffers.isEmpty
          ? _buildEmptyState()
          : _buildOffersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Accepted Offers Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When donors or requesters accept your delivery offers, they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back),
            label: Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    return RefreshIndicator(
      onRefresh: _loadAcceptedOffers,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _acceptedOffers.length,
        itemBuilder: (context, index) {
          final offer = _acceptedOffers[index];
          return _buildOfferCard(offer);
        },
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final isFromDonor = offer['source'] == 'donor';
    final icon = isFromDonor ? Icons.restaurant : Icons.shopping_cart;
    final color = isFromDonor ? Colors.orange : Colors.blue;
    final title = isFromDonor ? 'From Donor' : 'From Requester';
    final ownerInfo = offer['ownerId'] ?? {};
    final name =
        ownerInfo['name'] ??
        offer['donorName'] ??
        offer['requesterName'] ??
        'Unknown';
    final phone =
        ownerInfo['phone'] ??
        offer['donorPhone'] ??
        offer['requesterPhone'] ??
        '';
    final itemTitle = offer['itemTitle'] ?? offer['title'] ?? 'Food Item';
    final earning = offer['estimatedEarning'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                      Text(
                        'Accepted Offer',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Accepted',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item details
                Row(
                  children: [
                    Icon(Icons.restaurant, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Item: $itemTitle',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Person details
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Name: $name',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),

                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Phone: $phone')),
                    ],
                  ),
                ],

                // Earning details
                if (earning > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Payment:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PKR ${earning.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Message
                if (offer['message'] != null &&
                    offer['message'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          offer['message'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Delivery time
                if (offer['estimatedDeliveryTime'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated Delivery: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(offer['estimatedDeliveryTime']))}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Action buttons
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showContactDialog(offer),
                        icon: Icon(Icons.message, size: 18),
                        label: Text(
                          'Contact ${isFromDonor ? 'Donor' : 'Requester'}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _completeDelivery(offer),
                        icon: Icon(Icons.check_circle, size: 18),
                        label: Text('Complete Delivery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: BorderSide(color: Colors.green),
                          padding: EdgeInsets.symmetric(vertical: 12),
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
        ],
      ),
    );
  }

  void _showContactDialog(Map<String, dynamic> offer) {
    final isFromDonor = offer['source'] == 'donor';
    final ownerInfo = offer['ownerId'] ?? {};
    final name =
        ownerInfo['name'] ??
        offer['donorName'] ??
        offer['requesterName'] ??
        'Unknown';
    final phone =
        ownerInfo['phone'] ??
        offer['donorPhone'] ??
        offer['requesterPhone'] ??
        '';
    final title = isFromDonor ? 'Donor' : 'Requester';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name'),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Phone: $phone'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Implement call functionality
                      },
                      icon: Icon(Icons.phone, size: 16),
                      label: Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to chat screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUserName: name,
                              donationId: offer['itemId'],
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.message, size: 16),
                      label: Text('Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'No contact information available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _completeDelivery(Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete Delivery'),
        content: Text(
          'Are you sure you have completed this delivery? This action cannot be undone and will process your payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(
              'Complete Delivery',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
              Text('Completing delivery...'),
            ],
          ),
        ),
      );

      // Call API to complete delivery
      final token = await AuthService.getValidToken();
      final response = await ApiService.put(
        '/api/deliveries/${offer['deliveryId']}/status',
        body: {
          'status': 'completed',
          'notes': 'Delivery completed successfully',
        },
        token: token,
      );

      // Close loading dialog
      Navigator.pop(context);

      if (response['success'] == true) {
        // Remove the completed offer from the list
        setState(() {
          _acceptedOffers.removeWhere((item) => item['id'] == offer['id']);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Delivery completed successfully! Payment will be processed.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to dashboard to show updated stats
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to complete delivery: ${response['message'] ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error completing delivery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
