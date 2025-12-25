import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/request_service.dart';
import '../../services/donation_service.dart';
import '../../services/payment_service.dart';
import '../../utils/location_utils.dart';
import '../../theme/app_theme.dart';
import 'email_otp_verification_screen.dart';

class StripePaymentScreen extends StatefulWidget {
  final String userId;
  final int amount;
  final String userEmail;
  final String userName;
  final String? paymentType; // 'registration' or 'request'
  final Map<String, dynamic>? requestData; // For request payments

  const StripePaymentScreen({
    Key? key,
    required this.userId,
    required this.amount,
    required this.userEmail,
    required this.userName,
    this.paymentType = 'registration',
    this.requestData,
  }) : super(key: key);

  @override
  State<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends State<StripePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  String _selectedPaymentMethod = 'stripe';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userName;
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _formatCardNumber(String value) {
    value = value.replaceAll(' ', '');
    String formatted = '';
    for (int i = 0; i < value.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += value[i];
    }
    return formatted;
  }

  String _formatExpiry(String value) {
    value = value.replaceAll('/', '');
    if (value.length >= 2) {
      return '${value.substring(0, 2)}/${value.substring(2)}';
    }
    return value;
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create payment intent first
      final paymentIntent =
          await PaymentService.createPaymentIntentForRegistrationFee(
            amount: widget.amount,
            currency: 'PKR',
            userId: widget.userId,
            description: 'Registration Fee - PKR ${widget.amount}',
          );

      // Confirm payment with Stripe using card details
      final confirmationResult = await PaymentService.confirmPaymentIntent(
        paymentIntentId: paymentIntent['paymentIntentId'],
        clientSecret: paymentIntent['clientSecret'],
        paymentMethod: {
          'cardNumber': _cardNumberController.text.replaceAll(' ', ''),
          'expiryMonth': _expiryController.text.split('/')[0],
          'expiryYear': '20${_expiryController.text.split('/')[1]}',
          'cvc': _cvcController.text,
          'cardholderName': _nameController.text,
        },
      );

      if (confirmationResult['success'] == true) {
        // Complete the registration payment
        final result = await PaymentService.completeRegistrationPayment(
          userId: widget.userId,
          paymentIntentId: paymentIntent['paymentIntentId'],
          amount: widget.amount,
        );

        final paymentResponse = {
          'success': result['success'],
          'paymentIntentId': paymentIntent['paymentIntentId'],
        };

        if (paymentResponse['success'] == true) {
          if (widget.paymentType == 'request' && widget.requestData != null) {
            // Handle request payment success - CREATE THE REQUEST!
            try {
              print(' Payment successful! Creating request...');

              final requestData = widget.requestData!;
              final result = await RequestService.createRequest({
                'title': '${requestData['category']} Request',
                'description': requestData['description'],
                'foodType': requestData['category'],
                'quantity': int.tryParse(requestData['amount'] ?? '1') ?? 1,
                'quantityUnit': requestData['quantityUnit'] ?? 'pieces',
                'neededBy': requestData['neededBy'],
                'pickupAddress': requestData['location'],
                'latitude': requestData['latitude'],
                'longitude': requestData['longitude'],
                'deliveryOption': requestData['deliveryOption'],
                'distance': requestData['distance'],
                'notes': requestData['notes'] ?? '',
                'isUrgent': requestData['isUrgent'] ?? false,
                'images': requestData['imagePath'] != null
                    ? [requestData['imagePath']]
                    : [],
                'paymentAmount':
                    widget.amount - 100, // Delivery fee (total - service fee)
                'totalAmount': widget.amount, // Total amount paid
                'requestFee': 100.0, // Service fee
                'paymentStatus': 'paid',
                'stripePaymentIntentId':
                    paymentResponse['paymentIntentId'] ?? 'mock_payment_id',
                // Category-specific fields
                'medicineName': requestData['medicineName'],
                'prescriptionRequired': requestData['prescriptionRequired'],
                'foodName': requestData['foodName'],
                'foodCategory': requestData['foodCategory'],
                'clothesGenderAge': requestData['clothesGenderAge'],
                'clothesCondition': requestData['clothesCondition'],
                'otherDescription': requestData['otherDescription'],
              });

              if (result['success'] == true) {
                print(
                  ' Request created successfully! ID: ${result['requestId']}',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Payment successful! Request submitted for admin verification.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                throw Exception(
                  result['message'] ?? 'Failed to create request',
                );
              }
            } catch (e) {
              print('❌ Error creating request: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Request creation failed: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }

            // Navigate back to dashboard
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else if (widget.paymentType == 'registration') {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Please verify your email.'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to email verification
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmailOTPVerificationScreen(
                email: widget.userEmail,
                userId: widget.userId,
                userData: {
                  'name': widget.userName,
                  'email': widget.userEmail,
                  'paymentCompleted': true,
                },
              ),
            ),
          );
        } else if (widget.paymentType == 'donation' &&
            widget.requestData != null) {
          // Handle donation payment success - CREATE THE DONATION!
          try {
            print('💰 Donation payment successful! Creating donation...');

            final donationData = widget.requestData!;

            final donation = await DonationService.createDonation(
              title: '${donationData['category']} Donation',
              description: donationData['description'] ?? '',
              foodType: donationData['category'] ?? 'Other',
              quantity:
                  int.tryParse(donationData['quantity']?.toString() ?? '1') ??
                  1,
              quantityUnit: donationData['quantityUnit'] ?? 'items',
              expiryDate: donationData['expiryDate'] != null
                  ? DateTime.parse(donationData['expiryDate'])
                  : DateTime.now().add(const Duration(days: 7)),
              pickupAddress: donationData['location'] ?? '',
              latitude:
                  (donationData['latitude'] as num?)?.toDouble() ??
                  LocationUtils.centerLatitude,
              longitude:
                  (donationData['longitude'] as num?)?.toDouble() ??
                  LocationUtils.centerLongitude,
              notes: donationData['notes'] ?? '',
              deliveryOption: donationData['deliveryOption'] ?? 'Paid Delivery',
              distance: (donationData['distance'] as num?)?.toDouble(),
              paymentAmount: widget.amount.toDouble(),
              paymentStatus: 'paid',
              stripePaymentIntentId:
                  (paymentResponse['paymentIntentId'] as String?) ??
                  'mock_payment_id',
            );

            print('✅ Donation created successfully! ID: ${donation.id}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Payment successful! Donation submitted for admin verification.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            print('❌ Error creating donation: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Donation creation failed: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }

          // Navigate back to dashboard
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          throw Exception('Payment confirmation failed');
        }
      } else {
        throw Exception(
          confirmationResult['message'] ?? 'Payment confirmation failed',
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount', style: TextStyle(fontSize: 16)),
                      Text(
                        'PKR ${widget.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'PKR ${widget.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Test Card Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Test Card Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Card Number: 4242 4242 4242 4242'),
                  const Text('Expiry: Any future date (e.g., 12/25)'),
                  const Text('CVC: Any 3 digits (e.g., 123)'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method Selection
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.primaryColor.withOpacity(0.05),
              ),
              child: Row(
                children: [
                  Icon(Icons.credit_card, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Credit/Debit Card (Stripe)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Radio<String>(
                    value: 'stripe',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) =>
                        setState(() => _selectedPaymentMethod = value!),
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card Details Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Card Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cardholder Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Cardholder Name',
                      prefixIcon: const Icon(
                        Icons.person,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter cardholder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Card Number
                  TextFormField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Card Number',
                      prefixIcon: const Icon(
                        Icons.credit_card,
                        color: AppTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      String formatted = _formatCardNumber(value);
                      if (formatted != value) {
                        _cardNumberController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                      }
                    },
                    validator: (value) {
                      if (value == null ||
                          value.replaceAll(' ', '').length != 16) {
                        return 'Please enter a valid 16-digit card number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Expiry and CVC Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: InputDecoration(
                            labelText: 'MM/YY',
                            prefixIcon: const Icon(
                              Icons.calendar_month,
                              color: AppTheme.primaryColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            String formatted = _formatExpiry(value);
                            if (formatted != value) {
                              _expiryController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                  offset: formatted.length,
                                ),
                              );
                            }
                          },
                          validator: (value) {
                            if (value == null || value.length != 5) {
                              return 'MM/YY';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _cvcController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: 'CVC',
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: AppTheme.primaryColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length != 3) {
                              return 'CVC';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Pay PKR ${widget.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Security Notice
            Row(
              children: [
                Icon(Icons.security, color: Colors.grey.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your payment information is secure and encrypted',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
