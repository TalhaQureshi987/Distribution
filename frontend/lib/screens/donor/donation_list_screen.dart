import 'package:flutter/material.dart';
import '../../models/donation_model.dart';
import '../../services/donation_service.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';

class DonationListScreen extends StatefulWidget {
  @override
  _DonationListScreenState createState() => _DonationListScreenState();
}

class _DonationListScreenState extends State<DonationListScreen> {
  List<DonationModel> _donations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final donations = await DonationService.getUserDonations();

      setState(() {
        _donations = donations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _completeDonation(String donationId) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Complete Donation'),
          content: Text(
            'Mark this donation as received by the Care Connect team?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Complete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await DonationService.completeDonation(donationId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDonations(); // Refresh the list
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete donation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openChat(DonationModel donation) async {
    try {
      if (donation.assignedTo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No one is assigned to this donation yet'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get current user
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create or get chat room
      final chatRoom = await ChatService.createOrGetChatRoom(
        otherUserId: donation.assignedTo!,
        otherUserName:
            'Assigned Person', // You might want to get the actual name
        donationId: donation.id,
      );

      // Navigate to chat screen
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {'chatRoom': chatRoom, 'otherUserName': 'Assigned Person'},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDonationCard(DonationModel donation) {
    final isAssigned = donation.assignedTo != null;
    final canComplete =
        donation.status == 'picked_up' || donation.status == 'in_transit';
    final isCompleted = donation.status == 'completed';

    return Card(
      margin: EdgeInsets.all(8),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    donation.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(donation.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    donation.status.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Food details
            if (donation.foodName?.isNotEmpty == true) ...[
              Row(
                children: [
                  Icon(Icons.fastfood, size: 16, color: AppTheme.primaryColor),
                  SizedBox(width: 4),
                  Text('Food: ${donation.foodName}'),
                ],
              ),
              SizedBox(height: 4),
            ],

            // Description
            Text(
              donation.description,
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),

            // Quantity and delivery option
            Row(
              children: [
                Icon(Icons.inventory, size: 16, color: AppTheme.primaryColor),
                SizedBox(width: 4),
                Text('${donation.quantity} ${donation.quantityUnit}'),
                SizedBox(width: 16),
                Icon(
                  Icons.local_shipping,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    donation.deliveryOption,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _getDeliveryOptionColor(donation.deliveryOption),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                // Chat button - only show if assigned
                if (isAssigned && !isCompleted) ...[
                  ElevatedButton.icon(
                    onPressed: () => _openChat(donation),
                    icon: Icon(Icons.chat),
                    label: Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                ],

                // Complete button - only show if can be completed
                if (canComplete) ...[
                  ElevatedButton.icon(
                    onPressed: () => _completeDonation(donation.id),
                    icon: Icon(Icons.check_circle),
                    label: Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],

                // Status info
                if (isCompleted) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (!isAssigned && !isCompleted) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          color: Colors.orange,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Waiting for assignment',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.blue;
      case 'assigned':
        return Colors.orange;
      case 'picked_up':
        return Colors.purple;
      case 'in_transit':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getDeliveryOptionColor(String deliveryOption) {
    switch (deliveryOption) {
      case 'Self delivery':
        return Colors.green;
      case 'Volunteer Delivery':
        return Colors.orange;
      case 'Paid Delivery':
        return Colors.blue;
      case 'Paid Delivery (Earn)':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Donations'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.primaryTextColor,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadDonations),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error: $_error'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDonations,
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
          : _donations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No donations found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first donation to see it here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDonations,
              child: ListView.builder(
                itemCount: _donations.length,
                itemBuilder: (context, index) {
                  return _buildDonationCard(_donations[index]);
                },
              ),
            ),
    );
  }
}
