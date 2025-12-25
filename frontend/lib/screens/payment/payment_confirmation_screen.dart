import 'package:flutter/material.dart';
import '../../services/request_service.dart';
import '../../services/donation_service.dart';
import '../../services/payment_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String type;
  final Map<String, dynamic>? itemData;
  final String? userId;
  final double? registrationAmount;
  final String? paymentIntentId;
  final String? clientSecret;
  final double? amount;

  const PaymentConfirmationScreen({
    Key? key,
    required this.type,
    this.itemData,
    this.userId,
    this.registrationAmount,
    this.paymentIntentId,
    this.clientSecret,
    this.amount,
  }) : super(key: key);

  @override
  _PaymentConfirmationScreenState createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  String? _paymentIntentId;
  String? _clientSecret;
  bool _isProcessing = false;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _paymentIntentId = widget.paymentIntentId;
    _clientSecret = widget.clientSecret;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_paymentIntentId == null || _clientSecret == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment intent not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // For registration payments, redirect to proper payment screen
      if (widget.type == 'registration') {
        Navigator.pushReplacementNamed(
          context,
          '/stripe-payment',
          arguments: {
            'type': 'registration',
            'amount': widget.amount ?? widget.registrationAmount ?? 500,
            'paymentIntentId': _paymentIntentId,
            'clientSecret': _clientSecret,
          },
        );
        return;
      }

      // For donation/request payments, confirm the payment intent
      print('💳 Confirming payment for ${widget.type}');
      print('💳 Payment Intent ID: $_paymentIntentId');
      print('💳 Amount: ${widget.amount ?? widget.registrationAmount ?? 500}');

      // Call backend to confirm payment
      final response = await ApiService.postJson(
        '/api/payments/confirm-payment',
        body: {
          'paymentIntentId': _paymentIntentId,
          'type': widget.type,
          'amount': widget.amount ?? widget.registrationAmount ?? 500,
        },
        token: await AuthService.getValidToken(),
      );

      if (response['success'] == true) {
        print('✅ Payment confirmed successfully');

        // Process the item creation after successful payment
        await _createItemAfterPayment(
          widget.amount ?? widget.registrationAmount ?? 500,
        );
      } else {
        throw Exception(response['message'] ?? 'Payment confirmation failed');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      print('❌ Payment confirmation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createItemAfterPayment(double totalAmount) async {
    if (widget.type == 'request') {
      try {
        final category = widget.itemData?['category'] ?? 'Food';
        final description = widget.itemData?['description'] ?? '';
        final location = widget.itemData?['location'] ?? '';
        final deliveryOption =
            widget.itemData?['deliveryOption'] ?? 'Self delivery';
        final neededBy = widget.itemData?['neededBy'];
        final imagePath = widget.itemData?['imagePath'];
        final latitude = (widget.itemData?['latitude'] as num?)?.toDouble();
        final longitude = (widget.itemData?['longitude'] as num?)?.toDouble();
        final distance =
            (widget.itemData?['distance'] as num?)?.toDouble() ?? 0.0;
        final notes = widget.itemData?['notes'] ?? '';
        final quantity = (widget.itemData?['quantity'] as num?)?.toInt() ?? 1;
        final quantityUnit = widget.itemData?['quantityUnit'] ?? 'pieces';

        print('� Processing payment for $deliveryOption delivery');
        print('� Total payment amount: $totalAmount PKR');
        print('� Service fee: 100 PKR (mandatory for all requests)');
        print('💳 Distance: ${distance}km');

        // Calculate delivery fee based on delivery option
        double deliveryFee = 0.0;
        double serviceFee = 100.0; // Mandatory service fee for ALL requests

        if (deliveryOption == 'Paid Delivery') {
          deliveryFee =
              totalAmount - serviceFee; // Total minus 100 PKR service fee
          print('💳 Delivery charges: $deliveryFee PKR (distance-based)');
        } else {
          // Volunteer Delivery and Self delivery have no delivery charges
          deliveryFee = 0.0;
          print('💳 Delivery charges: 0 PKR ($deliveryOption - FREE delivery)');
        }

        // Validate minimum payment (service fee)
        if (totalAmount < serviceFee) {
          throw Exception(
            'Invalid payment: All requests require minimum $serviceFee PKR service fee',
          );
        }

        print(
          '💳 Final breakdown: Service Fee: $serviceFee PKR + Delivery: $deliveryFee PKR = Total: $totalAmount PKR',
        );

        final result = await RequestService.createRequest({
          'title': '$category Request',
          'description': description,
          'foodType': category,
          'quantity': quantity,
          'quantityUnit': quantityUnit,
          'neededBy': neededBy,
          'pickupAddress': location,
          'latitude': latitude,
          'longitude': longitude,
          'deliveryOption': deliveryOption, // ✅ Properly pass delivery option
          'distance': distance,
          'notes': notes,
          'isUrgent': false,
          'images': imagePath != null ? [imagePath] : [],
          'paymentAmount':
              deliveryFee, // ✅ Pass delivery fee (excluding request fee)
          'totalAmount':
              totalAmount, // ✅ Pass total amount including request fee
          'requestFee': serviceFee, // ✅ Pass request fee
          'paymentStatus': 'paid', // ✅ Mark as paid since payment completed
          'stripePaymentIntentId':
              _paymentIntentId, // ✅ Include payment intent ID
          // Category-specific fields from itemData
          'medicineName': widget.itemData?['medicineName'],
          'prescriptionRequired': widget.itemData?['prescriptionRequired'],
          'foodName': widget.itemData?['foodName'],
          'foodCategory': widget.itemData?['foodCategory'],
          'clothesGenderAge': widget.itemData?['clothesGenderAge'],
          'clothesCondition': widget.itemData?['clothesCondition'],
          'otherDescription': widget.itemData?['otherDescription'],
        });

        if (result['success'] == true) {
          print('✅ Request created successfully after payment');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          throw Exception(result['message'] ?? 'Failed to create request');
        }
      } catch (e) {
        print('❌ Error creating request after payment: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (widget.type == 'donation') {
      try {
        final category = widget.itemData?['category'] ?? '';
        final description = widget.itemData?['description'] ?? '';
        final quantity = (widget.itemData?['quantity'] as num?)?.toInt() ?? 1;
        final location = widget.itemData?['location'] ?? '';
        final expiryDate = widget.itemData?['expiryDate'];
        final imagePath = widget.itemData?['imagePath'];
        final latitude = (widget.itemData?['latitude'] as num?)?.toDouble();
        final longitude = (widget.itemData?['longitude'] as num?)?.toDouble();
        final distance =
            (widget.itemData?['distance'] as num?)?.toDouble() ?? 0.0;
        final notes = widget.itemData?['notes'] ?? '';

        await DonationService.createDonation(
          title: '$category Donation',
          description: description,
          foodType: category,
          quantity: quantity,
          quantityUnit: 'pieces',
          expiryDate: expiryDate != null
              ? DateTime.parse(expiryDate)
              : DateTime.now().add(Duration(days: 7)),
          pickupAddress: location,
          latitude: latitude ?? 0.0,
          longitude: longitude ?? 0.0,
          distance: distance,
          notes: notes,
          isUrgent: false,
          images: imagePath != null ? [imagePath] : [],
          // Payment-related fields
          paymentAmount: totalAmount,
          paymentStatus: 'paid',
          deliveryOption: widget.itemData?['deliveryOption'] ?? 'Paid Delivery',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating donation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (widget.type == 'registration') {
      try {
        // Complete registration payment
        final result = await PaymentService.completeRegistrationPayment(
          userId: widget.userId!,
          amount: widget.registrationAmount!.toInt(),
          paymentIntentId: _paymentIntentId!,
        );

        if (result['success'] == true) {
          print('✅ Registration payment completed successfully');
          print('   User data: ${result['user']}');
          print('   User email: ${result['user']?['email']}');
          print('   User ID: ${widget.userId}');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment successful! Please verify your email.'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to email OTP verification for registration
          final email = result['user']?['email'] ?? '';
          print('🔄 Navigating to email OTP verification with email: $email');

          Navigator.pushReplacementNamed(
            context,
            '/email-otp-verification',
            arguments: {
              'email': email,
              'userId': widget.userId,
              'userData': result['user'],
            },
          );
        } else {
          throw Exception(result['message'] ?? 'Registration failed');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Payment Confirmation'),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 100),
              SizedBox(height: 20),
              Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Processing your registration...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: Text('Continue'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Confirmation'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registration Fee: PKR ${widget.registrationAmount ?? 500}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Payment Intent ID: ${_paymentIntentId ?? 'Not available'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Amount: PKR ${widget.registrationAmount ?? 500}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Status: Ready for confirmation',
                    style: TextStyle(fontSize: 12, color: Colors.green[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Click the button below to confirm your payment and complete registration.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Processing...'),
                        ],
                      )
                    : Text(
                        'Confirm Payment - PKR ${widget.registrationAmount ?? 500}',
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Note: Payment will be processed securely through Stripe',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
