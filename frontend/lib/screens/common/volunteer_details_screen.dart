import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VolunteerDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> volunteerData;
  final Map<String, dynamic> itemData;
  final String itemType; // 'donation' or 'request'

  const VolunteerDetailsScreen({
    Key? key,
    required this.volunteerData,
    required this.itemData,
    required this.itemType,
  }) : super(key: key);

  @override
  _VolunteerDetailsScreenState createState() => _VolunteerDetailsScreenState();
}

class _VolunteerDetailsScreenState extends State<VolunteerDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final volunteer = widget.volunteerData;
    final item = widget.itemData;
    final isRequest = widget.itemType == 'request';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Volunteer Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Volunteer Info Card
            _buildVolunteerCard(volunteer),
            
            SizedBox(height: 16),
            
            // Item Details Card
            _buildItemDetailsCard(item, isRequest),
            
            SizedBox(height: 16),
            
            // Volunteer Status Card
            _buildVolunteerStatusCard(),
            
            SizedBox(height: 16),
            
            // Action Buttons
            _buildActionButtons(volunteer),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerCard(Map<String, dynamic> volunteer) {
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
                  backgroundColor: Colors.blue[100],
                  child: Icon(
                    Icons.volunteer_activism,
                    size: 30,
                    color: Colors.blue[600],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        volunteer['volunteerName'] ?? volunteer['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.verified, color: Colors.blue, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Verified Volunteer',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'FREE SERVICE',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
              volunteer['volunteerPhone'] ?? volunteer['phone'] ?? 'Not provided',
              Colors.blue[600]!,
            ),
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.email,
              'Email',
              volunteer['email'] ?? 'Not provided',
              Colors.grey[600]!,
            ),
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.location_on,
              'Current Location',
              volunteer['address'] ?? 'Location updating...',
              Colors.red[600]!,
            ),
            
            if (volunteer['experience'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.star,
                'Experience',
                volunteer['experience'],
                Colors.orange[600]!,
              ),
            ],
            
            if (volunteer['completedDeliveries'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.done_all,
                'Completed Deliveries',
                '${volunteer['completedDeliveries']} deliveries',
                Colors.green[600]!,
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

  Widget _buildVolunteerStatusCard() {
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
                Icon(Icons.volunteer_activism, color: Colors.blue[600], size: 24),
                SizedBox(width: 8),
                Text(
                  'Volunteer Status',
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
          'Volunteer Accepted',
          'Volunteer has accepted to help with your request',
          true,
          Colors.green,
          Icons.check_circle,
        ),
        _buildTimelineItem(
          'On the Way',
          'Volunteer is heading to pickup location',
          false,
          Colors.orange,
          Icons.directions_walk,
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

  Widget _buildActionButtons(Map<String, dynamic> volunteer) {
    return Column(
      children: [
        // Call Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _makePhoneCall(volunteer['volunteerPhone'] ?? volunteer['phone']),
            icon: Icon(Icons.phone, color: Colors.white),
            label: Text(
              'Call Volunteer',
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
        
        // Chat Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _openChat(volunteer),
            icon: Icon(Icons.chat, color: Colors.white),
            label: Text(
              'Chat with Volunteer',
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
        
        // Thank You Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _sendThankYou(),
            icon: Icon(Icons.favorite, color: Colors.pink[600]),
            label: Text(
              'Send Thank You Message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.pink[600],
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.pink[600]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        // Free Service Notice
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.volunteer_activism,
                color: Colors.green[600],
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                'Free Volunteer Service',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'This volunteer is helping you for free as part of our community service program. Please show your appreciation!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[600],
                ),
              ),
            ],
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

  void _openChat(Map<String, dynamic> volunteer) {
    Navigator.pushNamed(context, '/chat', arguments: {
      'recipientId': volunteer['volunteerId'] ?? volunteer['_id'],
      'recipientName': volunteer['volunteerName'] ?? volunteer['name'],
      'itemId': widget.itemData['_id'],
      'itemType': widget.itemType,
    });
  }

  void _sendThankYou() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.favorite, color: Colors.pink[600]),
              SizedBox(width: 8),
              Text('Thank You Message'),
            ],
          ),
          content: Text(
            'Would you like to send a thank you message to this volunteer for their free service?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openChat(widget.volunteerData);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Chat opened to send thank you message!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[600],
              ),
              child: Text(
                'Send Message',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
