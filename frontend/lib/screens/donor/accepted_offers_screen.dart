import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AcceptedOffersScreen extends StatefulWidget {
  @override
  _AcceptedOffersScreenState createState() => _AcceptedOffersScreenState();
}

class _AcceptedOffersScreenState extends State<AcceptedOffersScreen> {
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

      // Debug: Check database state
      try {
        final debugResponse = await ApiService.getJson(
          '/api/delivery-offers/debug-accepted-offers',
          token: token,
        );
        print('🔍 DEBUG RESPONSE: $debugResponse');
      } catch (debugError) {
        print('❌ Debug endpoint error: $debugError');
        // Continue without debug info
      }

      // Load accepted delivery offers
      Map<String, dynamic> deliveryResponse = {'offers': []};
      try {
        deliveryResponse = await ApiService.getJson(
          '/api/delivery-offers/accepted-for-donors',
          token: token,
        );
      } catch (e) {
        print('❌ Error loading delivery offers: $e');
        // Continue with empty list
      }

      // Load accepted volunteer offers
      Map<String, dynamic> volunteerResponse = {'offers': []};
      try {
        volunteerResponse = await ApiService.getJson(
          '/api/volunteers/accepted-offers-for-donors',
          token: token,
        );
      } catch (e) {
        print('❌ Error loading volunteer offers: $e');
        // Continue with empty list
      }

      print('🔍 Accepted Offers Debug:');
      print('  Delivery offers: ${deliveryResponse['offers']?.length ?? 0}');
      print('  Volunteer offers: ${volunteerResponse['offers']?.length ?? 0}');
      print('  Delivery response: $deliveryResponse');
      print('  Volunteer response: $volunteerResponse');

      // Debug individual offers
      if (deliveryResponse['offers'] != null) {
        print('  Delivery offers details:');
        for (int i = 0; i < deliveryResponse['offers'].length; i++) {
          print('    $i: ${deliveryResponse['offers'][i]}');
        }
      }

      if (volunteerResponse['offers'] != null) {
        print('  Volunteer offers details:');
        for (int i = 0; i < volunteerResponse['offers'].length; i++) {
          print('    $i: ${volunteerResponse['offers'][i]}');
        }
      }

      if (mounted) {
        setState(() {
          _acceptedOffers = [
            ...List<Map<String, dynamic>>.from(
              deliveryResponse['offers'] ?? [],
            ).map((offer) => {...offer, 'type': 'delivery'}),
            ...List<Map<String, dynamic>>.from(
              volunteerResponse['offers'] ?? [],
            ).map((offer) => {...offer, 'type': 'volunteer'}),
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading accepted offers: $e');
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAcceptedOffers,
          ),
          IconButton(
            icon: Icon(Icons.bug_report, color: Colors.white),
            onPressed: _testDebugEndpoint,
          ),
        ],
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
            'When volunteers or delivery partners accept your offers, they will appear here.',
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
    final isDelivery = offer['type'] == 'delivery';
    final icon = isDelivery ? Icons.local_shipping : Icons.volunteer_activism;
    final color = isDelivery ? Colors.blue : Colors.green;
    final title = isDelivery ? 'Delivery Partner' : 'Volunteer';
    final name =
        offer['offeredBy']?['name'] ??
        offer['deliveryPersonName'] ??
        offer['volunteerId']?['name'] ??
        offer['volunteerName'] ??
        'Unknown';
    final phone =
        offer['deliveryPersonPhone'] ??
        offer['volunteerId']?['phone'] ??
        offer['volunteerPhone'] ??
        '';
    // final status = offer['status'] ?? 'accepted';
    final itemTitle = offer['itemTitle'] ?? offer['title'] ?? 'Food Item';

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

                // Contact button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showContactDialog(offer),
                    icon: Icon(Icons.message, size: 18),
                    label: Text(
                      'Contact ${isDelivery ? 'Delivery Partner' : 'Volunteer'}',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testDebugEndpoint() async {
    try {
      final token = await AuthService.getValidToken();
      final debugResponse = await ApiService.getJson(
        '/api/delivery-offers/debug-accepted-offers',
        token: token,
      );

      print('🔍 DEBUG ENDPOINT RESPONSE: $debugResponse');

      // Show debug info in a dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Debug Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Delivery Offers: ${debugResponse['debug']?['totalDeliveryOffers'] ?? 0}',
                ),
                Text(
                  'Total Volunteer Offers: ${debugResponse['debug']?['totalVolunteerOffers'] ?? 0}',
                ),
                Text(
                  'User Delivery Offers: ${debugResponse['debug']?['userDeliveryOffers'] ?? 0}',
                ),
                Text(
                  'User Volunteer Offers: ${debugResponse['debug']?['userVolunteerOffers'] ?? 0}',
                ),
                SizedBox(height: 16),
                Text(
                  'All Delivery Offers:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...(debugResponse['debug']?['allDeliveryOffers'] ?? [])
                    .map<Widget>(
                      (offer) => Text(
                        '  - ${offer['id']}: ${offer['status']} (${offer['ownerName']})',
                      ),
                    )
                    .toList(),
                SizedBox(height: 16),
                Text(
                  'All Volunteer Offers:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...(debugResponse['debug']?['allVolunteerOffers'] ?? [])
                    .map<Widget>(
                      (offer) => Text(
                        '  - ${offer['id']}: ${offer['status']} (${offer['ownerName']})',
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Debug endpoint error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showContactDialog(Map<String, dynamic> offer) {
    final isDelivery = offer['type'] == 'delivery';
    final name =
        offer['offeredBy']?['name'] ??
        offer['deliveryPersonName'] ??
        offer['volunteerId']?['name'] ??
        offer['volunteerName'] ??
        'Unknown';
    final phone =
        offer['deliveryPersonPhone'] ??
        offer['volunteerId']?['phone'] ??
        offer['volunteerPhone'] ??
        '';
    final title = isDelivery ? 'Delivery Partner' : 'Volunteer';

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
                        // TODO: Implement message functionality
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
}
