import 'package:flutter/material.dart';
import '../../services/donation_service.dart';
import '../../services/chat_service.dart';
import '../../models/donation_model.dart';
import 'chat_screen.dart';

class DonationListScreen extends StatefulWidget {
  @override
  _DonationListScreenState createState() => _DonationListScreenState();
}

class _DonationListScreenState extends State<DonationListScreen> {
  List<DonationModel> donations = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      
      final loadedDonations = await DonationService.getAvailableDonations();
      setState(() {
        donations = loadedDonations;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load donations: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _contactDonor(DonationModel donation) async {
    try {
      print('🔍 Donation details:');
      print('  donorId: "${donation.donorId}"');
      print('  donorName: "${donation.donorName}"');
      print('  donation.id: "${donation.id}"');
      
      // Validate donorId before proceeding
      if (donation.donorId.isEmpty) {
        throw Exception('Donor ID is empty');
      }
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting chat...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Create or get chat room
      final chatRoom = await ChatService.createOrGetChatRoom(
        otherUserId: donation.donorId,
        otherUserName: donation.donorName,
        donationId: donation.id,
      );

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            roomId: chatRoom.id,
            otherUserName: donation.donorName,
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Donations'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDonations,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(error!, textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDonations,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : donations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No donations available'),
                          SizedBox(height: 8),
                          Text('Check back later for new donations'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDonations,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: donations.length,
                        itemBuilder: (context, index) {
                          final donation = donations[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _getCategoryIcon(donation.foodType),
                                        color: Color(0xFF8B4513), // Brown theme color
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          donation.title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (donation.isUrgent)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'URGENT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    donation.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 16, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Text(
                                        donation.donorName,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(Icons.inventory, size: 16, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Text(
                                        '${donation.quantity} ${donation.quantityUnit}',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  if (donation.pickupAddress != null) ...[
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            donation.pickupAddress!,
                                            style: TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _contactDonor(donation),
                                      icon: Icon(Icons.chat),
                                      label: Text('Contact Donor'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF8B4513), // Brown theme color
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  IconData _getCategoryIcon(String foodType) {
    switch (foodType.toLowerCase()) {
      case 'food':
        return Icons.fastfood;
      case 'medicine':
        return Icons.medical_services;
      case 'clothes':
        return Icons.checkroom;
      case 'money':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }
}
