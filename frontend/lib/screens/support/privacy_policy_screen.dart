import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Privacy Policy'), leading: BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Last updated: January 2024',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            SizedBox(height: 24),
            _section(
              'Information We Collect',
              'We collect information you provide directly to us, such as when you create an account, make a donation, or request food. This may include your name, email address, phone number, and location.',
            ),
            _section(
              'How We Use Your Information',
              'We use the information we collect to provide, maintain, and improve our services, communicate with you, and ensure the safety and security of our community.',
            ),
            _section(
              'Information Sharing',
              'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as described in this policy.',
            ),
            _section(
              'Data Security',
              'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.',
            ),
            _section(
              'Your Rights',
              'You have the right to access, update, or delete your personal information. You can also opt out of certain communications and data collection.',
            ),
            _section(
              'Cookies and Tracking',
              'We may use cookies and similar technologies to enhance your experience and collect usage information to improve our services.',
            ),
            _section(
              'Children\'s Privacy',
              'Our services are not intended for children under 13. We do not knowingly collect personal information from children under 13.',
            ),
            _section(
              'Changes to This Policy',
              'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page.',
            ),
            _section(
              'Contact Us',
              'If you have any questions about this privacy policy, please contact us at privacy@zerofoodwaste.com',
            ),
            SizedBox(height: 32),
            Center(
              child: Text(
                'By using our app, you agree to this privacy policy.',
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
