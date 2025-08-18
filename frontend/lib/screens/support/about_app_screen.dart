import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('About App'), leading: BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.brown.withOpacity(0.1),
                    child: Icon(Icons.favorite, size: 50, color: Colors.brown),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Zero Food Waste',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Text(
              'About',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Zero Food Waste is a community-driven platform that connects food donors with those in need, helping reduce food waste and hunger in our communities.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            Text(
              'Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _featureItem(
              'Donate Food',
              'Share surplus food with those in need',
            ),
            _featureItem('Request Food', 'Find and request food donations'),
            _featureItem(
              'Real-time Chat',
              'Communicate with donors and requesters',
            ),
            _featureItem(
              'Track History',
              'Monitor your donations and requests',
            ),
            SizedBox(height: 24),
            Text(
              'Developer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Developed with ❤️ for the community',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            Center(
              child: Text(
                '© 2024 Zero Food Waste. All rights reserved.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
