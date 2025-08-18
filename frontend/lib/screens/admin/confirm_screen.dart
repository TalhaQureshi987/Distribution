import 'package:flutter/material.dart';
import 'dart:io';

class ConfirmScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String category = args['category'] ?? '';
    final String description = args['description'] ?? '';
    final String? imagePath = args['imagePath'];
    final String type = args['type'] ?? 'donate';

    final bool isDonation = type == 'donate';

    return Scaffold(
      appBar: AppBar(title: Text("Confirmation")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 60),
                  SizedBox(height: 20),
                  Text(
                    isDonation
                        ? "Thank you for your generous donation!"
                        : "Your request has been successfully submitted!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Divider(thickness: 1),
                  SizedBox(height: 10),
                  _infoRow("Category", category),
                  SizedBox(height: 10),
                  _infoRow("Description", description),
                  if (isDonation && imagePath != null && imagePath.isNotEmpty) ...[
                    SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(imagePath), height: 150),
                    ),
                  ],
                  SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: Icon(Icons.home),
                    label: Text("Return to Home"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    },
                  ),
                ],
              ),
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
        Text("$label: ", style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
