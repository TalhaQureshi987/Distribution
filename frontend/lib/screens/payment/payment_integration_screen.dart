import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class PaymentIntegrationScreen extends StatefulWidget {
  final String userId;
  final double amount;
  final String userEmail;
  final String userName;
  final String paymentType;
  final Map<String, dynamic>? requestData;

  const PaymentIntegrationScreen({
    Key? key,
    required this.userId,
    required this.amount,
    required this.userEmail,
    required this.userName,
    required this.paymentType,
    this.requestData,
  }) : super(key: key);

  @override
  _PaymentIntegrationScreenState createState() =>
      _PaymentIntegrationScreenState();
}

class _PaymentIntegrationScreenState extends State<PaymentIntegrationScreen> {
  bool _isLoading = false;
  String? _paymentIntentId;
  String? _clientSecret;

  @override
  void initState() {
    super.initState();
    _createPaymentIntent();
  }

  Future<void> _createPaymentIntent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.postJson(
        '/api/payments/create-payment-intent',
        body: {
          'amount': (widget.amount * 100).toInt(), // Convert to cents
          'currency': 'pkr',
          'paymentType': widget.paymentType,
          'userId': widget.userId,
          'userEmail': widget.userEmail,
          'userName': widget.userName,
          'requestData': widget.requestData,
        },
        token: await AuthService.getValidToken(),
      );

      if (response['success'] == true) {
        setState(() {
          _paymentIntentId = response['paymentIntentId'];
          _clientSecret = response['clientSecret'];
        });
      } else {
        throw Exception(
          response['message'] ?? 'Failed to create payment intent',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Integration'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Amount: PKR ${widget.amount}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_paymentIntentId != null)
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
                      'Payment Intent Created',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Payment Intent ID: $_paymentIntentId',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Client Secret: ${_clientSecret?.substring(0, 20) ?? 'Not available'}...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Amount: PKR ${widget.amount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Status: Ready for payment',
                      style: TextStyle(fontSize: 12, color: Colors.green[600]),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20),
            Text(
              'This screen handles payment integration with Stripe.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
