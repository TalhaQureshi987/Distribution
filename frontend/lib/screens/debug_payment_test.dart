import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class DebugPaymentTestScreen extends StatefulWidget {
  @override
  _DebugPaymentTestScreenState createState() => _DebugPaymentTestScreenState();
}

class _DebugPaymentTestScreenState extends State<DebugPaymentTestScreen> {
  Map<String, dynamic>? paymentInfo;
  bool loading = false;

  Future<void> testPaymentCalculation() async {
    setState(() => loading = true);

    try {
      print('🧪 Testing payment calculation for 10km Paid Delivery...');

      final result = await PaymentService.calculatePaymentPreview(
        type: 'donate',
        distance: 10.0,
        deliveryOption: 'Paid Delivery',
      );

      print('🧪 Payment calculation result: $result');

      setState(() {
        paymentInfo = result['paymentInfo'];
      });
    } catch (e) {
      print('❌ Error testing payment calculation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Debug Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: loading ? null : testPaymentCalculation,
              child: loading
                  ? CircularProgressIndicator()
                  : Text('Test Payment Calculation'),
            ),
            SizedBox(height: 20),
            if (paymentInfo != null) ...[
              Text(
                'Payment Info:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fixed Amount: ${paymentInfo!['fixedAmount']} PKR'),
                    Text(
                      'Delivery Charges: ${paymentInfo!['deliveryCharges']} PKR',
                    ),
                    Text('Total Amount: ${paymentInfo!['totalAmount']} PKR'),
                    Text('Distance: ${paymentInfo!['distance']} km'),
                    Text('Delivery Option: ${paymentInfo!['deliveryOption']}'),
                    Text(
                      'Requires Payment: ${paymentInfo!['requiresPayment']}',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
