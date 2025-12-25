import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../auth/identity_verification_screen.dart';

class DeliveryAcceptanceScreen extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final String deliveryType; // 'donation' or 'request'

  const DeliveryAcceptanceScreen({
    Key? key,
    required this.delivery,
    required this.deliveryType,
  }) : super(key: key);

  @override
  _DeliveryAcceptanceScreenState createState() => _DeliveryAcceptanceScreenState();
}

class _DeliveryAcceptanceScreenState extends State<DeliveryAcceptanceScreen> {
  bool _isLoading = false;
  bool _isOfferMade = false;
  bool _isVerified = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Delivery Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeliveryHeader(),
            const SizedBox(height: 20),
            _buildDeliveryDetails(),
            const SizedBox(height: 20),
            _buildLocationDetails(),
            const SizedBox(height: 20),
            _buildDeliveryInstructions(),
            const SizedBox(height: 30),
            if (!_isOfferMade) _buildMakeOfferButton(),
            if (_isOfferMade && !_isVerified) _buildVerificationButton(),
            if (_isVerified) _buildOfferMadeStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryHeader() {
    final isRequest = widget.deliveryType == 'request';
    final title = widget.delivery['title'] ?? (isRequest ? 'Food Request' : 'Food Donation');
    final isPaid = widget.delivery['paymentRequired'] == true || 
                   widget.delivery['paymentAmount'] != null && widget.delivery['paymentAmount'] > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRequest ? Icons.shopping_basket : Icons.volunteer_activism,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isPaid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PAID',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.delivery['description'] ?? 'No description available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          if (isPaid) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Earn PKR ${widget.delivery['paymentAmount'] ?? '50'} for this delivery',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    final foodType = widget.delivery['foodType'] ?? 'Food Item';
    final quantity = widget.delivery['quantity'] ?? 1;
    final quantityUnit = widget.delivery['quantityUnit'] ?? 'items';
    final urgencyLevel = widget.delivery['urgencyLevel'] ?? widget.delivery['isUrgent'] == true ? 'High' : 'Normal';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.fastfood, 'Food Type', foodType),
            _buildDetailRow(Icons.scale, 'Quantity', '$quantity $quantityUnit'),
            _buildDetailRow(Icons.priority_high, 'Urgency', urgencyLevel),
            if (widget.delivery['expiryDate'] != null)
              _buildDetailRow(Icons.schedule, 'Expires', 
                DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.delivery['expiryDate']))),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetails() {
    final pickupAddress = widget.delivery['pickupAddress'] ?? 'Pickup address not provided';
    final deliveryAddress = widget.delivery['deliveryAddress'] ?? widget.delivery['address'] ?? 'Delivery address not provided';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildLocationRow(Icons.location_on, 'Pickup Location', pickupAddress),
            const SizedBox(height: 12),
            _buildLocationRow(Icons.flag, 'Delivery Location', deliveryAddress),
            if (widget.delivery['distance'] != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(Icons.directions, 'Distance', '${widget.delivery['distance']} km'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInstructions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Contact the ${widget.deliveryType == 'request' ? 'requester' : 'donor'} before pickup\n'
                    '• Verify the food items match the description\n'
                    '• Handle food items with care during transport\n'
                    '• Complete delivery within the specified timeframe\n'
                    '• Take photos for delivery confirmation',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.delivery['notes'] != null && widget.delivery['notes'].isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Special Notes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.delivery['notes'],
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMakeOfferButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _makeOffer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Make an offer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyIdentity,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Verify your identity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferMadeStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          Text(
            'Offer made!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have successfully made an offer for this delivery. Please wait for the ${widget.deliveryType == 'request' ? 'requester' : 'donor'} to respond.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.primaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  color: AppTheme.primaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _makeOffer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Call API to make offer
      final response = await ApiService.postJsonAuth(
        '/api/${widget.deliveryType}s/${widget.delivery['_id']}/make-offer',
        body: {
          'offerPersonId': user.id,
          'offerPersonName': user.name,
          'offerMadeAt': DateTime.now().toIso8601String(),
        },
        token: await AuthService.getValidToken(),
      );

      if (response['success'] == true) {
        setState(() {
          _isOfferMade = true;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Offer made successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response['message'] ?? 'Failed to make offer');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyIdentity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = AuthService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Call API to verify identity
      final response = await ApiService.postJsonAuth(
        '/api/users/${user.id}/verify-identity',
        body: {
          'verificationCode': '123456', // Replace with actual verification code
        },
        token: await AuthService.getValidToken(),
      );

      if (response['success'] == true) {
        setState(() {
          _isVerified = true;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Identity verified successfully!',
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response['message'] ?? 'Failed to verify identity');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}