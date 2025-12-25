import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryPersonDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> deliveryData;
  final Map<String, dynamic> itemData;
  final String itemType; // 'donation' or 'request'

  const DeliveryPersonDetailsScreen({
    Key? key,
    required this.deliveryData,
    required this.itemData,
    required this.itemType,
  }) : super(key: key);

  @override
  _DeliveryPersonDetailsScreenState createState() => _DeliveryPersonDetailsScreenState();
}

class _DeliveryPersonDetailsScreenState extends State<DeliveryPersonDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final deliveryPerson = widget.deliveryData;
    final item = widget.itemData;
    final isRequest = widget.itemType == 'request';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Delivery Person Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[600],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Person Info Card
            _buildDeliveryPersonCard(deliveryPerson),
            
            SizedBox(height: 16),
            
            // Item Details Card
            _buildItemDetailsCard(item, isRequest),
            
            SizedBox(height: 16),
            
            // Delivery Status Card
            _buildDeliveryStatusCard(),
            
            SizedBox(height: 16),
            
            // Action Buttons
            _buildActionButtons(deliveryPerson),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryPersonCard(Map<String, dynamic> deliveryPerson) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green[100],
                  child: Icon(
                    Icons.local_shipping,
                    size: 30,
                    color: Colors.green[600],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deliveryPerson['deliveryPersonName'] ?? deliveryPerson['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.verified, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Verified Delivery Partner',
                            style: TextStyle(
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Contact Information
            _buildInfoRow(
              Icons.phone,
              'Phone Number',
              deliveryPerson['deliveryPersonPhone'] ?? deliveryPerson['phone'] ?? 'Not provided',
              Colors.blue[600]!,
            ),
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.email,
              'Email',
              deliveryPerson['email'] ?? 'Not provided',
              Colors.grey[600]!,
            ),
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.location_on,
              'Current Location',
              deliveryPerson['address'] ?? 'Location updating...',
              Colors.red[600]!,
            ),
            
            if (deliveryPerson['estimatedArrival'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.access_time,
                'Estimated Arrival',
                deliveryPerson['estimatedArrival'],
                Colors.orange[600]!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailsCard(Map<String, dynamic> item, bool isRequest) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRequest ? Icons.help_outline : Icons.food_bank,
                  color: isRequest ? Colors.orange[600] : Colors.green[600],
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  isRequest ? 'Request Details' : 'Donation Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            _buildInfoRow(
              isRequest ? Icons.category : Icons.fastfood,
              isRequest ? 'Category' : 'Food Type',
              item['category'] ?? item['foodType'] ?? 'Not specified',
              Colors.grey[600]!,
            ),
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.description,
              'Description',
              item['description'] ?? 'No description provided',
              Colors.grey[600]!,
            ),
            
            if (item['quantity'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.numbers,
                'Quantity',
                item['quantity'].toString(),
                Colors.grey[600]!,
              ),
            ],
            
            if (item['urgency'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.priority_high,
                'Urgency',
                item['urgency'],
                item['urgency'] == 'High' ? Colors.red[600]! : Colors.orange[600]!,
              ),
            ],
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.location_on,
              isRequest ? 'Delivery Address' : 'Pickup Address',
              item['address'] ?? 'Address not provided',
              Colors.blue[600]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.blue[600], size: 24),
                SizedBox(width: 8),
                Text(
                  'Delivery Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Status Timeline
            _buildStatusTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    return Column(
      children: [
        _buildTimelineItem(
          'Delivery Accepted',
          'Delivery person has accepted your request',
          true,
          Colors.green,
          Icons.check_circle,
        ),
        _buildTimelineItem(
          'On the Way',
          'Delivery person is heading to pickup location',
          false,
          Colors.orange,
          Icons.directions_car,
        ),
        _buildTimelineItem(
          'Picked Up',
          'Item has been collected',
          false,
          Colors.blue,
          Icons.inventory,
        ),
        _buildTimelineItem(
          'Delivered',
          'Item has been successfully delivered',
          false,
          Colors.grey,
          Icons.done_all,
        ),
      ],
    );
  }

  Widget _buildTimelineItem(String title, String subtitle, bool isCompleted, Color color, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted ? color : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isCompleted ? Colors.white : Colors.grey[600],
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.grey[800] : Colors.grey[500],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> deliveryPerson) {
    return Column(
      children: [
        // Call Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _makePhoneCall(deliveryPerson['deliveryPersonPhone'] ?? deliveryPerson['phone']),
            icon: Icon(Icons.phone, color: Colors.white),
            label: Text(
              'Call Delivery Person',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 12),
        
        // Chat Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _openChat(deliveryPerson),
            icon: Icon(Icons.chat, color: Colors.white),
            label: Text(
              'Chat with Delivery Person',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 12),
        
        // Track Location Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _trackLocation(),
            icon: Icon(Icons.location_on, color: Colors.orange[600]),
            label: Text(
              'Track Live Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange[600],
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.orange[600]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone dialer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChat(Map<String, dynamic> deliveryPerson) {
    Navigator.pushNamed(context, '/chat', arguments: {
      'recipientId': deliveryPerson['deliveryPersonId'] ?? deliveryPerson['_id'],
      'recipientName': deliveryPerson['deliveryPersonName'] ?? deliveryPerson['name'],
      'itemId': widget.itemData['_id'],
      'itemType': widget.itemType,
    });
  }

  void _trackLocation() {
    // TODO: Implement live location tracking
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Live tracking feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
