import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../common/volunteer_screen_new.dart';
import '../common/delivery_screen.dart';

class DonorDeliveryOptionsScreen extends StatelessWidget {
  final String donationId;
  final String donationTitle;
  final Function(String)? onDeliveryOptionSelected;

  const DonorDeliveryOptionsScreen({
    Key? key,
    required this.donationId,
    required this.donationTitle,
    this.onDeliveryOptionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Delivery Options',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_shipping,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How would you like to send your donation?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose the delivery method that works best for you',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (donationTitle.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Donation: $donationTitle',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Volunteer Delivery Option
            _buildDeliveryOptionCard(
              context: context,
              icon: Icons.volunteer_activism,
              title: 'Volunteer Delivery',
              description: 'Delivered by a volunteer near you and shown in volunteer screen.',
              features: [
                'Free volunteer service',
                'Community-driven support',
                'Coordinated through our platform',
                'Eco-friendly option',
              ],
              color: AppTheme.primaryColor,
              onTap: () => _selectDeliveryOption(context, 'Volunteer Delivery'),
            ),
            
            const SizedBox(height: 20),
            
            // Self Delivery Option
            _buildDeliveryOptionCard(
              context: context,
              icon: Icons.directions_car,
              title: 'Self Delivery',
              description: 'I will deliver it myself.',
              features: [
                'Full control over timing',
                'Direct interaction with receiver',
                'No additional costs',
                'Flexible scheduling',
              ],
              color: AppTheme.secondaryColor,
              onTap: () => _selectDeliveryOption(context, 'Self Delivery'),
            ),
            
            const SizedBox(height: 20),
            
            // Paid Delivery Option
            _buildDeliveryOptionCard(
              context: context,
              icon: Icons.payment,
              title: 'Paid Delivery (Earn)',
              description: 'Pay for delivery — helpers can earn.',
              features: [
                'Professional delivery service',
                'Helps others earn income',
                'Tracking and insurance',
                'Guaranteed delivery',
              ],
              color: Color(0xFFD2691E),
              onTap: () => _selectDeliveryOption(context, 'Paid Delivery'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Features list
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  void _selectDeliveryOption(BuildContext context, String option) {
    // Call the callback if provided
    if (onDeliveryOptionSelected != null) {
      onDeliveryOptionSelected!(option);
    }

    // Show confirmation and navigate based on option
    _showConfirmationDialog(context, option);
  }

  void _showConfirmationDialog(BuildContext context, String option) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delivery Option Selected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You have selected: $option'),
              const SizedBox(height: 8),
              if (option == 'Volunteer Delivery')
                Text('Your donation will be listed for volunteer pickup and delivery.')
              else if (option == 'Self Delivery')
                Text('You will coordinate delivery directly with the receiver.')
              else if (option == 'Paid Delivery')
                Text('Your donation will be available for paid delivery services.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateBasedOnOption(context, option);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _navigateBasedOnOption(BuildContext context, String option) {
    switch (option) {
      case 'Volunteer Delivery':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VolunteerScreen(),
          ),
        );
        break;
      case 'Paid Delivery':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryScreen(),
          ),
        );
        break;
      case 'Self Delivery':
        // Navigate back to donation completion or home
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
    }
  }
}
