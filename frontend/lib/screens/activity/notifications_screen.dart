import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final result = await NotificationService.getUserNotifications();
      setState(() {
        notifications =
            result
                .map(
                  (notification) => {
                    'id': notification['_id'],
                    'title': notification['title'],
                    'message': notification['message'],
                    'type': notification['type'],
                    'read': notification['read'] ?? false,
                    'createdAt': notification['createdAt'],
                  },
                )
                .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: $e')),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        leading: BackButton(),
        actions: [
          IconButton(
            icon: Icon(Icons.mark_email_read),
            onPressed: () async {
              try {
                await NotificationService.markAllNotificationsAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All notifications marked as read'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to mark notifications as read: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? Center(child: Text('No notifications yet.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color:
                        notification['read'] ? Colors.white : Colors.blue[50],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getNotificationColor(
                          notification['type'],
                        ),
                        child: Icon(
                          _getNotificationIcon(notification['type']),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        notification['title'],
                        style: TextStyle(
                          fontWeight:
                              notification['read']
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification['message']),
                          SizedBox(height: 4),
                          Text(
                            _formatTime(
                              DateTime.parse(notification['createdAt']),
                            ),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        try {
                          // Mark notification as read when tapped
                          await NotificationService.markNotificationAsRead(
                            notification['id'] ?? '',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Notification: ${notification['title']}',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error handling notification: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'donation':
        return Color(0xFF8B4513); // Brown theme color
      case 'request':
        return Color(0xFFD2691E); // Brown-orange theme color
      case 'message':
        return Color(0xFFCD853F); // Peru brown for messages
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'donation':
        return Icons.favorite;
      case 'request':
        return Icons.handshake;
      case 'message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }
}
