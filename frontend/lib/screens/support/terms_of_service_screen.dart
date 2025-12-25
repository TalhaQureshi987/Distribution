import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Terms of Service'), leading: BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Last updated: January 2024',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            SizedBox(height: 24),
            _section(
              'Acceptance of Terms',
              'By accessing and using the Care Connect app, you accept and agree to be bound by the terms and provision of this agreement.',
            ),
            _section(
              'Description of Service',
              'Care Connect is a platform that connects food donors with individuals in need, facilitating the sharing of surplus food to reduce waste and help those in need.',
            ),
            _section(
              'User Responsibilities',
              'Users are responsible for providing accurate information, maintaining the security of their accounts, and ensuring that donated food is safe and suitable for consumption.',
            ),
            _section(
              'Prohibited Activities',
              'Users may not use the service for illegal purposes, post false information, harass other users, or violate any applicable laws or regulations.',
            ),
            _section(
              'Food Safety',
              'Donors are responsible for ensuring that donated food is safe, properly stored, and within acceptable expiration dates. Recipients should verify food quality before consumption.',
            ),
            _section(
              'Privacy and Data',
              'Your privacy is important to us. Please review our Privacy Policy, which also governs your use of the service, to understand our practices.',
            ),
            _section(
              'Intellectual Property',
              'The service and its original content, features, and functionality are owned by Care Connect and are protected by international copyright, trademark, and other intellectual property laws.',
            ),
            _section(
              'Limitation of Liability',
              'Care Connect is not liable for any damages arising from the use of our service, including but not limited to food safety issues, user disputes, or technical problems.',
            ),
            _section(
              'Termination',
              'We may terminate or suspend your account and bar access to the service immediately, without prior notice, for any reason, including breach of the Terms.',
            ),
            _section(
              'Changes to Terms',
              'We reserve the right to modify or replace these terms at any time. If a revision is material, we will provide at least 30 days notice prior to any new terms taking effect.',
            ),
            _section(
              'Contact Information',
              'If you have any questions about these Terms of Service, please contact us at legal@careconnect.com',
            ),
            SizedBox(height: 32),
            Center(
              child: Text(
                'By using our app, you agree to these terms of service.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(content, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
