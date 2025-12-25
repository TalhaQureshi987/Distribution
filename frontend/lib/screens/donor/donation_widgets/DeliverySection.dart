// lib/screens/donor/donation_widgets/DeliverySection.dart
import 'package:flutter/material.dart';

class DeliverySection extends StatelessWidget {
  final List<String> deliveryOptions;
  final String? selectedDeliveryOption;
  final Function(String?) onDeliveryOptionSelected;

  const DeliverySection({
    Key? key,
    required this.deliveryOptions,
    required this.selectedDeliveryOption,
    required this.onDeliveryOptionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Divider(height: 24, thickness: 1, color: Colors.grey[200]),
        Text(
          "Delivery Option",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: deliveryOptions.map((option) => RadioListTile<String>(
                title: Text(option),
                subtitle: option == 'Paid Delivery'
                    ? Text('299 PKR fee applies for logistics support')
                    : null,
                value: option,
                groupValue: selectedDeliveryOption,
                onChanged: onDeliveryOptionSelected,
                activeColor: Colors.brown,
              )).toList(),
            ),
          ),
        ),
        if (selectedDeliveryOption == null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              "Please select a delivery option",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}