import 'package:flutter/material.dart';
import '../../services/support_service.dart';

class HelpSupportScreen extends StatelessWidget {
  final List<Map<String, dynamic>> topics = [
    {
      'title': 'How to donate food',
      'icon': Icons.favorite,
      'description': 'Learn how to share surplus food with those in need',
    },
    {
      'title': 'How to request food',
      'icon': Icons.handshake,
      'description': 'Find and request food donations from donors',
    },
    {
      'title': 'Account management',
      'icon': Icons.person,
      'description': 'Manage your profile, settings, and preferences',
    },
    {
      'title': 'Privacy and security',
      'icon': Icons.security,
      'description': 'Understand how we protect your data',
    },
    {
      'title': 'Food safety guidelines',
      'icon': Icons.safety_check,
      'description': 'Important guidelines for safe food sharing',
    },
    {
      'title': 'Contact information',
      'icon': Icons.contact_support,
      'description': 'Get in touch with our support team',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Help & Support'), leading: BackButton()),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help Topics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: topics.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.brown.withOpacity(0.1),
                      child: Icon(topic['icon'], color: Colors.brown, size: 20),
                    ),
                    title: Text(topic['title']),
                    subtitle: Text(topic['description']),
                    onTap: () {
                      _showTopicDetails(context, topic);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.email),
                label: Text('Contact Support'),
                onPressed: () async {
                  try {
                    // Show contact support dialog
                    _showContactSupportDialog(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to contact support: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopicDetails(BuildContext context, Map<String, dynamic> topic) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(topic['icon'], color: Colors.brown),
                SizedBox(width: 8),
                Text(topic['title']),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic['description']),
                SizedBox(height: 16),
                Text(
                  _getTopicContent(topic['title']),
                  style: TextStyle(fontSize: 14),
                ),
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

  String _getTopicContent(String title) {
    switch (title) {
      case 'How to donate food':
        return '1. Go to the Donate screen\n2. Add food details and photos\n3. Set pickup location and time\n4. Wait for requests from users\n5. Coordinate pickup with requesters';
      case 'How to request food':
        return '1. Browse available donations\n2. Select items you need\n3. Contact the donor\n4. Arrange pickup time\n5. Confirm pickup completion';
      case 'Account management':
        return '• Update your profile information\n• Change password and settings\n• View donation and request history\n• Manage notifications';
      case 'Privacy and security':
        return '• Your data is encrypted and secure\n• We never share personal information\n• Location data is only used for matching\n• You can delete your account anytime';
      case 'Food safety guidelines':
        return '• Only donate fresh, unexpired food\n• Store food properly before donation\n• Check food quality before accepting\n• Follow local food safety regulations';
      case 'Contact information':
        return 'Email: support@zerofoodwaste.com\nPhone: +1-555-0123\nHours: Monday-Friday, 9AM-6PM\nResponse time: Within 24 hours';
      default:
        return 'Detailed information will be available soon.';
    }
  }

  void _showContactSupportDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Contact Support'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await SupportService.contactSupport(
                      name: nameController.text,
                      email: emailController.text,
                      subject: subjectController.text,
                      message: messageController.text,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Message sent successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send message: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('Send'),
              ),
            ],
          ),
    );
  }
}
