import 'package:flutter/material.dart';

class DeliveryButton extends StatelessWidget {
  final String? foodItem;
  final String? donorName;

  const DeliveryButton({Key? key, this.foodItem, this.donorName})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/delivery');
        },
        icon: Icon(Icons.location_on),
        label: Text('Set Delivery Location'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.brown,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
