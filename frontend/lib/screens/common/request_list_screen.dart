import 'package:flutter/material.dart';
import '../../services/request_service.dart';
import '../../services/chat_service.dart';
import '../../models/request_model.dart';
import 'chat_screen.dart';

class RequestListScreen extends StatefulWidget {
  @override
  _RequestListScreenState createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  List<RequestModel> requests = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      
      final loadedRequests = await RequestService.getAvailableRequests();
      setState(() {
        requests = loadedRequests;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load requests: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _contactRequester(RequestModel request) async {
    try {
      print('🔍 Request details:');
      print('  requesterId: "${request.requesterId}"');
      print('  requesterName: "${request.requesterName}"');
      print('  request.id: "${request.id}"');
      
      // Validate requesterId before proceeding
      if (request.requesterId.isEmpty) {
        throw Exception('Requester ID is empty');
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
        otherUserId: request.requesterId,
        otherUserName: request.requesterName,
        requestId: request.id,
      );

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            roomId: chatRoom.id,
            otherUserName: request.requesterName,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference > 1) {
      return 'In $difference days';
    } else {
      return 'Overdue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Food Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRequests,
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
                        onPressed: _loadRequests,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No requests available'),
                          SizedBox(height: 8),
                          Text('Check back later for new requests'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          final isOverdue = request.neededBy.isBefore(DateTime.now());
                          
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
                                        _getCategoryIcon(request.foodType),
                                        color: Colors.orange,
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          request.title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isOverdue ? Colors.red : Colors.orange,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _formatDate(request.neededBy),
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
                                    request.description,
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
                                        request.requesterName,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(Icons.inventory, size: 16, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Text(
                                        '${request.quantity} ${request.quantityUnit}',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  if (request.notes != null && request.notes!.isNotEmpty) ...[
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.local_shipping, size: 16, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            request.notes!,
                                            style: TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (request.pickupAddress != null) ...[
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            request.pickupAddress!,
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
                                      onPressed: () => _contactRequester(request),
                                      icon: Icon(Icons.chat),
                                      label: Text('Contact Requester'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
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
