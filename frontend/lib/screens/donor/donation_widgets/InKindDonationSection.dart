// lib/screens/donor/donation_widgets/InKindDonationSection.dart
import 'package:flutter/material.dart';
import 'dart:io';

class InKindDonationSection extends StatelessWidget {
  final File? donationImage;
  final VoidCallback onPickImage;
  final VoidCallback? onClearImage; // optional clear callback
  final TextEditingController descriptionController;
  final String selectedCategory;
  final TextEditingController expiryController;
  final TextEditingController packagingController;
  final TextEditingController prescriptionController;
  final TextEditingController genderAgeController;
  final TextEditingController conditionController;
  final TextEditingController contactController;
  final TextEditingController locationController;

  const InKindDonationSection({
    Key? key,
    required this.donationImage,
    required this.onPickImage,
    this.onClearImage,
    required this.descriptionController,
    required this.selectedCategory,
    required this.expiryController,
    required this.packagingController,
    required this.prescriptionController,
    required this.genderAgeController,
    required this.conditionController,
    required this.contactController,
    required this.locationController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _sectionTitle("Add a Photo (optional)"),
        _buildImageUploadCard(),
        _sectionTitle("Donation Details"),
        _buildDonationDetailsCard(),
        if (selectedCategory == 'Food') _buildFoodFields(),
        if (selectedCategory == 'Medicine') _buildMedicineFields(),
        if (selectedCategory == 'Clothes') _buildClothesFields(),
        _buildContactFields(),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2, top: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildImageUploadCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (donationImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  donationImage!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Image',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    // call onClearImage if provided, otherwise do nothing
                    onPressed: onClearImage ?? () {},
                    tooltip: 'Remove selected image',
                  ),
                ],
              ),
              const Divider(),
            ],
            ElevatedButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.upload),
              label: Text(
                donationImage == null ? 'Upload Image' : 'Change Image',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload clear photos of your donation (max 5MB)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationDetailsCard() {
    IconData icon;
    Color iconColor;
    String hint;
    
    switch (selectedCategory) {
      case 'Food':
        icon = Icons.restaurant;
        iconColor = Colors.orange.shade700;
        hint = 'Describe the food you want to donate (type, quantity, etc.)';
        break;
      case 'Medicine':
        icon = Icons.medical_services;
        iconColor = Colors.red.shade700;
        hint = 'Describe the medicine you want to donate (name, expiry, etc.)';
        break;
      case 'Clothes':
        icon = Icons.checkroom;
        iconColor = Colors.blue.shade700;
        hint = 'Describe the clothes you want to donate (type, size, etc.)';
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.brown;
        hint = 'Tell us about your donation (optional)';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description*',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 5,
                          minLines: 3,
                          decoration: InputDecoration(
                            hintText: hint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodFields() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: expiryController,
          decoration: InputDecoration(
            labelText: 'Expiry Date',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: packagingController,
          decoration: InputDecoration(
            labelText: 'Packaging Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineFields() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: expiryController,
          decoration: InputDecoration(
            labelText: 'Expiry Date',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: prescriptionController,
          decoration: InputDecoration(
            labelText: 'Prescription Required?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildClothesFields() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: genderAgeController,
          decoration: InputDecoration(
            labelText: 'Gender/Age Group',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: conditionController,
          decoration: InputDecoration(
            labelText: 'Condition',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildContactFields() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextFormField(
          controller: contactController,
          decoration: InputDecoration(
            labelText: 'Contact Number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: locationController,
          decoration: InputDecoration(
            labelText: 'Pickup Location',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
