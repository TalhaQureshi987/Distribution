import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DonorRequesterDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ownerData; // donor or requester data
  final Map<String, dynamic> itemData; // donation or request data
  final String itemType; // 'donation' or 'request'
  final Map<String, dynamic>? deliveryData; // delivery assignment data

  const DonorRequesterDetailsScreen({
    Key? key,
    required this.ownerData,
    required this.itemData,
    required this.itemType,
    this.deliveryData,
  }) : super(key: key);

  @override
  _DonorRequesterDetailsScreenState createState() => _DonorRequesterDetailsScreenState();
}

class _DonorRequesterDetailsScreenState extends State<DonorRequesterDetailsScreen> {
  bool get isDonation => widget.itemType == 'donation';
  bool get isRequest => widget.itemType == 'request';

  @override
  Widget build(BuildContext context) {
    final owner = widget.ownerData;
    final item = widget.itemData;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isDonation ? 'Donor Details' : 'Requester Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: isDonation ? Colors.green[600] : Colors.orange[600],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Owner Info Card
            _buildOwnerCard(owner, isDonation),
            
            SizedBox(height: 16),
            
            // Item Details Card
            _buildItemDetailsCard(item, isDonation),
            
            SizedBox(height: 16),
            
            // Delivery Information Card
            _buildDeliveryInfoCard(),
            
            SizedBox(height: 16),
            
            // Earnings Card (for paid deliveries)
            if (widget.deliveryData?['paymentAmount'] != null)
              _buildEarningsCard(),
            
            SizedBox(height: 16),
            
            // Action Buttons
            _buildActionButtons(owner),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerCard(Map<String, dynamic> owner, bool isDonation) {
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
                  backgroundColor: isDonation ? Colors.green[100] : Colors.orange[100],
                  child: Icon(
                    isDonation ? Icons.volunteer_activism : Icons.help_outline,
                    size: 30,
                    color: isDonation ? Colors.green[600] : Colors.orange[600],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owner['name'] ?? owner['donorName'] ?? owner['requesterName'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.verified, color: isDonation ? Colors.green : Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text(
                            isDonation ? 'Verified Donor' : 'Verified Requester',
                            style: TextStyle(
                              color: isDonation ? Colors.green[600] : Colors.orange[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (owner['rating'] != null) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            ...List.generate(5, (index) => Icon(
                              index < (owner['rating'] ?? 0) ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            )),
                            SizedBox(width: 4),
                            Text(
                              '${owner['rating'] ?? 0}/5',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
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
              owner['phone'] ?? owner['donorPhone'] ?? owner['requesterPhone'] ?? 'Not provided',
              Colors.blue[600]!,
            ),
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.email,
              'Email',
              owner['email'] ?? 'Not provided',
              Colors.grey[600]!,
            ),
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.location_on,
              'Address',
              owner['address'] ?? widget.itemData['address'] ?? 'Address not provided',
              Colors.red[600]!,
            ),
            
            if (owner['joinedDate'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.calendar_today,
                'Member Since',
                _formatDate(owner['joinedDate']),
                Colors.purple[600]!,
              ),
            ],
            
            if (isDonation && owner['totalDonations'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.food_bank,
                'Total Donations',
                '${owner['totalDonations']} donations',
                Colors.green[600]!,
              ),
            ],
            
            if (isRequest && owner['totalRequests'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.help,
                'Total Requests',
                '${owner['totalRequests']} requests',
                Colors.orange[600]!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailsCard(Map<String, dynamic> item, bool isDonation) {
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
                  isDonation ? Icons.food_bank : Icons.help_outline,
                  color: isDonation ? Colors.green[600] : Colors.orange[600],
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  isDonation ? 'Donation Details' : 'Request Details',
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
              isDonation ? Icons.fastfood : Icons.category,
              isDonation ? 'Food Type' : 'Category',
              item['foodType'] ?? item['category'] ?? 'Not specified',
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
              isDonation ? 'Pickup Address' : 'Delivery Address',
              item['address'] ?? 'Address not provided',
              Colors.blue[600]!,
            ),
            
            if (item['specialInstructions'] != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(
                Icons.info_outline,
                'Special Instructions',
                item['specialInstructions'],
                Colors.purple[600]!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
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
                  'Delivery Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            if (widget.deliveryData?['distance'] != null) ...[
              _buildInfoRow(
                Icons.straighten,
                'Distance',
                '${widget.deliveryData!['distance']} km',
                Colors.blue[600]!,
              ),
              SizedBox(height: 12),
            ],
            
            if (widget.deliveryData?['estimatedTime'] != null) ...[
              _buildInfoRow(
                Icons.access_time,
                'Estimated Time',
                widget.deliveryData!['estimatedTime'],
                Colors.orange[600]!,
              ),
              SizedBox(height: 12),
            ],
            
            _buildInfoRow(
              Icons.delivery_dining,
              'Delivery Type',
              widget.itemData['deliveryOption'] ?? 'Standard Delivery',
              Colors.green[600]!,
            ),
            
            SizedBox(height: 12),
            
            _buildInfoRow(
              Icons.schedule,
              'Preferred Time',
              widget.itemData['preferredTime'] ?? 'Anytime',
              Colors.purple[600]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    final paymentAmount = widget.deliveryData?['paymentAmount'] ?? 0;
    final commission = (paymentAmount * 0.1).round(); // 10% commission
    final netEarning = paymentAmount - commission;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.green[400]!, Colors.green[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Your Earnings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Payment:',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    '₹$paymentAmount',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Platform Fee (10%):',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    '-₹$commission',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              
              Divider(color: Colors.white30, height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Earning:',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹$netEarning',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> owner) {
    return Column(
      children: [
        // Call Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _makePhoneCall(owner['phone'] ?? owner['donorPhone'] ?? owner['requesterPhone']),
            icon: Icon(Icons.phone, color: Colors.white),
            label: Text(
              isDonation ? 'Call Donor' : 'Call Requester',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDonation ? Colors.green[600] : Colors.orange[600],
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
            onPressed: () => _openChat(owner),
            icon: Icon(Icons.chat, color: Colors.white),
            label: Text(
              isDonation ? 'Chat with Donor' : 'Chat with Requester',
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
        
        // Navigation Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _openNavigation(),
            icon: Icon(Icons.navigation, color: Colors.purple[600]),
            label: Text(
              isDonation ? 'Navigate to Pickup' : 'Navigate to Delivery',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.purple[600],
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.purple[600]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 12),
        
        // Update Status Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _updateDeliveryStatus(),
            icon: Icon(Icons.update, color: Colors.teal[600]),
            label: Text(
              'Update Delivery Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal[600],
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.teal[600]!),
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
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

  void _openChat(Map<String, dynamic> owner) {
    Navigator.pushNamed(context, '/chat', arguments: {
      'recipientId': owner['_id'] ?? owner['donorId'] ?? owner['requesterId'],
      'recipientName': owner['name'] ?? owner['donorName'] ?? owner['requesterName'],
      'itemId': widget.itemData['_id'],
      'itemType': widget.itemType,
    });
  }

  void _openNavigation() {
    final address = widget.ownerData['address'] ?? widget.itemData['address'];
    if (address != null) {
      // TODO: Implement navigation to Google Maps or other map app
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening navigation to: $address'),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Address not available for navigation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateDeliveryStatus() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Delivery Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.directions_car, color: Colors.orange),
                title: Text('On the Way'),
                onTap: () => _setStatus('on_the_way'),
              ),
              ListTile(
                leading: Icon(Icons.inventory, color: Colors.blue),
                title: Text('Picked Up'),
                onTap: () => _setStatus('picked_up'),
              ),
              ListTile(
                leading: Icon(Icons.done_all, color: Colors.green),
                title: Text('Delivered'),
                onTap: () => _setStatus('delivered'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _setStatus(String status) {
    Navigator.of(context).pop();
    // TODO: Implement status update API call
    String statusText = status.replaceAll('_', ' ').toUpperCase();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to: $statusText'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
