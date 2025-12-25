import 'package:flutter/material.dart';
import 'dart:io';
import '../auth/stripe_payment_screen.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class ConfirmScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Safely convert route arguments to a strongly typed map
    final rawArgs = ModalRoute.of(context)!.settings.arguments as Map;
    final Map<String, dynamic> args = Map<String, dynamic>.from(rawArgs);
    final String category = args['category'] ?? '';
    final String description = args['description'] ?? '';
    final String? imagePath = args['imagePath'];
    final String type = args['type'] ?? 'donate';
    final double? distance = (args['distance'] as num?)?.toDouble();
    final Map<String, dynamic>? paymentInfo = args['paymentInfo'] != null
        ? Map<String, dynamic>.from(args['paymentInfo'])
        : null;

    // Debug logging
    print('🔍 ConfirmScreen: Payment info received: $paymentInfo');
    if (paymentInfo != null) {
      print('🔍 ConfirmScreen: Fixed Amount: ${paymentInfo['fixedAmount']}');
      print(
        '🔍 ConfirmScreen: Delivery Charges: ${paymentInfo['deliveryCharges']}',
      );
      print('🔍 ConfirmScreen: Total Amount: ${paymentInfo['totalAmount']}');
    }
    final double? latitude = (args['latitude'] as num?)?.toDouble();
    final double? longitude = (args['longitude'] as num?)?.toDouble();
    final String? deliveryOption = args['deliveryOption'] as String?;
    final String? neededBy = args['neededBy'] as String?;
    final int? quantity = int.tryParse(args['quantity']?.toString() ?? '');
    final String? quantityUnit = args['quantityUnit'] as String?;
    final String? notes = args['notes'] as String?;
    final bool? isUrgent = args['isUrgent'] as bool?;
    final String? contact = args['contact'] as String?;
    final String? location = args['location'] as String?;

    final bool isDonation = type == 'donate';
    final bool requiresPayment = paymentInfo != null;
    final bool isVolunteerDelivery = args['isVolunteerDelivery'] == true;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Confirmation",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Success Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryColor,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  requiresPayment
                      ? "Payment Required"
                      : isDonation
                      ? "Donation Confirmed!"
                      : "Request Submitted!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  requiresPayment
                      ? "Complete payment to finalize your ${isDonation ? 'donation' : 'request'}"
                      : isDonation
                      ? isVolunteerDelivery
                            ? "Thank you for your generous contribution! A volunteer will be assigned to pick up your donation soon."
                            : "Thank you for your generous contribution!"
                      : "We'll match you with available donors soon.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 32),

                // Details Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _infoRow("Category", category),
                        const SizedBox(height: 12),
                        _infoRow("Description", description),
                        if (contact != null && contact.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _infoRow("Contact", contact),
                        ],
                        if (location != null && location.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _infoRow("Location", location),
                        ],
                        if (deliveryOption != null) ...[
                          const SizedBox(height: 12),
                          _infoRow("Delivery", deliveryOption),
                        ],
                      ],
                    ),
                  ),
                ),

                // Payment Info Card
                if (requiresPayment) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.payment,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Payment Summary",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _paymentRow(
                            "Fixed Amount",
                            "${(paymentInfo['fixedAmount'] as num?)?.toStringAsFixed(0) ?? '0'} PKR",
                          ),
                          const SizedBox(height: 8),
                          _paymentRow(
                            "Delivery Charges",
                            "${(paymentInfo['deliveryCharges'] as num?)?.toStringAsFixed(0) ?? '0'} PKR",
                          ),
                          const SizedBox(height: 8),
                          Container(height: 1, color: AppTheme.dividerColor),
                          const SizedBox(height: 8),
                          _paymentRow(
                            "Total Amount",
                            "${(paymentInfo['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'} PKR",
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Image Preview
                if (isDonation &&
                    imagePath != null &&
                    imagePath.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Photo",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(imagePath),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      if (requiresPayment) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.payment, color: Colors.white),
                            label: Text(
                              "Proceed to Payment",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StripePaymentScreen(
                                    userId: AuthService.currentUser?.id ?? '',
                                    amount: (paymentInfo['totalAmount'] as num)
                                        .toInt(),
                                    userEmail:
                                        AuthService.currentUser?.email ?? '',
                                    userName:
                                        AuthService.currentUser?.name ?? '',
                                    paymentType: 'donation',
                                    requestData: <String, dynamic>{
                                      'category': category,
                                      'description': description,
                                      'imagePath': imagePath,
                                      'distance': distance,
                                      'latitude': latitude,
                                      'longitude': longitude,
                                      'deliveryOption': deliveryOption,
                                      'neededBy': neededBy,
                                      'quantity': quantity,
                                      'quantityUnit': quantityUnit,
                                      'notes': notes,
                                      'isUrgent': isUrgent ?? false,
                                      'contact': contact,
                                      'location': location,
                                      'paymentInfo': paymentInfo,
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppTheme.primaryColor),
                              ),
                            ),
                            child: Text(
                              "Back to Edit",
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.home, color: Colors.white),
                            label: Text(
                              "Return to Home",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: isDonation
                                ? () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.pending_actions,
                                                  color: Colors.orange,
                                                  size: 24,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Donation Submitted',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange[700],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.info,
                                                      color: Colors.blue,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        isVolunteerDelivery
                                                            ? 'Your donation is in verification process. Once approved, volunteers will be notified and one will be assigned to pick up your donation. You will receive email notifications throughout the process.'
                                                            : 'Your donation is in verification process. Admin will verify and you will receive email notification.',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                // Navigate to donor dashboard instead of logout
                                                Navigator.pushNamedAndRemoveUntil(
                                                  context,
                                                  '/donor-dashboard',
                                                  (route) => false,
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.orange[700],
                                                foregroundColor: Colors.white,
                                              ),
                                              child: Text('Go to Dashboard'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                : () {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      '/donor-dashboard',
                                      (route) => false,
                                    );
                                  },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            "$label:",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _paymentRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal
                ? AppTheme.primaryColor
                : AppTheme.secondaryTextColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppTheme.primaryColor : AppTheme.primaryTextColor,
          ),
        ),
      ],
    );
  }
}
