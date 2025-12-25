// lib/screens/donor/donation_widgets/PrivacySection.dart
import 'package:flutter/material.dart';

class PrivacySection extends StatelessWidget {
  final bool isAnonymous;
  final Function(bool) onPrivacyChanged;

  const PrivacySection({
    Key? key,
    required this.isAnonymous,
    required this.onPrivacyChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "Privacy",
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_off, color: Colors.grey[600], size: 25),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Make this donation anonymous',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(width: 5),
                        Tooltip(
                          message: 'Your name will not be shown to the recipient.',
                          child: Icon(Icons.info_outline, color: Colors.grey[400], size: 10),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isAnonymous,
                    onChanged: onPrivacyChanged,
                    activeColor: Colors.brown,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}